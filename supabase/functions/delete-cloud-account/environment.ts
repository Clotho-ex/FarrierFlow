import type { AppleConfiguration } from './apple.ts';
import { object } from './http.ts';
import type { BackendConfiguration } from './http.ts';

export interface DeletionConfiguration {
  backend: BackendConfiguration;
  apple: AppleConfiguration;
  encryptionKey: Uint8Array;
  workerKey: string;
}

export function readDeletionConfiguration(read: (name: string) => string | undefined): DeletionConfiguration {
  try {
    const required = (name: string): string => {
      const value = read(name);
      if (!value || value.length > 8_192) throw new Error('missing');
      return value;
    };
    const defaultKey = (name: string, prefix: string): string => {
      const values: unknown = JSON.parse(required(name));
      if (!object(values) || typeof values.default !== 'string' || !values.default.startsWith(prefix)) throw new Error('key');
      return values.default;
    };
    const url = new URL(required('SUPABASE_URL'));
    if (url.protocol !== 'https:' || !/^[a-z0-9-]+[.]supabase[.]co$/.test(url.hostname) || url.port ||
        url.username || url.password || url.hash || url.search || url.pathname !== '/') throw new Error('url');
    const teamID = required('FF_APPLE_TEAM_ID');
    const keyID = required('FF_APPLE_KEY_ID');
    const privateKey = required('FF_APPLE_SIGNING_PRIVATE_KEY');
    if (teamID !== '5SN9TWDXQ4' || !/^[A-Z0-9]{10}$/.test(keyID) ||
        !/^-----BEGIN PRIVATE KEY-----\s+[A-Za-z0-9+/=\s]+\s+-----END PRIVATE KEY-----\s*$/.test(privateKey)) throw new Error('apple');
    const encoded = required('FF_APPLE_TOKEN_ENCRYPTION_KEY');
    if (!/^[A-Za-z0-9+/]{43}=$/.test(encoded)) throw new Error('encryption');
    const encryptionKey = Uint8Array.from(atob(encoded), (value) => value.charCodeAt(0));
    if (encryptionKey.length !== 32 || btoa(String.fromCharCode(...encryptionKey)) !== encoded) throw new Error('encryption');
    const workerKey = required('FF_DELETION_WORKER_KEY');
    if (!/^[A-Za-z0-9_-]{43}$/.test(workerKey)) throw new Error('worker');
    const decoded = atob(workerKey.replaceAll('-', '+').replaceAll('_', '/'));
    if (decoded.length !== 32 || btoa(decoded).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '') !== workerKey) throw new Error('worker');
    return {
      backend: { url: url.origin, publishableKey: defaultKey('SUPABASE_PUBLISHABLE_KEYS', 'sb_publishable_'),
        secretKey: defaultKey('SUPABASE_SECRET_KEYS', 'sb_secret_') },
      apple: { clientID: 'com.farrierflow.yusufcan.FarrierFlow', teamID, keyID, privateKey },
      encryptionKey, workerKey,
    };
  } catch { throw new Error('deletion_configuration_invalid'); }
}
