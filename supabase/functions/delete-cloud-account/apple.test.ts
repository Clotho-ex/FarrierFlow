import assert from 'node:assert/strict';
import test from 'node:test';
import { appleClientSecret, verifyAppleIdentity, sealAppleToken, openAppleToken, revokeAppleToken } from './apple.ts';

const now = 1_800_000_000;
const clientID = 'com.farrierflow.yusufcan.FarrierFlow';
const b64url = (bytes: Uint8Array) => Buffer.from(bytes).toString('base64url');
const encode = (value: unknown) => b64url(new TextEncoder().encode(JSON.stringify(value)));

test('Apple client secret is a short-lived ES256 assertion for the approved native audience', async () => {
  const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const key = Buffer.from(await crypto.subtle.exportKey('pkcs8', pair.privateKey)).toString('base64');
  const jwt = await appleClientSecret({ clientID, teamID: '5SN9TWDXQ4', keyID: 'TESTKEY123', privateKey: `-----BEGIN PRIVATE KEY-----\n${key}\n-----END PRIVATE KEY-----` }, now);
  const [header, payload, signature] = jwt.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(header, 'base64url').toString()), { alg: 'ES256', kid: 'TESTKEY123' });
  assert.deepEqual(JSON.parse(Buffer.from(payload, 'base64url').toString()), { iss: '5SN9TWDXQ4', iat: now, exp: now + 300, aud: 'https://appleid.apple.com', sub: clientID });
  assert.equal(await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, pair.publicKey,
    Buffer.from(signature, 'base64url'), new TextEncoder().encode(`${header}.${payload}`)), true);
});

test('Apple identity requires a verified signature, current audience, subject, freshness and nonce', async () => {
  const pair = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const jwk = { ...await crypto.subtle.exportKey('jwk', pair.publicKey), kid: 'apple-test-key', alg: 'RS256', use: 'sig' };
  const header = encode({ alg: 'RS256', kid: jwk.kid });
  const payload = encode({ iss: 'https://appleid.apple.com', aud: clientID, sub: 'synthetic-apple-owner', iat: now, exp: now + 300, nonce: 'a'.repeat(64) });
  const unsigned = `${header}.${payload}`;
  const signature = b64url(new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', pair.privateKey, new TextEncoder().encode(unsigned))));
  const token = `${unsigned}.${signature}`;
  const options = { clientID, subject: 'synthetic-apple-owner', nonceHash: 'a'.repeat(64), now };
  await verifyAppleIdentity(token, [jwk], options);
  await assert.rejects(verifyAppleIdentity(token, [jwk], { ...options, subject: 'another-owner' }));
  await assert.rejects(verifyAppleIdentity(token, [jwk], { ...options, clientID: 'another.app' }));
  await assert.rejects(verifyAppleIdentity(token, [jwk], { ...options, nonceHash: 'b'.repeat(64) }));
  await assert.rejects(verifyAppleIdentity(token, [jwk], { ...options, now: now + 301 }));
  await assert.rejects(verifyAppleIdentity(`${header}.${encode({ sub: options.subject })}.${signature}`, [jwk], options));
  await assert.rejects(verifyAppleIdentity(`${encode({ alg: 'none' })}.${payload}.`, [jwk], options));
});

test('Stored Apple refresh token is encrypted and authenticated to its deletion job', async () => {
  const key = crypto.getRandomValues(new Uint8Array(32));
  const scope = 'synthetic-user:synthetic-workspace:synthetic-job';
  const sealed = await sealAppleToken('synthetic-refresh-token', key, scope);
  assert.equal(JSON.stringify(sealed).includes('synthetic-refresh-token'), false);
  assert.equal(await openAppleToken(sealed, key, scope), 'synthetic-refresh-token');
  await assert.rejects(openAppleToken(sealed, key, 'different-owner:workspace:job'));
  await assert.rejects(openAppleToken(sealed, crypto.getRandomValues(new Uint8Array(32)), scope));
  await assert.rejects(sealAppleToken('synthetic-refresh-token', new Uint8Array(16), scope));
});

test('Revocation is sent only to Apple and success requires its 200 response', async () => {
  let calls = 0;
  const request: typeof fetch = async (input, init) => {
    calls++;
    assert.equal(input, 'https://appleid.apple.com/auth/revoke');
    assert.equal(init?.method, 'POST');
    const body = new URLSearchParams(String(init?.body));
    assert.equal(body.get('client_id'), clientID);
    assert.equal(body.get('token'), 'synthetic-refresh-token');
    assert.equal(body.get('token_type_hint'), 'refresh_token');
    return new Response(null, { status: 200 });
  };
  await revokeAppleToken('synthetic-refresh-token', clientID, 'synthetic-client-assertion', request);
  assert.equal(calls, 1);
  await assert.rejects(revokeAppleToken('synthetic-refresh-token', clientID, 'synthetic-client-assertion', async () => new Response(null, { status: 500 })));
});
