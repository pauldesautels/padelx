import { createHash } from 'node:crypto';

export const RELIABILITY_EVENTS = 'reliabilityEvents';
export const RELIABILITY_PROFILES = 'reliabilityProfiles';
// Reserved server-only seam for future corroborated attendance evidence.
// V1 deliberately does not consume these records or infer absence from app use.
export const ATTENDANCE_EVIDENCE = 'attendanceEvidence';
export const RELIABILITY_POLICY_VERSION = 'objective-reliability-v2-attendance';
export const RELIABILITY_MINIMUM_SAMPLE = 5;
export const RELIABILITY_EVENT_WINDOW = 200;

const cancellationPenalty = Object.freeze({
  over_24_hours: 5,
  '6_to_24_hours': 10,
  '2_to_6_hours': 20,
  under_2_hours: 35,
});
export const RELIABILITY_NO_SHOW_PENALTY = 50;

export function calculateReliability(events, now = new Date()) {
  const cancelledMatches = new Set(events
    .filter((event) => event?.type === 'confirmed_match_cancelled' && event.matchId)
    .map((event) => event.matchId));
  const committedMatches = new Set(events
    .filter((event) => event?.type === 'confirmed_match_committed' && event.matchId
      && (cancelledMatches.has(event.matchId)
        || (event.scheduledAt?.toDate?.() ?? event.scheduledAt) <= now))
    .map((event) => event.matchId));
  const mitigatedMatches = new Set(events
    .filter((event) => event?.type === 'replacement_secured' && event.matchId)
    .map((event) => event.matchId));
  const attendedMatches = new Set(events
    .filter((event) => event?.type === 'attendance_confirmed' && event.matchId)
    .map((event) => event.matchId));
  const noShowMatches = new Set(events
    .filter((event) => event?.type === 'no_show_confirmed' && event.matchId)
    .map((event) => event.matchId));
  let penalty = 0;
  for (const event of events) {
    if (event?.type !== 'confirmed_match_cancelled' || !committedMatches.has(event.matchId)) continue;
    const value = cancellationPenalty[event.timingCategory] ?? 0;
    penalty += mitigatedMatches.has(event.matchId) ? Math.ceil(value / 2) : value;
  }
  for (const matchId of noShowMatches) {
    // A canonical cancellation and an attendance outcome can never both
    // penalize the same commitment. Cancellation remains authoritative.
    if (!cancelledMatches.has(matchId)) penalty += RELIABILITY_NO_SHOW_PENALTY;
  }
  const resolvedMatches = new Set([...cancelledMatches, ...attendedMatches, ...noShowMatches]
    .filter((matchId) => committedMatches.has(matchId)));
  const legacyCommittedMatches = new Set(events
    .filter((event) => event?.type === 'confirmed_match_committed' && event.matchId
      && event.policyVersion !== RELIABILITY_POLICY_VERSION
      && (cancelledMatches.has(event.matchId)
        || (event.scheduledAt?.toDate?.() ?? event.scheduledAt) <= now))
    .map((event) => event.matchId));
  const sampleSize = new Set([...legacyCommittedMatches, ...resolvedMatches]).size;
  if (sampleSize < RELIABILITY_MINIMUM_SAMPLE) return {
    schemaVersion: 1, policyVersion: RELIABILITY_POLICY_VERSION,
    status: 'new_player', percent: null, sampleSize,
  };
  const raw = Math.max(0, Math.min(100, 100 - penalty));
  return { schemaVersion: 1, policyVersion: RELIABILITY_POLICY_VERSION,
    status: 'established', percent: Math.round(raw / 5) * 5, sampleSize };
}

export async function rebuildReliabilityProjection(firestore, uid, now = new Date()) {
  // Keep projection work bounded. The public percentage represents the most
  // recent objective history window, rather than an ever-growing account log.
  const snapshot = await firestore.collection(RELIABILITY_EVENTS)
    .where('uid', '==', uid)
    .orderBy('occurredAt', 'desc')
    .limit(RELIABILITY_EVENT_WINDOW)
    .get();
  const projection = { uid, ...calculateReliability(snapshot.docs.map((doc) => doc.data()), now),
    updatedAt: now };
  await firestore.doc(`${RELIABILITY_PROFILES}/${uid}`).set(projection);
  return projection;
}

export async function handleReliabilityEventWritten(firestore, event, now = new Date()) {
  const current = event.data?.after?.data?.() ?? event.data?.before?.data?.();
  const uid = current?.uid;
  if (typeof uid !== 'string' || uid.length === 0) return;
  const [user, deletionBarrier] = await firestore.getAll(
    firestore.doc(`users/${uid}`),
    firestore.doc(`accountDeletionBarriers/${uid}`),
  );
  if (!user.exists || deletionBarrier.exists) {
    await firestore.doc(`${RELIABILITY_PROFILES}/${uid}`).delete();
    return;
  }
  // When a vacancy is successfully filled, link that objective outcome to the
  // player(s) whose earlier cancellation created the vacancy. This linkage is
  // private and idempotent; it never exposes a cancellation history.
  if (current?.type === 'replacement_found' && typeof current.matchId === 'string') {
    const cancellations = await firestore.collection(RELIABILITY_EVENTS)
      .where('matchId', '==', current.matchId).where('type', '==', 'confirmed_match_cancelled').get();
    for (const cancellation of cancellations.docs) {
      const cancelledUid = cancellation.data()?.uid;
      if (typeof cancelledUid !== 'string' || cancelledUid.length === 0) continue;
      const id = createHash('sha256')
        .update(`${current.matchId}\0${cancelledUid}\0replacement_secured`).digest('hex');
      const reference = firestore.doc(`${RELIABILITY_EVENTS}/${id}`);
      await firestore.runTransaction(async (transaction) => {
        if (!(await transaction.get(reference)).exists) transaction.create(reference, {
          schemaVersion: 1, eventId: id, uid: cancelledUid, type: 'replacement_secured',
          matchId: current.matchId, occurredAt: now, source: 'matchmaking',
        });
      });
    }
  }
  await rebuildReliabilityProjection(firestore, uid, now);
}

export function reliabilityPriority(data) {
  return data?.status === 'established' && Number.isFinite(data.percent)
    ? Math.max(0, Math.min(100, data.percent)) : 0;
}

export function rankByReliability(candidates) {
  return [...candidates].sort((left, right) =>
    reliabilityPriority(right) - reliabilityPriority(left));
}
