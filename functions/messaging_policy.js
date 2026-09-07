import { createHash } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';
import { blockId, friendshipId, validRelationshipUid } from './friendship_policy.js';

export const MESSAGE_MAX_LENGTH = 1000;
export const MESSAGE_PREVIEW_LENGTH = 140;
export const MESSAGE_PAGE_MAX = 50;
export const CONVERSATION_PAGE_MAX = 20;
export const MATCH_CHAT_GRACE_MS = 24 * 60 * 60 * 1000;
export const SEND_WINDOW_MS = 60 * 1000;
export const SEND_WINDOW_MAX = 20;

const digest = (value) => createHash('sha256').update(value).digest('hex');

export function directConversationId(left, right) {
  if (!validRelationshipUid(left) || !validRelationshipUid(right) || left === right) {
    throw new HttpsError('invalid-argument', 'A different valid player is required.');
  }
  return `direct_${digest([...([left, right])].sort().join('\0'))}`;
}

export function matchConversationId(matchId) {
  if (typeof matchId !== 'string' || !matchId || matchId.length > 128 || matchId.includes('/')) {
    throw new HttpsError('invalid-argument', 'A valid match is required.');
  }
  return `match_${digest(matchId)}`;
}

export function normalizeMessageText(value) {
  if (typeof value !== 'string') throw new HttpsError('invalid-argument', 'Message text is required.');
  const text = value.trim();
  if (!text) throw new HttpsError('invalid-argument', 'Message cannot be empty.');
  if ([...text].length > MESSAGE_MAX_LENGTH) {
    throw new HttpsError('invalid-argument', `Messages can be at most ${MESSAGE_MAX_LENGTH} characters.`);
  }
  return text;
}

export function validRequestId(value) {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{16,128}$/.test(value);
}

export function matchMemberUids(data) {
  const organizer = typeof data?.creatorUid === 'string' && data.creatorUid
    ? data.creatorUid : data?.createdBy;
  const players = Array.isArray(data?.players) ? data.players : [];
  return [...new Set([organizer, ...players.map((p) => p?.uid ?? p?.userId)]
    .filter((uid) => validRelationshipUid(uid)))].slice(0, 4);
}

export function matchSendState(data, uid, now = new Date()) {
  if (!matchMemberUids(data).includes(uid)) return { canRead: false, canSend: false, reason: 'unavailable' };
  if (data?.status === 'cancelled') return { canRead: true, canSend: false, reason: 'cancelled' };
  const scheduledAt = data?.scheduledAt?.toDate?.() ?? data?.scheduledAt;
  const scheduledMs = scheduledAt instanceof Date ? scheduledAt.getTime() : Number.NaN;
  if (Number.isFinite(scheduledMs) && now.getTime() > scheduledMs + MATCH_CHAT_GRACE_MS) {
    return { canRead: true, canSend: false, reason: 'completed' };
  }
  return { canRead: true, canSend: true, reason: null };
}

export function messagingRefs(firestore, left, right) {
  return {
    friendship: firestore.doc(`friendships/${friendshipId(left, right)}`),
    leftBlocksRight: firestore.doc(`blocks/${blockId(left, right)}`),
    rightBlocksLeft: firestore.doc(`blocks/${blockId(right, left)}`),
  };
}
