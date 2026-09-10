import { requireActiveAccount } from './account_state.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { assertNoDeletionBarrier, relationshipRefs, requireSocialActorAndTarget, validRelationshipUid } from './friendship_policy.js';

const nowFrom = (request) => request?.rawRequest?.relationshipNow ?? new Date();

export async function blockPlayerOperation(firestore, request) {
  const blockedUid = request?.data?.targetUid;
  const blockerUid = await requireSocialActorAndTarget(firestore, request, blockedUid);
  const refs = relationshipRefs(firestore, blockerUid, blockedUid);
  const now = nowFrom(request);
  const result = await firestore.runTransaction(async (transaction) => {
    const [block, barrierA, barrierB] = await transaction.getAll(
      refs.leftBlocksRight, refs.leftBarrier, refs.rightBarrier);
    assertNoDeletionBarrier([barrierA, barrierB]);
    if (!block.exists) transaction.create(refs.leftBlocksRight, { blockerUid, blockedUid, createdAt: now });
    transaction.delete(refs.friendship); transaction.delete(refs.leftView); transaction.delete(refs.rightView);
    return { blocked: true, changed: !block.exists };
  });
  // Best-effort bounded cleanup makes old invitations non-actionable without
  // revealing block direction. Unblocking does not recreate them.
  const snapshots = await Promise.all([blockerUid, blockedUid].map((recipientUid) =>
    firestore.collection('notifications').where('recipientUid', '==', recipientUid).limit(100).get()));
  const batch = firestore.batch();
  let changed = false;
  for (const snapshot of snapshots) for (const notification of snapshot.docs) {
    const data = notification.data();
    const pairMatches = data.type === 'play_again_invite'
      && ((data.recipientUid === blockerUid && data.actorUid === blockedUid)
        || (data.recipientUid === blockedUid && data.actorUid === blockerUid));
    if (!pairMatches || typeof data.matchId !== 'string' || !data.matchId) continue;
    batch.update(firestore.doc(`matches/${data.matchId}/invites/${data.recipientUid}`),
      { status: 'dismissed', updatedAt: now });
    batch.delete(notification.ref); changed = true;
  }
  if (changed) await batch.commit();
  return result;
}

export async function unblockPlayerOperation(firestore, request) {
  const blockedUid = request?.data?.targetUid;
  const blockerUid = await requireActiveAccount(firestore, request);
  if (!validRelationshipUid(blockedUid) || blockerUid === blockedUid) {
    throw new HttpsError('invalid-argument', 'A different valid player is required.');
  }
  const refs = relationshipRefs(firestore, blockerUid, blockedUid);
  return firestore.runTransaction(async (transaction) => {
    const block = await transaction.get(refs.leftBlocksRight);
    if (block.exists) transaction.delete(refs.leftBlocksRight);
    return { blocked: false, changed: block.exists };
  });
}

export async function listBlockedPlayersOperation(firestore, request) {
  const blockerUid = await requireActiveAccount(firestore, request);
  const actor = await firestore.doc(`users/${blockerUid}`).get();
  if (!actor.exists || actor.data()?.active === false) {
    throw new HttpsError('failed-precondition', 'Active account required.');
  }
  const payload = request?.data ?? {};
  if (typeof payload !== 'object' || Array.isArray(payload)
      || Object.keys(payload).some((key) => !['cursor', 'limit'].includes(key))) {
    throw new HttpsError('invalid-argument', 'Invalid blocked-player request.');
  }
  const limit = payload.limit ?? 20;
  const cursor = payload.cursor ?? null;
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 20
      || (cursor !== null && (typeof cursor !== 'string' || !/^[a-f0-9]{64}$/.test(cursor)))) {
    throw new HttpsError('invalid-argument', 'Invalid blocked-player pagination.');
  }
  let query = firestore.collection('blocks')
    .where('blockerUid', '==', blockerUid)
    .orderBy('__name__')
    .limit(limit + 1);
  if (cursor) query = query.startAfter(cursor);
  const snapshot = await query.get();
  const documents = snapshot.docs.slice(0, limit)
    .filter((document) => document.data().blockerUid === blockerUid
      && validRelationshipUid(document.data().blockedUid));
  const profiles = documents.length
    ? await firestore.getAll(...documents.map((document) =>
      firestore.doc(`publicProfiles/${document.data().blockedUid}`)))
    : [];
  const players = documents.map((document, index) => {
    const block = document.data();
    const profile = profiles[index]?.data();
    const available = profiles[index]?.exists && profile?.deleted !== true;
    return {
      blockedUid: block.blockedUid,
      displayName: available && typeof profile.displayName === 'string' && profile.displayName.trim()
        ? profile.displayName.trim() : 'Unavailable player',
      level: available && typeof profile.level === 'string' ? profile.level.trim() : '',
      avatarVersion: available && Number.isSafeInteger(profile.avatarVersion) && profile.avatarVersion > 0
        ? profile.avatarVersion : 0,
      unavailable: !available,
      blockedAt: block.createdAt ?? null,
    };
  });
  return {
    players,
    cursor: documents.length ? documents.at(-1).id : cursor,
    hasMore: snapshot.docs.length > limit,
  };
}
