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
