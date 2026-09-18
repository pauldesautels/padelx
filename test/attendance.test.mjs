import { after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getAttendanceStateOperation, submitAttendanceEvidenceOperation,
  recoverAttendanceResolutions } from '../functions/attendance.js';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Firestore emulator is required');
const projectId = 'demo-padelx-attendance';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'attendance-tests');
const db = getFirestore(app);
after(() => deleteApp(app));

const scheduledAt = new Date('2030-01-01T10:00:00Z');
const request = (uid, data, now = new Date('2030-01-01T13:00:00Z')) => ({
  auth: { uid, token: { email_verified: true } }, data, rawRequest: { attendanceNow: now },
});
const roster = ['player-a', 'player-b', 'player-c', 'player-d'];

async function seed({ status = 'active', members = roster } = {}) {
  await Promise.all(members.map((uid) => db.doc(`users/${uid}`).set({ uid, active: true })));
  await db.doc('matches/attendance-match').set({ source: 'matchmaking', status,
    scheduledAt: Timestamp.fromDate(scheduledAt), participantUids: members,
    creatorUid: members[0], players: members.slice(1).map((uid) => ({ uid })),
    venueType: 'private_free', location: { city: 'Synthetic city', latitude: 1, longitude: 2 } });
}

beforeEach(async () => {
  for (const name of ['users', 'matches', 'accountDeletionBarriers', 'accountEnforcement',
    'attendanceSubmissions', 'attendanceEvidence', 'attendanceResolutions',
    'attendanceResolutionJobs', 'reliabilityEvents']) {
    const documents = await db.collection(name).listDocuments();
    await Promise.all(documents.map((document) => document.delete()));
  }
  await seed();
});

test('only final roster may submit inside authoritative window', async () => {
  await db.doc('users/outsider').set({ uid: 'outsider', active: true });
  await assert.rejects(() => submitAttendanceEvidenceOperation(db, request('outsider', {
    matchId: 'attendance-match', requestId: 'outsider-request', matchHappened: true,
    attendedUids: roster,
  })), (error) => error.code === 'permission-denied');
  await assert.rejects(() => submitAttendanceEvidenceOperation(db,
    request('player-a', { matchId: 'attendance-match', requestId: 'early-request',
      matchHappened: true, attendedUids: roster }, new Date('2030-01-01T11:59:00Z'))),
  (error) => error.code === 'failed-precondition');
  await assert.rejects(() => submitAttendanceEvidenceOperation(db,
    request('player-a', { matchId: 'attendance-match', requestId: 'late-request',
      matchHappened: true, attendedUids: roster }, new Date('2030-01-04T12:01:00Z'))),
  (error) => error.code === 'deadline-exceeded');
});

test('submission is immutable, idempotent, private-shaped, and adjudicates normal attendance', async () => {
  for (const uid of roster) {
    const payload = { matchId: 'attendance-match', requestId: `request-${uid}`,
      matchHappened: true, attendedUids: roster };
    assert.equal((await submitAttendanceEvidenceOperation(db, request(uid, payload))).status, 'submitted');
    assert.equal((await submitAttendanceEvidenceOperation(db, request(uid,
      { ...payload, attendedUids: [] }))).status, 'already_submitted');
  }
  assert.equal((await db.collection('attendanceSubmissions').get()).size, 4);
  const evidence = await db.collection('attendanceEvidence').get();
  assert.equal(evidence.size, 16);
  assert.ok(evidence.docs.every((doc) => !['address', 'location', 'latitude', 'longitude']
    .some((key) => key in doc.data())));
  const resolution = (await db.doc('attendanceResolutions/attendance-match').get()).data();
  assert.equal(resolution.matchState, 'played');
  assert.ok(Object.values(resolution.subjectStates).every((state) => state === 'attended'));
  assert.equal((await db.collection('reliabilityEvents').where('type', '==', 'attendance_confirmed').get()).size, 4);
  const state = await getAttendanceStateOperation(db, request('player-a', { matchId: 'attendance-match' }));
  assert.equal(state.submitted, true);
  assert.equal(state.resolved, true);
});

test('self-attestation cannot defeat corroborated peer absence', async () => {
  for (const uid of roster) await submitAttendanceEvidenceOperation(db, request(uid, {
    matchId: 'attendance-match', requestId: `partial-${uid}`, matchHappened: true,
    attendedUids: uid === 'player-d' ? roster : roster.slice(0, 3),
  }));
  const resolution = (await db.doc('attendanceResolutions/attendance-match').get()).data();
  assert.equal(resolution.subjectStates['player-d'], 'no_show');
  assert.equal((await db.collection('reliabilityEvents').where('type', '==', 'no_show_confirmed').get()).size, 1);
  assert.equal((await db.collection('accountEnforcement').get()).size, 0);
  assert.equal((await db.collection('reports').get()).size, 0);
  assert.equal((await db.collection('ratings').get()).size, 0);
});

test('independent peer disagreement produces dispute without Reliability outcome', async () => {
  const claims = {
    'player-a': roster.slice(0, 3),
    'player-b': roster.slice(0, 3),
    'player-c': roster,
    'player-d': roster,
  };
  for (const uid of roster) await submitAttendanceEvidenceOperation(db, request(uid, {
    matchId: 'attendance-match', requestId: `conflict-${uid}`, matchHappened: true,
    attendedUids: claims[uid],
  }));
  const resolution = (await db.doc('attendanceResolutions/attendance-match').get()).data();
  assert.equal(resolution.subjectStates['player-d'], 'disputed');
  assert.equal((await db.collection('reliabilityEvents')
    .where('type', '==', 'no_show_confirmed').get()).size, 0);
});

test('window recovery resolves bounded missing responders and cancelled matches reject attendance', async () => {
  for (const uid of roster.slice(0, 3)) await submitAttendanceEvidenceOperation(db, request(uid, {
    matchId: 'attendance-match', requestId: `recovery-${uid}`, matchHappened: true,
    attendedUids: roster.slice(0, 3),
  }));
  await recoverAttendanceResolutions(db, new Date('2030-01-04T13:00:00Z'));
  const resolution = (await db.doc('attendanceResolutions/attendance-match').get()).data();
  assert.equal(resolution.subjectStates['player-d'], 'no_show');
  await db.doc('matches/attendance-match').update({ status: 'cancelled' });
  await assert.rejects(() => submitAttendanceEvidenceOperation(db, request('player-a', {
    matchId: 'attendance-match', requestId: 'cancelled-new', matchHappened: true, attendedUids: roster,
  })), (error) => error.code === 'failed-precondition');
});

test('authoritative final roster excludes departed player and includes accepted replacement', async () => {
  await db.doc('users/player-e').set({ uid: 'player-e', active: true });
  const finalRoster = ['player-a', 'player-b', 'player-c', 'player-e'];
  await db.doc('matches/attendance-match').update({ participantUids: finalRoster,
    players: finalRoster.slice(1).map((uid) => ({ uid })) });
  await assert.rejects(() => submitAttendanceEvidenceOperation(db, request('player-d', {
    matchId: 'attendance-match', requestId: 'departed-player', matchHappened: true,
    attendedUids: finalRoster,
  })), (error) => error.code === 'permission-denied');
  const result = await submitAttendanceEvidenceOperation(db, request('player-e', {
    matchId: 'attendance-match', requestId: 'accepted-replacement', matchHappened: true,
    attendedUids: finalRoster,
  }));
  assert.equal(result.status, 'submitted');
});
