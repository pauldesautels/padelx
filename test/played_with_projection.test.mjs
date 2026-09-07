import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import {
  contributionId, parseMatchPlayers, reconcilePlayedWithMatch, recoverPlayedWithMatches,
} from '../functions/played_with_projection.js';

const projectId = 'demo-padelx-played-with';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= '127.0.0.1:9099';
const app = initializeApp({ projectId }, 'played-with-tests');
const db = getFirestore(app);
const past = Timestamp.fromMillis(Date.parse('2026-09-01T10:00:00Z'));
const now = Timestamp.fromMillis(Date.parse('2026-09-02T10:00:00Z'));
const future = Timestamp.fromMillis(Date.parse('2026-09-03T10:00:00Z'));

const match = (uids, scheduledAt = past, extra = {}) => ({
  creatorUid: uids[0], players: uids.slice(1).map((uid) => ({ uid })),
  participantUids: uids, spotsLeft: 4 - uids.length, scheduledAt, ...extra,
});
async function account(uid, profile = true) {
  await db.doc(`users/${uid}`).set({ uid });
  if (profile) await db.doc(`publicProfiles/${uid}`).set({ uid });
}
async function seed(uids) { for (const uid of uids) await account(uid); }
async function data(path) { return (await db.doc(path).get()).data(); }
async function project(id, value, at = now) {
  if (value) await db.doc(`matches/${id}`).set(value);
  await reconcilePlayedWithMatch(db, id, at);
}

before(async () => { await db.collection('_warmup').doc('ready').set({ ready: true }); });
beforeEach(async () => {
  const collections = await db.listCollections();
  for (const collection of collections) {
    const docs = await collection.listDocuments();
    for (const ref of docs) await db.recursiveDelete(ref);
  }
});
after(async () => deleteApp(app));

test('strict parsing accepts 2/3/4 players and excludes exact deleted placeholders', () => {
  for (const uids of [['a', 'b'], ['a', 'b', 'c'], ['a', 'b', 'c', 'd']]) {
    assert.deepEqual(parseMatchPlayers(match(uids), now).participantUids, uids);
  }
  const deleted = match(['a', 'b']); deleted.players = [{ deleted: true, displayName: 'Deleted player' }];
  deleted.participantUids = ['a'];
  assert.deepEqual(parseMatchPlayers(deleted, now).participantUids, ['a']);
  for (const bad of [
    { ...match(['a', 'b']), scheduledAt: 'bad' },
    { ...match(['a', 'b']), createdBy: 'other' },
    { ...match(['a', 'b']), participantUids: ['a', 'wrong'] },
    { ...match(['a', 'b']), players: [{ uid: 'a' }] },
    { ...match(['a', 'b']), players: [{ displayName: 'missing' }] },
  ]) assert.throws(() => parseMatchPlayers(bad, now), /Ambiguous/);
  assert.equal(parseMatchPlayers(match(['a', 'b'], future), now).eligibleByMatch, false);
  assert.equal(parseMatchPlayers(match(['a', 'b'], past, { status: 'cancelled' }), now).eligibleByMatch, false);
});

test('2-player projection is directional, exact, and replay-idempotent', async () => {
  await seed(['a', 'b']); await project('m1', match(['a', 'b'])); await reconcilePlayedWithMatch(db, 'm1', now);
  const ab = await data('users/a/playedWith/b'); const ba = await data('users/b/playedWith/a');
  assert.deepEqual([ab.otherUid, ab.completedMatchCount, ab.lastMatchId], ['b', 1, 'm1']);
  assert.deepEqual([ba.otherUid, ba.completedMatchCount, ba.lastMatchId], ['a', 1, 'm1']);
  assert.equal(ab.firstPlayedAt.toMillis(), past.toMillis());
  assert.deepEqual([(await data('publicProfiles/a')).completedMatchCount,
    (await data('publicProfiles/b')).completedMatchCount], [1, 1]);
  assert.equal((await db.collection('playedWithContributions').get()).size, 1);
});

test('3-player and organizer-plus-3 projection create n*(n-1) directions', async () => {
  for (const [id, uids, expected] of [['three', ['a', 'b', 'c'], 6], ['four', ['d', 'e', 'f', 'g'], 12]]) {
    await seed(uids); await project(id, match(uids));
    let count = 0;
    for (const uid of uids) count += (await db.collection(`users/${uid}/playedWith`).get()).size;
    assert.equal(count, expected);
    for (const uid of uids) assert.equal((await data(`publicProfiles/${uid}`)).completedMatchCount, 1);
  }
});

test('out-of-order matches preserve first/latest and repeat transitions once', async () => {
  await seed(['a', 'b']);
  const newest = Timestamp.fromMillis(past.toMillis() + 2000);
  const middle = Timestamp.fromMillis(past.toMillis() + 1000);
  await project('new', match(['a', 'b'], newest));
  await project('old', match(['a', 'b'], past));
  let relation = await data('users/a/playedWith/b');
  assert.deepEqual([relation.completedMatchCount, relation.lastMatchId], [2, 'new']);
  assert.equal(relation.firstPlayedAt.toMillis(), past.toMillis());
  assert.equal((await data('publicProfiles/a')).repeatPlayerCount, 1);
  await project('middle', match(['a', 'b'], middle));
  relation = await data('users/a/playedWith/b');
  assert.equal(relation.completedMatchCount, 3);
  assert.equal((await data('publicProfiles/a')).repeatPlayerCount, 1);
  assert.equal((await data('publicProfiles/a')).completedMatchCount, 3);
});

test('cancellation reverses counts and recomputes extrema', async () => {
  await seed(['a', 'b']);
  const later = Timestamp.fromMillis(past.toMillis() + 1000);
  await project('m1', match(['a', 'b'], past)); await project('m2', match(['a', 'b'], later));
  await project('m2', match(['a', 'b'], later, { status: 'cancelled' }));
  let relation = await data('users/a/playedWith/b');
  assert.deepEqual([relation.completedMatchCount, relation.lastMatchId], [1, 'm1']);
  assert.equal((await data('publicProfiles/a')).repeatPlayerCount, 0);
  await project('m1', match(['a', 'b'], past, { status: 'cancelled' }));
  assert.equal(await data('users/a/playedWith/b'), undefined);
  assert.equal((await data('publicProfiles/a')).completedMatchCount, 0);
});

test('barrier and missing profile exclude identities and never recreate references', async () => {
  await seed(['a', 'b', 'c']); await project('m1', match(['a', 'b', 'c']));
  await db.doc('accountDeletionBarriers/b').set({ status: 'deleting' });
  await reconcilePlayedWithMatch(db, 'm1', now);
  assert.equal(await data('users/a/playedWith/b'), undefined);
  assert.equal(await data('users/b/playedWith/a'), undefined);
  assert.equal((await data('users/a/playedWith/c')).completedMatchCount, 1);
  await reconcilePlayedWithMatch(db, 'm1', now);
  assert.equal(await data('users/b/playedWith/c'), undefined);
  await account('d', false); await project('m2', match(['a', 'd']));
  assert.equal(await data('users/a/playedWith/d'), undefined);
});

test('future exclusion and recovery cursor process bounded pages without double counting', async () => {
  await seed(['a', 'b']);
  await db.doc('matches/future').set(match(['a', 'b'], future));
  await reconcilePlayedWithMatch(db, 'future', now);
  assert.equal(await data('users/a/playedWith/b'), undefined);
  for (let index = 0; index < 3; index += 1) {
    await db.doc(`matches/r${index}`).set(match(['a', 'b'], Timestamp.fromMillis(now.toMillis() - 1000 + index)));
  }
  const first = await recoverPlayedWithMatches(db, now, 2);
  const second = await recoverPlayedWithMatches(db, now, 2);
  const third = await recoverPlayedWithMatches(db, now, 2);
  assert.deepEqual([first.complete, second.complete, third.complete], [false, true, false]);
  assert.equal((await data('users/a/playedWith/b')).completedMatchCount, 3);
});

test('stable contribution IDs separate matches and unordered pair order', () => {
  assert.equal(contributionId('m', 'a', 'b'), contributionId('m', 'b', 'a'));
  assert.notEqual(contributionId('m', 'a', 'b'), contributionId('n', 'a', 'b'));
});

test('backend guard failure occurs before a projection transaction or write', async () => {
  const original = {
    GCLOUD_PROJECT: process.env.GCLOUD_PROJECT,
    GOOGLE_CLOUD_PROJECT: process.env.GOOGLE_CLOUD_PROJECT,
    FIREBASE_CONFIG: process.env.FIREBASE_CONFIG,
  };
  let transactions = 0;
  try {
    delete process.env.GCLOUD_PROJECT;
    delete process.env.GOOGLE_CLOUD_PROJECT;
    delete process.env.FIREBASE_CONFIG;
    await assert.rejects(reconcilePlayedWithMatch({
      projectId: 'padelx-staging',
      async runTransaction() { transactions += 1; },
    }, 'm1', now), /Missing or conflicting/);
    assert.equal(transactions, 0);
  } finally {
    for (const [key, value] of Object.entries(original)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
  }
});
