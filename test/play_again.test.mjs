import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { blockId, friendshipId } from '../functions/friendship_policy.js';
import { createPlayAgainInvitationOperation, dismissPlayAgainInvitationOperation,
  playAgainNotificationId, reconcilePlayAgainInvitesForMatch,
  MAX_PLAY_AGAIN_INVITES_PER_MATCH } from '../functions/play_again.js';

const projectId = 'demo-padelx-play-again';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= '127.0.0.1:9099';
const app = initializeApp({ projectId }, 'play-again-tests');
const db = getFirestore(app);
const now = new Date('2026-09-07T12:00:00Z');
const request = (uid, data) => ({ auth: { uid, token: { email_verified: true } }, data,
  rawRequest: { relationshipNow: now } });
async function account(uid, values = {}) {
  await db.doc(`users/${uid}`).set({ uid, ...values });
  await db.doc(`publicProfiles/${uid}`).set({ uid });
}
async function match(id = 'new-match', values = {}) {
  await db.doc(`matches/${id}`).set({ creatorUid: 'a', players: [], spotsLeft: 3,
    scheduledAt: new Date('2026-09-08T12:00:00Z'), clubName: 'Central Padel', ...values });
}
async function playedWith(left = 'a', right = 'b') {
  await db.doc(`users/${left}/playedWith/${right}`).set({ otherUid: right, completedMatchCount: 1 });
}
async function invite(data = {}) {
  return createPlayAgainInvitationOperation(db, request('a', {
    matchId: 'new-match', inviteeUid: 'b', ...data,
  }));
}

before(async () => db.doc('_warmup/ready').set({ ready: true }));
beforeEach(async () => {
  for (const collection of await db.listCollections()) {
    for (const ref of await collection.listDocuments()) await db.recursiveDelete(ref);
  }
  await account('a'); await account('b'); await match();
});
after(async () => deleteApp(app));

test('Played With invitation is deterministic, idempotent, and creates no membership or join request', async () => {
  await playedWith();
  assert.deepEqual(await invite(), { status: 'pending', changed: true });
  assert.deepEqual(await invite(), { status: 'pending', changed: false });
  const invitation = (await db.doc('matches/new-match/invites/b').get()).data();
  assert.equal(invitation.status, 'pending');
  assert.equal((await db.doc(`notifications/${playAgainNotificationId('new-match', 'b')}`).get()).exists, true);
  assert.deepEqual((await db.doc('matches/new-match').get()).data().players, []);
  assert.equal((await db.doc('matches/new-match/joinRequests/b').get()).exists, false);
});

test('accepted friend is eligible while a stranger and self are denied', async () => {
  await db.doc(`friendships/${friendshipId('a', 'b')}`).set({
    memberUids: ['a', 'b'], status: 'accepted', requesterUid: 'a', recipientUid: 'b',
  });
  assert.equal((await invite()).changed, true);
  await account('c');
  await assert.rejects(createPlayAgainInvitationOperation(db,
    request('a', { matchId: 'new-match', inviteeUid: 'c' })), /friends or prior players/);
  await assert.rejects(createPlayAgainInvitationOperation(db,
    request('a', { matchId: 'new-match', inviteeUid: 'a' })), /yourself/);
});

test('blocks, deletion, inactivity, ownership, capacity, and existing membership deny invitation', async () => {
  await playedWith();
  await db.doc(`blocks/${blockId('b', 'a')}`).set({ blockerUid: 'b', blockedUid: 'a' });
  await assert.rejects(invite(), /unavailable/);
  await db.doc(`blocks/${blockId('b', 'a')}`).delete();
  await db.doc('accountDeletionBarriers/b').set({ status: 'deleting' });
  await assert.rejects(invite(), /deletion/);
  await db.doc('accountDeletionBarriers/b').delete();
  await db.doc('users/b').update({ active: false });
  await assert.rejects(invite(), /unavailable/);
  await db.doc('users/b').update({ active: true });
  await db.doc('matches/new-match').update({ creatorUid: 'c' });
  await assert.rejects(invite(), /organizer/);
  await db.doc('matches/new-match').update({ creatorUid: 'a', spotsLeft: 0 });
  await assert.rejects(invite(), /full/);
  await db.doc('matches/new-match').update({ spotsLeft: 2, players: [{ uid: 'b' }] });
  await assert.rejects(invite(), /already joined/);
});

test('past new match and invalid source match are denied; valid completed source is accepted', async () => {
  await playedWith();
  await db.doc('matches/new-match').update({ scheduledAt: new Date('2026-09-06T12:00:00Z') });
  await assert.rejects(invite(), /no longer open/);
  await db.doc('matches/new-match').update({ scheduledAt: new Date('2026-09-08T12:00:00Z') });
  await match('source', { scheduledAt: new Date('2026-09-06T12:00:00Z'), players: [{ uid: 'b' }] });
  assert.equal((await invite({ sourceMatchId: 'source' })).changed, true);
});

test('dismissal is final for a match and removes its notification', async () => {
  await playedWith(); await invite();
  assert.deepEqual(await dismissPlayAgainInvitationOperation(db,
    request('b', { matchId: 'new-match' })), { status: 'dismissed', changed: true });
  assert.equal((await db.doc(`notifications/${playAgainNotificationId('new-match', 'b')}`).get()).exists, false);
  await assert.rejects(invite(), /cannot be invited/);
});

test('confirmed membership transitions invitation to joined and resolves notification', async () => {
  await playedWith(); await invite();
  await db.doc('matches/new-match').update({ players: [{ uid: 'b' }], spotsLeft: 2 });
  await reconcilePlayAgainInvitesForMatch(db, 'new-match', now);
  assert.equal((await db.doc('matches/new-match/invites/b').get()).data().status, 'joined');
  assert.equal((await db.doc(`notifications/${playAgainNotificationId('new-match', 'b')}`).get()).exists, false);
});

test('active invitations are capped at three per match', async () => {
  for (let index = 0; index <= MAX_PLAY_AGAIN_INVITES_PER_MATCH; index += 1) {
    const uid = `target-${index}`; await account(uid); await playedWith('a', uid);
    if (index < MAX_PLAY_AGAIN_INVITES_PER_MATCH) {
      await createPlayAgainInvitationOperation(db, request('a', { matchId: 'new-match', inviteeUid: uid }));
    } else {
      await assert.rejects(createPlayAgainInvitationOperation(db,
        request('a', { matchId: 'new-match', inviteeUid: uid })), /maximum active/);
    }
  }
});
