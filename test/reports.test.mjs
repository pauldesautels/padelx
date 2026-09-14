import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { blockId } from '../functions/friendship_policy.js';
import { directConversationId, matchConversationId } from '../functions/messaging_policy.js';
import { submitReportOperation } from '../functions/reports.js';
import {
  REPORT_ROLLING_MAX, REPORT_ROLLING_WINDOW_MS, REPORT_SUBJECT_COOLDOWN_MS,
  REPORT_RATE_LIMIT_CLEANUP_MARGIN_MS, normalizeReportPayload, reportDedupeKey,
  reporterRateLimitId, subjectRateLimitId,
} from '../functions/report_policy.js';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
const projectId = 'demo-padelx-reports';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'reports-tests');
const db = getFirestore(app);
after(() => deleteApp(app));

const now = new Date('2026-09-11T12:00:00Z');
const request = (uid, data, verified = true) => ({
  auth: { uid, token: { email_verified: verified } }, data,
  rawRequest: { messagingNow: now },
});
const payload = (overrides = {}) => ({
  requestId: `request_${crypto.randomUUID()}`,
  subjectType: 'player',
  subjectId: 'target',
  reason: 'harassment_bullying',
  ...overrides,
});

async function account(uid, { eligible = true, active = true, profile = {} } = {}) {
  await db.doc(`users/${uid}`).set({ uid, active, email: `${uid}@private.invalid` });
  await db.doc(`publicProfiles/${uid}`).set({
    uid, displayName: `Player ${uid}`, bio: `Bio ${uid}`, avatarVersion: 2,
    discoverable: true, level: '3', preferredSide: 'either',
    countryCode: 'MX', city: 'Mexico City', ...profile,
  });
  if (eligible) await db.doc(`accountEligibility/${uid}`).set({
    uid, age18Confirmed: true, ageEligibilityVersion: '18-plus-v1',
    confirmedAt: now, schemaVersion: 1,
  });
}

const reports = async () => (await db.collection('reports').get()).docs.map((doc) => doc.data());

test('report payload accepts only canonical, bounded plain-text input', () => {
  assert.deepEqual(normalizeReportPayload({
    requestId: 'request_123456789', subjectType: 'player', subjectId: 'target',
    reason: 'other', details: '  context  ',
  }).details, 'context');
  assert.equal(normalizeReportPayload({
    requestId: 'request_123456789', subjectType: 'match', subjectId: 'm1',
    reason: 'spam_scam', details: '   ',
  }).details, undefined);
  for (const invalid of [
    { reason: 'unknown' }, { subjectType: 'unknown' }, { requestId: 'short' },
    { details: 'x'.repeat(501) }, { details: 'bad\u0000text' }, { reporterUid: 'forged' },
    { expiresAt: now },
    { subjectType: 'message', subjectId: 'message_123456789' },
    { subjectType: 'player', conversationId: `direct_${'a'.repeat(64)}` },
  ]) assert.throws(() => normalizeReportPayload(payload(invalid)), { code: 'invalid-argument' });
});

test('submitReport export inherits non-emulator App Check enforcement', async () => {
  const source = await readFile(new URL('../functions/index.js', import.meta.url), 'utf8');
  assert.match(source, /const accountCallable = \(operation\) => onCall\(\{\s*enforceAppCheck: process\.env\.FUNCTIONS_EMULATOR !== 'true'/);
  assert.match(source, /export const submitReport = accountCallable\(submitReportOperation\)/);
});

test('reporter requires verified active account, eligibility, and no deletion barrier', async () => {
  await account('admitted'); await account('target');
  await assert.rejects(submitReportOperation(db, { data: payload() }, now), { code: 'unauthenticated' });
  await assert.rejects(submitReportOperation(db, request('admitted', payload(), false), now), { code: 'permission-denied' });
  await account('ineligible', { eligible: false });
  await assert.rejects(submitReportOperation(db, request('ineligible', payload()), now), { code: 'failed-precondition' });
  await account('inactive', { active: false });
  await assert.rejects(submitReportOperation(db, request('inactive', payload()), now), { code: 'failed-precondition' });
  await account('deleting');
  await db.doc('accountDeletionBarriers/deleting').set({ uid: 'deleting' });
  await assert.rejects(submitReportOperation(db, request('deleting', payload()), now), { code: 'permission-denied' });
});

test('player report stores exact public evidence and idempotent retry returns no evidence', async () => {
  await account('player-reporter');
  await account('player-target', { profile: {
    displayName: 'Public Name', bio: 'Public bio', avatarVersion: 7,
    email: 'must-not-copy@example.com', discoveryLocation: { latitude: 1 },
  } });
  const data = payload({ subjectId: 'player-target', details: '  concise details  ' });
  assert.deepEqual(await submitReportOperation(db, request('player-reporter', data), now),
    { submitted: true, duplicate: false });
  assert.deepEqual(await submitReportOperation(db, request('player-reporter', data), now),
    { submitted: true, duplicate: true });
  const stored = (await reports()).find((report) => report.reporterUid === 'player-reporter');
  assert.deepEqual(stored.evidence, { displayName: 'Public Name', bio: 'Public bio', avatarVersion: 7 });
  assert.equal(stored.subjectOwnerUid, 'player-target');
  assert.equal(stored.details, 'concise details');
  assert.equal(stored.status, 'open');
  for (const forbidden of ['email', 'discoveryLocation', 'friendships', 'blocks']) {
    assert.equal(stored.evidence[forbidden], undefined);
  }
  assert.deepEqual(Object.keys(await submitReportOperation(db, request('player-reporter', data), now)).sort(),
    ['duplicate', 'submitted']);
});

test('player self-report, absent target, inactive target, and deleting target are denied', async () => {
  await account('player-denied');
  await assert.rejects(submitReportOperation(db, request('player-denied',
    payload({ subjectId: 'player-denied' })), now), { code: 'invalid-argument' });
  await assert.rejects(submitReportOperation(db, request('player-denied',
    payload({ subjectId: 'absent' })), now), { code: 'not-found' });
  await account('inactive-target', { active: false });
  await assert.rejects(submitReportOperation(db, request('player-denied',
    payload({ subjectId: 'inactive-target' })), now), { code: 'not-found' });
  await account('deleting-target');
  await db.doc('accountDeletionBarriers/deleting-target').set({ uid: 'deleting-target' });
  await assert.rejects(submitReportOperation(db, request('player-denied',
    payload({ subjectId: 'deleting-target' })), now), { code: 'not-found' });
});

async function directFixture(left, right, messageId, senderUid = right) {
  await account(left); await account(right);
  const conversationId = directConversationId(left, right);
  await db.doc(`conversations/${conversationId}`).set({
    type: 'direct', memberUids: [left, right], createdAt: now,
  });
  await db.doc(`conversations/${conversationId}/messages/${messageId}`).set({
    senderUid, text: 'reported message only', createdAt: now,
  });
  return conversationId;
}

test('direct message reporting reuses read policy and captures one canonical message', async () => {
  const messageId = 'message_direct_1234';
  const conversationId = await directFixture('direct-reporter', 'direct-sender', messageId);
  await db.doc(`conversations/${conversationId}/messages/surrounding_message`).set({
    senderUid: 'direct-sender', text: 'must not copy', createdAt: now,
  });
  const data = payload({ subjectType: 'message', subjectId: messageId, conversationId });
  assert.deepEqual(await submitReportOperation(db, request('direct-reporter', data), now),
    { submitted: true, duplicate: false });
  const stored = (await reports()).find((report) => report.reporterUid === 'direct-reporter');
  assert.deepEqual(stored.evidence, {
    messageId, senderUid: 'direct-sender', text: 'reported message only',
    createdAt: stored.evidence.createdAt, conversationType: 'direct',
  });
  assert.equal(stored.conversationType, 'direct');
  assert.equal(JSON.stringify(stored).includes('must not copy'), false);
});

test('message report denies own, missing, mismatched, and unauthorized messages', async () => {
  const ownConversation = await directFixture('own-reporter', 'own-other', 'own_message_12345', 'own-reporter');
  await assert.rejects(submitReportOperation(db, request('own-reporter', payload({
    subjectType: 'message', subjectId: 'own_message_12345', conversationId: ownConversation,
  })), now), { code: 'failed-precondition' });
  await assert.rejects(submitReportOperation(db, request('own-reporter', payload({
    subjectType: 'message', subjectId: 'missing_message_1', conversationId: ownConversation,
  })), now), { code: 'not-found' });
  const otherConversation = await directFixture('mismatch-left', 'mismatch-right', 'mismatch_message_1');
  await assert.rejects(submitReportOperation(db, request('own-reporter', payload({
    subjectType: 'message', subjectId: 'mismatch_message_1', conversationId: ownConversation,
  })), now), { code: 'not-found' });
  await assert.rejects(submitReportOperation(db, request('own-reporter', payload({
    subjectType: 'message', subjectId: 'mismatch_message_1', conversationId: otherConversation,
  })), now), { code: 'permission-denied' });

  const blockedConversation = await directFixture('blocked-reporter', 'blocked-sender', 'blocked_message_1');
  await db.doc(`blocks/${blockId('blocked-sender', 'blocked-reporter')}`).set({
    blockerUid: 'blocked-sender', blockedUid: 'blocked-reporter',
  });
  await assert.rejects(submitReportOperation(db, request('blocked-reporter', payload({
    subjectType: 'message', subjectId: 'blocked_message_1', conversationId: blockedConversation,
  })), now), { code: 'permission-denied' });

  await account('match-outsider');
  const matchId = 'outsider-match';
  const matchConversation = matchConversationId(matchId);
  await db.doc(`matches/${matchId}`).set({
    creatorUid: 'blocked-sender', players: [{ uid: 'blocked-reporter' }],
    scheduledAt: new Date('2026-09-12T12:00:00Z'),
  });
  await db.doc(`conversations/${matchConversation}`).set({
    type: 'match', matchId, memberUids: ['blocked-sender', 'blocked-reporter'],
  });
  await db.doc(`conversations/${matchConversation}/messages/outsider_message_1`).set({
    senderUid: 'blocked-sender', text: 'not available', createdAt: now,
  });
  await assert.rejects(submitReportOperation(db, request('match-outsider', payload({
    subjectType: 'message', subjectId: 'outsider_message_1', conversationId: matchConversation,
  })), now), { code: 'permission-denied' });
});

test('Match Chat reports retain context and allow members to report independently', async () => {
  await account('match-chat-reporter'); await account('match-chat-reporter-2');
  await account('match-chat-sender');
  const matchId = 'match-chat-source';
  const conversationId = matchConversationId(matchId);
  await db.doc(`matches/${matchId}`).set({
    creatorUid: 'match-chat-sender',
    players: [{ uid: 'match-chat-reporter' }, { uid: 'match-chat-reporter-2' }],
    scheduledAt: new Date('2026-09-12T12:00:00Z'),
  });
  await db.doc(`conversations/${conversationId}`).set({
    type: 'match', matchId,
    memberUids: ['match-chat-sender', 'match-chat-reporter', 'match-chat-reporter-2'],
  });
  await db.doc(`conversations/${conversationId}/messages/match_message_1234`).set({
    senderUid: 'match-chat-sender', text: 'match evidence', createdAt: now,
  });
  const data = payload({ subjectType: 'message', subjectId: 'match_message_1234', conversationId });
  await submitReportOperation(db, request('match-chat-reporter', data), now);
  await submitReportOperation(db, request('match-chat-reporter-2', {
    ...data, requestId: 'independent_report_2',
  }), now);
  const stored = (await reports()).find((report) => report.reporterUid === 'match-chat-reporter');
  assert.equal(stored.matchId, matchId);
  assert.equal(stored.conversationType, 'match');
  assert.equal(stored.evidence.text, 'match evidence');
  assert.equal((await reports()).filter((report) => report.subjectId === 'match_message_1234').length, 2);
});

test('visible match report stores minimal location and omits coordinates and participants', async () => {
  await account('match-reporter'); await account('match-organizer');
  await db.doc('matches/reportable-match').set({
    title: 'Evening match', clubName: 'Central Club', creatorUid: 'match-organizer',
    scheduledAt: now, players: [{ uid: 'private-player' }], participantUids: ['match-organizer'],
    location: { countryCode: 'MX', city: 'Mexico City', area: 'Centro',
      latitude: 19.4, longitude: -99.1, placeId: 'private-place' },
  });
  await submitReportOperation(db, request('match-reporter', payload({
    subjectType: 'match', subjectId: 'reportable-match', reason: 'threats_unsafe_behavior',
  })), now);
  const stored = (await reports()).find((report) => report.reporterUid === 'match-reporter');
  assert.deepEqual(stored.evidence, {
    organizerUid: 'match-organizer', title: 'Evening match', clubName: 'Central Club',
    scheduledAt: stored.evidence.scheduledAt, countryCode: 'MX', city: 'Mexico City', area: 'Centro',
  });
  assert.equal(stored.evidence.latitude, undefined);
  assert.equal(stored.evidence.players, undefined);
  await assert.rejects(submitReportOperation(db, request('match-reporter', payload({
    subjectType: 'match', subjectId: 'reportable-match', reason: 'other',
  })), now), { code: 'already-exists' });
  await submitReportOperation(db, request('match-reporter', payload({
    subjectType: 'match', subjectId: 'reportable-match', reason: 'other',
  })), new Date(now.getTime() + REPORT_SUBJECT_COOLDOWN_MS + 1));
  await assert.rejects(submitReportOperation(db, request('match-organizer', payload({
    subjectType: 'match', subjectId: 'reportable-match',
  })), now), { code: 'invalid-argument' });
  await assert.rejects(submitReportOperation(db, request('match-reporter', payload({
    subjectType: 'match', subjectId: 'absent-match',
  })), now), { code: 'not-found' });
});

test('subject dedupe is reporter-scoped, message-permanent, and player cooldown-bound', async () => {
  await account('dedupe-a'); await account('dedupe-b'); await account('dedupe-target');
  const sharedRequestId = 'shared_request_1234';
  const first = payload({ subjectId: 'dedupe-target', requestId: sharedRequestId });
  await submitReportOperation(db, request('dedupe-a', first), now);
  await assert.rejects(submitReportOperation(db, request('dedupe-a', payload({
    subjectId: 'dedupe-target', reason: 'other',
  })), now), { code: 'already-exists' });
  await submitReportOperation(db, request('dedupe-b', payload({
    subjectId: 'dedupe-target', requestId: sharedRequestId,
  })), now);
  await submitReportOperation(db, request('dedupe-a', payload({ subjectId: 'dedupe-target' })),
    new Date(now.getTime() + REPORT_SUBJECT_COOLDOWN_MS + 1));

  const conversationId = await directFixture('dedupe-message-a', 'dedupe-message-sender', 'dedupe_message_1');
  await db.doc(`conversations/${conversationId}/messages/dedupe_message_2`).set({
    senderUid: 'dedupe-message-sender', text: 'second', createdAt: now,
  });
  await submitReportOperation(db, request('dedupe-message-a', payload({
    subjectType: 'message', subjectId: 'dedupe_message_1', conversationId,
  })), now);
  await assert.rejects(submitReportOperation(db, request('dedupe-message-a', payload({
    subjectType: 'message', subjectId: 'dedupe_message_1', conversationId, reason: 'other',
  })), now), { code: 'already-exists' });
  await submitReportOperation(db, request('dedupe-message-a', payload({
    subjectType: 'message', subjectId: 'dedupe_message_2', conversationId,
  })), now);
});

test('rolling reporter limit rejects new reports while idempotent retry remains free', async () => {
  await account('rate-reporter'); await account('rate-organizer');
  for (let index = 0; index <= REPORT_ROLLING_MAX; index++) {
    await db.doc(`matches/rate-match-${index}`).set({
      creatorUid: 'rate-organizer', title: `Match ${index}`,
    });
  }
  let first;
  for (let index = 0; index < REPORT_ROLLING_MAX; index++) {
    const data = payload({ subjectType: 'match', subjectId: `rate-match-${index}` });
    first ??= data;
    await submitReportOperation(db, request('rate-reporter', data), now);
  }
  assert.deepEqual(await submitReportOperation(db, request('rate-reporter', first), now),
    { submitted: true, duplicate: true });
  await assert.rejects(submitReportOperation(db, request('rate-reporter', payload({
    subjectType: 'match', subjectId: `rate-match-${REPORT_ROLLING_MAX}`,
  })), now), { code: 'resource-exhausted' });
});

test('new rolling and subject limits receive server-derived cleanup expiry', async () => {
  await account('expiry-reporter'); await account('expiry-target');
  const data = payload({ subjectId: 'expiry-target', requestId: 'expiry_request_1234' });
  await submitReportOperation(db, request('expiry-reporter', data), now);
  const reporter = (await db.doc(`reportRateLimits/${reporterRateLimitId('expiry-reporter')}`).get()).data();
  const dedupeKey = reportDedupeKey('expiry-reporter', data);
  const subject = (await db.doc(`reportRateLimits/${subjectRateLimitId(dedupeKey)}`).get()).data();

  assert.equal(reporter.expiresAt.toMillis(), now.getTime() + REPORT_ROLLING_WINDOW_MS
    + REPORT_RATE_LIMIT_CLEANUP_MARGIN_MS);
  assert.equal(subject.enforcementExpiresAt.toMillis(), now.getTime() + REPORT_SUBJECT_COOLDOWN_MS);
  assert.equal(subject.expiresAt.toMillis(), now.getTime() + REPORT_SUBJECT_COOLDOWN_MS
    + REPORT_RATE_LIMIT_CLEANUP_MARGIN_MS);
  assert.ok(subject.expiresAt.toMillis() > subject.enforcementExpiresAt.toMillis());

  await submitReportOperation(db, request('expiry-reporter', data),
    new Date(now.getTime() + 1000));
  const afterRetry = (await db.doc(`reportRateLimits/${reporterRateLimitId('expiry-reporter')}`).get()).data();
  assert.equal(afterRetry.expiresAt.toMillis(), reporter.expiresAt.toMillis());

  const conversationId = await directFixture(
    'expiry-message-reporter', 'expiry-message-sender', 'expiry_message_1234');
  const messageData = payload({
    subjectType: 'message', subjectId: 'expiry_message_1234', conversationId,
    requestId: 'expiry_message_request',
  });
  await submitReportOperation(db, request('expiry-message-reporter', messageData), now);
  const messageDedupeKey = reportDedupeKey('expiry-message-reporter', messageData);
  const messageLimit = (await db.doc(
    `reportRateLimits/${subjectRateLimitId(messageDedupeKey)}`,
  ).get()).data();
  assert.ok(messageLimit.expiresAt.toMillis() > now.getTime());
  assert.equal(messageLimit.enforcementExpiresAt, undefined);
  await assert.rejects(submitReportOperation(db, request(
    'expiry-message-reporter', { ...messageData, requestId: 'expiry_message_retry' }),
  new Date(now.getTime() + REPORT_SUBJECT_COOLDOWN_MS * 2)), { code: 'already-exists' });
});

test('legacy subject limits without cleanup expiry remain compatible', async () => {
  await account('legacy-limit-reporter'); await account('legacy-limit-target');
  const data = payload({ subjectId: 'legacy-limit-target', requestId: 'legacy_limit_request' });
  const dedupeKey = reportDedupeKey('legacy-limit-reporter', data);
  const limitRef = db.doc(`reportRateLimits/${subjectRateLimitId(dedupeKey)}`);
  await limitRef.set({ subjectType: 'player', dedupeKey, createdAt: now, updatedAt: now });

  await submitReportOperation(db, request('legacy-limit-reporter', data), now);
  const refreshed = (await limitRef.get()).data();
  assert.ok(refreshed.expiresAt);
  assert.ok(refreshed.enforcementExpiresAt);
});
