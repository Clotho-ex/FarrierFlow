import assert from 'node:assert/strict';
import test from 'node:test';
import { HTTPDeletionBackend } from './http.ts';
import type { DeletionJob } from './worker.ts';

const workspace = '00000000-0000-4000-8000-000000000002';
const account = '00000000-0000-4000-8000-000000000001';
const session = '00000000-0000-4000-8000-000000000005';
const path = `${workspace}/00000000-0000-4000-8000-000000000004.jpg`;
const job: DeletionJob = { jobID: '00000000-0000-4000-8000-000000000003', accountID: account, workspaceID: workspace,
  leaseID: '00000000-0000-4000-8000-000000000006', photosRemoved: false, recordsRemoved: false,
  appleRevoked: false, encryptedAppleToken: null };
const config = { url: 'https://xufledziawaapvrifbfv.supabase.co', publishableKey: 'sb_publishable_synthetic_only', secretKey: 'sb_secret_synthetic_only' };

test('Owner eligibility uses only the caller JWT and public key, not administrative authority', async () => {
  const backend = new HTTPDeletionBackend(config, async (input, init) => {
    assert.equal(input, `${config.url}/rest/v1/rpc/ff_deletion_owner`);
    const headers = new Headers(init?.headers);
    assert.equal(headers.get('Authorization'), 'Bearer synthetic-user-jwt');
    assert.equal(headers.get('apikey'), config.publishableKey);
    assert.deepEqual(JSON.parse(String(init?.body)), { p_workspace: workspace });
    return Response.json({ accountID: account, sessionID: session, appleSubject: 'synthetic-apple-owner' });
  });
  assert.deepEqual(await backend.owner('synthetic-user-jwt', workspace), { accountID: account, sessionID: session, appleSubject: 'synthetic-apple-owner' });
});

test('Storage removal is exact-path private cleanup and first requires the current worker lease', async () => {
  let leaseChecked = false;
  const backend = new HTTPDeletionBackend(config, async (input, init) => {
    const headers = new Headers(init?.headers);
    assert.equal(headers.get('apikey'), config.secretKey);
    if (input === `${config.url}/rest/v1/rpc/ff_deletion_photos`) {
      assert.deepEqual(JSON.parse(String(init?.body)), { p_job: job.jobID, p_lease: job.leaseID });
      leaseChecked = true;
      return Response.json([path]);
    }
    assert.equal(leaseChecked, true);
    assert.equal(input, `${config.url}/storage/v1/object/farrierflow-photos`);
    assert.equal(init?.method, 'DELETE');
    assert.deepEqual(JSON.parse(String(init?.body)), { prefixes: [path] });
    return Response.json([{ name: path }]);
  });
  await backend.removePhotos(job, [path]);
});

test('A missing leased path or malformed worker row cannot become a deletion request', async () => {
  let storageCalled = false;
  const backend = new HTTPDeletionBackend(config, async (input) => {
    if (String(input).includes('/storage/')) storageCalled = true;
    return Response.json([]);
  });
  await assert.rejects(backend.removePhotos(job, [path]));
  assert.equal(storageCalled, false);
  const malformed = new HTTPDeletionBackend(config, async () => Response.json([{ ...job, accountID: 'not-a-uuid' }]));
  await assert.rejects(malformed.claim(1));
});

test('Provider and database error contents are not reflected as application errors', async () => {
  const backend = new HTTPDeletionBackend(config, async () => Response.json({ message: 'synthetic-sensitive-detail' }, { status: 500 }));
  await assert.rejects(backend.owner('synthetic-user-jwt', workspace), (error: unknown) =>
    error instanceof Error && error.message === 'deletion_request_unconfirmed');
});
