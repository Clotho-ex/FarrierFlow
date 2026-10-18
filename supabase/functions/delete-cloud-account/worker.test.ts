import assert from 'node:assert/strict';
import test from 'node:test';
import { runDeletionJob } from './worker.ts';
import type { DeletionBackend, DeletionJob, DeletionPhase } from './worker.ts';
import { sealAppleToken } from './apple.ts';

const account = '00000000-0000-4000-8000-000000000001';
const workspace = '00000000-0000-4000-8000-000000000002';
const jobID = '00000000-0000-4000-8000-000000000003';
const photo = `${workspace}/00000000-0000-4000-8000-000000000004.jpg`;

async function fixture() {
  const signing = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const p8 = Buffer.from(await crypto.subtle.exportKey('pkcs8', signing.privateKey)).toString('base64');
  const key = crypto.getRandomValues(new Uint8Array(32));
  const job: DeletionJob = { jobID, accountID: account, workspaceID: workspace, leaseID: crypto.randomUUID(),
    photosRemoved: false, recordsRemoved: false, appleRevoked: false,
    encryptedAppleToken: await sealAppleToken('synthetic-refresh-token', key, `${account}:${workspace}:${jobID}`) };
  const backend = new MemoryDeletionBackend(job);
  return { job, backend, options: { encryptionKey: key,
    apple: { clientID: 'com.farrierflow.yusufcan.FarrierFlow', teamID: '5SN9TWDXQ4', keyID: 'TESTKEY123', privateKey: `-----BEGIN PRIVATE KEY-----\n${p8}\n-----END PRIVATE KEY-----` },
    now: () => 1_800_000_000, request: (async () => new Response(null, { status: 200 })) as typeof fetch } };
}

test('Deletion requests Storage cleanup before records, Apple revocation and Auth removal', async () => {
  const f = await fixture();
  assert.equal(await runDeletionJob(f.job, f.backend, f.options), true);
  assert.equal(f.backend.objects.size, 0);
  assert.equal(f.backend.recordsExist, false);
  assert.equal(f.backend.authExists, false);
  assert.equal(f.backend.complete, true);
  assert.equal(f.backend.job.encryptedAppleToken, null);
});

test('A failed Storage delete does not clear business records or Auth and remains retryable', async () => {
  const f = await fixture();
  f.backend.storageFails = true;
  assert.equal(await runDeletionJob(f.job, f.backend, f.options), false);
  assert.equal(f.backend.objects.has(photo), true);
  assert.equal(f.backend.recordsExist, true);
  assert.equal(f.backend.authExists, true);
  assert.equal(f.backend.complete, false);
  assert.equal(f.backend.lastError, 'cleanup_unconfirmed');
  f.backend.storageFails = false;
  assert.equal(await runDeletionJob(f.backend.job, f.backend, f.options), true);
});

test('Apple failure preserves Auth and encrypted credentials; retry finishes from durable phases', async () => {
  const f = await fixture();
  const options = { ...f.options, request: (async () => new Response(null, { status: 500 })) as typeof fetch };
  assert.equal(await runDeletionJob(f.job, f.backend, options), false);
  assert.equal(f.backend.recordsExist, false);
  assert.equal(f.backend.authExists, true);
  assert.notEqual(f.backend.job.encryptedAppleToken, null);
  assert.equal(await runDeletionJob(f.backend.job, f.backend, f.options), true);
  assert.equal(f.backend.complete, true);
});

test('A foreign-workspace Storage path is never deleted', async () => {
  const f = await fixture();
  const other = '00000000-0000-4000-8000-000000000099/00000000-0000-4000-8000-000000000004.jpg';
  f.backend.objects.clear(); f.backend.objects.add(other);
  assert.equal(await runDeletionJob(f.job, f.backend, f.options), false);
  assert.equal(f.backend.objects.has(other), true);
  assert.equal(f.backend.recordsExist, true);
  assert.equal(f.backend.authExists, true);
});

test('A residual photo is drained even when the durable photo phase is already complete', async () => {
  const f = await fixture();
  f.backend.job.photosRemoved = true;
  f.backend.job.recordsRemoved = true;
  f.backend.job.appleRevoked = true;
  f.backend.job.encryptedAppleToken = null;
  f.backend.recordsExist = false;
  assert.equal(await runDeletionJob(f.backend.job, f.backend, f.options), true);
  assert.equal(f.backend.objects.size, 0);
  assert.equal(f.backend.complete, true);
});

test('A photo appearing before Auth deletion is retained as retryable work and drained next time', async () => {
  const f = await fixture();
  f.backend.addPhotoAfterApple = true;
  assert.equal(await runDeletionJob(f.job, f.backend, f.options), false);
  assert.equal(f.backend.authExists, true);
  assert.equal(f.backend.job.photosRemoved, true);
  assert.equal(f.backend.job.appleRevoked, true);
  assert.equal(await runDeletionJob(f.backend.job, f.backend, f.options), true);
  assert.equal(f.backend.objects.size, 0);
  assert.equal(f.backend.complete, true);
});

test('A replaced worker lease cannot remove Auth after a late Apple response', async () => {
  const f = await fixture();
  const options = { ...f.options, request: (async () => {
    f.backend.job.leaseID = crypto.randomUUID();
    return new Response(null, { status: 200 });
  }) as typeof fetch };
  assert.equal(await runDeletionJob(f.job, f.backend, options), false);
  assert.equal(f.backend.authExists, true);
  assert.equal(f.backend.complete, false);
});

class MemoryDeletionBackend implements DeletionBackend {
  job: DeletionJob;
  objects = new Set([photo]);
  recordsExist = true;
  authExists = true;
  complete = false;
  storageFails = false;
  addPhotoAfterApple = false;
  lastError: string | null = null;
  constructor(job: DeletionJob) { this.job = structuredClone(job); }
  private require(job: DeletionJob) {
    assert.equal(job.accountID, this.job.accountID); assert.equal(job.workspaceID, this.job.workspaceID);
    assert.equal(job.jobID, this.job.jobID); assert.equal(job.leaseID, this.job.leaseID);
  }
  async photos(job: DeletionJob) { this.require(job); return [...this.objects].slice(0, 200); }
  async removePhotos(job: DeletionJob, paths: string[]) {
    this.require(job); if (this.storageFails) throw new Error('synthetic_failure');
    for (const path of paths) this.objects.delete(path);
  }
  async markPhase(job: DeletionJob, phase: DeletionPhase) {
    this.require(job);
    if (phase === 'photos') { assert.equal(this.objects.size, 0); this.job.photosRemoved = true; }
    if (phase === 'records') { assert.equal(this.job.photosRemoved, true); this.recordsExist = false; this.job.recordsRemoved = true; }
    if (phase === 'apple') {
      this.job.appleRevoked = true; this.job.encryptedAppleToken = null;
      if (this.addPhotoAfterApple) this.objects.add(photo);
    }
    return structuredClone(this.job);
  }
  async deleteAuth(job: DeletionJob) {
    this.require(job); assert.equal(this.objects.size, 0); assert.equal(this.recordsExist, false);
    assert.equal(this.job.appleRevoked, true); this.authExists = false;
  }
  async finish(job: DeletionJob) {
    this.require(job); assert.equal(this.authExists, false); this.complete = true;
  }
  async failed(job: DeletionJob, code: string) {
    this.require(job); this.lastError = code;
  }
}
