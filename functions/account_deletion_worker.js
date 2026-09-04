import { DeletionVerificationFailure, failVerification, verifyManifestMatch } from './account_deletion_verify.js';
import { prepareRatingReconciliation, ratingIdentity, RatingReconciliationError } from './rating_contributions.js';
import { assertSafeFirestore } from './backend_environment.js';
import { cleanDeletionMatch, validDeletionTimestamp } from './account_deletion_matches.js';
import { ACCOUNT_SCHEMA_VERSION, DELETION_BARRIERS, DELETION_JOBS, DELETION_PHASES } from './account_state.js';
import { DELETION_OUTBOX, performDeletionAuthLock } from './account_deletion.js';

// Backend-only primitive. Generate a fresh token per attempt (e.g. randomUUID),
// and reuse it only when retrying an acquisition whose response was lost.
function jobReference(db, uid, lease) {
  assertSafeFirestore(db);
  for (const value of [uid, lease?.leaseOwner, lease?.leaseToken]) {
    if (typeof value !== 'string' || !value || value.length > 128 || value.includes('/')) {
      throw new Error('Invalid worker identity.');
    }
  }
  return db.collection(DELETION_JOBS).doc(uid);
}
function time(now) {
  if (!(now instanceof Date) || !Number.isFinite(now.getTime())) throw new Error('Invalid worker time.');
  return now.getTime();
}
function owns(job, lease, now) {
  return job?.leaseOwner === lease.leaseOwner && job?.leaseToken === lease.leaseToken
    && job.leaseExpiresAt?.toMillis() > time(now);
}
function requireOwner(job, lease, now) {
  if (!owns(job, lease, now)) throw new Error('Worker lease lost.');
}

export async function acquireDeletionLease(db, uid, lease, { now: at, leaseMs = 60000 } = {}) {
  const ref = jobReference(db, uid, lease);
  if (at !== undefined) time(at);
  if (!Number.isSafeInteger(leaseMs) || leaseMs <= 0 || leaseMs > 3600000) throw new Error('Invalid lease duration.');
  return db.runTransaction(async (tx) => {
    const [snapshot, outbox] = await tx.getAll(ref, db.collection(DELETION_OUTBOX).doc(uid));
    const now = at ?? new Date();
    const job = snapshot.data();
    if (!job || outbox.data()?.status !== 'ready_for_cleanup'
        || !['pending', 'retry_wait'].includes(job.status) || job.completedAt
        || !DELETION_PHASES.includes(job.phase) || ['disableAuth', 'complete'].includes(job.phase)) return false;
    if (owns(job, lease, now)) return true; // No extension or extra attempt on replay.
    if (job.leaseExpiresAt?.toMillis() > now.getTime()) return false;
    // An expired/released token cannot resurrect an old worker.
    if (job.leaseToken === lease.leaseToken) return false;
    if (job.nextAttemptAt?.toMillis() > now.getTime()) return false;
    tx.update(ref, { leaseOwner: lease.leaseOwner, leaseToken: lease.leaseToken,
      leaseExpiresAt: new Date(now.getTime() + leaseMs),
      attemptCount: (job.attemptCount ?? 0) + 1, status: 'pending', nextAttemptAt: null });
    return true;
  });
}

// Checkpoints are monotonically increasing integer batch positions within the
// current phase. CAS prevents a delayed call from overwriting later progress.
// This helper never transitions phases or marks deletion complete.
export async function checkpointDeletion(db, uid, lease, { phase, expectedCheckpoint, checkpoint }, at, validate) {
  const ref = jobReference(db, uid, lease);
  if (at !== undefined) time(at);
  if (!DELETION_PHASES.includes(phase) || ['disableAuth', 'deleteAuth', 'complete'].includes(phase)
      || !(expectedCheckpoint === null || (Number.isSafeInteger(expectedCheckpoint) && expectedCheckpoint >= 0))
      || !Number.isSafeInteger(checkpoint) || checkpoint <= (expectedCheckpoint ?? -1)) {
    throw new Error('Invalid worker checkpoint.');
  }
  return db.runTransaction(async (tx) => {
    const job = (await tx.get(ref)).data();
    const now = at ?? new Date();
    requireOwner(job, lease, now);
    if (validate) await validate(tx, job);
    if (job.phase !== phase || job.completedAt || job.status !== 'pending') throw new Error('Worker phase changed.');
    if (job.checkpoint === checkpoint) return; // Lost response replay.
    if (job.checkpoint !== expectedCheckpoint) throw new Error('Worker checkpoint changed.');
    tx.update(ref, { checkpoint, lastErrorCode: null });
  });
}

const SAFE_WORKER_ERROR_CATEGORIES = new Set([
  'missing-index', 'failed-precondition', 'permission-denied',
  'resource-exhausted', 'aborted', 'internal', 'unavailable',
  'deadline-exceeded', 'invalid-worker-state', 'worker-work-failed',
]);

export function sanitizedWorkerErrorCategory(error) {
  const code = typeof error?.code === 'string'
    ? error.code.replace(/^\d+\s+/, '')
    : error?.code;
  if ((code === 9 || code === 'failed-precondition')
      && typeof error?.message === 'string' && /index/i.test(error.message)) return 'missing-index';
  return new Map([
    [9, 'failed-precondition'], ['failed-precondition', 'failed-precondition'],
    [7, 'permission-denied'], ['permission-denied', 'permission-denied'],
    [8, 'resource-exhausted'], ['resource-exhausted', 'resource-exhausted'],
    [10, 'aborted'], ['aborted', 'aborted'],
    [13, 'internal'], ['internal', 'internal'],
    [14, 'unavailable'], ['unavailable', 'unavailable'],
    [4, 'deadline-exceeded'], ['deadline-exceeded', 'deadline-exceeded'],
  ]).get(code) ?? 'invalid-worker-state';
}

export async function retryDeletionLease(db, uid, lease, {
  now: at, retryMs = 1000, errorCategory = 'worker-work-failed',
} = {}) {
  const ref = jobReference(db, uid, lease);
  if (at !== undefined) time(at);
  if (!Number.isSafeInteger(retryMs) || retryMs < 0 || retryMs > 3600000) throw new Error('Invalid retry delay.');
  if (!SAFE_WORKER_ERROR_CATEGORIES.has(errorCategory)) throw new Error('Invalid worker error category.');
  return db.runTransaction(async (tx) => {
    const job = (await tx.get(ref)).data();
    const now = at ?? new Date();
    // Idempotent failure acknowledgement, without changing the retry deadline.
    if (job?.leaseToken === lease.leaseToken && job.leaseOwner === null && job.status === 'retry_wait') return;
    requireOwner(job, lease, now);
    tx.update(ref, { status: 'retry_wait', leaseOwner: null, leaseExpiresAt: null,
      lastErrorCode: 'worker-work-failed', lastFailureCategory: errorCategory,
      nextAttemptAt: new Date(now.getTime() + retryMs) });
  });
}

// Work must itself be idempotent: lease loss/crash after an external effect can
// cause it to run again. Never put external work inside a Firestore transaction.
export async function runDeletionStep(db, uid, lease, progress, work) {
  const ref = jobReference(db, uid, lease);
  await db.runTransaction(async (tx) => requireOwner((await tx.get(ref)).data(), lease, new Date()));
  try { await work(); }
  catch (error) {
    await retryDeletionLease(db, uid, lease);
    throw error;
  }
  await checkpointDeletion(db, uid, lease, progress);
}

// Keep admission's disableAuth separate from the ordered cleanup phases.
export const DELETION_WORKER_PHASES = Object.freeze([
  'accepted', 'matches', 'joinRequests', 'notifications', 'ratings', 'verify', 'deleteAuth',
]);
// Reserved end-of-phase marker, recorded through checkpointDeletion (or
// runDeletionStep) only after all work for that phase has succeeded.
export const DELETION_PHASE_COMPLETE_CHECKPOINT = Number.MAX_SAFE_INTEGER;

export async function transitionDeletionPhase(db, uid, lease, { expectedPhase, nextPhase }, at, validate) {
  const ref = jobReference(db, uid, lease);
  if (at !== undefined) time(at);
  const index = DELETION_WORKER_PHASES.indexOf(expectedPhase);
  if (index < 0 || index === DELETION_WORKER_PHASES.length - 1
      || nextPhase !== DELETION_WORKER_PHASES[index + 1]) {
    throw new Error('Invalid worker phase transition.');
  }
  return db.runTransaction(async (tx) => {
    const job = (await tx.get(ref)).data();
    requireOwner(job, lease, at ?? new Date());
    if (validate) await validate(tx, job);
    if (job.status !== 'pending' || job.completedAt || job.phase === 'complete') {
      throw new Error('Worker job cannot transition.');
    }
    const receipt = job.lastPhaseTransition;
    if (job.phase === nextPhase && receipt?.from === expectedPhase && receipt.to === nextPhase
        && receipt.leaseOwner === lease.leaseOwner && receipt.leaseToken === lease.leaseToken) {
      return; // Preserve any progress already made in the next phase on replay.
    }
    if (job.phase !== expectedPhase) throw new Error('Worker phase changed.');
    if (job.checkpoint !== DELETION_PHASE_COMPLETE_CHECKPOINT) {
      throw new Error('Worker phase checkpoint incomplete.');
    }
    tx.update(ref, { phase: nextPhase, checkpoint: null,
      lastPhaseTransition: { from: expectedPhase, to: nextPhase,
        leaseOwner: lease.leaseOwner, leaseToken: lease.leaseToken } });
    // Preserve owner/token/expiry and retry state; never write cutoff/completion.
  });
}

// Preparation only. No cleanup dispatch or permanent Auth deletion.
export async function runAcceptedDeletionPhase(db, auth, uid, lease) {
  try { return await prepareAcceptedDeletion(db, auth, uid, lease); }
  catch (error) {
    // Firestore may exhaust its own retries or lose a write acknowledgement.
    // Retain progress and the completion marker so the next lease can resume.
    if ([4, 8, 10, 13, 14, 'deadline-exceeded', 'resource-exhausted',
      'aborted', 'internal', 'unavailable'].includes(error.code)) {
      await retryDeletionLease(db, uid, lease);
      throw new Error('Accepted preparation failed.');
    }
    throw error;
  }
}

async function prepareAcceptedDeletion(db, auth, uid, lease) {
  const ref = jobReference(db, uid, lease);
  let cutoff;
  const invalid = () => { throw new Error('Invalid accepted deletion state.'); };
  const timestamp = (value) => Number.isInteger(value?.seconds)
    && Number.isInteger(value?.nanoseconds) && value.nanoseconds >= 0
    && value.nanoseconds < 1e9 && Number.isFinite(value?.toMillis?.())
    && value.seconds >= -62135596800 && value.seconds <= 253402300799;
  const validate = async (tx, job, requireLocked = false) => {
    const snapshots = await tx.getAll(db.collection(DELETION_BARRIERS).doc(uid),
      db.collection(DELETION_OUTBOX).doc(uid), db.collection('users').doc(uid),
      db.collection('publicProfiles').doc(uid));
    const [barrier, outbox] = snapshots.map((snapshot) => snapshot.data());
    if (!job || !barrier || !outbox || snapshots[2].exists || snapshots[3].exists) invalid();
    for (const record of [job, barrier, outbox]) {
      if (record.uid !== uid || record.schemaVersion !== ACCOUNT_SCHEMA_VERSION
          || !timestamp(record.deletionRequestedAt)) invalid();
    }
    const fixed = job.deletionRequestedAt;
    if (![barrier.deletionRequestedAt, outbox.deletionRequestedAt, cutoff ?? fixed]
      .every((value) => value.isEqual(fixed))) invalid();
    cutoff ??= fixed;
    if (barrier.status !== 'deleting' || outbox.jobId !== uid
        || outbox.status !== 'ready_for_cleanup' || job.status !== 'pending'
        || job.completedAt !== null || typeof job.authMissing !== 'boolean') invalid();
    for (const value of [job.authDisabledAt, job.authRevokedAt]) {
      if (value !== null && (!timestamp(value) || value.toMillis() < fixed.toMillis())) invalid();
    }
    if ((job.authRevokedAt !== null && job.authDisabledAt === null)
        || (job.authMissing && job.authDisabledAt === null)) invalid();
    if (requireLocked && (!job.authDisabledAt || !job.authRevokedAt)) invalid();
    if (job.phase === 'matches') {
      const receipt = job.lastPhaseTransition;
      if (receipt?.from !== 'accepted' || receipt.to !== 'matches'
          || receipt.leaseOwner !== lease.leaseOwner || receipt.leaseToken !== lease.leaseToken
          || !job.authDisabledAt || !job.authRevokedAt) invalid();
      return;
    }
    if (job.phase !== 'accepted' || ![null, DELETION_PHASE_COMPLETE_CHECKPOINT].includes(job.checkpoint)
        || (job.checkpoint !== null && (!job.authDisabledAt || !job.authRevokedAt))) invalid();
  };
  const inspect = () => db.runTransaction(async (tx) => {
    const job = (await tx.get(ref)).data();
    requireOwner(job, lease, new Date());
    await validate(tx, job);
    return job;
  });
  // Malformed state fails closed without scheduling another attempt.
  let job = await inspect();
  if (job.phase === 'matches') return;
  for (const [operation, field] of [['disable', 'authDisabledAt'], ['revoke', 'authRevokedAt']]) {
    job = await inspect();
    if (job.phase === 'matches') return;
    if (job[field]) continue;
    let missing;
    try { missing = await performDeletionAuthLock(auth, uid, operation); }
    catch {
      await retryDeletionLease(db, uid, lease);
      throw new Error('Auth lockdown failed.');
    }
    await db.runTransaction(async (tx) => {
      const current = (await tx.get(ref)).data();
      requireOwner(current, lease, new Date());
      await validate(tx, current);
      if (current.phase === 'accepted' && !current[field]) {
        tx.update(ref, { [field]: new Date(), authMissing: current.authMissing || missing });
      }
    });
  }
  const locked = (tx, current) => validate(tx, current, true);
  job = await inspect();
  if (job.phase === 'matches') return;
  try {
    await checkpointDeletion(db, uid, lease, { phase: 'accepted', expectedCheckpoint: null,
      checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT }, undefined, locked);
  } catch (error) {
    // A concurrent duplicate may already have completed the fenced transition.
    if ((await inspect()).phase === 'matches') return;
    throw error;
  }
  await transitionDeletionPhase(db, uid, lease,
    { expectedPhase: 'accepted', nextPhase: 'matches' }, undefined, locked);
}

// One atomic, bounded page per call. The caller may resume with any fresh lease.
// Document-ID ordering includes missing/bad scheduledAt values for quarantine.
export async function runMatchesDeletionPhase(db, uid, lease, { pageSize = 100 } = {}) {
  const ref = jobReference(db, uid, lease);
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) throw new Error('Invalid match page size.');
  const streams = ['creatorUid', 'createdBy', 'participantUids'];
  const initial = () => Object.fromEntries(streams.map((key) => [key, { after: null, done: false }]));
  let cutoff;
  const validate = async (tx, job) => {
    const [barrier, outbox] = await tx.getAll(db.collection(DELETION_BARRIERS).doc(uid),
      db.collection(DELETION_OUTBOX).doc(uid));
    const records = [job, barrier.data(), outbox.data()];
    if (records.some((r) => !r || r.uid !== uid || r.schemaVersion !== ACCOUNT_SCHEMA_VERSION
        || !validDeletionTimestamp(r.deletionRequestedAt))
        || records.some((r) => !r.deletionRequestedAt.isEqual(job.deletionRequestedAt))
        || (cutoff && !cutoff.isEqual(job.deletionRequestedAt))
        || barrier.data().status !== 'deleting' || outbox.data().status !== 'ready_for_cleanup'
        || outbox.data().jobId !== uid || job.status !== 'pending' || job.completedAt !== null
        || !validDeletionTimestamp(job.authDisabledAt) || !validDeletionTimestamp(job.authRevokedAt)) {
      throw new Error('Invalid matches deletion state.');
    }
    cutoff ??= job.deletionRequestedAt;
    const state = job.matchesCheckpoint ?? initial();
    if (Object.keys(state).length !== 3 || streams.some((s) => !state[s]
        || typeof state[s].done !== 'boolean'
        || !(state[s].after === null || (typeof state[s].after === 'string'
          && state[s].after.length > 0 && !state[s].after.includes('/'))))
        || (job.matchesCutoff && !job.matchesCutoff.isEqual(cutoff))) throw new Error('Invalid match checkpoint.');
    return state;
  };
  try {
    const result = await db.runTransaction(async (tx) => {
      const job = (await tx.get(ref)).data();
      requireOwner(job, lease, new Date());
      const state = await validate(tx, job);
      if (job.phase === 'joinRequests' && job.lastPhaseTransition?.from === 'matches') return { complete: true };
      if (job.phase !== 'matches') throw new Error('Worker phase changed.');
      const stream = streams.find((s) => !state[s].done);
      if (!stream) return { exhausted: true, checkpoint: job.checkpoint };
      if (!(job.checkpoint === null || (Number.isSafeInteger(job.checkpoint)
          && job.checkpoint >= 0 && job.checkpoint < DELETION_PHASE_COMPLETE_CHECKPOINT - 1))) {
        throw new Error('Invalid match checkpoint.');
      }
      let query = db.collection('matches').where(stream, stream === 'participantUids' ? 'array-contains' : '==', uid)
        .orderBy('__name__').limit(pageSize);
      if (state[stream].after) query = query.startAfter(state[stream].after);
      const page = await tx.get(query);
      const effects = [];
      for (const doc of page.docs) {
        try { effects.push({ doc, ...cleanDeletionMatch(doc.data(), uid, cutoff) }); }
        catch {
          requireOwner(job, lease, new Date());
          tx.update(ref, { status: 'blocked', lastErrorCode: 'matches-ambiguous-state',
            matchesBlockedRecord: doc.id });
          return { blocked: true };
        }
      }
      requireOwner(job, lease, new Date());
      for (const effect of effects) {
        tx.set(effect.doc.ref, effect.data);
        // Bounded durable manifest, not an ever-growing array on the job.
        tx.set(ref.collection('matchCleanup').doc(effect.doc.id), {
          matchId: effect.doc.id, organized: effect.organized, future: effect.future,
          deletionRequestedAt: cutoff,
        });
      }
      state[stream] = { after: page.docs.at(-1)?.id ?? state[stream].after, done: page.size < pageSize };
      const checkpoint = (job.checkpoint ?? -1) + 1;
      tx.update(ref, { checkpoint, matchesCheckpoint: state, matchesCutoff: cutoff, lastErrorCode: null });
      return { processed: page.size, stream, exhausted: streams.every((s) => state[s].done), checkpoint };
    });
    if (result.blocked) throw new Error('Ambiguous match state; job blocked.');
    if (result.exhausted) {
      const exhausted = async (tx, job) => {
        const state = await validate(tx, job);
        if (!streams.every((s) => state[s].done)) throw new Error('Match streams incomplete.');
        requireOwner(job, lease, new Date());
      };
      if (result.checkpoint !== DELETION_PHASE_COMPLETE_CHECKPOINT) {
        await checkpointDeletion(db, uid, lease, { phase: 'matches', expectedCheckpoint: result.checkpoint,
          checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT }, undefined, exhausted);
      }
      await transitionDeletionPhase(db, uid, lease, { expectedPhase: 'matches', nextPhase: 'joinRequests' }, undefined, exhausted);
      return { ...result, complete: true };
    }
    return result;
  } catch (error) {
    if ([4, 8, 10, 13, 14, 'deadline-exceeded', 'resource-exhausted', 'aborted', 'internal', 'unavailable'].includes(error.code)) {
      await retryDeletionLease(db, uid, lease);
      throw new Error('Matches cleanup failed.');
    }
    throw error;
  }
}

// Supported global schema requires userId; a collection-group document-name
// filter cannot search a bare UID across unknown parents. Manifest paths also
// cover legacy path-only requests without scanning unrelated matches.
export async function runJoinRequestsDeletionPhase(db, uid, lease, { pageSize = 100 } = {}) {
  const ref = jobReference(db, uid, lease);
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) throw new Error('Invalid join-request page size.');
  const validId = (v) => typeof v === 'string' && v.length > 0 && v.length <= 128 && !v.includes('/');
  const requestPath = (v) => typeof v === 'string' && /^matches\/[^/]+\/joinRequests\/[^/]+$/.test(v);
  const initial = () => ({ userAfter: null, userDone: false, manifestAfter: null,
    manifestDone: false, requestAfter: null });
  let cutoff;
  const validate = async (tx, job) => {
    const [barrier, outbox] = await tx.getAll(db.collection(DELETION_BARRIERS).doc(uid), db.collection(DELETION_OUTBOX).doc(uid));
    if ([job, barrier.data(), outbox.data()].some((r) => !r || r.uid !== uid
        || r.schemaVersion !== ACCOUNT_SCHEMA_VERSION || !validDeletionTimestamp(r.deletionRequestedAt)
        || !r.deletionRequestedAt.isEqual(job.deletionRequestedAt))
        || (cutoff && !cutoff.isEqual(job.deletionRequestedAt))
        || (job.joinRequestsCutoff && !job.joinRequestsCutoff.isEqual(job.deletionRequestedAt))
        || (job.matchesCutoff && !job.matchesCutoff.isEqual(job.deletionRequestedAt))
        || barrier.data().status !== 'deleting' || outbox.data().status !== 'ready_for_cleanup'
        || outbox.data().jobId !== uid || job.status !== 'pending' || job.completedAt !== null
        || !validDeletionTimestamp(job.authDisabledAt) || !validDeletionTimestamp(job.authRevokedAt)) {
      throw new Error('Invalid join-request deletion state.');
    }
    cutoff ??= job.deletionRequestedAt;
    const state = job.joinRequestsCheckpoint ?? initial();
    if (Object.keys(state).length !== 5 || typeof state.userDone !== 'boolean'
        || typeof state.manifestDone !== 'boolean'
        || !(state.userAfter === null || requestPath(state.userAfter))
        || !(state.manifestAfter === null || validId(state.manifestAfter))
        || !(state.requestAfter === null || validId(state.requestAfter))) throw new Error('Invalid join-request checkpoint.');
    return state;
  };
  try {
    const result = await db.runTransaction(async (tx) => {
      const job = (await tx.get(ref)).data();
      requireOwner(job, lease, new Date());
      const state = await validate(tx, job);
      if (job.phase === 'notifications' && job.lastPhaseTransition?.from === 'joinRequests') return { complete: true };
      if (job.phase !== 'joinRequests') throw new Error('Worker phase changed.');
      if (state.userDone && state.manifestDone) return { exhausted: true, checkpoint: job.checkpoint };
      if (!(job.checkpoint === null || (Number.isSafeInteger(job.checkpoint) && job.checkpoint >= 0
          && job.checkpoint < DELETION_PHASE_COMPLETE_CHECKPOINT - 1))) throw new Error('Invalid join-request checkpoint.');
      const block = (path) => {
        requireOwner(job, lease, new Date());
        tx.update(ref, { status: 'blocked', lastErrorCode: 'joinRequests-ambiguous-state', joinRequestsBlockedRecord: path });
        return { blocked: true };
      };
      let docs = [];
      if (!state.userDone) {
        let query = db.collectionGroup('joinRequests').where('userId', '==', uid).orderBy('__name__').limit(pageSize);
        if (state.userAfter) query = query.startAfter(db.doc(state.userAfter));
        const page = await tx.get(query);
        docs = page.docs;
        state.userAfter = docs.at(-1)?.ref.path ?? state.userAfter;
        state.userDone = page.size < pageSize;
      } else {
        // One manifest entry and at most one descendant page per invocation.
        // Keep the manifest cursor behind the current entry until it is drained.
        let query = ref.collection('matchCleanup').orderBy('__name__').limit(1);
        if (state.manifestAfter) query = query.startAfter(state.manifestAfter);
        const entry = (await tx.get(query)).docs[0];
        if (!entry) state.manifestDone = true;
        else {
          const data = entry.data();
          if (!validId(entry.id) || data.matchId !== entry.id || typeof data.organized !== 'boolean'
              || typeof data.future !== 'boolean' || !validDeletionTimestamp(data.deletionRequestedAt)
              || !data.deletionRequestedAt.isEqual(cutoff)) return block(entry.ref.path);
          const requests = db.collection(`matches/${entry.id}/joinRequests`);
          let done = true;
          if (data.organized && data.future) {
            let children = requests.orderBy('__name__').limit(pageSize);
            if (state.requestAfter) children = children.startAfter(state.requestAfter);
            const page = await tx.get(children);
            docs = page.docs;
            done = page.size < pageSize;
            state.requestAfter = docs.at(-1)?.id ?? state.requestAfter;
          } else {
            if (state.requestAfter !== null) return block(entry.ref.path);
            const own = await tx.get(requests.doc(uid));
            if (own.exists) docs = [own];
          }
          if (done) { state.manifestAfter = entry.id; state.requestAfter = null; }
        }
      }
      // Validate the entire page before deleting any record. Email and status
      // never participate in identity or selection, including legacy statuses.
      for (const doc of docs) {
        const data = doc.data();
        if (!requestPath(doc.ref.path) || !validId(doc.id)
            || ['uid', 'userId'].some((key) => key in data && (!validId(data[key]) || data[key] !== doc.id))) {
          return block(doc.ref.path);
        }
      }
      requireOwner(job, lease, new Date());
      for (const doc of docs) tx.delete(doc.ref);
      const checkpoint = (job.checkpoint ?? -1) + 1;
      tx.update(ref, { checkpoint, joinRequestsCheckpoint: state, joinRequestsCutoff: cutoff, lastErrorCode: null });
      return { processed: docs.length, checkpoint, exhausted: state.userDone && state.manifestDone };
    });
    if (result.blocked) throw new Error('Ambiguous join request; job blocked.');
    if (result.exhausted) {
      const exhausted = async (tx, job) => {
        const state = await validate(tx, job);
        if (!state.userDone || !state.manifestDone) throw new Error('Join-request streams incomplete.');
        requireOwner(job, lease, new Date());
      };
      if (result.checkpoint !== DELETION_PHASE_COMPLETE_CHECKPOINT) await checkpointDeletion(db, uid, lease,
        { phase: 'joinRequests', expectedCheckpoint: result.checkpoint, checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT }, undefined, exhausted);
      await transitionDeletionPhase(db, uid, lease,
        { expectedPhase: 'joinRequests', nextPhase: 'notifications' }, undefined, exhausted);
      return { ...result, complete: true };
    }
    return result;
  } catch (error) {
    if ([4, 8, 10, 13, 14, 'deadline-exceeded', 'resource-exhausted', 'aborted', 'internal', 'unavailable'].includes(error.code)) {
      await retryDeletionLease(db, uid, lease);
      throw new Error('Join-request cleanup failed.');
    }
    throw error;
  }
}

// One bounded notification page, or one manifest entry, per trusted invocation.
export async function runNotificationsDeletionPhase(db, uid, lease, { pageSize = 100 } = {}) {
  const ref = jobReference(db, uid, lease);
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) throw new Error('Invalid notification page size.');
  const validId = (v) => typeof v === 'string' && v.length > 0 && v.length <= 128 && !v.includes('/');
  const documentId = (v) => typeof v === 'string' && v.length > 0 && !v.includes('/');
  const initial = () => ({ recipientAfter: null, recipientDone: false, actorAfter: null, actorDone: false, manifestAfter: null,
    manifestDone: false, matchAfter: null });
  let cutoff;
  const validate = async (tx, job) => {
    const [barrier, outbox] = await tx.getAll(db.collection(DELETION_BARRIERS).doc(uid), db.collection(DELETION_OUTBOX).doc(uid));
    if ([job, barrier.data(), outbox.data()].some((r) => !r || r.uid !== uid
        || r.schemaVersion !== ACCOUNT_SCHEMA_VERSION || !validDeletionTimestamp(r.deletionRequestedAt)
        || !r.deletionRequestedAt.isEqual(job.deletionRequestedAt))
        || (cutoff && !cutoff.isEqual(job.deletionRequestedAt))
        || (job.notificationsCutoff && !job.notificationsCutoff.isEqual(job.deletionRequestedAt))
        || (job.matchesCutoff && !job.matchesCutoff.isEqual(job.deletionRequestedAt))
        || (job.joinRequestsCutoff && !job.joinRequestsCutoff.isEqual(job.deletionRequestedAt))
        || barrier.data().status !== 'deleting' || outbox.data().status !== 'ready_for_cleanup'
        || outbox.data().jobId !== uid || job.status !== 'pending' || job.completedAt !== null
        || !validDeletionTimestamp(job.authDisabledAt) || !validDeletionTimestamp(job.authRevokedAt)) {
      throw new Error('Invalid notification deletion state.');
    }
    cutoff ??= job.deletionRequestedAt;
    const state = job.notificationsCheckpoint ?? initial();
    if (Object.keys(state).length !== 7 || typeof state.recipientDone !== 'boolean'
        || typeof state.actorDone !== 'boolean'
        || typeof state.manifestDone !== 'boolean'
        || !(state.recipientAfter === null || documentId(state.recipientAfter))
        || !(state.actorAfter === null || documentId(state.actorAfter))
        || !(state.manifestAfter === null || validId(state.manifestAfter))
        || !(state.matchAfter === null || documentId(state.matchAfter))
        || (state.actorDone && !state.recipientDone)
        || (state.manifestDone && (!state.actorDone || state.matchAfter !== null))) throw new Error('Invalid notification checkpoint.');
    return state;
  };
  try {
    const result = await db.runTransaction(async (tx) => {
      const job = (await tx.get(ref)).data();
      requireOwner(job, lease, new Date());
      const state = await validate(tx, job);
      if (job.phase === 'ratings' && job.lastPhaseTransition?.from === 'notifications') return { complete: true };
      if (job.phase !== 'notifications') throw new Error('Worker phase changed.');
      if (state.recipientDone && state.actorDone && state.manifestDone) return { exhausted: true, checkpoint: job.checkpoint };
      if (!(job.checkpoint === null || (Number.isSafeInteger(job.checkpoint) && job.checkpoint >= 0
          && job.checkpoint < DELETION_PHASE_COMPLETE_CHECKPOINT - 1))) throw new Error('Invalid notification checkpoint.');
      const block = (path) => {
        requireOwner(job, lease, new Date());
        tx.update(ref, { status: 'blocked', lastErrorCode: 'notifications-ambiguous-state', notificationsBlockedRecord: path });
        return { blocked: true };
      };
      let docs = [];
      if (!state.recipientDone || !state.actorDone) {
        const stream = !state.recipientDone ? 'recipient' : 'actor';
        let query = db.collection('notifications').where(`${stream}Uid`, '==', uid).orderBy('__name__').limit(pageSize);
        if (state[`${stream}After`]) query = query.startAfter(state[`${stream}After`]);
        const page = await tx.get(query);
        docs = page.docs;
        state[`${stream}After`] = docs.at(-1)?.id ?? state[`${stream}After`];
        state[`${stream}Done`] = page.size < pageSize;
      } else {
        // One manifest entry and at most one descendant page per invocation.
        // Keep the manifest cursor behind the current entry until it is drained.
        let query = ref.collection('matchCleanup').orderBy('__name__').limit(1);
        if (state.manifestAfter) query = query.startAfter(state.manifestAfter);
        const entry = (await tx.get(query)).docs[0];
        if (!entry) state.manifestDone = true;
        else {
          const data = entry.data();
          if (!validId(entry.id) || data.matchId !== entry.id || typeof data.organized !== 'boolean'
              || typeof data.future !== 'boolean' || !validDeletionTimestamp(data.deletionRequestedAt)
              || !data.deletionRequestedAt.isEqual(cutoff)) return block(entry.ref.path);
          const notifications = db.collection('notifications').where('matchId', '==', entry.id);
          let done = true;
          if (data.organized && data.future) {
            let children = notifications.orderBy('__name__').limit(pageSize);
            if (state.matchAfter) children = children.startAfter(state.matchAfter);
            const page = await tx.get(children);
            docs = page.docs;
            done = page.size < pageSize;
            state.matchAfter = docs.at(-1)?.id ?? state.matchAfter;
          } else {
            if (state.matchAfter !== null) return block(entry.ref.path);
          }
          if (done) { state.manifestAfter = entry.id; state.matchAfter = null; }
        }
      }
      // Validate the entire page before any deletion. Modern event-bearing
      // records redundantly encode their match/event reference in the ID.
      // Legacy records may lack actorUid/eventId; snapshots are never identity.
      for (const doc of docs) {
        const data = doc.data();
        if (!validId(data.recipientUid) || !documentId(data.matchId)
            || ('actorUid' in data && !validId(data.actorUid))
            || ('eventId' in data && data.eventId !== '' &&
              (!documentId(data.eventId)
                || !['join_request', 'join_approved', 'join_declined'].includes(data.type)
                || doc.id !== `${data.type}_${data.matchId}_${data.eventId}`))) {
          return block(doc.ref.path);
        }
      }
      requireOwner(job, lease, new Date());
      for (const doc of docs) tx.delete(doc.ref);
      const checkpoint = (job.checkpoint ?? -1) + 1;
      tx.update(ref, { checkpoint, notificationsCheckpoint: state, notificationsCutoff: cutoff, lastErrorCode: null });
      return { processed: docs.length, checkpoint, exhausted: state.recipientDone && state.actorDone && state.manifestDone };
    });
    if (result.blocked) throw new Error('Ambiguous notification; job blocked.');
    if (result.exhausted) {
      const exhausted = async (tx, job) => {
        const state = await validate(tx, job);
        if (!state.recipientDone || !state.actorDone || !state.manifestDone) throw new Error('Notification streams incomplete.');
        requireOwner(job, lease, new Date());
      };
      if (result.checkpoint !== DELETION_PHASE_COMPLETE_CHECKPOINT) await checkpointDeletion(db, uid, lease,
        { phase: 'notifications', expectedCheckpoint: result.checkpoint, checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT }, undefined, exhausted);
      await transitionDeletionPhase(db, uid, lease,
        { expectedPhase: 'notifications', nextPhase: 'ratings' }, undefined, exhausted);
      return { ...result, complete: true };
    }
    return result;
  } catch (error) {
    if ([4, 8, 10, 13, 14, 'deadline-exceeded', 'resource-exhausted', 'aborted', 'internal', 'unavailable'].includes(error.code)) {
      await retryDeletionLease(db, uid, lease);
      throw new Error('Notification cleanup failed.');
    }
    throw error;
  }
}

// Bounded, atomic ratings/contribution cleanup; stops at verification.
export async function runRatingsDeletionPhase(db, uid, lease, { pageSize = 100 } = {}) {
  const ref = jobReference(db, uid, lease);
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) throw new Error('Invalid rating page size.');
  const validId = (v) => typeof v === 'string' && v.length > 0 && v.length <= 128 && !v.includes('/');
  const ratingPath = (v) => {
    try { return typeof v === 'string' && Boolean(ratingIdentity(v)); } catch { return false; }
  };
  const initial = () => ({ givenAfter: null, givenDone: false, receivedAfter: null, receivedDone: false, manifestAfter: null,
    manifestDone: false, matchAfter: null });
  let cutoff;
  const validate = async (tx, job) => {
    const [barrier, outbox] = await tx.getAll(db.collection(DELETION_BARRIERS).doc(uid), db.collection(DELETION_OUTBOX).doc(uid));
    if ([job, barrier.data(), outbox.data()].some((r) => !r || r.uid !== uid
        || r.schemaVersion !== ACCOUNT_SCHEMA_VERSION || !validDeletionTimestamp(r.deletionRequestedAt)
        || !r.deletionRequestedAt.isEqual(job.deletionRequestedAt))
        || (cutoff && !cutoff.isEqual(job.deletionRequestedAt))
        || (job.ratingsCutoff && !job.ratingsCutoff.isEqual(job.deletionRequestedAt))
        || (job.matchesCutoff && !job.matchesCutoff.isEqual(job.deletionRequestedAt))
        || (job.joinRequestsCutoff && !job.joinRequestsCutoff.isEqual(job.deletionRequestedAt))
        || (job.notificationsCutoff && !job.notificationsCutoff.isEqual(job.deletionRequestedAt))
        || barrier.data().status !== 'deleting' || outbox.data().status !== 'ready_for_cleanup'
        || outbox.data().jobId !== uid || job.status !== 'pending' || job.completedAt !== null
        || !validDeletionTimestamp(job.authDisabledAt) || !validDeletionTimestamp(job.authRevokedAt)) {
      throw new Error('Invalid rating deletion state.');
    }
    cutoff ??= job.deletionRequestedAt;
    const state = job.ratingsCheckpoint ?? initial();
    if (Object.keys(state).length !== 7 || typeof state.givenDone !== 'boolean'
        || typeof state.receivedDone !== 'boolean'
        || typeof state.manifestDone !== 'boolean'
        || !(state.givenAfter === null || ratingPath(state.givenAfter))
        || !(state.receivedAfter === null || ratingPath(state.receivedAfter))
        || !(state.manifestAfter === null || validId(state.manifestAfter))
        || !(state.matchAfter === null || ratingPath(state.matchAfter))
        || (state.receivedDone && !state.givenDone)
        || (state.manifestDone && (!state.receivedDone || state.matchAfter !== null))) throw new Error('Invalid rating checkpoint.');
    return state;
  };
  try {
    const result = await db.runTransaction(async (tx) => {
      const job = (await tx.get(ref)).data();
      requireOwner(job, lease, new Date());
      const state = await validate(tx, job);
      if (job.phase === 'verify' && job.lastPhaseTransition?.from === 'ratings') return { complete: true };
      if (job.phase !== 'ratings') throw new Error('Worker phase changed.');
      if (state.givenDone && state.receivedDone && state.manifestDone) return { exhausted: true, checkpoint: job.checkpoint };
      if (!(job.checkpoint === null || (Number.isSafeInteger(job.checkpoint) && job.checkpoint >= 0
          && job.checkpoint < DELETION_PHASE_COMPLETE_CHECKPOINT - 1))) throw new Error('Invalid rating checkpoint.');
      const block = (path) => {
        requireOwner(job, lease, new Date());
        tx.update(ref, { status: 'blocked', lastErrorCode: 'ratings-ambiguous-state', ratingsBlockedRecord: path });
        return { blocked: true };
      };
      let docs = [];
      if (!state.givenDone || !state.receivedDone) {
        const stream = !state.givenDone ? 'given' : 'received';
        let query = db.collectionGroup('ratings').where(stream === 'given' ? 'raterUid' : 'ratedUid', '==', uid).orderBy('__name__').limit(pageSize);
        if (state[`${stream}After`]) query = query.startAfter(db.doc(state[`${stream}After`]));
        const page = await tx.get(query);
        docs = page.docs;
        state[`${stream}After`] = docs.at(-1)?.ref.path ?? state[`${stream}After`];
        state[`${stream}Done`] = page.size < pageSize;
      } else {
        // One manifest entry and at most one descendant page per invocation.
        // Keep the manifest cursor behind the current entry until it is drained.
        let query = ref.collection('matchCleanup').orderBy('__name__').limit(1);
        if (state.manifestAfter) query = query.startAfter(state.manifestAfter);
        const entry = (await tx.get(query)).docs[0];
        if (!entry) state.manifestDone = true;
        else {
          const data = entry.data();
          if (!validId(entry.id) || data.matchId !== entry.id || typeof data.organized !== 'boolean'
              || typeof data.future !== 'boolean' || !validDeletionTimestamp(data.deletionRequestedAt)
              || !data.deletionRequestedAt.isEqual(cutoff)) return block(entry.ref.path);
          const ratings = db.collectionGroup('ratings').where('matchId', '==', entry.id);
          let done = true;
          if (data.organized && data.future) {
            let children = ratings.orderBy('__name__').limit(pageSize);
            if (state.matchAfter) children = children.startAfter(db.doc(state.matchAfter));
            const page = await tx.get(children);
            docs = page.docs;
            done = page.size < pageSize;
            state.matchAfter = docs.at(-1)?.ref.path ?? state.matchAfter;
          } else {
            if (state.matchAfter !== null) return block(entry.ref.path);
          }
          if (done) { state.manifestAfter = entry.id; state.matchAfter = null; }
        }
      }
      // The existing reconciler rereads current rating/contribution/profile
      // state and stages all effects before writing anything. A malformed page
      // or inconsistent aggregate baseline is preserved in full for repair.
      let apply;
      try {
        apply = await prepareRatingReconciliation(db, tx, docs.map((doc) => doc.ref.path), { removeRatings: true });
      } catch (error) {
        if (error instanceof RatingReconciliationError) return block(error.recordPath ?? ref.path);
        throw error;
      }
      requireOwner(job, lease, new Date());
      apply();
      const checkpoint = (job.checkpoint ?? -1) + 1;
      tx.update(ref, { checkpoint, ratingsCheckpoint: state, ratingsCutoff: cutoff,
        lastErrorCode: null, lastFailureCategory: null });
      return { processed: docs.length, checkpoint, exhausted: state.givenDone && state.receivedDone && state.manifestDone };
    });
    if (result.blocked) throw new Error('Ambiguous rating; job blocked.');
    if (result.exhausted) {
      const exhausted = async (tx, job) => {
        const state = await validate(tx, job);
        if (!state.givenDone || !state.receivedDone || !state.manifestDone) throw new Error('Rating streams incomplete.');
        requireOwner(job, lease, new Date());
      };
      if (result.checkpoint !== DELETION_PHASE_COMPLETE_CHECKPOINT) await checkpointDeletion(db, uid, lease,
        { phase: 'ratings', expectedCheckpoint: result.checkpoint, checkpoint: DELETION_PHASE_COMPLETE_CHECKPOINT }, undefined, exhausted);
      await transitionDeletionPhase(db, uid, lease,
        { expectedPhase: 'ratings', nextPhase: 'verify' }, undefined, exhausted);
      return { ...result, complete: true };
    }
    return result;
  } catch (error) {
    if ([4, 8, 10, 13, 14, 'deadline-exceeded', 'resource-exhausted', 'aborted', 'internal', 'unavailable'].includes(error.code)) {
      await retryDeletionLease(db, uid, lease, { errorCategory: sanitizedWorkerErrorCategory(error) });
      throw new Error('Rating cleanup failed.');
    }
    throw error;
  }
}

// Bounded verification only. Auth deletion is the separately fenced final phase.
export async function runVerifyDeletionPhase(db, uid, lease) {
  const ref = jobReference(db, uid, lease);
  let cutoff;
  const validId = (value) => typeof value === 'string' && value.length > 0 && !value.includes('/');
  const validate = async (tx, job) => {
    const [barrier, outbox, privateProfile, publicProfile] = await tx.getAll(
      db.collection(DELETION_BARRIERS).doc(uid), db.collection(DELETION_OUTBOX).doc(uid),
      db.collection('users').doc(uid), db.collection('publicProfiles').doc(uid));
    if ([job, barrier.data(), outbox.data()].some((record) => !record || record.uid !== uid
        || record.schemaVersion !== ACCOUNT_SCHEMA_VERSION || !validDeletionTimestamp(record.deletionRequestedAt)
        || !record.deletionRequestedAt.isEqual(job.deletionRequestedAt))
        || (cutoff && !cutoff.isEqual(job.deletionRequestedAt))
        || ['matchesCutoff', 'joinRequestsCutoff', 'notificationsCutoff', 'ratingsCutoff', 'verifyCutoff']
          .some((key) => key in job && (!validDeletionTimestamp(job[key]) || !job[key].isEqual(job.deletionRequestedAt)))
        || barrier.data()?.status !== 'deleting' || outbox.data()?.status !== 'ready_for_cleanup'
        || outbox.data()?.jobId !== uid || job.status !== 'pending' || job.completedAt !== null
        || Object.keys(job).some((key) => key.endsWith('BlockedRecord') && job[key] !== null)
        || !validDeletionTimestamp(job.authDisabledAt) || !validDeletionTimestamp(job.authRevokedAt)
        || job.authDisabledAt.toMillis() < job.deletionRequestedAt.toMillis()
        || job.authRevokedAt.toMillis() < job.authDisabledAt.toMillis()) failVerification('verify-infrastructure');
    cutoff ??= job.deletionRequestedAt;
    if (privateProfile.exists || publicProfile.exists) failVerification('verify-profile-remains');
    const state = job.verifyCheckpoint ?? { manifestAfter: null, manifestDone: false };
    if (Object.keys(state).length !== 2 || typeof state.manifestDone !== 'boolean'
        || !(state.manifestAfter === null || validId(state.manifestAfter))
        || (job.verifyCheckpoint && !validDeletionTimestamp(job.verifyCutoff))
        || (!job.verifyCheckpoint && job.checkpoint !== null)
        || (job.phase === 'verify' && state.manifestDone && job.checkpoint !== DELETION_PHASE_COMPLETE_CHECKPOINT)
        || (job.phase === 'deleteAuth' && !state.manifestDone)) failVerification('verify-checkpoint');
    return state;
  };
  const absent = async (tx, query, code) => {
    if (!(await tx.get(query.limit(1))).empty) failVerification(code);
  };
  // Repeat these constant-size probes on every page and at the final transition.
  // Checking all owner references also rejects non-anonymized historical owners.
  const globalChecks = async (tx) => {
    for (const field of ['creatorUid', 'createdBy', 'participantUids']) {
      await absent(tx, db.collection('matches').where(field, field === 'participantUids' ? 'array-contains' : '==', uid), 'verify-match-reference');
    }
    for (const field of ['userId', 'uid']) {
      await absent(tx, db.collectionGroup('joinRequests').where(field, '==', uid), 'verify-join-request-remains');
    }
    for (const field of ['recipientUid', 'actorUid']) {
      await absent(tx, db.collection('notifications').where(field, '==', uid), 'verify-notification-remains');
    }
    for (const field of ['raterUid', 'ratedUid']) {
      await absent(tx, db.collectionGroup('ratings').where(field, '==', uid), 'verify-rating-remains');
      await absent(tx, db.collection('ratingContributions').where(field, '==', uid), 'verify-contribution-remains');
    }
  };
  try {
    const result = await db.runTransaction(async (tx) => {
      const job = (await tx.get(ref)).data();
      requireOwner(job, lease, new Date());
      const state = await validate(tx, job);
      if (job.phase === 'deleteAuth' && job.lastPhaseTransition?.from === 'verify'
          && job.lastPhaseTransition?.to === 'deleteAuth'
          && job.lastPhaseTransition?.leaseOwner === lease.leaseOwner
          && job.lastPhaseTransition?.leaseToken === lease.leaseToken) return { complete: true };
      if (job.phase !== 'verify') throw new Error('Worker phase changed.');
      if (!(job.checkpoint === null || (Number.isSafeInteger(job.checkpoint) && job.checkpoint >= 0
          && job.checkpoint < DELETION_PHASE_COMPLETE_CHECKPOINT - 1)
          || (job.checkpoint === DELETION_PHASE_COMPLETE_CHECKPOINT && state.manifestDone))) failVerification('verify-checkpoint');
      await globalChecks(tx);
      let processed = 0;
      if (!state.manifestDone) {
        let query = ref.collection('matchCleanup').orderBy('__name__').limit(1);
        if (state.manifestAfter) query = query.startAfter(state.manifestAfter);
        const entry = (await tx.get(query)).docs[0];
        if (!entry) state.manifestDone = true;
        else {
          const data = entry.data();
          if (data.matchId !== entry.id || typeof data.organized !== 'boolean' || typeof data.future !== 'boolean'
              || !validDeletionTimestamp(data.deletionRequestedAt)
              || !data.deletionRequestedAt.isEqual(cutoff)) failVerification('verify-manifest');
          const match = await tx.get(db.collection('matches').doc(entry.id));
          verifyManifestMatch(match.data(), data, uid, cutoff);
          // Supported legacy path-only requests are deterministically addressable
          // beneath every manifest match, including missing parent documents.
          const requests = db.collection(`matches/${entry.id}/joinRequests`);
          if ((await tx.get(requests.doc(uid))).exists) failVerification('verify-join-request-remains');
          if (data.organized && data.future) {
            await absent(tx, requests, 'verify-cancelled-match-request');
            await absent(tx, db.collection('notifications').where('matchId', '==', entry.id), 'verify-cancelled-match-notification');
            await absent(tx, db.collectionGroup('ratings').where('matchId', '==', entry.id), 'verify-cancelled-match-rating');
            await absent(tx, db.collection('ratingContributions').where('matchId', '==', entry.id), 'verify-cancelled-match-contribution');
          }
          state.manifestAfter = entry.id;
          processed = 1;
        }
      }
      requireOwner(job, lease, new Date());
      tx.update(ref, { verifyCheckpoint: state, verifyCutoff: cutoff, lastErrorCode: null,
        checkpoint: state.manifestDone ? DELETION_PHASE_COMPLETE_CHECKPOINT : (job.checkpoint ?? -1) + 1 });
      return { processed, exhausted: state.manifestDone };
    });
    if (result.exhausted) {
      await transitionDeletionPhase(db, uid, lease, { expectedPhase: 'verify', nextPhase: 'deleteAuth' }, undefined,
        async (tx, job) => {
          const state = await validate(tx, job);
          if (!state.manifestDone) failVerification('verify-checkpoint');
          await globalChecks(tx);
          requireOwner(job, lease, new Date());
        });
      return { ...result, complete: true };
    }
    return result;
  } catch (error) {
    if (error instanceof DeletionVerificationFailure) {
      await db.runTransaction(async (tx) => {
        const job = (await tx.get(ref)).data();
        requireOwner(job, lease, new Date());
        if (job.phase !== 'verify' || job.status !== 'pending') throw new Error('Worker phase changed.');
        tx.update(ref, { status: 'blocked', lastErrorCode: error.verificationCode });
      });
      throw error;
    }
    if ([4, 8, 10, 13, 14, 'deadline-exceeded', 'resource-exhausted', 'aborted', 'internal', 'unavailable'].includes(error.code)) {
      await retryDeletionLease(db, uid, lease);
      throw new Error('Verification failed; retry required.');
    }
    throw error;
  }
}

// Auth is an external idempotent effect. Both sides of that effect are fenced;
// a worker losing its lease cannot finalize a receipt.
export async function runDeleteAuthDeletionPhase(db, auth, uid, lease) {
  const ref = jobReference(db, uid, lease);
  const inspect = async (tx) => {
    const [snapshot, barrier, outbox] = await tx.getAll(ref,
      db.collection(DELETION_BARRIERS).doc(uid), db.collection(DELETION_OUTBOX).doc(uid));
    const job = snapshot.data();
    if (job?.status === 'completed' && job.phase === 'complete') return null;
    requireOwner(job, lease, new Date());
    if (job.uid !== uid || job.phase !== 'deleteAuth' || job.status !== 'pending'
        || job.completedAt !== null || job.verifyCheckpoint?.manifestDone !== true
        || job.lastPhaseTransition?.from !== 'verify' || job.lastPhaseTransition?.to !== 'deleteAuth'
        || !validDeletionTimestamp(job.verifyCutoff)
        || !job.verifyCutoff.isEqual(job.deletionRequestedAt)
        || barrier.data()?.status !== 'deleting' || outbox.data()?.status !== 'ready_for_cleanup'
        || [barrier.data(), outbox.data()].some(r => r.uid !== uid
          || !r.deletionRequestedAt?.isEqual(job.deletionRequestedAt))) {
      throw new Error('Invalid Auth finalization state.');
    }
    return job;
  };
  const job = await db.runTransaction(inspect);
  if (!job) return { complete: true };
  try { await auth.deleteUser(job.uid); }
  catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }
  // Remove operational manifests in bounded pages before retaining a receipt.
  return db.runTransaction(async tx => {
    const current = await inspect(tx);
    if (!current) return { complete: true };
    const page = await tx.get(ref.collection('matchCleanup').limit(100));
    requireOwner(current, lease, new Date());
    for (const doc of page.docs) tx.delete(doc.ref);
    if (!page.empty) return { processed: page.size };
    const receipt = { uid, schemaVersion: ACCOUNT_SCHEMA_VERSION,
      deletionRequestedAt: current.deletionRequestedAt, completedAt: new Date() };
    tx.set(ref, { ...receipt, phase: 'complete', status: 'completed' });
    tx.set(db.collection(DELETION_BARRIERS).doc(uid), { ...receipt, status: 'deleted' });
    tx.set(db.collection(DELETION_OUTBOX).doc(uid), { ...receipt, jobId: uid, status: 'consumed' });
    return { complete: true };
  });
}
