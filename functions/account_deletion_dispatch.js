import { randomUUID } from 'node:crypto';
import { assertSafeFirestore } from './backend_environment.js';
import { DELETION_OUTBOX, lockDeletionAuth, acceptAccountDeletion } from './account_deletion.js';
import * as worker from './account_deletion_worker.js';

const handlers = {
  accepted: worker.runAcceptedDeletionPhase,
  matches: worker.runMatchesDeletionPhase,
  joinRequests: worker.runJoinRequestsDeletionPhase,
  notifications: worker.runNotificationsDeletionPhase,
  ratings: worker.runRatingsDeletionPhase,
  verify: worker.runVerifyDeletionPhase,
  deleteAuth: worker.runDeleteAuthDeletionPhase,
};

// A scheduler is sufficient at this scale: bounded pages, no queue/IAM adapter.
// nextAttemptAt rotates every selected outbox item, preventing head starvation.
export async function recoverAccountDeletions(db, auth, { pageSize = 20 } = {}) {
  const environment = assertSafeFirestore(db);
  if (environment.mode !== 'emulator' && process.env.PADELX_ACCOUNT_DELETION_ENABLED !== 'true') return;
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 20) throw new Error('Invalid recovery page size.');
  const page = await db.collection(DELETION_OUTBOX).where('nextAttemptAt', '<=', new Date())
    .orderBy('nextAttemptAt').limit(pageSize).get();
  return Promise.allSettled(page.docs.map(doc => dispatchAccountDeletion(db, auth, doc.id)));
}

export async function dispatchAccountDeletion(db, auth, uid) {
  assertSafeFirestore(db);
  const outboxRef = db.collection(DELETION_OUTBOX).doc(uid);
  const ref = db.collection('accountDeletionJobs').doc(uid);
  const lease = { leaseOwner: 'scheduled-worker', leaseToken: randomUUID() };
  // This is a durable visibility deadline, not a claim of successful work.
  const selected = await db.runTransaction(async tx => {
    const [outbox, snapshot] = await tx.getAll(outboxRef, ref);
    const job = snapshot.data();
    if (!job || !outbox.exists || outbox.data().status === 'consumed') return false;
    if (job.status === 'blocked' || job.status === 'completed') {
      tx.update(outboxRef, { nextAttemptAt: null }); return false;
    }
    if (outbox.data().nextAttemptAt?.toMillis() > Date.now()) return false;
    tx.update(outboxRef, { nextAttemptAt: new Date(Date.now() + 120000) });
    return true;
  });
  if (!selected) return;
  try {
    let job = (await ref.get()).data();
    if (job.phase === 'disableAuth') await lockDeletionAuth(db, auth, uid);
    if (!await worker.acquireDeletionLease(db, uid, lease, { leaseMs: 90000 })) return;
    // Bound execution, while reusing every existing page/checkpoint handler.
    for (let step = 0; step < 10; step++) {
      job = (await ref.get()).data();
      if (job.status !== 'pending') break;
      const handler = handlers[job.phase];
      if (!handler) throw new Error('Invalid deletion phase.');
      if (['accepted', 'deleteAuth'].includes(job.phase)) await handler(db, auth, uid, lease);
      else await handler(db, uid, lease);
      if (Date.now() > job.leaseExpiresAt.toMillis() - 15000) break;
    }
    await db.runTransaction(async tx => {
      const current = (await tx.get(ref)).data();
      if (current.status === 'pending' && current.leaseToken === lease.leaseToken) {
        tx.update(ref, { leaseOwner: null, leaseExpiresAt: null, nextAttemptAt: new Date(), failureCount: 0 });
        tx.update(outboxRef, { nextAttemptAt: new Date() });
      }
    });
  } catch (error) {
    await db.runTransaction(async tx => {
      const current = (await tx.get(ref)).data();
      if (!current || ['blocked', 'completed'].includes(current.status)
          || (current.leaseToken && current.leaseToken !== lease.leaseToken)) return;
      const failures = (current.failureCount ?? 0) + 1;
      const next = new Date(Date.now() + Math.min(3600000, 1000 * 2 ** Math.min(failures, 12)));
      tx.update(ref, { failureCount: failures, status: failures >= 8 ? 'blocked' : 'retry_wait',
        lastErrorCode: failures >= 8 ? 'retry-exhausted' : 'dispatch-failed',
        lastFailureCategory: current.lastFailureCategory ?? worker.sanitizedWorkerErrorCategory(error),
        leaseOwner: null, leaseExpiresAt: null, nextAttemptAt: failures >= 8 ? null : next });
      tx.update(outboxRef, { nextAttemptAt: failures >= 8 ? null : next });
    });
  }
}

// Trusted Auth event only; no client payload is passed through this entry point.
export async function acceptDeletedAuthUser(db, uid) {
  return acceptAccountDeletion(db, { auth: { uid, token: { auth_time: Math.floor(Date.now() / 1000) } }, data: {} });
}
