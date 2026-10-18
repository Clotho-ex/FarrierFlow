import { appleClientSecret, sealAppleToken, verifyAppleIdentity } from './apple.ts';
import type { AppleConfiguration, ApplePublicKey } from './apple.ts';
import { boundedJSON, object, uuid } from './http.ts';
import type { HTTPDeletionBackend } from './http.ts';
import { runDeletionJob } from './worker.ts';

export interface HandlerConfiguration {
  backend: HTTPDeletionBackend;
  apple: AppleConfiguration;
  encryptionKey: Uint8Array;
  workerKey: string;
  now: () => number;
  request?: typeof fetch;
}

const encoder = new TextEncoder();
const reply = (value: unknown, status = 200) => Response.json(value, {
  status, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
});
const error = (status: number) => reply({ error: 'deletion_request_unconfirmed' }, status);

function capability(value: unknown): value is string {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(value)) return false;
  // Canonical 32-byte encodings cannot carry alternative unused padding bits.
  try {
    const decoded = atob(value.replaceAll('-', '+').replaceAll('_', '/'));
    return decoded.length === 32 && btoa(decoded).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '') === value;
  } catch { return false; }
}
function exactKeys(value: Record<string, unknown>, expected: string[]): boolean {
  return Object.keys(value).length === expected.length && expected.every((key) => Object.hasOwn(value, key));
}
function bearer(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header || header.length > 16_400) return null;
  return /^Bearer ([^\s]+)$/i.exec(header)?.[1] ?? null;
}
async function digest(value: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)));
}
async function hexDigest(value: string): Promise<string> {
  return Array.from(await digest(value), (byte) => byte.toString(16).padStart(2, '0')).join('');
}
async function equalSecret(actual: string, expected: string): Promise<boolean> {
  const [left, right] = await Promise.all([digest(actual), digest(expected)]);
  let different = 0;
  for (let index = 0; index < left.length; index++) different |= left[index] ^ right[index];
  return different === 0;
}
function publicKey(value: unknown): value is ApplePublicKey {
  return object(value) && value.kty === 'RSA' && value.alg === 'RS256' && value.use === 'sig' &&
    typeof value.kid === 'string' && typeof value.n === 'string' && typeof value.e === 'string' &&
    value.d === undefined && value.p === undefined && value.q === undefined;
}

export function createDeletionHandler(configuration: HandlerConfiguration): (request: Request) => Promise<Response> {
  if (configuration.encryptionKey.length !== 32 || !capability(configuration.workerKey)) {
    throw new Error('deletion_configuration_invalid');
  }
  const { backend, apple, encryptionKey, workerKey, now } = configuration;
  const send = configuration.request ?? fetch;
  return async (request) => {
    const route = /^\/(?:functions\/v1\/)?delete-cloud-account\/(request|status|run)$/.exec(new URL(request.url).pathname)?.[1];
    if (!route) return error(404);
    if (request.method !== 'POST') return error(405);
    if (request.headers.get('Content-Type')?.split(';')[0].trim().toLowerCase() !== 'application/json') return error(415);
    if (route === 'run') {
      const token = bearer(request);
      if (!token || !await equalSecret(token, workerKey)) return error(401);
    }
    let body: unknown;
    try { body = await boundedJSON(request, 32_768); } catch { return error(400); }
    if (!object(body)) return error(400);
    if (route === 'run') {
      if (!exactKeys(body, [])) return error(400);
      try {
        const jobs = await backend.claim(1);
        let completed = 0;
        for (const job of jobs) {
          if (await runDeletionJob(job, backend, { apple, encryptionKey, now, request: send })) completed++;
        }
        return reply({ processed: jobs.length, completed });
      } catch { return error(503); }
    }
    const fields = route === 'status' ? ['operationID', 'receiptToken'] :
      ['operationID', 'receiptToken', 'workspaceID', 'nonce', 'identityToken', 'authorizationCode'];
    if (!exactKeys(body, fields) || !uuid(body.operationID) || !capability(body.receiptToken)) return error(400);
    const operationID = body.operationID.toLowerCase();
    if (route === 'request' && (!uuid(body.workspaceID) || !capability(body.nonce) ||
        typeof body.identityToken !== 'string' || body.identityToken.length < 1 || body.identityToken.length > 16_384 ||
        typeof body.authorizationCode !== 'string' || body.authorizationCode.length < 1 || body.authorizationCode.length > 8_192)) return error(400);
    try {
      // The opaque device-held receipt permits confirmation after Auth removal.
      // Never put it in a URL or expose account/workspace data through status.
      const receiptHash = await hexDigest(`${operationID}:${body.receiptToken}`);
      const previous = await backend.status(receiptHash);
      if (previous.state !== 'notFound') {
        if (previous.jobID !== operationID) return error(409);
        return reply(previous, previous.state === 'pending' ? 202 : 200);
      }
      if (route === 'status') return reply(previous);
      const token = bearer(request);
      if (!token) return error(401);
      // Narrow again rather than casting caller-controlled JSON into a DTO.
      if (!uuid(body.workspaceID) || typeof body.nonce !== 'string' || typeof body.identityToken !== 'string' ||
          typeof body.authorizationCode !== 'string') return error(400);
      const workspaceID = body.workspaceID.toLowerCase();
      const owner = await backend.owner(token, workspaceID);
      const keysResponse = await send('https://appleid.apple.com/auth/keys', { signal: AbortSignal.timeout(15_000) });
      if (!keysResponse.ok) return error(409);
      const document = await boundedJSON(keysResponse);
      if (!object(document) || !Array.isArray(document.keys) || document.keys.length < 1 ||
          document.keys.length > 32 || !document.keys.every(publicKey)) return error(409);
      const expected = { clientID: apple.clientID, subject: owner.appleSubject, now: now() };
      await verifyAppleIdentity(body.identityToken, document.keys, { ...expected, nonceHash: await hexDigest(body.nonce) });
      const assertion = await appleClientSecret(apple, now());
      const exchange = await send('https://appleid.apple.com/auth/token', {
        method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ grant_type: 'authorization_code', client_id: apple.clientID,
          client_secret: assertion, code: body.authorizationCode }), signal: AbortSignal.timeout(15_000),
      });
      if (!exchange.ok) return error(409);
      const grant = await boundedJSON(exchange);
      if (!object(grant) || typeof grant.refresh_token !== 'string' || !grant.refresh_token ||
          grant.refresh_token.length > 16_384 || typeof grant.id_token !== 'string') return error(409);
      await verifyAppleIdentity(grant.id_token, document.keys, { ...expected, now: now() });
      const encrypted = await sealAppleToken(grant.refresh_token, encryptionKey,
        `${owner.accountID}:${workspaceID}:${operationID}`);
      const queued = await backend.queue(owner, workspaceID, operationID, receiptHash, encrypted);
      return reply(queued, queued.state === 'pending' ? 202 : 200);
    } catch {
      // Provider/database errors may include credentials or personal data.
      // Do not reflect or log them; the durable receipt resolves ambiguity.
      return error(409);
    }
  };
}
