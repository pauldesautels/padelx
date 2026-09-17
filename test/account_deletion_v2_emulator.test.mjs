import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { deletionStateFor } from '../functions/account_state.js';
import { acquireDeletionLease, runMessagingDeletionPhase, runSocialDeletionPhase,
  runMatchesDeletionPhase, runNotificationsDeletionPhase, runStorageDeletionPhase,
  runVerifyDeletionPhase } from '../functions/account_deletion_worker.js';
import { requestFriendOperation } from '../functions/friendship.js';
import { friendshipId } from '../functions/friendship_policy.js';
import { sendMessageOperation } from '../functions/messaging.js';
import { directConversationId, matchConversationId } from '../functions/messaging_policy.js';
import { createPlayAgainInvitationOperation, playAgainNotificationId } from '../functions/play_again.js';
import { reconcilePlayedWithMatch } from '../functions/played_with_projection.js';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-padelx-deletion-v2';
process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'deletion-v2-tests');
const db = getFirestore(app); after(() => deleteApp(app));
const cutoff = Timestamp.fromDate(new Date('2026-06-01T00:00:00Z'));
const lease = { leaseOwner: 'v2-worker', leaseToken: 'v2-token' };
const request = (uid, data) => ({ auth: { uid, token: { email_verified: true } }, data,
  rawRequest: { relationshipNow: cutoff.toDate(), messagingNow: cutoff.toDate() } });
async function account(uid) {
  await db.doc(`users/${uid}`).set({ uid });
  await db.doc(`publicProfiles/${uid}`).set({ uid, completedMatchCount: 0, repeatPlayerCount: 0 });
}
async function beginDeletion(uid, token = uid) {
  const state = deletionStateFor(uid, cutoff.toDate(), 2);
  await db.doc(`accountDeletionJobs/${uid}`).set({ ...state.job, phase: 'social',
    authDisabledAt: cutoff, authRevokedAt: cutoff, matchesCutoff: cutoff,
    joinRequestsCutoff: cutoff });
  await db.doc(`accountDeletionBarriers/${uid}`).set(state.barrier);
  await db.doc(`accountDeletionOutbox/${uid}`).set({ ...state.barrier, jobId: uid, status: 'ready_for_cleanup' });
  const owned = { leaseOwner: 'v2-worker', leaseToken: token };
  assert.equal(await acquireDeletionLease(db, uid, owned), true);
  return owned;
}
async function drain(phase, uid, owned) {
  for (let i = 0; i < 30; i++) { const result = await phase(db, uid, owned); if (result.complete) return; }
  assert.fail('phase did not complete');
}

test('schema-v2 social, messaging, storage, and verification remove identity', async () => {
  const uid = 'deleting-v2'; const other = 'survivor-v2';
  const state = deletionStateFor(uid, cutoff.toDate(), 2);
  await db.doc(`accountDeletionJobs/${uid}`).set({ ...state.job, phase: 'social',
    authDisabledAt: cutoff, authRevokedAt: cutoff });
  await db.doc(`accountDeletionBarriers/${uid}`).set(state.barrier);
  await db.doc(`accountDeletionOutbox/${uid}`).set({ ...state.barrier, jobId: uid, status: 'ready_for_cleanup' });
  await db.doc('friendships/pair-v2').set({ memberUids: [uid, other], requesterUid: uid, recipientUid: other });
  await db.doc(`users/${other}/friendViews/${uid}`).set({ otherUid: uid });
  await db.doc('blocks/block-v2').set({ blockerUid: other, blockedUid: uid });
  await db.doc('matches/match-v2/invites/deleting-v2').set({ inviterUid: other, inviteeUid: uid });
  await db.doc(`playAgainRateLimits/${uid}`).set({ inviterUid: uid });
  await db.doc('pushDevices/device-v2-a').set({ uid, token: 'token-a', platform: 'ios' });
  await db.doc('pushDevices/device-v2-b').set({ uid, token: 'token-b', platform: 'android' });
  await db.doc('pushDevices/device-survivor').set({ uid: other, token: 'token-c' });
  await db.doc(`users/${uid}/settings/notifications`).set({ pushEnabled: true });
  assert.equal(await acquireDeletionLease(db, uid, lease), true);
  for (let i = 0; i < 20; i++) { const result = await runSocialDeletionPhase(db, uid, lease); if (result.complete) break; }
  assert.equal((await db.doc(`accountDeletionJobs/${uid}`).get()).data().phase, 'messaging');
  assert.equal((await db.collection('pushDevices').where('uid', '==', uid).get()).empty, true);
  assert.equal((await db.doc('pushDevices/device-survivor').get()).exists, true);
  assert.equal((await db.doc(`users/${uid}/settings/notifications`).get()).exists, false);

  await db.doc('conversations/direct_v2').set({ type: 'direct', memberUids: [uid, other],
    lastSenderUid: uid, lastMessagePreview: 'private text' });
  await db.doc('conversations/direct_v2/messages/message-v2').set({ senderUid: uid, text: 'private text' });
  await db.doc(`users/${other}/conversationViews/direct_v2`).set({ otherUid: uid });
  await db.doc(`messagingRateLimits/${uid}`).set({ count: 1 });
  for (let i = 0; i < 10; i++) { const result = await runMessagingDeletionPhase(db, uid, lease); if (result.complete) break; }
  const message = (await db.doc('conversations/direct_v2/messages/message-v2').get()).data();
  assert.deepEqual(message, { senderDeleted: true, text: 'Deleted message' });
  assert.equal((await db.doc('conversations/direct_v2').get()).exists, false);

  await db.doc(`accountDeletionJobs/${uid}`).update({ phase: 'storage', checkpoint: null });
  let deleted = false;
  const bucket = { file: () => ({ delete: async () => { deleted = true; } }),
    getFiles: async () => [[], null] };
  await runStorageDeletionPhase(db, bucket, uid, lease);
  assert.equal(deleted, true);
  for (let i = 0; i < 5; i++) { const result = await runVerifyDeletionPhase(db, uid, lease); if (result.complete) break; }
  assert.equal((await db.doc(`accountDeletionJobs/${uid}`).get()).data().phase, 'deleteAuth');
});

test('future organizer deletion removes protected private venue', async () => {
  const uid = 'private-venue-owner';
  const owned = await beginDeletion(uid, 'private-venue-token');
  await db.doc(`accountDeletionJobs/${uid}`).update({ phase: 'matches', checkpoint: null });
  await db.doc('matches/private-venue-match').set({ creatorUid: uid, creatorDisplayName: 'Owner',
    creatorLevel: 'Level 3', players: [], participantUids: [uid], spotsLeft: 3,
    scheduledAt: Timestamp.fromDate(new Date('2026-06-02T00:00:00Z')),
    source: 'matchmaking', venueType: 'private_free' });
  await db.doc('matchPrivateVenues/private-venue-match').set({ schemaVersion: 1,
    matchId: 'private-venue-match', address: 'Synthetic address', latitude: 19.4, longitude: -99.1 });
  await drain(runMatchesDeletionPhase, uid, owned);
  assert.equal((await db.doc('matchPrivateVenues/private-venue-match').get()).exists, false);
  assert.equal((await db.doc('matches/private-venue-match').get()).data().status, 'cancelled');
});

test('deleting proposal member releases unaffected matchmaking requests', async () => {
  const uid = 'proposal-deleting';
  const survivor = 'proposal-survivor';
  const owned = await beginDeletion(uid, 'proposal-cleanup-token');
  await db.doc('matchmakingRequests/deleting-request').set({ ownerUid: uid,
    memberUids: [uid], status: 'matched', proposalId: 'deletion-proposal' });
  await db.doc('matchmakingRequests/survivor-request').set({ ownerUid: survivor,
    memberUids: [survivor], status: 'matched', proposalId: 'deletion-proposal' });
  await db.doc('matchProposals/deletion-proposal').set({ memberUids: [uid, survivor],
    sourceRequestIds: ['deleting-request', 'survivor-request'], status: 'confirming' });
  await db.doc(`users/${survivor}/matchmakingRequestViews/survivor-request`).set({
    status: 'matched', proposalId: 'deletion-proposal',
  });
  await db.doc(`users/${survivor}/matchProposalViews/deletion-proposal`).set({ status: 'confirming' });
  await db.doc(`matchmakingActiveOwners/${survivor}`).set({ ownerUid: survivor,
    activeRequestId: 'survivor-request', status: 'matched' });
  await drain(runSocialDeletionPhase, uid, owned);
  assert.equal((await db.doc('matchProposals/deletion-proposal').get()).exists, false);
  assert.equal((await db.doc('matchmakingRequests/deleting-request').get()).exists, false);
  assert.equal((await db.doc('matchmakingRequests/survivor-request').get()).data().status, 'active');
  assert.equal((await db.doc(`users/${survivor}/matchmakingRequestViews/survivor-request`).get())
    .data().status, 'active');
  assert.equal((await db.doc(`users/${survivor}/matchProposalViews/deletion-proposal`).get()).exists,
    false);
  assert.equal((await db.doc(`matchmakingActiveOwners/${survivor}`).get()).data().status, 'active');
});

test('deletion barrier and friend request converge in both commit orders', async () => {
  await account('friend-deleting'); await account('friend-survivor');
  await beginDeletion('friend-deleting', 'friend-barrier-first');
  await assert.rejects(requestFriendOperation(db, request('friend-survivor', { targetUid: 'friend-deleting' })), /unavailable/);

  await account('friend-first'); await account('friend-first-survivor');
  await requestFriendOperation(db, request('friend-first-survivor', { targetUid: 'friend-first' }));
  const owned = await beginDeletion('friend-first', 'friend-first-token');
  await drain(runSocialDeletionPhase, 'friend-first', owned);
  assert.equal((await db.doc(`friendships/${friendshipId('friend-first', 'friend-first-survivor')}`).get()).exists, false);
  assert.equal((await db.doc('users/friend-first-survivor/friendViews/friend-first').get()).exists, false);
});

test('deletion barrier and direct-message send converge in both commit orders', async () => {
  for (const uid of ['direct-deleting', 'direct-survivor']) await account(uid);
  const directId = directConversationId('direct-deleting', 'direct-survivor');
  await db.doc(`friendships/${friendshipId('direct-deleting', 'direct-survivor')}`).set({
    memberUids: ['direct-deleting', 'direct-survivor'].sort(), status: 'accepted',
    requesterUid: 'direct-survivor', recipientUid: 'direct-deleting' });
  await db.doc(`conversations/${directId}`).set({ type: 'direct', memberUids: ['direct-deleting', 'direct-survivor'].sort() });
  await beginDeletion('direct-deleting', 'direct-barrier-first');
  await assert.rejects(sendMessageOperation(db, request('direct-survivor', { conversationId: directId,
    requestId: 'request_direct_barrier', text: 'private' })), /unavailable/);

  for (const uid of ['direct-first', 'direct-first-survivor']) await account(uid);
  const firstId = directConversationId('direct-first', 'direct-first-survivor');
  await db.doc(`friendships/${friendshipId('direct-first', 'direct-first-survivor')}`).set({
    memberUids: ['direct-first', 'direct-first-survivor'].sort(), status: 'accepted',
    requesterUid: 'direct-first', recipientUid: 'direct-first-survivor' });
  await db.doc(`conversations/${firstId}`).set({ type: 'direct', memberUids: ['direct-first', 'direct-first-survivor'].sort() });
  await sendMessageOperation(db, request('direct-first', { conversationId: firstId,
    requestId: 'request_direct_first', text: 'secret' }));
  const owned = await beginDeletion('direct-first', 'direct-first-token');
  await drain(runSocialDeletionPhase, 'direct-first', owned);
  await drain(runMessagingDeletionPhase, 'direct-first', owned);
  const tombstone = (await db.doc(`conversations/${firstId}/messages/request_direct_first`).get()).data();
  assert.deepEqual(Object.keys(tombstone).sort(), ['createdAt', 'requestId', 'senderDeleted', 'text']);
  assert.equal(tombstone.text, 'Deleted message'); assert.equal(tombstone.senderDeleted, true);
  assert.equal((await db.doc(`conversations/${firstId}`).get()).exists, false);
});

test('match-chat barrier denies sends and cleanup cannot recreate deleted identity', async () => {
  for (const uid of ['match-deleting', 'match-survivor']) await account(uid);
  const matchId = 'race-match-chat'; const conversationId = matchConversationId(matchId);
  await db.doc(`matches/${matchId}`).set({ creatorUid: 'match-deleting', players: [{ uid: 'match-survivor' }],
    participantUids: ['match-deleting', 'match-survivor'], scheduledAt: cutoff });
  await db.doc(`conversations/${conversationId}`).set({ type: 'match', matchId,
    memberUids: ['match-deleting', 'match-survivor'] });
  const owned = await beginDeletion('match-deleting', 'match-chat-token');
  await assert.rejects(sendMessageOperation(db, request('match-deleting', { conversationId,
    requestId: 'request_match_barrier', text: 'private' })), /deletion/);
  await drain(runSocialDeletionPhase, 'match-deleting', owned);
  await drain(runMessagingDeletionPhase, 'match-deleting', owned);
  assert.deepEqual((await db.doc(`conversations/${conversationId}`).get()).data().memberUids, ['match-survivor']);
});

test('deletion barrier and Play Again invitation converge in both commit orders', async () => {
  for (const uid of ['invite-deleting', 'invite-survivor']) await account(uid);
  await db.doc('matches/invite-target').set({ creatorUid: 'invite-survivor', players: [], spotsLeft: 3,
    scheduledAt: Timestamp.fromDate(new Date('2026-06-02T00:00:00Z')) });
  await db.doc('users/invite-survivor/playedWith/invite-deleting').set({ otherUid: 'invite-deleting', completedMatchCount: 1 });
  await beginDeletion('invite-deleting', 'invite-barrier-first');
  await assert.rejects(createPlayAgainInvitationOperation(db, request('invite-survivor', {
    matchId: 'invite-target', inviteeUid: 'invite-deleting' })), /deletion/);

  for (const uid of ['invite-first', 'invite-first-survivor']) await account(uid);
  await db.doc('matches/invite-first-target').set({ creatorUid: 'invite-first-survivor', players: [], spotsLeft: 3,
    scheduledAt: Timestamp.fromDate(new Date('2026-06-02T00:00:00Z')) });
  await db.doc('users/invite-first-survivor/playedWith/invite-first').set({ otherUid: 'invite-first', completedMatchCount: 1 });
  await createPlayAgainInvitationOperation(db, request('invite-first-survivor', {
    matchId: 'invite-first-target', inviteeUid: 'invite-first' }));
  const owned = await beginDeletion('invite-first', 'invite-first-token');
  await drain(runSocialDeletionPhase, 'invite-first', owned);
  assert.equal((await db.doc('matches/invite-first-target/invites/invite-first').get()).exists, false);
  await drain(runMessagingDeletionPhase, 'invite-first', owned);
  await drain(runNotificationsDeletionPhase, 'invite-first', owned);
  assert.equal((await db.doc(`notifications/${playAgainNotificationId('invite-first-target', 'invite-first')}`).get()).exists, false);
});

test('concurrent Played With reconciliations and deletion converge exactly', async () => {
  for (const uid of ['project-deleting', 'project-a', 'project-b']) await account(uid);
  await db.doc('matches/project-race').set({ creatorUid: 'project-deleting',
    players: [{ uid: 'project-a' }, { uid: 'project-b' }],
    participantUids: ['project-deleting', 'project-a', 'project-b'], scheduledAt: cutoff });
  await Promise.all(Array.from({ length: 6 }, () => reconcilePlayedWithMatch(db, 'project-race', cutoff)));
  await db.doc('accountDeletionBarriers/project-deleting').set({ status: 'deleting', schemaVersion: 2,
    uid: 'project-deleting', deletionRequestedAt: cutoff });
  await Promise.all(Array.from({ length: 6 }, () => reconcilePlayedWithMatch(db, 'project-race', cutoff)));
  assert.equal((await db.doc('users/project-a/playedWith/project-deleting').get()).exists, false);
  assert.equal((await db.doc('users/project-deleting/playedWith/project-a').get()).exists, false);
  assert.equal((await db.doc('users/project-a/playedWith/project-b').get()).data().completedMatchCount, 1);
  assert.equal((await db.doc('publicProfiles/project-a').get()).data().completedMatchCount, 1);
  assert.equal((await db.doc('publicProfiles/project-a').get()).data().repeatPlayerCount, 0);
});
