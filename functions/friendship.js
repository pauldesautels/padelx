import { HttpsError } from 'firebase-functions/v2/https';
import {
  MAX_PENDING_OUTGOING_FRIEND_REQUESTS, assertNoBlock, assertNoDeletionBarrier, relationshipRefs,
  requireSocialActorAndTarget,
} from './friendship_policy.js';

const targetFrom = (request) => request?.data?.targetUid;
const nowFrom = (request) => request?.rawRequest?.relationshipNow ?? new Date();

function view(friendshipId, otherUid, status, direction, createdAt, updatedAt, acceptedAt) {
  const result = { otherUid, friendshipId, status, direction, createdAt, updatedAt };
  if (acceptedAt) result.acceptedAt = acceptedAt;
  return result;
}

function socialNotification(type, recipientUid, actorUid, now) {
  const accepted = type === 'friend_accepted';
  return { type, recipientUid, actorUid, title: accepted ? 'Friend request accepted' : 'New friend request',
    message: accepted ? 'You are now friends.' : 'You have a new friend request.',
    isRead: false, createdAt: now, updatedAt: now };
}

export async function requestFriendOperation(firestore, request) {
  const targetUid = targetFrom(request);
  const requesterUid = await requireSocialActorAndTarget(firestore, request, targetUid);
  const refs = relationshipRefs(firestore, requesterUid, targetUid);
  const now = nowFrom(request);
  return firestore.runTransaction(async (transaction) => {
    const [friendship, blockA, blockB, barrierA, barrierB] = await transaction.getAll(
      refs.friendship, refs.leftBlocksRight, refs.rightBlocksLeft, refs.leftBarrier, refs.rightBarrier,
    );
    assertNoDeletionBarrier([barrierA, barrierB]);
    assertNoBlock([blockA, blockB]);
    const existing = friendship.data();
    if (existing?.status === 'accepted') return { status: 'accepted', changed: false };
    if (existing?.status === 'pending') {
      if (existing.requesterUid === requesterUid) return { status: 'pending', changed: false };
      if (existing.recipientUid !== requesterUid) {
        throw new HttpsError('failed-precondition', 'Friend request state is invalid.');
      }
      transaction.update(refs.friendship, { status: 'accepted', updatedAt: now, acceptedAt: now });
      transaction.set(refs.leftView, view(refs.id, targetUid, 'accepted', 'mutual', existing.createdAt, now, now));
      transaction.set(refs.rightView, view(refs.id, requesterUid, 'accepted', 'mutual', existing.createdAt, now, now));
      transaction.set(firestore.doc(`notifications/friend_accepted_${refs.id}_${targetUid}`),
        socialNotification('friend_accepted', targetUid, requesterUid, now), { merge: true });
      return { status: 'accepted', changed: true };
    }
    const pending = await transaction.get(firestore.collection(`users/${requesterUid}/friendViews`)
      .where('status', '==', 'pending').where('direction', '==', 'outgoing')
      .limit(MAX_PENDING_OUTGOING_FRIEND_REQUESTS));
    if (pending.size >= MAX_PENDING_OUTGOING_FRIEND_REQUESTS) {
      throw new HttpsError('resource-exhausted', 'Too many pending friend requests.');
    }
    transaction.create(refs.friendship, {
      memberUids: [requesterUid, targetUid].sort(), requesterUid, recipientUid: targetUid,
      status: 'pending', createdAt: now, updatedAt: now,
    });
    transaction.set(refs.leftView, view(refs.id, targetUid, 'pending', 'outgoing', now, now));
    transaction.set(refs.rightView, view(refs.id, requesterUid, 'pending', 'incoming', now, now));
    transaction.set(firestore.doc(`notifications/friend_request_${refs.id}_${targetUid}`),
      socialNotification('friend_request', targetUid, requesterUid, now), { merge: true });
    return { status: 'pending', changed: true };
  });
}

export async function respondToFriendRequestOperation(firestore, request) {
  const requesterUid = targetFrom(request);
  const recipientUid = await requireSocialActorAndTarget(firestore, request, requesterUid);
  const action = request?.data?.action;
  if (!['accept', 'decline'].includes(action)) throw new HttpsError('invalid-argument', 'Accept or decline is required.');
  const refs = relationshipRefs(firestore, recipientUid, requesterUid);
  const now = nowFrom(request);
  return firestore.runTransaction(async (transaction) => {
    const [friendship, blockA, blockB, barrierA, barrierB] = await transaction.getAll(
      refs.friendship, refs.leftBlocksRight, refs.rightBlocksLeft, refs.leftBarrier, refs.rightBarrier);
    assertNoDeletionBarrier([barrierA, barrierB]);
    assertNoBlock([blockA, blockB]);
    if (!friendship.exists) return { status: action === 'accept' ? 'missing' : 'declined', changed: false };
    const data = friendship.data();
    if (data.status === 'accepted' && action === 'accept') return { status: 'accepted', changed: false };
    if (data.status !== 'pending' || data.recipientUid !== recipientUid || data.requesterUid !== requesterUid) {
      throw new HttpsError('permission-denied', 'Only the recipient can respond.');
    }
    if (action === 'decline') {
      transaction.delete(refs.friendship); transaction.delete(refs.leftView); transaction.delete(refs.rightView);
      return { status: 'declined', changed: true };
    }
    transaction.update(refs.friendship, { status: 'accepted', updatedAt: now, acceptedAt: now });
    transaction.set(refs.leftView, view(refs.id, requesterUid, 'accepted', 'mutual', data.createdAt, now, now));
    transaction.set(refs.rightView, view(refs.id, recipientUid, 'accepted', 'mutual', data.createdAt, now, now));
    transaction.set(firestore.doc(`notifications/friend_accepted_${refs.id}_${requesterUid}`),
      socialNotification('friend_accepted', requesterUid, recipientUid, now), { merge: true });
    return { status: 'accepted', changed: true };
  });
}

async function deleteFriendship(firestore, request, mode) {
  const otherUid = targetFrom(request);
  const actorUid = await requireSocialActorAndTarget(firestore, request, otherUid);
  const refs = relationshipRefs(firestore, actorUid, otherUid);
  return firestore.runTransaction(async (transaction) => {
    const [friendship, barrierA, barrierB] = await transaction.getAll(
      refs.friendship, refs.leftBarrier, refs.rightBarrier);
    assertNoDeletionBarrier([barrierA, barrierB]);
    if (!friendship.exists) return { status: mode === 'cancel' ? 'cancelled' : 'removed', changed: false };
    const data = friendship.data();
    const allowed = mode === 'cancel'
      ? data.status === 'pending' && data.requesterUid === actorUid
      : data.status === 'accepted' && data.memberUids?.includes(actorUid);
    if (!allowed) throw new HttpsError('permission-denied', mode === 'cancel'
      ? 'Only the requester can cancel.' : 'Only a friend can remove this friendship.');
    transaction.delete(refs.friendship); transaction.delete(refs.leftView); transaction.delete(refs.rightView);
    return { status: mode === 'cancel' ? 'cancelled' : 'removed', changed: true };
  });
}

export const cancelFriendRequestOperation = (firestore, request) => deleteFriendship(firestore, request, 'cancel');
export const removeFriendOperation = (firestore, request) => deleteFriendship(firestore, request, 'remove');
