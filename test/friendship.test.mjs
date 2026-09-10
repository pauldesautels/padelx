import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { requestFriendOperation, respondToFriendRequestOperation,
  cancelFriendRequestOperation, removeFriendOperation } from '../functions/friendship.js';
import { blockPlayerOperation, listBlockedPlayersOperation, unblockPlayerOperation } from '../functions/blocks.js';
import { friendshipId, blockId, getRelationshipPoliciesOperation } from '../functions/friendship_policy.js';

const projectId = 'demo-padelx-friends';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= '127.0.0.1:9099';
const app = initializeApp({ projectId }, 'friend-tests');
const db = getFirestore(app);
const request = (uid, data) => ({ auth: { uid, token: { email_verified: true } }, data,
  rawRequest: { relationshipNow: new Date('2026-09-07T12:00:00Z') } });
async function account(uid) { await db.doc(`users/${uid}`).set({ uid }); await db.doc(`publicProfiles/${uid}`).set({ uid }); }
async function data(path) { return (await db.doc(path).get()).data(); }

before(async () => db.doc('_warmup/ready').set({ ready: true }));
beforeEach(async () => { for (const collection of await db.listCollections()) {
  for (const ref of await collection.listDocuments()) await db.recursiveDelete(ref);
} await account('a'); await account('b'); await account('c'); });
after(async () => deleteApp(app));

test('request, duplicate, reciprocal convergence, and removal are deterministic', async () => {
  assert.equal(friendshipId('a', 'b'), friendshipId('b', 'a'));
  assert.deepEqual(await requestFriendOperation(db, request('a', { targetUid: 'b' })), { status: 'pending', changed: true });
  assert.deepEqual(await requestFriendOperation(db, request('a', { targetUid: 'b' })), { status: 'pending', changed: false });
  assert.deepEqual(await requestFriendOperation(db, request('b', { targetUid: 'a' })), { status: 'accepted', changed: true });
  const friendship = await data(`friendships/${friendshipId('a', 'b')}`);
  assert.equal(friendship.status, 'accepted');
  assert.equal((await data('users/a/friendViews/b')).direction, 'mutual');
  assert.equal((await data('users/b/friendViews/a')).direction, 'mutual');
  assert.deepEqual(await removeFriendOperation(db, request('a', { targetUid: 'b' })), { status: 'removed', changed: true });
  assert.equal(await data('users/a/friendViews/b'), undefined);
  assert.deepEqual(await removeFriendOperation(db, request('a', { targetUid: 'b' })), { status: 'removed', changed: false });
});

test('recipient accepts or declines; requester alone cancels', async () => {
  await requestFriendOperation(db, request('a', { targetUid: 'b' }));
  await assert.rejects(respondToFriendRequestOperation(db, request('a', { targetUid: 'b', action: 'accept' })));
  await assert.rejects(cancelFriendRequestOperation(db, request('b', { targetUid: 'a' })));
  assert.equal((await respondToFriendRequestOperation(db, request('b', { targetUid: 'a', action: 'accept' }))).status, 'accepted');
  assert.equal((await respondToFriendRequestOperation(db, request('b', { targetUid: 'a', action: 'accept' }))).changed, false);
  await removeFriendOperation(db, request('a', { targetUid: 'b' }));
  await requestFriendOperation(db, request('a', { targetUid: 'b' }));
  assert.equal((await respondToFriendRequestOperation(db, request('b', { targetUid: 'a', action: 'decline' }))).status, 'declined');
  await requestFriendOperation(db, request('a', { targetUid: 'b' }));
  assert.equal((await cancelFriendRequestOperation(db, request('a', { targetUid: 'b' }))).status, 'cancelled');
});

test('blocking removes relationships, is replay-safe, prevents both directions, and unblock restores nothing', async () => {
  await requestFriendOperation(db, request('a', { targetUid: 'b' }));
  await respondToFriendRequestOperation(db, request('b', { targetUid: 'a', action: 'accept' }));
  assert.deepEqual(await blockPlayerOperation(db, request('a', { targetUid: 'b' })), { blocked: true, changed: true });
  assert.equal(await data(`friendships/${friendshipId('a', 'b')}`), undefined);
  assert.equal(await data('users/a/friendViews/b'), undefined); assert.equal(await data('users/b/friendViews/a'), undefined);
  assert.ok(await data(`blocks/${blockId('a', 'b')}`));
  assert.equal((await blockPlayerOperation(db, request('a', { targetUid: 'b' }))).changed, false);
  await assert.rejects(requestFriendOperation(db, request('a', { targetUid: 'b' })), /unavailable/);
  await assert.rejects(requestFriendOperation(db, request('b', { targetUid: 'a' })), /unavailable/);
  const policy = await getRelationshipPoliciesOperation(db, request('b', { targetUids: ['a'] }));
  assert.deepEqual(policy.policies.a, { interactionAllowed: false, blockedByViewer: false, status: 'none', direction: 'none' });
  assert.equal((await unblockPlayerOperation(db, request('a', { targetUid: 'b' }))).changed, true);
  assert.equal(await data(`friendships/${friendshipId('a', 'b')}`), undefined);
  assert.equal((await unblockPlayerOperation(db, request('a', { targetUid: 'b' }))).changed, false);
});

test('blocked-player listing is owner-scoped, bounded, deterministic, and public-only', async () => {
  await db.doc('publicProfiles/b').set({ uid: 'b', displayName: 'Bee', level: '4', avatarVersion: 2,
    email: 'private@example.com' });
  await blockPlayerOperation(db, request('a', { targetUid: 'b' }));
  await blockPlayerOperation(db, request('a', { targetUid: 'c' }));
  await blockPlayerOperation(db, request('b', { targetUid: 'c' }));

  const first = await listBlockedPlayersOperation(db, request('a', { limit: 1 }));
  assert.equal(first.players.length, 1); assert.equal(first.hasMore, true);
  assert.ok(first.cursor); assert.deepEqual(Object.keys(first.players[0]).sort(),
    ['avatarVersion', 'blockedAt', 'blockedUid', 'displayName', 'level', 'unavailable']);
  assert.equal(first.players[0].email, undefined);
  const second = await listBlockedPlayersOperation(db, request('a', { limit: 1, cursor: first.cursor }));
  assert.equal(second.players.length, 1); assert.notEqual(second.players[0].blockedUid, first.players[0].blockedUid);
  assert.equal(second.hasMore, false);
  assert.deepEqual(new Set([...first.players, ...second.players].map((player) => player.blockedUid)), new Set(['b', 'c']));
});

test('blocked-player listing validates input and returns unavailable fallback', async () => {
  await blockPlayerOperation(db, request('a', { targetUid: 'b' }));
  await db.doc('publicProfiles/b').delete();
  const page = await listBlockedPlayersOperation(db, request('a', {}));
  assert.equal(page.players[0].displayName, 'Unavailable player');
  assert.equal(page.players[0].unavailable, true);
  await assert.rejects(listBlockedPlayersOperation(db, request('a', { cursor: 'bad' })));
  await assert.rejects(listBlockedPlayersOperation(db, request('a', { limit: 21 })));
  await assert.rejects(listBlockedPlayersOperation(db, { ...request('a', {}), auth: { uid: 'a', token: {} } }));
  await db.doc('users/a').update({ active: false });
  await assert.rejects(listBlockedPlayersOperation(db, request('a', {})));
  await db.doc('users/a').update({ active: true });
  await db.doc('accountDeletionBarriers/a').set({ uid: 'a', status: 'deleting' });
  await assert.rejects(listBlockedPlayersOperation(db, request('a', {})));
});

test('self, unverified, inactive, and deleting accounts are rejected', async () => {
  await assert.rejects(requestFriendOperation(db, request('a', { targetUid: 'a' })));
  await assert.rejects(requestFriendOperation(db, { ...request('a', { targetUid: 'b' }), auth: { uid: 'a', token: {} } }));
  await db.doc('publicProfiles/b').delete();
  await assert.rejects(requestFriendOperation(db, request('a', { targetUid: 'b' })));
  await db.doc('publicProfiles/b').set({ uid: 'b' }); await db.doc('accountDeletionBarriers/b').set({ status: 'deleting' });
  await assert.rejects(requestFriendOperation(db, request('a', { targetUid: 'b' })));
});

test('outgoing pending requests are capped at fifty', async () => {
  for (let index = 0; index < 51; index += 1) await account(`target-${index}`);
  for (let index = 0; index < 50; index += 1) {
    await requestFriendOperation(db, request('a', { targetUid: `target-${index}` }));
  }
  await assert.rejects(
    requestFriendOperation(db, request('a', { targetUid: 'target-50' })),
    /Too many pending/,
  );
});
