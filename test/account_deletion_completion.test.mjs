import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getStorage } from 'firebase-admin/storage';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { admitAccountDeletion, lockDeletionAuth } from '../functions/account_deletion.js';
import { dispatchAccountDeletion, acceptDeletedAuthUser, recoverAccountDeletions } from '../functions/account_deletion_dispatch.js';
import { acquireDeletionLease, runAcceptedDeletionPhase, runDeleteAuthDeletionPhase,
  runJoinRequestsDeletionPhase, runMatchesDeletionPhase, runNotificationsDeletionPhase,
  runRatingsDeletionPhase, runVerifyDeletionPhase } from '../functions/account_deletion_worker.js';
import { deletionStateFor, DELETION_PHASES_BY_VERSION } from '../functions/account_state.js';
import { prepareDeletion, preparationOptions } from '../tool/prepare_account_deletion.mjs';
import { reconcilePlayedWithMatch } from '../functions/played_with_projection.js';
import { friendshipId, blockId } from '../functions/friendship_policy.js';
import { directConversationId, matchConversationId } from '../functions/messaging_policy.js';
import { playAgainNotificationId } from '../functions/play_again.js';
const projectId = 'demo-padelx-phase8';
process.env.GCLOUD_PROJECT = projectId; process.env.GOOGLE_CLOUD_PROJECT = projectId;
const storageBucket = `${projectId}.firebasestorage.app`;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId, storageBucket });
const app = initializeApp({ projectId, storageBucket }, 'completion');
const db = getFirestore(app), auth = getAuth(app);
const bucket = getStorage(app).bucket();
after(() => deleteApp(app));
const ref = uid => db.doc(`accountDeletionJobs/${uid}`);
const request = uid => ({ auth: { uid, token: { auth_time: Math.floor(Date.now()/1000) } }, data: {} });
async function finish(uid) {
  for (let i = 0; i < 20; i++) {
    await dispatchAccountDeletion(db, auth, bucket, uid);
    if ((await ref(uid).get()).data().status === 'completed') return;
  }
  assert.fail('deletion did not complete');
}
test('unverified incomplete user, lost response, duplicate dispatch, Auth finalization and minimal receipt', async () => {
  const uid = 'complete-user'; await auth.createUser({ uid, emailVerified: false });
  await admitAccountDeletion(db, auth, request(uid));
  const cutoff = (await ref(uid).get()).data().deletionRequestedAt;
  await admitAccountDeletion(db, auth, request(uid));
  await Promise.all([dispatchAccountDeletion(db, auth, bucket, uid), dispatchAccountDeletion(db, auth, bucket, uid)]);
  await finish(uid);
  await assert.rejects(auth.getUser(uid), { code: 'auth/user-not-found' });
  const job = (await ref(uid).get()).data();
  assert.equal(job.phase, 'complete'); assert.ok(job.completedAt);
  assert.ok(job.deletionRequestedAt.isEqual(cutoff));
  assert.deepEqual(Object.keys(job).sort(), ['completedAt','deletionRequestedAt','phase','schemaVersion','status','uid']);
  assert.equal((await db.doc(`accountDeletionOutbox/${uid}`).get()).data().status, 'consumed');
  await lockDeletionAuth(db, auth, uid); // Late admission trigger cannot regress completion.
  assert.equal((await ref(uid).get()).data().status, 'completed');
  await acceptDeletedAuthUser(db, uid); // Auth event after normal finalization.
  assert.ok((await ref(uid).get()).data().deletionRequestedAt.isEqual(cutoff));
});

test('storage phase uses the configured modern bucket and rejects a mismatched injected bucket', async () => {
  assert.equal(bucket.name, storageBucket);
  assert.notEqual(bucket.name, `${projectId}.appspot.com`);
  const uid = 'configured-storage-bucket';
  await auth.createUser({ uid });
  await admitAccountDeletion(db, auth, request(uid));
  const wrongBucket = getStorage(app).bucket(`${projectId}.appspot.com`);
  for (let attempt = 0; attempt < 20; attempt++) {
    await dispatchAccountDeletion(db, auth, wrongBucket, uid);
    if ((await ref(uid).get()).data().status === 'retry_wait') break;
  }
  const failed = (await ref(uid).get()).data();
  assert.equal(failed.phase, 'storage');
  assert.equal(failed.status, 'retry_wait');
  assert.equal(failed.lastFailureCategory, 'storage-configuration-invalid');
  assert.ok(await auth.getUser(uid));
  await ref(uid).update({ nextAttemptAt: new Date(0) });
  await db.doc(`accountDeletionOutbox/${uid}`).update({ nextAttemptAt: new Date(0) });
  await finish(uid);
  await assert.rejects(auth.getUser(uid), { code: 'auth/user-not-found' });
});

test('missing authoritative bucket fails closed before Auth deletion', async () => {
  const uid = 'missing-storage-bucket';
  await auth.createUser({ uid });
  await admitAccountDeletion(db, auth, request(uid));
  const configured = process.env.FIREBASE_CONFIG;
  process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
  try {
    for (let attempt = 0; attempt < 20; attempt++) {
      await dispatchAccountDeletion(db, auth, null, uid);
      if ((await ref(uid).get()).data().status === 'retry_wait') break;
    }
  } finally {
    process.env.FIREBASE_CONFIG = configured;
  }
  const failed = (await ref(uid).get()).data();
  assert.equal(failed.phase, 'storage');
  assert.equal(failed.status, 'retry_wait');
  assert.equal(failed.lastFailureCategory, 'storage-bucket-unavailable');
  assert.ok(await auth.getUser(uid));
});
test('direct Auth fallback uses pipeline and absent Auth is successful', async () => {
  const uid = 'external-delete'; await acceptDeletedAuthUser(db, uid); await finish(uid);
  assert.equal((await ref(uid).get()).data().status, 'completed');
});

test('existing schema-v1 jobs resume from every Phase 8 phase and never enter Phase 9 phases', async () => {
  const phases = DELETION_PHASES_BY_VERSION[1].filter((phase) => phase !== 'complete');
  const handlers = {
    accepted: (uid, owned) => runAcceptedDeletionPhase(db, auth, uid, owned),
    matches: (uid, owned) => runMatchesDeletionPhase(db, uid, owned),
    joinRequests: (uid, owned) => runJoinRequestsDeletionPhase(db, uid, owned),
    notifications: (uid, owned) => runNotificationsDeletionPhase(db, uid, owned),
    ratings: (uid, owned) => runRatingsDeletionPhase(db, uid, owned),
    verify: (uid, owned) => runVerifyDeletionPhase(db, uid, owned),
  };
  for (const targetPhase of phases) {
    const uid = `schema-v1-${targetPhase}`; const cutoffDate = new Date('2026-03-01T00:00:00Z');
    await auth.createUser({ uid });
    const state = deletionStateFor(uid, cutoffDate, 1);
    await db.doc(`accountDeletionJobs/${uid}`).set({ ...state.job, authMissing: false,
      authDisabledAt: null, authRevokedAt: null });
    await db.doc(`accountDeletionBarriers/${uid}`).set(state.barrier);
    await db.doc(`accountDeletionOutbox/${uid}`).set({ ...state.barrier, jobId: uid,
      status: 'ready_for_cleanup', nextAttemptAt: cutoffDate });
    const owned = { leaseOwner: 'schema-v1-setup', leaseToken: `token-${targetPhase}` };
    assert.equal(await acquireDeletionLease(db, uid, owned), true);
    const observed = [];
    while ((await ref(uid).get()).data().phase !== targetPhase) {
      const phase = (await ref(uid).get()).data().phase; observed.push(phase);
      for (let attempts = 0; attempts < 30 && (await ref(uid).get()).data().phase === phase; attempts++) {
        await handlers[phase](uid, owned);
      }
    }
    observed.push(targetPhase);
    assert.equal(observed.some((phase) => ['social', 'messaging', 'storage'].includes(phase)), false);
    await ref(uid).update({ status: 'retry_wait', leaseOwner: null, leaseToken: null,
      leaseExpiresAt: null, nextAttemptAt: new Date(0) });
    await db.doc(`accountDeletionOutbox/${uid}`).update({ nextAttemptAt: new Date(0) });
    await recoverAccountDeletions(db, auth, bucket);
    for (let attempts = 0; attempts < 30 && (await ref(uid).get()).data().status !== 'completed'; attempts++) {
      await db.doc(`accountDeletionOutbox/${uid}`).update({ nextAttemptAt: new Date(0) });
      await ref(uid).update({ nextAttemptAt: new Date(0) });
      await recoverAccountDeletions(db, auth, bucket);
    }
    const completed = (await ref(uid).get()).data();
    assert.equal(completed.status, 'completed', `${targetPhase}: ${JSON.stringify(completed)}`);
    await assert.rejects(auth.getUser(uid), { code: 'auth/user-not-found' });
  }
});
test('Auth deletion requires verified phase, fences stale workers and does not complete on transient failure', async () => {
  const uid = 'finalization-failure'; await admitAccountDeletion(db, auth, request(uid));
  const lease = { leaseOwner: 'test', leaseToken: 'one' };
  await acquireDeletionLease(db, uid, lease);
  await assert.rejects(runDeleteAuthDeletionPhase(db, { deleteUser: () => assert.fail() }, uid, lease), /Invalid Auth/);
  await ref(uid).update({ leaseExpiresAt: new Date(0), leaseOwner: null });
  const cutoff = (await ref(uid).get()).data().deletionRequestedAt;
  await ref(uid).update({ phase: 'deleteAuth', verifyCheckpoint: { manifestDone: true, manifestAfter: null },
    verifyCutoff: cutoff, lastPhaseTransition: { from: 'verify', to: 'deleteAuth' } });
  const fresh = { leaseOwner: 'test', leaseToken: 'two' };
  assert.equal(await acquireDeletionLease(db, uid, fresh), true);
  await assert.rejects(runDeleteAuthDeletionPhase(db, auth, uid, lease), /lease lost/);
  await assert.rejects(runDeleteAuthDeletionPhase(db, { deleteUser: async () => { throw new Error('unavailable'); } }, uid, fresh));
  assert.equal((await ref(uid).get()).data().completedAt, null);
  await runDeleteAuthDeletionPhase(db, auth, uid, fresh);
  assert.equal((await ref(uid).get()).data().status, 'completed');
});
test('bounded recovery rejects invalid pages and production', async () => {
  await assert.rejects(recoverAccountDeletions(db, auth, { pageSize: 21 }));
  await assert.rejects(recoverAccountDeletions({ projectId: 'padelx-f168f' }, auth));
});
test('preparation is dry-run, blocker-first, idempotent and production-refusing', async () => {
  assert.throws(() => preparationOptions([]));
  assert.throws(() => preparationOptions(['--project=padelx-f168f','--apply','--writers-paused']));
  assert.throws(() => preparationOptions([`--project=${projectId}`,'--apply']));
  await db.doc('matches/missing/joinRequests/requester').set({ email: 'legacy@example.com' });
  const report = await prepareDeletion(db, { apply: true, writersPaused: true });
  assert.ok(report.blockers.length); assert.equal(report.applied, 0);
  assert.equal((await db.doc('matches/missing/joinRequests/requester').get()).data().email, 'legacy@example.com');
});

test('preparation projects membership, removes emails and markers, and establishes exact contribution baseline', async () => {
  const prepApp = initializeApp({ projectId: 'demo-padelx-preparation' }, 'preparation');
  const prep = getFirestore(prepApp);
  try {
    await prep.doc('publicProfiles/player').set({ ratingSum: 999 });
    await prep.doc('matches/past').set({ creatorUid: 'owner', players: [{ uid: 'player' }], spotsLeft: 2,
      scheduledAt: Timestamp.fromDate(new Date('2020-01-01')) });
    await prep.doc('matches/past/joinRequests/player').set({ email: 'legacy@example.com' });
    await prep.doc('matches/past/ratingRaters/owner/ratings/player').set({ matchId: 'past', raterUid: 'owner', ratedUid: 'player', rating: 4 });
    await prep.doc('ratingAggregationEvents/old').set({ processed: true });
    const dry = await prepareDeletion(prep);
    assert.deepEqual(dry.blockers, []); assert.equal(dry.applied, 0); assert.ok(dry.plannedWrites >= 5);
    assert.equal((await prep.doc('publicProfiles/player').get()).data().ratingSum, 999);
    const applied = await prepareDeletion(prep, { apply: true, writersPaused: true });
    assert.equal(applied.applied, dry.plannedWrites);
    assert.deepEqual((await prep.doc('matches/past').get()).data().participantUids, ['owner','player']);
    assert.equal((await prep.doc('publicProfiles/player').get()).data().ratingSum, 4);
    assert.equal('email' in (await prep.doc('matches/past/joinRequests/player').get()).data(), false);
    assert.equal((await prep.collection('ratingContributions').get()).size, 1);
    assert.equal((await prep.collection('ratingAggregationEvents').get()).size, 0);
    assert.equal((await prepareDeletion(prep)).plannedWrites, 0);
  } finally { await deleteApp(prepApp); }
});

test('combined deletion preserves all four match outcomes and exact surviving rating aggregate', async () => {
  const uid = 'all-effects', survivor = 'surviving-player';
  await auth.createUser({ uid });
  await db.doc(`publicProfiles/${survivor}`).set({ ratingCount: 2, ratingSum: 9, ratingAverage: 4.5 });
  const { ratingIdentity } = await import('../functions/rating_contributions.js');
  for (const organized of [true, false]) for (const past of [true, false]) {
    const id = `combined-${organized}-${past}`;
    await db.doc(`matches/${id}`).set({ creatorUid: organized ? uid : survivor,
      creatorEmail: organized ? 'old@example.com' : 'survivor@example.com',
      players: [{ uid: organized ? survivor : uid, displayName: 'Player', email: 'old@example.com' }],
      participantUids: organized ? [uid, survivor] : [survivor, uid], spotsLeft: 2,
      scheduledAt: Timestamp.fromMillis(Date.now() + (past ? -86400000 : 86400000)) });
  }
  const removed = 'matches/combined-true-true/ratingRaters/all-effects/ratings/surviving-player';
  const remaining = 'matches/unrelated/ratingRaters/other/ratings/surviving-player';
  await db.doc('matches/unrelated').set({ creatorUid: 'other', players: [{ uid: survivor }],
    participantUids: ['other', survivor], spotsLeft: 2, scheduledAt: Timestamp.fromMillis(Date.now()-86400000) });
  for (const [path, score] of [[removed, 4], [remaining, 5]]) {
    const { contributionId, ...identity } = ratingIdentity(path);
    await db.doc(path).set({ ...identity, rating: score });
    await db.doc(`ratingContributions/${contributionId}`).set({ ...identity, ratingPath: path, score, schemaVersion: 1 });
  }
  await db.doc('matches/combined-true-false/joinRequests/surviving-player').set({ userId: survivor });
  await db.doc('matches/unrelated/joinRequests/all-effects').set({ userId: uid });
  await db.doc('notifications/all-effects').set({ recipientUid: survivor, actorUid: uid, matchId: 'combined-true-false' });
  await admitAccountDeletion(db, auth, request(uid)); await finish(uid);
  const readMatch = async (organized, past) => (await db.doc(`matches/combined-${organized}-${past}`).get()).data();
  assert.equal((await readMatch(true, false)).status, 'cancelled');
  assert.deepEqual((await readMatch(true, true)).organizer, { deleted: true, displayName: 'Deleted player' });
  assert.deepEqual((await readMatch(false, false)).players, []);
  assert.deepEqual((await readMatch(false, true)).players, [{ deleted: true, displayName: 'Deleted player' }]);
  assert.equal((await db.doc(removed).get()).exists, false);
  assert.equal((await db.doc(remaining).get()).exists, true);
  assert.equal((await db.doc(`publicProfiles/${survivor}`).get()).data().ratingSum, 5);
  assert.equal((await db.doc(`publicProfiles/${survivor}`).get()).data().ratingCount, 1);
  assert.equal((await db.doc('notifications/all-effects').get()).exists, false);
  assert.equal((await db.doc('matches/unrelated/joinRequests/all-effects').get()).exists, false);
  assert.equal((await ref(uid).collection('matchCleanup').get()).size, 0);
  await assert.rejects(auth.getUser(uid), { code: 'auth/user-not-found' });
});

test('fully populated schema-v2 deletion removes Phase 9 identity and preserves exact surviving aggregates', async () => {
  const uid = 'phase9-full-delete', left = 'phase9-left', right = 'phase9-right';
  await auth.createUser({ uid, email: 'delete-me@example.com', displayName: 'Delete Me' });
  for (const player of [uid, left, right]) {
    await db.doc(`users/${player}`).set({ uid: player, email: `${player}@example.com`, bio: 'private bio',
      discoveryLocation: { countryCode: 'MX', city: 'Mexico City', area: 'Centro' }, avatarVersion: 7 });
    await db.doc(`publicProfiles/${player}`).set({ uid: player, displayName: player, bio: 'public bio',
      countryCode: 'MX', city: 'Mexico City', area: 'Centro', avatarVersion: 7,
      completedMatchCount: 0, repeatPlayerCount: 0 });
  }
  const past = Timestamp.fromDate(new Date('2026-01-01T12:00:00Z'));
  for (const id of ['phase9-history-one', 'phase9-history-two']) {
    await db.doc(`matches/${id}`).set({ creatorUid: uid, players: [{ uid: left }, { uid: right }],
      participantUids: [uid, left, right], spotsLeft: 1, scheduledAt: past });
    await reconcilePlayedWithMatch(db, id, new Date('2026-02-01T00:00:00Z'));
  }
  assert.deepEqual([(await db.doc(`users/${left}/playedWith/${right}`).get()).data().completedMatchCount,
    (await db.doc(`publicProfiles/${left}`).get()).data().repeatPlayerCount], [2, 2]);

  const accepted = friendshipId(uid, left), pending = friendshipId(uid, right);
  await db.doc(`friendships/${accepted}`).set({ memberUids: [uid, left].sort(), requesterUid: uid,
    recipientUid: left, status: 'accepted' });
  await db.doc(`friendships/${pending}`).set({ memberUids: [uid, right].sort(), requesterUid: right,
    recipientUid: uid, status: 'pending' });
  await db.doc(`users/${left}/friendViews/${uid}`).set({ otherUid: uid, status: 'accepted' });
  await db.doc(`users/${right}/friendViews/${uid}`).set({ otherUid: uid, status: 'pending' });
  await db.doc(`blocks/${blockId(uid, right)}`).set({ blockerUid: uid, blockedUid: right });
  await db.doc(`blocks/${blockId(left, uid)}`).set({ blockerUid: left, blockedUid: uid });

  const directId = directConversationId(uid, left), matchId = 'phase9-history-one';
  const matchChatId = matchConversationId(matchId);
  await db.doc(`conversations/${directId}`).set({ type: 'direct', memberUids: [uid, left].sort(),
    friendshipId: accepted, lastSenderUid: uid, lastMessagePreview: 'private' });
  await db.doc(`conversations/${directId}/messages/phase9-authored-direct`).set({ senderUid: uid,
    text: 'private authored text', createdAt: past, requestId: 'phase9-authored-direct' });
  await db.doc(`conversations/${directId}/messages/phase9-received-direct`).set({ senderUid: left,
    text: 'survivor text', createdAt: past, requestId: 'phase9-received-direct' });
  await db.doc(`conversations/${matchChatId}`).set({ type: 'match', matchId,
    memberUids: [uid, left, right], lastSenderUid: uid, lastMessagePreview: 'private match text' });
  await db.doc(`conversations/${matchChatId}/messages/phase9-authored-match`).set({ senderUid: uid,
    text: 'private match text', createdAt: past, requestId: 'phase9-authored-match' });
  for (const player of [uid, left, right]) {
    await db.doc(`users/${player}/conversationViews/${matchChatId}`).set({ conversationId: matchChatId,
      otherUid: uid, lastMessageAt: past });
  }
  await db.doc(`users/${left}/conversationViews/${directId}`).set({ conversationId: directId, otherUid: uid, lastMessageAt: past });

  for (const id of ['phase9-invite-by', 'phase9-invite-to']) await db.doc(`matches/${id}`).set({
    creatorUid: id.endsWith('by') ? uid : left, players: [], participantUids: [id.endsWith('by') ? uid : left],
    spotsLeft: 3, scheduledAt: Timestamp.fromDate(new Date('2027-01-01T00:00:00Z')) });
  await db.doc(`matches/phase9-invite-by/invites/${left}`).set({ matchId: 'phase9-invite-by', inviterUid: uid, inviteeUid: left, status: 'pending' });
  await db.doc(`matches/phase9-invite-to/invites/${uid}`).set({ matchId: 'phase9-invite-to', inviterUid: left, inviteeUid: uid, status: 'pending' });
  for (const [inviteMatch, inviter, invitee] of [['phase9-invite-by', uid, left], ['phase9-invite-to', left, uid]]) {
    await db.doc(`notifications/${playAgainNotificationId(inviteMatch, invitee)}`).set({ type: 'play_again_invite',
      recipientUid: invitee, actorUid: inviter, matchId: inviteMatch, eventId: invitee });
  }
  await db.doc(`notifications/message_${directId}_${left}`).set({ type: 'direct_message', recipientUid: left,
    actorUid: uid, conversationId: directId });
  await db.doc(`notifications/message_${matchChatId}_${uid}`).set({ type: 'match_message', recipientUid: uid,
    actorUid: left, conversationId: matchChatId, matchId });
  await db.doc(`messagingRateLimits/${uid}`).set({ count: 4 });
  await db.doc(`playAgainRateLimits/${uid}`).set({ inviterUid: uid, createdAt: [past] });
  await bucket.file(`profileAvatars/${uid}/avatar.jpg`).save(Buffer.from([0xff, 0xd8, 0xff]), { contentType: 'image/jpeg' });

  await admitAccountDeletion(db, auth, request(uid)); await finish(uid);
  const job = (await ref(uid).get()).data();
  assert.equal(job.status, 'completed'); assert.equal(job.phase, 'complete');
  assert.equal((await db.doc(`accountDeletionOutbox/${uid}`).get()).data().status, 'consumed');
  assert.equal((await db.doc(`accountDeletionBarriers/${uid}`).get()).data().status, 'deleted');
  await assert.rejects(auth.getUser(uid), { code: 'auth/user-not-found' });
  assert.equal((await bucket.getFiles({ prefix: `profileAvatars/${uid}/` }))[0].length, 0);
  for (const path of [`users/${uid}`, `publicProfiles/${uid}`, `friendships/${accepted}`,
    `friendships/${pending}`, `blocks/${blockId(uid, right)}`, `blocks/${blockId(left, uid)}`,
    `conversations/${directId}`, `users/${left}/conversationViews/${directId}`,
    `messagingRateLimits/${uid}`, `playAgainRateLimits/${uid}`]) {
    assert.equal((await db.doc(path).get()).exists, false, path);
  }
  assert.equal((await db.collectionGroup('friendViews').where('otherUid', '==', uid).get()).empty, true);
  assert.equal((await db.collectionGroup('playedWith').where('otherUid', '==', uid).get()).empty, true);
  assert.equal((await db.collectionGroup('invites').where('inviterUid', '==', uid).get()).empty, true);
  assert.equal((await db.collectionGroup('invites').where('inviteeUid', '==', uid).get()).empty, true);
  const directTombstone = (await db.doc(`conversations/${directId}/messages/phase9-authored-direct`).get()).data();
  const matchTombstone = (await db.doc(`conversations/${matchChatId}/messages/phase9-authored-match`).get()).data();
  for (const message of [directTombstone, matchTombstone]) {
    assert.deepEqual(Object.keys(message).sort(), ['createdAt', 'requestId', 'senderDeleted', 'text']);
    assert.equal(message.text, 'Deleted message'); assert.equal(message.senderDeleted, true);
  }
  assert.equal((await db.doc(`conversations/${matchChatId}`).get()).data().memberUids.includes(uid), false);
  assert.deepEqual([(await db.doc(`users/${left}/playedWith/${right}`).get()).data().completedMatchCount,
    (await db.doc(`publicProfiles/${left}`).get()).data().completedMatchCount,
    (await db.doc(`publicProfiles/${left}`).get()).data().repeatPlayerCount], [2, 2, 1]);
  assert.deepEqual((await db.doc('matches/phase9-history-one').get()).data().organizer,
    { deleted: true, displayName: 'Deleted player' });
});

test('actual first-generation Auth deletion event creates the durable pipeline', async () => {
  const eventApp = initializeApp({ projectId: 'demo-padelx-phase8' }, 'auth-event');
  try {
    const eventAuth = getAuth(eventApp), eventDb = getFirestore(eventApp);
    const uid = 'actual-direct-auth-deletion';
    await eventAuth.createUser({ uid });
    await eventAuth.deleteUser(uid);
    for (let i = 0; i < 100; i++) {
      const job = await eventDb.doc(`accountDeletionJobs/${uid}`).get();
      if (job.exists) {
        assert.equal(job.data().uid, uid);
        assert.ok((await eventDb.doc(`accountDeletionBarriers/${uid}`).get()).exists);
        return;
      }
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    assert.fail('Auth deletion event did not create pipeline');
  } finally { await deleteApp(eventApp); }
});

test('eight retryable dispatch failures block without deleting Auth; future retries stay ineligible', async () => {
  const uid = 'exhausted'; await auth.createUser({ uid });
  await admitAccountDeletion(db, auth, request(uid));
  // Force an external retryable failure while retaining accepted checkpoint.
  await ref(uid).update({ authDisabledAt: null, authRevokedAt: null });
  const failingAuth = { updateUser: async () => { throw new Error('temporary failure'); } };
  for (let i = 0; i < 8; i++) {
    await db.doc(`accountDeletionOutbox/${uid}`).update({ nextAttemptAt: new Date(0) });
    await ref(uid).update({ nextAttemptAt: new Date(0) });
    await dispatchAccountDeletion(db, failingAuth, bucket, uid);
    if (i === 0) {
      const before = (await ref(uid).get()).data();
      assert.equal(await acquireDeletionLease(db, uid, { leaseOwner: 'early', leaseToken: 'early' }), false);
      assert.equal(before.status, 'retry_wait');
    }
  }
  const job = (await ref(uid).get()).data();
  assert.equal(job.status, 'blocked'); assert.equal(job.lastErrorCode, 'retry-exhausted');
  assert.equal(job.completedAt, null); assert.ok(await auth.getUser(uid));
  await recoverAccountDeletions(db, auth, bucket);
  assert.equal((await ref(uid).get()).data().status, 'blocked');
});

test('late lockdown delivery cannot revive an operator-blocked admission job', async () => {
  const uid = 'blocked-admission'; await acceptDeletedAuthUser(db, uid);
  await ref(uid).update({ status: 'blocked' });
  await lockDeletionAuth(db, { updateUser: () => assert.fail('blocked Auth effect') }, uid);
  assert.equal((await ref(uid).get()).data().status, 'blocked');
});
