import process from 'node:process';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const projectId = 'padelx-staging';
const uid = process.argv[2];
if (!uid || uid.includes('/') || uid.length > 128) {
  console.error('Usage: node tool/inspect_account_deletion.mjs <staging-uid>');
  process.exitCode = 2;
} else {
  const db = getFirestore(initializeApp({ projectId }));
  const jobRef = db.collection('accountDeletionJobs').doc(uid);
  const [barrier, job, outbox, manifestCount] = await Promise.all([
    db.collection('accountDeletionBarriers').doc(uid).get(),
    jobRef.get(),
    db.collection('accountDeletionOutbox').doc(uid).get(),
    jobRef.collection('matchCleanup').count().get(),
  ]);

  const timestamp = (value) => value?.toDate?.().toISOString() ?? null;
  const cursor = (value) => value == null ? null : '<set>';
  const checkpointState = (value) => value && typeof value === 'object'
    ? Object.fromEntries(Object.entries(value).map(([key, item]) => [
      key, key.endsWith('After') ? cursor(item) : item,
    ]))
    : null;
  const data = (snapshot) => snapshot.exists ? snapshot.data() : null;
  const barrierData = data(barrier);
  const jobData = data(job);
  const outboxData = data(outbox);
  const leaseExpiresAtMillis = jobData?.leaseExpiresAt?.toMillis?.();

  console.log(JSON.stringify({
    projectId,
    inspectedAt: new Date().toISOString(),
    barrier: barrierData && {
      status: barrierData.status ?? null,
      schemaVersion: barrierData.schemaVersion ?? null,
      deletionRequestedAt: timestamp(barrierData.deletionRequestedAt),
      completedAt: timestamp(barrierData.completedAt),
    },
    job: jobData && {
      status: jobData.status ?? null,
      phase: jobData.phase ?? null,
      checkpoint: jobData.checkpoint ?? null,
      attemptCount: jobData.attemptCount ?? null,
      failureCount: jobData.failureCount ?? null,
      nextAttemptAt: timestamp(jobData.nextAttemptAt),
      leaseOwner: jobData.leaseOwner ?? null,
      leaseTokenPresent: Boolean(jobData.leaseToken),
      activeLease: Number.isFinite(leaseExpiresAtMillis)
        && leaseExpiresAtMillis > Date.now(),
      leaseExpiresAt: timestamp(jobData.leaseExpiresAt),
      lastErrorCode: jobData.lastErrorCode ?? null,
      lastFailureCategory: jobData.lastFailureCategory ?? null,
      completedAt: timestamp(jobData.completedAt),
      authDisabledAt: timestamp(jobData.authDisabledAt),
      authRevokedAt: timestamp(jobData.authRevokedAt),
      authMissing: jobData.authMissing ?? null,
      lastPhaseTransition: jobData.lastPhaseTransition && {
        from: jobData.lastPhaseTransition.from ?? null,
        to: jobData.lastPhaseTransition.to ?? null,
      },
      matchesCheckpoint: checkpointState(jobData.matchesCheckpoint),
      joinRequestsCheckpoint: checkpointState(jobData.joinRequestsCheckpoint),
      notificationsCheckpoint: checkpointState(jobData.notificationsCheckpoint),
      ratingsCheckpointPresent: Object.hasOwn(jobData, 'ratingsCheckpoint'),
      ratingsCheckpoint: checkpointState(jobData.ratingsCheckpoint),
      verifyCheckpoint: checkpointState(jobData.verifyCheckpoint),
      blockedRecordPresent: Object.keys(jobData).some(
        (key) => key.endsWith('BlockedRecord') && jobData[key] != null,
      ),
    },
    outbox: outboxData && {
      status: outboxData.status ?? null,
      attemptCount: outboxData.attemptCount ?? null,
      nextAttemptAt: timestamp(outboxData.nextAttemptAt),
      leaseExpiresAt: timestamp(outboxData.leaseExpiresAt),
      lastErrorCode: outboxData.lastErrorCode ?? null,
      deletionRequestedAt: timestamp(outboxData.deletionRequestedAt),
      completedAt: timestamp(outboxData.completedAt),
    },
    manifest: {
      matchCleanupCount: manifestCount.data().count,
    },
  }, null, 2));
}
