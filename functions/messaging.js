import { HttpsError } from 'firebase-functions/v2/https';
import { DELETION_BARRIERS, requireActiveAccount } from './account_state.js';
import { assertSafeFirestore } from './backend_environment.js';
import { validRelationshipUid } from './friendship_policy.js';
import {
  CONVERSATION_PAGE_MAX, MESSAGE_PAGE_MAX, MESSAGE_PREVIEW_LENGTH,
  SEND_WINDOW_MAX, SEND_WINDOW_MS, directConversationId, matchConversationId,
  matchMemberUids, matchSendState, messagingRefs, normalizeMessageText, validRequestId,
} from './messaging_policy.js';

const nowFrom = (request) => request?.rawRequest?.messagingNow ?? new Date();
const timestampDate = (value) => value?.toDate?.() ?? value;
const cursorDate = (value) => {
  if (value == null) return null;
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) throw new HttpsError('invalid-argument', 'Invalid cursor.');
  return date;
};
const boundedLimit = (value, fallback, maximum) =>
  Number.isInteger(value) && value > 0 ? Math.min(value, maximum) : fallback;

export async function requireMessagingActor(firestore, request) {
  assertSafeFirestore(firestore);
  const uid = await requireActiveAccount(firestore, request);
  const [user, profile] = await firestore.getAll(
    firestore.doc(`users/${uid}`), firestore.doc(`publicProfiles/${uid}`));
  if (!user.exists || !profile.exists) throw new HttpsError('failed-precondition', 'Complete your profile first.');
  return uid;
}

async function directPolicy(firestore, left, right) {
  const refs = messagingRefs(firestore, left, right);
  const [friendship, blockA, blockB, barrierA, barrierB, userA, userB] = await firestore.getAll(
    refs.friendship, refs.leftBlocksRight, refs.rightBlocksLeft,
    firestore.doc(`${DELETION_BARRIERS}/${left}`), firestore.doc(`${DELETION_BARRIERS}/${right}`),
    firestore.doc(`users/${left}`), firestore.doc(`users/${right}`));
  const blocked = blockA.exists || blockB.exists;
  const active = !barrierA.exists && !barrierB.exists && userA.exists && userB.exists;
  return { blocked, active, accepted: friendship.data()?.status === 'accepted' };
}

function viewData(conversation, uid, overrides = {}) {
  const otherUid = conversation.type === 'direct'
    ? conversation.memberUids.find((member) => member !== uid) : null;
  return {
    conversationId: conversation.id, type: conversation.type,
    ...(otherUid ? { otherUid } : {}), ...(conversation.matchId ? { matchId: conversation.matchId } : {}),
    lastMessageAt: conversation.lastMessageAt ?? conversation.createdAt,
    lastMessagePreview: conversation.lastMessagePreview ?? '', unreadCount: 0,
    updatedAt: conversation.updatedAt, ...overrides,
  };
}

export async function ensureDirectConversationOperation(firestore, request) {
  const otherUid = request?.data?.otherUid;
  const uid = await requireMessagingActor(firestore, request);
  if (!validRelationshipUid(otherUid) || otherUid === uid) throw new HttpsError('invalid-argument', 'A different valid player is required.');
  const policy = await directPolicy(firestore, uid, otherUid);
  if (!policy.active || !policy.accepted || policy.blocked) {
    throw new HttpsError('failed-precondition', 'Messaging is unavailable.');
  }
  const id = directConversationId(uid, otherUid);
  const members = [uid, otherUid].sort();
  const now = nowFrom(request);
  await firestore.runTransaction(async (tx) => {
    const ref = firestore.doc(`conversations/${id}`);
    const refs = messagingRefs(firestore, uid, otherUid);
    const [snap, friendship, blockA, blockB, barrierA, barrierB, userA, userB] = await Promise.all([
      tx.get(ref), tx.get(refs.friendship), tx.get(refs.leftBlocksRight), tx.get(refs.rightBlocksLeft),
      tx.get(firestore.doc(`${DELETION_BARRIERS}/${uid}`)),
      tx.get(firestore.doc(`${DELETION_BARRIERS}/${otherUid}`)),
      tx.get(firestore.doc(`users/${uid}`)), tx.get(firestore.doc(`users/${otherUid}`)),
    ]);
    if (friendship.data()?.status !== 'accepted' || blockA.exists || blockB.exists
        || barrierA.exists || barrierB.exists || !userA.exists || !userB.exists) {
      throw new HttpsError('failed-precondition', 'Messaging is unavailable.');
    }
    if (!snap.exists) tx.create(ref, {
      type: 'direct', memberUids: members, friendshipId: id.slice(7), createdAt: now,
      updatedAt: now, lastMessageAt: null, lastMessagePreview: '', lastSenderUid: null, schemaVersion: 1,
    });
    const conversation = { id, ...(snap.data() ?? { type: 'direct', memberUids: members, createdAt: now, updatedAt: now }) };
    for (const member of members) tx.set(firestore.doc(`users/${member}/conversationViews/${id}`), viewData(conversation, member), { merge: true });
  });
  return { conversationId: id };
}

export async function ensureMatchConversationOperation(firestore, request) {
  const matchId = request?.data?.matchId;
  const uid = await requireMessagingActor(firestore, request);
  const id = matchConversationId(matchId);
  const match = await firestore.doc(`matches/${matchId}`).get();
  if (!match.exists) throw new HttpsError('not-found', 'Match is unavailable.');
  const state = matchSendState(match.data(), uid, nowFrom(request));
  if (!state.canRead) throw new HttpsError('permission-denied', 'Match chat is unavailable.');
  const members = matchMemberUids(match.data());
  const now = nowFrom(request);
  await firestore.runTransaction(async (tx) => {
    const ref = firestore.doc(`conversations/${id}`);
    const [snap, currentMatch, ...barriers] = await Promise.all([tx.get(ref), tx.get(firestore.doc(`matches/${matchId}`)),
      ...members.map((member) => tx.get(firestore.doc(`${DELETION_BARRIERS}/${member}`)))]);
    if (!currentMatch.exists || !matchSendState(currentMatch.data(), uid, now).canRead) {
      throw new HttpsError('permission-denied', 'Match chat is unavailable.');
    }
    if (barriers.some((barrier) => barrier.exists)) {
      throw new HttpsError('failed-precondition', 'Messaging is unavailable.');
    }
    if (!snap.exists) tx.create(ref, {
      type: 'match', matchId, memberUids: members, createdAt: now, updatedAt: now,
      lastMessageAt: null, lastMessagePreview: '', lastSenderUid: null, schemaVersion: 1,
    });
    else if (JSON.stringify(snap.data().memberUids) !== JSON.stringify(members)) {
      tx.update(ref, { memberUids: members, updatedAt: now });
    }
    const conversation = { id, ...(snap.data() ?? { type: 'match', matchId, createdAt: now, updatedAt: now }), memberUids: members };
    for (const member of members) tx.set(firestore.doc(`users/${member}/conversationViews/${id}`), viewData(conversation, member), { merge: true });
  });
  return { conversationId: id, canSend: state.canSend, disabledReason: state.reason };
}

export async function conversationAccess(firestore, uid, conversation, now, { sending = false } = {}) {
  if (!conversation?.memberUids?.includes(uid)) return { allowed: false };
  if (conversation.type === 'direct') {
    const other = conversation.memberUids.find((member) => member !== uid);
    const policy = await directPolicy(firestore, uid, other);
    return { allowed: policy.active && !policy.blocked && (!sending || policy.accepted), canSend: policy.active && !policy.blocked && policy.accepted,
      reason: policy.accepted ? null : 'You are no longer friends.' };
  }
  const match = await firestore.doc(`matches/${conversation.matchId}`).get();
  if (!match.exists) return { allowed: !sending, canSend: false, reason: 'This match was cancelled.' };
  const state = matchSendState(match.data(), uid, now);
  return { allowed: state.canRead && (!sending || state.canSend), canSend: state.canSend, reason: state.reason };
}

export async function sendMessageOperation(firestore, request) {
  const uid = await requireMessagingActor(firestore, request);
  const conversationId = request?.data?.conversationId;
  const requestId = request?.data?.requestId;
  const text = normalizeMessageText(request?.data?.text);
  if (typeof conversationId !== 'string' || !/^(direct|match)_[a-f0-9]{64}$/.test(conversationId) || !validRequestId(requestId)) {
    throw new HttpsError('invalid-argument', 'Valid conversation and request IDs are required.');
  }
  const ref = firestore.doc(`conversations/${conversationId}`);
  const snapshot = await ref.get();
  if (!snapshot.exists) throw new HttpsError('not-found', 'Conversation is unavailable.');
  const conversation = snapshot.data();
  const now = nowFrom(request);
  const access = await conversationAccess(firestore, uid, conversation, now, { sending: true });
  if (!access.allowed) throw new HttpsError('failed-precondition', 'Messaging is unavailable.');
  const messageRef = ref.collection('messages').doc(requestId);
  const senderRateRef = firestore.doc(`messagingRateLimits/${uid}`);
  await firestore.runTransaction(async (tx) => {
    const initial = await Promise.all([tx.get(ref), tx.get(messageRef), tx.get(senderRateRef)]);
    const [current, existing, rate] = initial;
    if (existing.exists) return;
    if (!current.exists || !current.data().memberUids?.includes(uid)) throw new HttpsError('permission-denied', 'Conversation is unavailable.');
    if (current.data().type === 'direct') {
      const other = current.data().memberUids.find((member) => member !== uid);
      const refs = messagingRefs(firestore, uid, other);
      const [friendship, blockA, blockB, barrierA, barrierB, userA, userB] = await Promise.all([
        tx.get(refs.friendship), tx.get(refs.leftBlocksRight), tx.get(refs.rightBlocksLeft),
        tx.get(firestore.doc(`${DELETION_BARRIERS}/${uid}`)), tx.get(firestore.doc(`${DELETION_BARRIERS}/${other}`)),
        tx.get(firestore.doc(`users/${uid}`)), tx.get(firestore.doc(`users/${other}`)),
      ]);
      if (friendship.data()?.status !== 'accepted' || blockA.exists || blockB.exists
          || barrierA.exists || barrierB.exists || !userA.exists || !userB.exists) {
        throw new HttpsError('failed-precondition', 'Messaging is unavailable.');
      }
    } else {
      const [match, ...barriers] = await Promise.all([
        tx.get(firestore.doc(`matches/${current.data().matchId}`)),
        ...current.data().memberUids.map((member) => tx.get(firestore.doc(`${DELETION_BARRIERS}/${member}`))),
      ]);
      if (!match.exists || !matchSendState(match.data(), uid, now).canSend) {
        throw new HttpsError('failed-precondition', 'Match chat is read-only.');
      }
      if (barriers.some((barrier) => barrier.exists)) {
        throw new HttpsError('failed-precondition', 'Messaging is unavailable.');
      }
    }
    const memberViews = await Promise.all(current.data().memberUids.map((member) =>
      tx.get(firestore.doc(`users/${member}/conversationViews/${conversationId}`))));
    const rateData = rate.data();
    const windowStart = timestampDate(rateData?.windowStartedAt);
    const inWindow = windowStart instanceof Date && now - windowStart < SEND_WINDOW_MS;
    const count = inWindow ? (rateData?.count ?? 0) : 0;
    if (count >= SEND_WINDOW_MAX) throw new HttpsError('resource-exhausted', 'Please wait before sending more messages.');
    tx.set(senderRateRef, { windowStartedAt: inWindow ? windowStart : now, count: count + 1, updatedAt: now });
    tx.create(messageRef, { senderUid: uid, text, createdAt: now, requestId });
    tx.update(ref, { updatedAt: now, lastMessageAt: now, lastMessagePreview: [...text].slice(0, MESSAGE_PREVIEW_LENGTH).join(''), lastSenderUid: uid });
    for (const [index, member] of current.data().memberUids.entries()) {
      const viewRef = firestore.doc(`users/${member}/conversationViews/${conversationId}`);
      tx.set(viewRef, viewData({ id: conversationId, ...current.data(), updatedAt: now, lastMessageAt: now,
        lastMessagePreview: [...text].slice(0, MESSAGE_PREVIEW_LENGTH).join('') }, member,
      member === uid ? { unreadCount: 0 } : { unreadCount: (memberViews[index].data()?.unreadCount ?? 0) + 1 }), { merge: true });
      if (member !== uid) tx.set(firestore.doc(`notifications/message_${conversationId}_${member}`), {
        type: current.data().type === 'direct' ? 'direct_message' : 'match_message', recipientUid: member,
        actorUid: uid, conversationId, ...(current.data().matchId ? { matchId: current.data().matchId } : {}),
        title: current.data().type === 'direct' ? 'New message' : 'New match message', message: 'You have unread messages.',
        isRead: false, createdAt: now, updatedAt: now,
      }, { merge: true });
    }
  });
  return { conversationId, messageId: requestId };
}

export async function listMessagesOperation(firestore, request) {
  const uid = await requireMessagingActor(firestore, request);
  const conversationId = request?.data?.conversationId;
  const ref = firestore.doc(`conversations/${conversationId}`);
  const snapshot = await ref.get();
  if (!snapshot.exists) throw new HttpsError('not-found', 'Conversation is unavailable.');
  const access = await conversationAccess(firestore, uid, snapshot.data(), nowFrom(request));
  if (!access.allowed) throw new HttpsError('permission-denied', 'Conversation is unavailable.');
  const limit = boundedLimit(request?.data?.limit, 40, MESSAGE_PAGE_MAX);
  const cursor = cursorDate(request?.data?.before);
  let query = ref.collection('messages').orderBy('createdAt', 'desc').limit(limit + 1);
  if (cursor) query = query.startAfter(cursor);
  const result = await query.get();
  const docs = result.docs.slice(0, limit);
  return { messages: docs.map((doc) => ({ id: doc.id, ...doc.data() })), hasMore: result.size > limit,
    nextCursor: docs.length ? timestampDate(docs.at(-1).data().createdAt)?.toISOString?.() : null,
    canSend: access.canSend, disabledReason: access.reason ?? null };
}

export async function listConversationsOperation(firestore, request) {
  const uid = await requireMessagingActor(firestore, request);
  const limit = boundedLimit(request?.data?.limit, 20, CONVERSATION_PAGE_MAX);
  const cursor = cursorDate(request?.data?.before);
  let query = firestore.collection(`users/${uid}/conversationViews`).orderBy('lastMessageAt', 'desc').limit(limit * 3 + 1);
  if (cursor) query = query.startAfter(cursor);
  const result = await query.get();
  const conversations = [];
  for (const view of result.docs) {
    if (conversations.length >= limit) break;
    const canonical = await firestore.doc(`conversations/${view.id}`).get();
    if (!canonical.exists) continue;
    const access = await conversationAccess(firestore, uid, canonical.data(), nowFrom(request));
    if (access.allowed) conversations.push({ id: view.id, ...view.data(), canSend: access.canSend, disabledReason: access.reason ?? null });
  }
  return { conversations, hasMore: result.size > limit * 3,
    nextCursor: conversations.length ? timestampDate(conversations.at(-1).lastMessageAt)?.toISOString?.() : null };
}

export async function markConversationReadOperation(firestore, request) {
  const uid = await requireMessagingActor(firestore, request);
  const conversationId = request?.data?.conversationId;
  const ref = firestore.doc(`conversations/${conversationId}`);
  const conversation = await ref.get();
  if (!conversation.exists || !(await conversationAccess(firestore, uid, conversation.data(), nowFrom(request))).allowed) {
    throw new HttpsError('permission-denied', 'Conversation is unavailable.');
  }
  const now = nowFrom(request);
  await firestore.runTransaction(async (tx) => {
    const notificationRef = firestore.doc(`notifications/message_${conversationId}_${uid}`);
    const notification = await tx.get(notificationRef);
    tx.set(firestore.doc(`users/${uid}/conversationViews/${conversationId}`), { unreadCount: 0, lastReadAt: now, updatedAt: now }, { merge: true });
    if (notification.exists) tx.update(notificationRef, { isRead: true, updatedAt: now });
  });
  return { conversationId };
}
