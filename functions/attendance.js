import { createHash, randomUUID } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';
import { requireActiveAccount } from './account_state.js';
import { ATTENDANCE_POLICY_VERSION, ATTENDANCE_STATES, MAX_MATCH_PARTICIPANTS,
  adjudicateAttendance, attendanceWindow } from './attendance_policy.js';

export const ATTENDANCE_EVIDENCE = 'attendanceEvidence';
export const ATTENDANCE_SUBMISSIONS = 'attendanceSubmissions';
export const ATTENDANCE_RESOLUTIONS = 'attendanceResolutions';
export const ATTENDANCE_RESOLUTION_JOBS = 'attendanceResolutionJobs';
const RELIABILITY_EVENTS = 'reliabilityEvents';
const digest = (value) => createHash('sha256').update(value).digest('hex');
const validId = (value) => typeof value === 'string' && value.length >= 8
  && value.length <= 200 && !value.includes('/');
const asDate = (value) => value?.toDate?.() ?? value;

function rosterFor(match) {
  const roster = [...new Set(match?.participantUids ?? [])];
  if (roster.length < 2 || roster.length > MAX_MATCH_PARTICIPANTS
      || roster.some((uid) => typeof uid !== 'string' || !uid || uid.includes('/'))) {
    throw new HttpsError('failed-precondition', 'Match attendance is unavailable.');
  }
  return roster;
}

function validateTiming(match, now) {
  if (match?.status === 'cancelled') throw new HttpsError('failed-precondition', 'Match was cancelled.');
  const scheduledAt = asDate(match?.scheduledAt);
  if (!(scheduledAt instanceof Date) || !Number.isFinite(scheduledAt.getTime())) {
    throw new HttpsError('failed-precondition', 'Match time is unavailable.');
  }
  const window = attendanceWindow(scheduledAt);
  if (now < window.opensAt) throw new HttpsError('failed-precondition', 'Attendance is not open yet.');
  if (now > window.closesAt) throw new HttpsError('deadline-exceeded', 'Attendance window closed.');
  return { scheduledAt, ...window };
}

export async function getAttendanceStateOperation(firestore, request) {
  const now = request.rawRequest?.attendanceNow ?? new Date();
  const uid = await requireActiveAccount(firestore, request, { now });
  const matchId = request?.data?.matchId;
  if (!validId(matchId) || Object.keys(request.data ?? {}).some((key) => key !== 'matchId')) {
    throw new HttpsError('invalid-argument', 'Invalid attendance request.');
  }
  const [matchSnapshot, submission, resolution] = await firestore.getAll(
    firestore.doc(`matches/${matchId}`),
    firestore.doc(`${ATTENDANCE_SUBMISSIONS}/${digest(`${matchId}\0${uid}`)}`),
    firestore.doc(`${ATTENDANCE_RESOLUTIONS}/${matchId}`),
  );
  if (!matchSnapshot.exists) throw new HttpsError('not-found', 'Match not found.');
  const match = matchSnapshot.data();
  const roster = rosterFor(match);
  if (!roster.includes(uid)) throw new HttpsError('permission-denied', 'Attendance unavailable.');
  if (match.status === 'cancelled') return { eligible: false, submitted: submission.exists,
    resolved: resolution.exists };
  const scheduledAt = asDate(match.scheduledAt);
  if (!(scheduledAt instanceof Date) || !Number.isFinite(scheduledAt.getTime())) {
    throw new HttpsError('failed-precondition', 'Match time is unavailable.');
  }
  const timing = attendanceWindow(scheduledAt);
  return { eligible: now >= timing.opensAt && now <= timing.closesAt,
    submitted: submission.exists, resolved: resolution.exists,
    opensAt: timing.opensAt.toISOString(), closesAt: timing.closesAt.toISOString() };
}

export async function adjudicateMatchAttendance(firestore, matchId, now = new Date(), { force = false } = {}) {
  const [matchSnapshot, evidencePage, existing] = await Promise.all([
    firestore.doc(`matches/${matchId}`).get(),
    firestore.collection(ATTENDANCE_SUBMISSIONS).where('matchId', '==', matchId)
      .limit(MAX_MATCH_PARTICIPANTS + 1).get(),
    firestore.doc(`${ATTENDANCE_RESOLUTIONS}/${matchId}`).get(),
  ]);
  if (!matchSnapshot.exists || existing.exists) return existing.data() ?? null;
  const match = matchSnapshot.data();
  if (match.status === 'cancelled') return null;
  const roster = rosterFor(match);
  const scheduledAt = asDate(match.scheduledAt);
  const { closesAt } = attendanceWindow(scheduledAt);
  const final = force || now >= closesAt || evidencePage.size === roster.length;
  const result = adjudicateAttendance({ roster,
    submissions: evidencePage.docs.map((doc) => doc.data()), final });
  if (!result) return null;
  const resolution = { schemaVersion: 1, matchId, policyVersion: ATTENDANCE_POLICY_VERSION,
    matchState: result.matchState, subjectStates: result.subjects, expectedRoster: roster,
    evidenceCount: evidencePage.size, resolvedAt: now };
  await firestore.runTransaction(async (transaction) => {
    const resolutionRef = firestore.doc(`${ATTENDANCE_RESOLUTIONS}/${matchId}`);
    const commitmentRefs = roster.map((subjectUid) => firestore.doc(
      `${RELIABILITY_EVENTS}/${digest(`${matchId}\0${subjectUid}\0confirmed_match_committed`)}`));
    const [currentResolution, ...commitments] = await transaction.getAll(resolutionRef, ...commitmentRefs);
    if (currentResolution.exists) return;
    transaction.create(resolutionRef, resolution);
    transaction.set(firestore.doc(`${ATTENDANCE_RESOLUTION_JOBS}/${matchId}`),
      { matchId, status: 'complete', closesAt, completedAt: now }, { merge: true });
    for (const [index, [subjectUid, state]] of Object.entries(result.subjects).entries()) {
      if (!commitments[index].exists) transaction.create(commitmentRefs[index], {
        schemaVersion: 2, eventId: commitmentRefs[index].id, uid: subjectUid,
        type: 'confirmed_match_committed', matchId, scheduledAt: match.scheduledAt,
        occurredAt: now, source: match.source === 'matchmaking' ? 'matchmaking' : 'manual_match',
        policyVersion: 'objective-reliability-v2-attendance',
      });
      if (![ATTENDANCE_STATES.attended, ATTENDANCE_STATES.noShow].includes(state)) continue;
      const eventId = digest(`${matchId}\0${subjectUid}\0attendance_v2`);
      transaction.create(firestore.doc(`${RELIABILITY_EVENTS}/${eventId}`), {
        schemaVersion: 2, eventId, uid: subjectUid,
        type: state === ATTENDANCE_STATES.attended ? 'attendance_confirmed' : 'no_show_confirmed',
        matchId, scheduledAt: match.scheduledAt, occurredAt: now,
        source: 'attendance_resolution', policyVersion: ATTENDANCE_POLICY_VERSION,
      });
    }
  });
  return resolution;
}

export async function submitAttendanceEvidenceOperation(firestore, request) {
  const now = request.rawRequest?.attendanceNow ?? new Date();
  const uid = await requireActiveAccount(firestore, request, { now });
  const data = request?.data;
  if (!data || typeof data !== 'object' || Array.isArray(data)
      || Object.keys(data).some((key) => !['matchId', 'requestId', 'matchHappened', 'attendedUids'].includes(key))
      || !validId(data.matchId) || !validId(data.requestId)
      || typeof data.matchHappened !== 'boolean' || !Array.isArray(data.attendedUids)) {
    throw new HttpsError('invalid-argument', 'Invalid attendance submission.');
  }
  const matchRef = firestore.doc(`matches/${data.matchId}`);
  const matchSnapshot = await matchRef.get();
  if (!matchSnapshot.exists) throw new HttpsError('not-found', 'Match not found.');
  const match = matchSnapshot.data();
  const roster = rosterFor(match);
  if (!roster.includes(uid)) throw new HttpsError('permission-denied', 'Attendance unavailable.');
  const timing = validateTiming(match, now);
  const attendedUids = [...new Set(data.attendedUids)];
  if ((!data.matchHappened && attendedUids.length > 0)
      || attendedUids.some((subject) => !roster.includes(subject))) {
    throw new HttpsError('invalid-argument', 'Invalid attendance claims.');
  }
  const submissionId = digest(`${data.matchId}\0${uid}`);
  const submissionRef = firestore.doc(`${ATTENDANCE_SUBMISSIONS}/${submissionId}`);
  const outcome = await firestore.runTransaction(async (transaction) => {
    const prior = await transaction.get(submissionRef);
    if (prior.exists) return { status: 'already_submitted' };
    transaction.create(submissionRef, { schemaVersion: 1, submissionId, requestId: data.requestId,
      matchId: data.matchId, observerUid: uid, matchHappened: data.matchHappened,
      attendedUids, submittedAt: now, policyVersion: ATTENDANCE_POLICY_VERSION,
      windowClosesAt: timing.closesAt });
    transaction.set(firestore.doc(`${ATTENDANCE_RESOLUTION_JOBS}/${data.matchId}`), {
      schemaVersion: 1, matchId: data.matchId, status: 'pending', closesAt: timing.closesAt,
      updatedAt: now,
    }, { merge: true });
    for (const subjectUid of roster) {
      const evidenceId = digest(`${data.matchId}\0${uid}\0${subjectUid}`);
      transaction.create(firestore.doc(`${ATTENDANCE_EVIDENCE}/${evidenceId}`), {
        schemaVersion: 1, evidenceId, matchId: data.matchId, observerUid: uid, subjectUid,
        matchHappened: data.matchHappened,
        claim: data.matchHappened && attendedUids.includes(subjectUid) ? 'attended' : 'absent',
        submittedAt: now, policyVersion: ATTENDANCE_POLICY_VERSION,
      });
    }
    return { status: 'submitted' };
  });
  await adjudicateMatchAttendance(firestore, data.matchId, now);
  return outcome;
}

export async function recoverAttendanceResolutions(firestore, now = new Date(), limit = 25) {
  if (!Number.isInteger(limit) || limit < 1 || limit > 50) throw new Error('Invalid attendance recovery limit.');
  const page = await firestore.collection(ATTENDANCE_RESOLUTION_JOBS)
    .where('status', '==', 'pending').where('closesAt', '<=', now)
    .orderBy('closesAt').limit(limit).get();
  const matchIds = page.docs.map((doc) => doc.id);
  for (const matchId of matchIds) await adjudicateMatchAttendance(firestore, matchId, now, { force: true });
  return { inspected: matchIds.length, recoveryId: randomUUID() };
}
