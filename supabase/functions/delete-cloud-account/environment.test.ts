import assert from 'node:assert/strict';
import test from 'node:test';
import { readDeletionConfiguration } from './environment.ts';

const base: Record<string, string> = {
  SUPABASE_URL: 'https://xufledziawaapvrifbfv.supabase.co',
  SUPABASE_PUBLISHABLE_KEYS: JSON.stringify({ default: 'sb_publishable_synthetic' }),
  SUPABASE_SECRET_KEYS: JSON.stringify({ default: 'sb_secret_synthetic' }),
  FF_APPLE_TEAM_ID: '5SN9TWDXQ4', FF_APPLE_KEY_ID: 'TESTKEY123',
  FF_APPLE_SIGNING_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\nsynthetic\n-----END PRIVATE KEY-----',
  FF_APPLE_TOKEN_ENCRYPTION_KEY: Buffer.alloc(32, 5).toString('base64'),
  FF_DELETION_WORKER_KEY: Buffer.alloc(32, 6).toString('base64url'),
};

test('Runtime uses injected default server keys and fixed FarrierFlow audience, never client-supplied configuration', () => {
  const value = readDeletionConfiguration((name) => base[name]);
  assert.equal(value.backend.url, base.SUPABASE_URL);
  assert.equal(value.backend.secretKey, 'sb_secret_synthetic');
  assert.equal(value.backend.publishableKey, 'sb_publishable_synthetic');
  assert.equal(value.apple.clientID, 'com.farrierflow.yusufcan.FarrierFlow');
  assert.deepEqual(value.encryptionKey, new Uint8Array(32).fill(5));
});

test('Missing, malformed and substituted secrets fail closed without reflecting values', () => {
  for (const [name, replacement] of [
    ['FF_APPLE_TEAM_ID', 'different-team'], ['FF_APPLE_KEY_ID', ''],
    ['FF_APPLE_SIGNING_PRIVATE_KEY', 'sensitive-invalid-key'],
    ['FF_APPLE_TOKEN_ENCRYPTION_KEY', Buffer.alloc(16).toString('base64')],
    ['FF_DELETION_WORKER_KEY', 'short'], ['SUPABASE_SECRET_KEYS', 'sensitive-malformed-json'],
    ['SUPABASE_PUBLISHABLE_KEYS', JSON.stringify({ default: 'sb_secret_wrong-location' })],
    ['SUPABASE_URL', 'http://localhost'],
  ]) {
    assert.throws(() => readDeletionConfiguration((key) => key === name ? replacement : base[key]),
      (error: unknown) => error instanceof Error && error.message === 'deletion_configuration_invalid');
  }
});
