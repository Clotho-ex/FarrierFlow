export interface AppleConfiguration {
  clientID: string;
  teamID: string;
  keyID: string;
  privateKey: string;
}

export interface ApplePublicKey extends JsonWebKey { kid?: string; alg?: string; use?: string }
export interface SealedAppleToken { version: 1; iv: string; ciphertext: string }

const encoder = new TextEncoder();
const appleIssuer = 'https://appleid.apple.com';
const fail = (): never => { throw new Error('apple_authorization_invalid'); };

function base64(bytes: Uint8Array): string {
  return btoa(Array.from(bytes, (byte) => String.fromCharCode(byte)).join(''));
}
function url64(bytes: Uint8Array): string {
  return base64(bytes).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}
function decode64(text: string, url = true): Uint8Array<ArrayBuffer> {
  if (text.length > 32_768 || !(url ? /^[A-Za-z0-9_-]+$/ : /^[A-Za-z0-9+/]*={0,2}$/).test(text)) fail();
  const value = url ? text.replaceAll('-', '+').replaceAll('_', '/') : text;
  try { return new Uint8Array(Array.from(atob(value), (character) => character.charCodeAt(0))); }
  catch { return fail(); }
}
function json64(value: unknown): string { return url64(encoder.encode(JSON.stringify(value))); }

export async function appleClientSecret(config: AppleConfiguration, now: number): Promise<string> {
  if (!/^[A-Z0-9]{10}$/.test(config.teamID) || !/^[A-Z0-9]{10}$/.test(config.keyID) ||
      config.clientID !== 'com.farrierflow.yusufcan.FarrierFlow' || !Number.isSafeInteger(now) ||
      config.privateKey.length > 8_192) fail();
  const match = /^-----BEGIN PRIVATE KEY-----\s+([A-Za-z0-9+/=\s]+)\s+-----END PRIVATE KEY-----\s*$/.exec(config.privateKey);
  if (!match) return fail();
  const key = await crypto.subtle.importKey('pkcs8', decode64(match[1].replace(/\s/g, ''), false),
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const header = json64({ alg: 'ES256', kid: config.keyID });
  const payload = json64({ iss: config.teamID, iat: now, exp: now + 300, aud: appleIssuer, sub: config.clientID });
  const unsigned = `${header}.${payload}`;
  const signature = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, encoder.encode(unsigned)));
  if (signature.length !== 64) fail();
  return `${unsigned}.${url64(signature)}`;
}

export async function verifyAppleIdentity(token: string, keys: ApplePublicKey[], expected: {
  clientID: string; subject: string; nonceHash?: string; now: number;
}): Promise<void> {
  if (token.length > 16_384 || keys.length > 32 || !Number.isSafeInteger(expected.now) || !expected.subject) fail();
  const parts = token.split('.');
  if (parts.length !== 3) fail();
  let header: Record<string, unknown>, claims: Record<string, unknown>;
  try {
    header = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(decode64(parts[0])));
    claims = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(decode64(parts[1])));
  } catch { return fail(); }
  if (!header || !claims || header.alg !== 'RS256' || typeof header.kid !== 'string') fail();
  const jwk = keys.find((key) => key.kid === header.kid);
  if (!jwk || jwk.kty !== 'RSA' || jwk.alg !== 'RS256' || jwk.use !== 'sig' || jwk.d ||
      typeof jwk.n !== 'string' || decode64(jwk.n).length < 256) return fail();
  const key = await crypto.subtle.importKey('jwk', jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  if (!await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, decode64(parts[2]), encoder.encode(`${parts[0]}.${parts[1]}`))) fail();
  if (claims.iss !== appleIssuer || claims.aud !== expected.clientID || claims.sub !== expected.subject ||
      typeof claims.iat !== 'number' || !Number.isSafeInteger(claims.iat) ||
      typeof claims.exp !== 'number' || !Number.isSafeInteger(claims.exp) || claims.exp <= expected.now ||
      claims.iat < expected.now - 300 || claims.iat > expected.now + 30 ||
      (expected.nonceHash !== undefined && claims.nonce !== expected.nonceHash)) fail();
}

export async function sealAppleToken(token: string, keyBytes: Uint8Array, scope: string): Promise<SealedAppleToken> {
  if (keyBytes.length !== 32 || !scope || !token || encoder.encode(token).length > 16_384) fail();
  const key = await crypto.subtle.importKey('raw', new Uint8Array(keyBytes), 'AES-GCM', false, ['encrypt']);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: encoder.encode(scope), tagLength: 128 }, key, encoder.encode(token));
  return { version: 1, iv: url64(iv), ciphertext: url64(new Uint8Array(encrypted)) };
}

export async function openAppleToken(sealed: SealedAppleToken, keyBytes: Uint8Array, scope: string): Promise<string> {
  if (sealed.version !== 1 || keyBytes.length !== 32 || !scope) fail();
  const iv = decode64(sealed.iv), ciphertext = decode64(sealed.ciphertext);
  if (iv.length !== 12 || ciphertext.length < 17 || ciphertext.length > 16_400) fail();
  const key = await crypto.subtle.importKey('raw', new Uint8Array(keyBytes), 'AES-GCM', false, ['decrypt']);
  const decrypted = await crypto.subtle.decrypt({ name: 'AES-GCM', iv, additionalData: encoder.encode(scope), tagLength: 128 }, key, ciphertext);
  return new TextDecoder('utf-8', { fatal: true }).decode(decrypted);
}

export async function revokeAppleToken(token: string, clientID: string, clientSecret: string, request: typeof fetch = fetch): Promise<void> {
  const response = await request(`${appleIssuer}/auth/revoke`, {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: clientID, client_secret: clientSecret, token, token_type_hint: 'refresh_token' }),
    signal: AbortSignal.timeout(15_000),
  });
  // Apple returns 200 for both first revocation and an already revoked token.
  // Other responses never prove authorization was removed.
  if (response.status !== 200) throw new Error('apple_revocation_unconfirmed');
}
