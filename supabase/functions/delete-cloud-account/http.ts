import type { SealedAppleToken } from './apple.ts';
import type { DeletionBackend, DeletionJob, DeletionPhase } from './worker.ts';

export interface DeletionOwner { accountID: string; sessionID: string; appleSubject: string }
export type DeletionStatus = { state: 'pending' | 'complete'; jobID: string } | { state: 'notFound' };
export interface BackendConfiguration { url: string; publishableKey: string; secretKey: string }

export function object(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
export function uuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}
const invalid = (): never => { throw new Error('deletion_request_unconfirmed'); };

export async function boundedJSON(message: Request | Response, maximum = 131_072): Promise<unknown> {
  if (!message.body) return null;
  const reader = message.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      length += next.value.length;
      if (length > maximum) { await reader.cancel(); return invalid(); }
      chunks.push(next.value);
    }
  } finally { reader.releaseLock(); }
  if (length === 0) return null;
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
  catch { return invalid(); }
}

function status(value: unknown): DeletionStatus {
  if (!object(value)) return invalid();
  if (value.state === 'notFound') return { state: 'notFound' };
  if ((value.state === 'pending' || value.state === 'complete') && uuid(value.jobID)) {
    return { state: value.state, jobID: value.jobID };
  }
  return invalid();
}
function job(value: unknown): DeletionJob {
  if (!object(value) || !uuid(value.jobID) || !uuid(value.accountID) || !uuid(value.workspaceID) ||
      !uuid(value.leaseID) || typeof value.photosRemoved !== 'boolean' ||
      typeof value.recordsRemoved !== 'boolean' || typeof value.appleRevoked !== 'boolean') return invalid();
  let sealed: SealedAppleToken | null = null;
  if (value.encryptedAppleToken !== null) {
    const token = value.encryptedAppleToken;
    if (!object(token) || token.version !== 1 || typeof token.iv !== 'string' || typeof token.ciphertext !== 'string') return invalid();
    sealed = { version: 1, iv: token.iv, ciphertext: token.ciphertext };
  }
  return { jobID: value.jobID, accountID: value.accountID, workspaceID: value.workspaceID, leaseID: value.leaseID,
    photosRemoved: value.photosRemoved, recordsRemoved: value.recordsRemoved, appleRevoked: value.appleRevoked,
    encryptedAppleToken: sealed };
}

export class HTTPDeletionBackend implements DeletionBackend {
  private readonly config: BackendConfiguration;
  private readonly request: typeof fetch;
  constructor(config: BackendConfiguration, request: typeof fetch = fetch) {
    const url = new URL(config.url);
    if (url.protocol !== 'https:' || !/^[a-z0-9-]+[.]supabase[.]co$/.test(url.hostname) ||
        url.port || url.username || url.password || url.search || url.hash || (url.pathname !== '/' && url.pathname !== '') ||
        !config.publishableKey.startsWith('sb_publishable_') || !config.secretKey) invalid();
    this.config = { ...config, url: url.origin };
    this.request = request;
  }

  async owner(token: string, workspaceID: string): Promise<DeletionOwner> {
    if (!token || token.length > 16_384 || /\s/.test(token) || !uuid(workspaceID)) return invalid();
    const value = await this.send('/rest/v1/rpc/ff_deletion_owner', 'POST', { p_workspace: workspaceID }, {
      apikey: this.config.publishableKey, Authorization: `Bearer ${token}`,
    });
    if (!object(value) || !uuid(value.accountID) || !uuid(value.sessionID) ||
        typeof value.appleSubject !== 'string' || value.appleSubject.length < 1 || value.appleSubject.length > 255) return invalid();
    return { accountID: value.accountID, sessionID: value.sessionID, appleSubject: value.appleSubject };
  }

  async queue(owner: DeletionOwner, workspaceID: string, operationID: string, receiptHash: string, token: SealedAppleToken): Promise<DeletionStatus> {
    const result = status(await this.rpc('ff_queue_deletion', {
      p_account: owner.accountID, p_session: owner.sessionID, p_workspace: workspaceID,
      p_operation: operationID, p_receipt_hash: receiptHash, p_token: token,
    }));
    if (result.state === 'notFound' || result.jobID !== operationID) return invalid();
    return result;
  }
  async status(receiptHash: string): Promise<DeletionStatus> {
    return status(await this.rpc('ff_deletion_status', { p_hash: receiptHash }));
  }
  async claim(limit: number): Promise<DeletionJob[]> {
    if (!Number.isInteger(limit) || limit < 1 || limit > 3) return invalid();
    const values = await this.rpc('ff_claim_deletions', { p_limit: limit });
    if (!Array.isArray(values) || values.length > limit) return invalid();
    const jobs = values.map(job);
    if (new Set(jobs.map((value) => value.jobID)).size !== jobs.length) return invalid();
    return jobs;
  }
  async photos(job: DeletionJob): Promise<string[]> {
    const paths = await this.rpc('ff_deletion_photos', { p_job: job.jobID, p_lease: job.leaseID });
    if (!Array.isArray(paths) || paths.length > 200 || !paths.every((path): path is string => typeof path === 'string')) return invalid();
    return paths;
  }
  async removePhotos(job: DeletionJob, paths: string[]): Promise<void> {
    const currentlyLeased = await this.photos(job);
    if (paths.length === 0 || paths.length > 200 || new Set(paths).size !== paths.length ||
        !paths.every((path) => currentlyLeased.includes(path))) return invalid();
    await this.send('/storage/v1/object/farrierflow-photos', 'DELETE', { prefixes: paths }, this.adminHeaders());
  }
  async markPhase(original: DeletionJob, phase: DeletionPhase): Promise<DeletionJob> {
    return this.sameScope(original, job(await this.rpc('ff_deletion_phase', {
      p_job: original.jobID, p_lease: original.leaseID, p_phase: phase,
    })));
  }
  async deleteAuth(original: DeletionJob): Promise<void> {
    const ready = this.sameScope(original, job(await this.rpc('ff_deletion_phase', {
      p_job: original.jobID, p_lease: original.leaseID, p_phase: 'ready',
    })));
    if (!ready.photosRemoved || !ready.recordsRemoved || !ready.appleRevoked) return invalid();
    // 404 may mean a previous attempt already removed Auth. finish() verifies
    // absence in the database; an unexpected route 404 cannot create success.
    await this.send(`/auth/v1/admin/users/${ready.accountID}`, 'DELETE', undefined, this.adminHeaders(), true);
  }
  async finish(job: DeletionJob): Promise<void> {
    await this.rpc('ff_finish_deletion', { p_job: job.jobID, p_lease: job.leaseID });
  }
  async failed(job: DeletionJob, code: string): Promise<void> {
    await this.rpc('ff_deletion_failed', { p_job: job.jobID, p_lease: job.leaseID, p_code: code });
  }

  private sameScope(original: DeletionJob, updated: DeletionJob): DeletionJob {
    if (original.jobID !== updated.jobID || original.accountID !== updated.accountID ||
        original.workspaceID !== updated.workspaceID || original.leaseID !== updated.leaseID) return invalid();
    return updated;
  }
  private adminHeaders(): Record<string, string> {
    // Secret API keys authenticate through apikey. A legacy service-role JWT
    // additionally works as a bearer; never send sb_secret_ as a user JWT.
    return this.config.secretKey.startsWith('sb_secret_') ? { apikey: this.config.secretKey } :
      { apikey: this.config.secretKey, Authorization: `Bearer ${this.config.secretKey}` };
  }
  private rpc(name: string, parameters: Record<string, unknown>): Promise<unknown> {
    return this.send(`/rest/v1/rpc/${name}`, 'POST', parameters, this.adminHeaders());
  }
  private async send(path: string, method: string, body: unknown, headers: Record<string, string>, allowNotFound = false): Promise<unknown> {
    try {
      const response = await this.request(this.config.url + path, {
        method, headers: { ...headers, 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(15_000),
      });
      if (allowNotFound && response.status === 404) return null;
      if (!response.ok) return invalid();
      return await boundedJSON(response);
    } catch { return invalid(); }
  }
}
