import { createHash } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';
import { DELETION_BARRIERS, requireActiveAccount } from './account_state.js';
import { assertSafeFirestore } from './backend_environment.js';

export const MAX_PENDING_OUTGOING_FRIEND_REQUESTS = 50;

export function validRelationshipUid(value) {
  return typeof value === 'string' && value.length >= 1
    && value.length <= 128 && !value.includes('/');
}

function digest(value) {
  return createHash('sha256').update(value).digest('hex');
}

export function friendshipId(left, right) {
  if (!validRelationshipUid(left) || !validRelationshipUid(right) || left === right) {
    throw new HttpsError('invalid-argument', 'A different valid player is required.');
  }
  return digest([...([left, right])].sort().join('\0'));
}

export function blockId(blockerUid, blockedUid) {
  if (!validRelationshipUid(blockerUid) || !validRelationshipUid(blockedUid)
      || blockerUid === blockedUid) {
    throw new HttpsError('invalid-argument', 'A different valid player is required.');
  }
  return digest(`${blockerUid}\0${blockedUid}`);
}

export function relationshipRefs(firestore, left, right) {
  const id = friendshipId(left, right);
  return {
    id,
    friendship: firestore.doc(`friendships/${id}`),
    leftView: firestore.doc(`users/${left}/friendViews/${right}`),
    rightView: firestore.doc(`users/${right}/friendViews/${left}`),
    leftBlocksRight: firestore.doc(`blocks/${blockId(left, right)}`),
    rightBlocksLeft: firestore.doc(`blocks/${blockId(right, left)}`),
    leftBarrier: firestore.doc(`${DELETION_BARRIERS}/${left}`),
    rightBarrier: firestore.doc(`${DELETION_BARRIERS}/${right}`),
  };
}

export async function requireSocialActorAndTarget(firestore, request, targetUid) {
  assertSafeFirestore(firestore);
  const actorUid = await requireActiveAccount(firestore, request);
  if (!validRelationshipUid(targetUid) || actorUid === targetUid) {
    throw new HttpsError('invalid-argument', 'A different valid player is required.');
  }
  const refs = [
    firestore.doc(`users/${actorUid}`), firestore.doc(`publicProfiles/${actorUid}`),
    firestore.doc(`users/${targetUid}`), firestore.doc(`publicProfiles/${targetUid}`),
    firestore.doc(`${DELETION_BARRIERS}/${targetUid}`),
  ];
  const [actor, actorProfile, target, targetProfile, targetBarrier] = await firestore.getAll(...refs);
  if (!actor.exists || !actorProfile.exists) {
    throw new HttpsError('failed-precondition', 'Complete your profile first.');
  }
  if (!target.exists || !targetProfile.exists || targetBarrier.exists) {
    throw new HttpsError('not-found', 'Player is unavailable.');
  }
  return actorUid;
}

export function assertNoBlock(blockSnapshots) {
  if (blockSnapshots.some((snapshot) => snapshot.exists)) {
    // Intentionally direction-neutral to avoid disclosing who blocked whom.
    throw new HttpsError('failed-precondition', 'This social action is unavailable.');
  }
}

export function assertNoDeletionBarrier(barrierSnapshots) {
  if (barrierSnapshots.some((snapshot) => snapshot.exists)) {
    throw new HttpsError('permission-denied', 'Account deletion is in progress.');
  }
}

export async function getRelationshipPoliciesOperation(firestore, request) {
  assertSafeFirestore(firestore);
  const viewerUid = await requireActiveAccount(firestore, request);
  const targetUids = request?.data?.targetUids;
  if (!Array.isArray(targetUids) || targetUids.length > 30
      || targetUids.some((uid) => !validRelationshipUid(uid) || uid === viewerUid)
      || new Set(targetUids).size !== targetUids.length) {
    throw new HttpsError('invalid-argument', 'Up to 30 unique players are required.');
  }
  const refs = targetUids.flatMap((targetUid) => {
    const pair = relationshipRefs(firestore, viewerUid, targetUid);
    return [pair.friendship, pair.leftBlocksRight, pair.rightBlocksLeft];
  });
  const snapshots = refs.length ? await firestore.getAll(...refs) : [];
  const policies = {};
  targetUids.forEach((targetUid, index) => {
    const friendship = snapshots[index * 3];
    const mine = snapshots[index * 3 + 1];
    const theirs = snapshots[index * 3 + 2];
    const blocked = mine.exists || theirs.exists;
    const data = friendship.data();
    let direction = 'none';
    if (!blocked && data?.status === 'accepted') direction = 'mutual';
    else if (!blocked && data?.status === 'pending') {
      direction = data.requesterUid === viewerUid ? 'outgoing' : 'incoming';
    }
    policies[targetUid] = {
      interactionAllowed: !blocked,
      blockedByViewer: mine.exists,
      status: blocked ? 'none' : data?.status ?? 'none',
      direction,
    };
  });
  return { policies };
}
