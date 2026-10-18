import assert from 'node:assert/strict';
import test from 'node:test';
import { createDeletionHandler } from './handler.ts';
import { HTTPDeletionBackend } from './http.ts';
import { openAppleToken } from './apple.ts';

const account = '00000000-0000-4000-8000-000000000001';
const workspace = '00000000-0000-4000-8000-000000000002';
const operation = '00000000-0000-4000-8000-000000000003';
const session = '00000000-0000-4000-8000-000000000004';
const clientID = 'com.farrierflow.yusufcan.FarrierFlow';
const now = 1_800_000_000;
const receiptToken = Buffer.alloc(32, 1).toString('base64url');
const nonce = Buffer.alloc(32, 2).toString('base64url');
const encoder = new TextEncoder();
const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url');
const backendConfig = { url: 'https://xufledziawaapvrifbfv.supabase.co', publishableKey: 'sb_publishable_synthetic', secretKey: 'sb_secret_synthetic' };

async function fixture(options: { subject?: string; exchangeSubject?: string; expired?: boolean; cached?: boolean } = {}) {
  const signing = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const pem = Buffer.from(await crypto.subtle.exportKey('pkcs8', signing.privateKey)).toString('base64');
  const apple = { clientID, teamID: '5SN9TWDXQ4', keyID: 'TESTKEY123', privateKey: `-----BEGIN PRIVATE KEY-----\n${pem}\n-----END PRIVATE KEY-----` };
  const pair = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const jwk = { ...await crypto.subtle.exportKey('jwk', pair.publicKey), kid: 'test-apple', alg: 'RS256', use: 'sig' };
  async function identity(subject: string, includeNonce: boolean) {
    const hash = Buffer.from(await crypto.subtle.digest('SHA-256', encoder.encode(nonce))).toString('hex');
    const unsigned = `${encode({ alg: 'RS256', kid: jwk.kid })}.${encode({ iss: 'https://appleid.apple.com', aud: clientID, sub: subject,
      iat: options.expired ? now - 301 : now, exp: now + 300, ...(includeNonce ? { nonce: hash } : {}) })}`;
    return `${unsigned}.${Buffer.from(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', pair.privateKey, encoder.encode(unsigned))).toString('base64url')}`;
  }
  const nativeToken = await identity(options.subject ?? 'apple-owner', true);
  const exchangedToken = await identity(options.exchangeSubject ?? 'apple-owner', false);
  const encryptionKey = crypto.getRandomValues(new Uint8Array(32));
  const events: string[] = [];
  const request: typeof fetch = async (url, init) => {
    const path = String(url);
    if (path.endsWith('/ff_deletion_status')) { events.push('status'); return Response.json(options.cached ? { state: 'complete', jobID: operation } : { state: 'notFound' }); }
    if (path.endsWith('/ff_deletion_owner')) {
      assert.equal(new Headers(init?.headers).get('Authorization'), 'Bearer synthetic-caller-session');
      events.push('owner'); return Response.json({ accountID: account, sessionID: session, appleSubject: 'apple-owner' });
    }
    if (path === 'https://appleid.apple.com/auth/keys') { events.push('keys'); return Response.json({ keys: [jwk] }); }
    if (path === 'https://appleid.apple.com/auth/token') {
      const form = new URLSearchParams(String(init?.body));
      assert.equal(form.get('client_id'), clientID);
      assert.equal(form.get('grant_type'), 'authorization_code');
      assert.equal(form.get('code'), 'synthetic-one-use-apple-code');
      assert.equal(form.has('redirect_uri'), false);
      events.push('exchange'); return Response.json({ refresh_token: 'synthetic-apple-refresh', id_token: exchangedToken, token_type: 'Bearer', expires_in: 3600, access_token: 'synthetic-access' });
    }
    if (path.endsWith('/ff_queue_deletion')) {
      const body = JSON.parse(String(init?.body));
      assert.equal(body.p_account, account); assert.equal(body.p_session, session);
      assert.equal(body.p_workspace, workspace); assert.equal(body.p_operation, operation);
      assert.match(body.p_receipt_hash, /^[a-f0-9]{64}$/);
      assert.equal(await openAppleToken(body.p_token, encryptionKey, `${account}:${workspace}:${operation}`), 'synthetic-apple-refresh');
      assert.equal(String(init?.body).includes('synthetic-apple-refresh'), false);
      events.push('queue'); return Response.json({ state: 'pending', jobID: operation });
    }
    if (path.endsWith('/ff_claim_deletions')) { events.push('claim'); return Response.json([]); }
    throw new Error('Unexpected synthetic network route');
  };
  const handler = createDeletionHandler({ backend: new HTTPDeletionBackend(backendConfig, request), apple,
    encryptionKey, workerKey: 'w'.repeat(43), now: () => now, request });
  const body = { workspaceID: workspace, operationID: operation, receiptToken, nonce,
    identityToken: nativeToken, authorizationCode: 'synthetic-one-use-apple-code' };
  const call = (route: string, value: unknown, bearer?: string) => handler(new Request(`https://example.com/delete-cloud-account/${route}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}) }, body: JSON.stringify(value),
  }));
  return { call, body, events };
}

test('Fresh native Apple proof queues only the current owner with an encrypted refresh token', async () => {
  const { call, body, events } = await fixture();
  const response = await call('request', body, 'synthetic-caller-session');
  assert.equal(response.status, 202);
  assert.deepEqual(await response.json(), { state: 'pending', jobID: operation });
  assert.deepEqual(events, ['status', 'owner', 'keys', 'exchange', 'queue']);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
});

test('Wrong native or exchanged Apple identity and stale proof never queue deletion', async () => {
  for (const options of [{ subject: 'different-owner' }, { exchangeSubject: 'different-owner' }, { expired: true }]) {
    const { call, body, events } = await fixture(options);
    const response = await call('request', body, 'synthetic-caller-session');
    assert.equal(response.status, 409); assert.equal(events.includes('queue'), false);
    assert.deepEqual(await response.json(), { error: 'deletion_request_unconfirmed' });
  }
});

test('Deletion receipt recovers a lost response after Auth deletion without another Apple exchange', async () => {
  const { call, body, events } = await fixture({ cached: true });
  const response = await call('status', { operationID: operation, receiptToken });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { state: 'complete', jobID: operation });
  assert.deepEqual(events, ['status']);
  const retry = await call('request', body);
  assert.equal(retry.status, 200);
  assert.deepEqual(events, ['status', 'status']);
});

test('Unauthenticated requests, extra account IDs, malformed capabilities and worker calls cannot mutate', async () => {
  const { call, body, events } = await fixture();
  assert.equal((await call('request', body)).status, 401);
  assert.equal((await call('request', { ...body, accountID: account }, 'synthetic-caller-session')).status, 400);
  assert.equal((await call('status', { operationID: operation, receiptToken: 'short' })).status, 400);
  assert.equal((await call('run', {}, 'wrong-worker')).status, 401);
  assert.equal(events.includes('owner') || events.includes('exchange') || events.includes('queue') || events.includes('claim'), false);
  assert.equal((await call('run', {}, 'w'.repeat(43))).status, 200);
  assert.equal(events.at(-1), 'claim');
});

test('Oversized bodies and unknown routes are rejected without provider calls', async () => {
  const { call, events } = await fixture();
  assert.equal((await call('request', { padding: 'x'.repeat(33_000) }, 'synthetic-caller-session')).status, 400);
  assert.equal((await call('unrecognized', {})).status, 404);
  assert.deepEqual(events, []);
});
