import { pathToFileURL } from 'node:url';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { validateBackendEnvironment } from '../functions/backend_environment.js';

const stagingProjectId = 'padelx-staging';

export function recoveryOptions(args) {
  const allowed = args.every((arg) => arg === '--apply'
    || arg.startsWith('--project=') || arg.startsWith('--uid='));
  const projects = args.filter((arg) => arg.startsWith('--project='));
  const uids = args.filter((arg) => arg.startsWith('--uid='));
  if (!allowed || projects.length !== 1 || uids.length !== 1
      || projects[0] !== `--project=${stagingProjectId}`) {
    throw new Error('Requires exactly --project=padelx-staging --uid=<uid> and optional --apply.');
  }
  const uid = uids[0].slice(6);
  if (!uid || uid.length > 128 || uid.includes('/')) throw new Error('Invalid UID.');
  return { projectId: stagingProjectId, uid, apply: args.includes('--apply') };
}

function validTimestamp(value) {
  return Number.isFinite(value?.toMillis?.());
}

export async function recoverBlockedRatingsDeletion(db, uid, { apply = false, now = new Date() } = {}) {
  const environment = validateBackendEnvironment({
    projectId: db.projectId,
    firestoreHost: process.env.FIRESTORE_EMULATOR_HOST,
    authHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
  });
  if (environment.mode !== 'emulator' && environment.projectId !== stagingProjectId) {
    throw new Error('Recovery is restricted to staging.');
  }
  if (!uid || uid.length > 128 || uid.includes('/') || !Number.isFinite(now.getTime())) {
    throw new Error('Invalid recovery input.');
  }

  const jobRef = db.collection('accountDeletionJobs').doc(uid);
  const barrierRef = db.collection('accountDeletionBarriers').doc(uid);
  const outboxRef = db.collection('accountDeletionOutbox').doc(uid);
  return db.runTransaction(async (tx) => {
    const [jobSnapshot, barrierSnapshot, outboxSnapshot] = await tx.getAll(
      jobRef, barrierRef, outboxRef,
    );
    const job = jobSnapshot.data();
    const barrier = barrierSnapshot.data();
    const outbox = outboxSnapshot.data();
    if (!job || !barrier || !outbox) throw new Error('Deletion lifecycle is incomplete.');

    const cutoff = job.deletionRequestedAt;
    const commonStateIsValid = [job, barrier, outbox].every((record) =>
      record.uid === uid && validTimestamp(record.deletionRequestedAt)
      && record.deletionRequestedAt.isEqual(cutoff));
    if (!commonStateIsValid || barrier.status !== 'deleting'
        || outbox.status !== 'ready_for_cleanup' || outbox.jobId !== uid
        || job.phase !== 'ratings' || job.ratingsCheckpoint != null
        || job.checkpoint !== null || job.completedAt !== null
        || !validTimestamp(job.authDisabledAt) || !validTimestamp(job.authRevokedAt)
        || job.authRevokedAt.toMillis() < job.authDisabledAt.toMillis()
        || job.authDisabledAt.toMillis() < cutoff.toMillis()) {
      throw new Error('Deletion state is not eligible for ratings recovery.');
    }
    const leaseExpiresAtIsValid = validTimestamp(job.leaseExpiresAt);
    if ((leaseExpiresAtIsValid && job.leaseExpiresAt.toMillis() > now.getTime())
        || (job.leaseOwner != null && !leaseExpiresAtIsValid)) {
      throw new Error('Deletion job has an active lease.');
    }

    const alreadyRecovered = ['pending', 'retry_wait'].includes(job.status)
      && job.failureCount === 0 && job.lastErrorCode === null;
    if (alreadyRecovered) return { outcome: 'already-recovered', applied: false };
    if (job.status !== 'blocked' || job.lastErrorCode !== 'retry-exhausted'
        || job.failureCount !== 8 || job.attemptCount !== 8
        || job.lastFailureCategory && job.lastFailureCategory !== 'missing-index') {
      throw new Error('Job is not the expected exhausted missing-index failure.');
    }
    if (!apply) return { outcome: 'eligible', applied: false };

    tx.update(jobRef, {
      status: 'retry_wait',
      failureCount: 0,
      nextAttemptAt: now,
      lastErrorCode: null,
    });
    tx.update(outboxRef, { nextAttemptAt: now });
    return { outcome: 'recovered', applied: true };
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const options = recoveryOptions(process.argv.slice(2));
  const app = initializeApp({ projectId: options.projectId });
  try {
    const result = await recoverBlockedRatingsDeletion(
      getFirestore(app), options.uid, { apply: options.apply },
    );
    console.log(JSON.stringify({
      projectId: options.projectId,
      mode: options.apply ? 'apply' : 'dry-run',
      ...result,
    }, null, 2));
    if (!options.apply && result.outcome === 'eligible') {
      console.log('No writes performed. Re-run with --apply after reviewing this result.');
    }
  } finally {
    await deleteApp(app);
  }
}
