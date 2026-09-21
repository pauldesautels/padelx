import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { recoverBlockedStorageDeletion,
  storageRecoveryOptions } from '../tool/recover_blocked_storage_deletion.mjs';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-storage-recovery';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId,
  storageBucket: `${projectId}.firebasestorage.app` });
const app = initializeApp({ projectId }, 'storage-recovery-tests');
const db = getFirestore(app);
after(() => deleteApp(app));
const cutoff = Timestamp.fromDate(new Date('2030-01-01T00:00:00Z'));

async function seed(uid, job = {}) {
  await Promise.all([
    db.doc(`accountDeletionJobs/${uid}`).set({
      uid, schemaVersion: 2, deletionRequestedAt: cutoff, status: 'blocked',
      phase: 'storage', checkpoint: null, attemptCount: 12, failureCount: 8,
      nextAttemptAt: null, lastErrorCode: 'retry-exhausted',
      lastFailureCategory: 'invalid-worker-state', completedAt: null,
      leaseOwner: null, leaseExpiresAt: null, authDisabledAt: cutoff,
      authRevokedAt: cutoff, ...job,
    }),
    db.doc(`accountDeletionBarriers/${uid}`).set({ uid, schemaVersion: 2,
      deletionRequestedAt: cutoff, status: 'deleting' }),
    db.doc(`accountDeletionOutbox/${uid}`).set({ uid, schemaVersion: 2,
      deletionRequestedAt: cutoff, jobId: uid, status: 'ready_for_cleanup',
      nextAttemptAt: null }),
  ]);
}

test('CLI requires dual staging confirmation and never accepts production', () => {
  assert.deepEqual(storageRecoveryOptions(['--project=padelx-staging',
    '--confirm-project=padelx-staging', '--uid=test']), {
    projectId: 'padelx-staging', uid: 'test', apply: false,
  });
  for (const args of [[], ['--project=padelx-f168f',
    '--confirm-project=padelx-f168f', '--uid=test'],
  ['--project=padelx-staging', '--uid=test'],
  ['--project=padelx-staging', '--confirm-project=padelx-staging', '--uid=a/b']]) {
    assert.throws(() => storageRecoveryOptions(args));
  }
});

test('dry-run is read-only and apply resets only bounded retry state', async () => {
  const uid = 'recoverable-storage';
  await seed(uid);
  const before = (await db.doc(`accountDeletionJobs/${uid}`).get()).data();
  assert.deepEqual(await recoverBlockedStorageDeletion(db, uid),
    { outcome: 'eligible', applied: false });
  assert.deepEqual((await db.doc(`accountDeletionJobs/${uid}`).get()).data(), before);
  const now = new Date('2030-02-01T00:00:00Z');
  assert.deepEqual(await recoverBlockedStorageDeletion(db, uid, { apply: true, now }),
    { outcome: 'recovered', applied: true });
  const recovered = (await db.doc(`accountDeletionJobs/${uid}`).get()).data();
  assert.equal(recovered.status, 'retry_wait');
  assert.equal(recovered.phase, 'storage');
  assert.equal(recovered.failureCount, 0);
  assert.equal(recovered.lastErrorCode, null);
  assert.equal(recovered.lastFailureCategory, null);
  assert.equal(recovered.attemptCount, before.attemptCount);
  assert.equal(recovered.nextAttemptAt.toDate().toISOString(), now.toISOString());
});

for (const [name, job] of [
  ['wrong phase', { phase: 'ratings' }],
  ['wrong category', { lastFailureCategory: 'missing-index' }],
  ['partial budget', { failureCount: 7 }],
  ['completed', { completedAt: cutoff }],
  ['active lease', { leaseOwner: 'worker', leaseExpiresAt: Timestamp.fromDate(new Date('2099-01-01')) }],
]) test(`storage recovery rejects ${name}`, async () => {
  const uid = `reject-${name.replaceAll(' ', '-')}`;
  await seed(uid, job);
  await assert.rejects(recoverBlockedStorageDeletion(db, uid, { apply: true }));
  assert.equal((await db.doc(`accountDeletionJobs/${uid}`).get()).data().status, 'blocked');
});
