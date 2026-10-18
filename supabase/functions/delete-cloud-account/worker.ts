import { appleClientSecret, openAppleToken, revokeAppleToken } from './apple.ts';
import type { AppleConfiguration, SealedAppleToken } from './apple.ts';

export interface DeletionJob {
  jobID: string;
  accountID: string;
  workspaceID: string;
  leaseID: string;
  photosRemoved: boolean;
  recordsRemoved: boolean;
  appleRevoked: boolean;
  encryptedAppleToken: SealedAppleToken | null;
}
export type DeletionPhase = 'photos' | 'records' | 'apple';
export interface DeletionBackend {
  photos(job: DeletionJob): Promise<string[]>;
  removePhotos(job: DeletionJob, paths: string[]): Promise<void>;
  markPhase(job: DeletionJob, phase: DeletionPhase): Promise<DeletionJob>;
  deleteAuth(job: DeletionJob): Promise<void>;
  finish(job: DeletionJob): Promise<void>;
  failed(job: DeletionJob, code: string): Promise<void>;
}

export async function runDeletionJob(original: DeletionJob, backend: DeletionBackend, options: {
  apple: AppleConfiguration; encryptionKey: Uint8Array; now: () => number; request?: typeof fetch;
}): Promise<boolean> {
  let job = structuredClone(original);
  const scope = { jobID: job.jobID, accountID: job.accountID, workspaceID: job.workspaceID, leaseID: job.leaseID };
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  function validate(updated: DeletionJob): DeletionJob {
    if (Object.values(scope).some((id) => !uuid.test(id)) ||
        updated.jobID !== scope.jobID || updated.accountID !== scope.accountID ||
        updated.workspaceID !== scope.workspaceID || updated.leaseID !== scope.leaseID ||
        typeof updated.photosRemoved !== 'boolean' || typeof updated.recordsRemoved !== 'boolean' ||
        typeof updated.appleRevoked !== 'boolean') throw new Error('cleanup_unconfirmed');
    return updated;
  }
  async function mark(phase: DeletionPhase) { job = validate(await backend.markPhase(job, phase)); }

  try {
    validate(job);
    // A late upload may finish after an earlier checkpoint. Every retry must
    // recheck Storage; the checkpoint is not a permanent absence guarantee.
    {
      // Bound each invocation; large photo histories continue on the next
      // leased run. Never delete Storage metadata directly with SQL.
      let exhausted = false;
      for (let page = 0; page < 4; page++) {
        const paths = await backend.photos(job);
        if (paths.length > 200 || new Set(paths).size !== paths.length) throw new Error('cleanup_unconfirmed');
        if (paths.length === 0) { exhausted = true; break; }
        for (const path of paths) {
          const parts = path.split('/');
          if (parts.length !== 2 || parts[0].toLowerCase() !== job.workspaceID.toLowerCase() ||
              !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]jpg$/i.test(parts[1])) {
            throw new Error('cleanup_unconfirmed');
          }
        }
        await backend.removePhotos(job, paths);
      }
      if (!exhausted && (await backend.photos(job)).length > 0) {
        await backend.failed(job, 'more_photos_pending');
        return false;
      }
      await mark('photos');
    }
    if (!job.photosRemoved) throw new Error('cleanup_unconfirmed');
    if (!job.recordsRemoved) await mark('records');
    if (!job.recordsRemoved) throw new Error('cleanup_unconfirmed');
    if (!job.appleRevoked) {
      if (!job.encryptedAppleToken) throw new Error('cleanup_unconfirmed');
      const token = await openAppleToken(job.encryptedAppleToken, options.encryptionKey,
        `${job.accountID}:${job.workspaceID}:${job.jobID}`);
      const assertion = await appleClientSecret(options.apple, options.now());
      await revokeAppleToken(token, options.apple.clientID, assertion, options.request);
      await mark('apple');
    }
    if (!job.appleRevoked) throw new Error('cleanup_unconfirmed');
    await backend.deleteAuth(job);
    // Server must verify Auth absence and all phases before recording success.
    await backend.finish(job);
    return true;
  } catch {
    try { await backend.failed(job, 'cleanup_unconfirmed'); }
    catch {
      // Lost connectivity or a replaced lease cannot become success. The
      // durable job remains available after lease expiry; log no token/error.
    }
    return false;
  }
}
