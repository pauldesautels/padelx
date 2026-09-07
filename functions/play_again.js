import { HttpsError } from 'firebase-functions/v2/https';
import { DELETION_BARRIERS, requireActiveAccount } from './account_state.js';
import { assertSafeFirestore } from './backend_environment.js';
import { relationshipRefs, validRelationshipUid } from './friendship_policy.js';

export const MAX_PLAY_AGAIN_INVITES_PER_MATCH = 3;
export const MAX_PLAY_AGAIN_INVITES_PER_DAY = 12;
export const PLAY_AGAIN_RATE_WINDOW_MS = 24 * 60 * 60 * 1000;

const nowFrom = (request) => request?.rawRequest?.relationshipNow ?? new Date();
const text = (value) => typeof value === 'string' ? value : '';
const dateFrom = (value) => value instanceof Date ? value
  : typeof value?.toDate === 'function' ? value.toDate() : null;
const playerUid = (player) => text(player?.uid ?? player?.userId);
const organizerUid = (match) => text(match?.creatorUid || match?.createdBy || match?.organizer?.uid);
const participantUids = (match) => [organizerUid(match),
  ...(Array.isArray(match?.players) ? match.players.map(playerUid) : [])].filter(Boolean);

function requireId(value, label) {
  if (!validRelationshipUid(value)) throw new HttpsError('invalid-argument', `Valid ${label} required.`);
  return value;
}

function matchIsOpen(match, now) {
  const scheduledAt = dateFrom(match?.scheduledAt);
  return match?.status !== 'cancelled' && scheduledAt?.getTime() > now.getTime();
}

function availableSpots(match) {
  if (Number.isInteger(match?.spotsLeft)) return match.spotsLeft;
  const parsed = Number.parseInt(match?.spotsLeft, 10);
  return Number.isInteger(parsed) ? parsed : -1;
}

function invitationNotification(inviterUid, inviteeUid, matchId, club, now) {
  return {
    type: 'play_again_invite', recipientUid: inviteeUid, actorUid: inviterUid,
    matchId, matchClubName: club, title: 'Play again',
    message: club ? `You were invited to a match at ${club}.` : 'You were invited to play again.',
    isRead: false, createdAt: now, updatedAt: now, eventId: inviteeUid,
  };
}

export function playAgainNotificationId(matchId, inviteeUid) {
  return `play_again_invite_${matchId}_${inviteeUid}`;
}

export async function createPlayAgainInvitationOperation(firestore, request) {
  assertSafeFirestore(firestore);
  const inviterUid = await requireActiveAccount(firestore, request);
  const inviteeUid = requireId(request?.data?.inviteeUid, 'invitee');
  const matchId = requireId(request?.data?.matchId, 'match');
  const sourceMatchId = request?.data?.sourceMatchId == null || request.data.sourceMatchId === ''
    ? null : requireId(request.data.sourceMatchId, 'source match');
  if (inviteeUid === inviterUid) throw new HttpsError('invalid-argument', 'You cannot invite yourself.');
  const now = nowFrom(request);
  const pair = relationshipRefs(firestore, inviterUid, inviteeUid);
  const matchRef = firestore.doc(`matches/${matchId}`);
  const inviteRef = firestore.doc(`matches/${matchId}/invites/${inviteeUid}`);
  const notificationRef = firestore.doc(`notifications/${playAgainNotificationId(matchId, inviteeUid)}`);
  const rateRef = firestore.doc(`playAgainRateLimits/${inviterUid}`);
  const inviterRef = firestore.doc(`users/${inviterUid}`);
  const inviteeRef = firestore.doc(`users/${inviteeUid}`);
  const inviteeProfileRef = firestore.doc(`publicProfiles/${inviteeUid}`);
  const playedWithRef = firestore.doc(`users/${inviterUid}/playedWith/${inviteeUid}`);
  const sourceRef = sourceMatchId ? firestore.doc(`matches/${sourceMatchId}`) : null;

  return firestore.runTransaction(async (transaction) => {
    const refs = [matchRef, inviteRef, inviterRef, inviteeRef, inviteeProfileRef,
      pair.leftBarrier, pair.rightBarrier, pair.leftBlocksRight, pair.rightBlocksLeft,
      pair.friendship, playedWithRef, rateRef, ...(sourceRef ? [sourceRef] : [])];
    const snapshots = await transaction.getAll(...refs);
    const [matchSnap, inviteSnap, inviterSnap, inviteeSnap, inviteeProfile,
      inviterBarrier, inviteeBarrier, blockA, blockB, friendship, playedWith, rate, source] = snapshots;
    if (inviterBarrier.exists || inviteeBarrier.exists) {
      throw new HttpsError('permission-denied', 'Account deletion is in progress.');
    }
    if (blockA.exists || blockB.exists) {
      throw new HttpsError('failed-precondition', 'This social action is unavailable.');
    }
    if (!inviterSnap.exists || inviterSnap.data()?.active === false) {
      throw new HttpsError('failed-precondition', 'Active account required.');
    }
    if (!inviteeSnap.exists || !inviteeProfile.exists || inviteeSnap.data()?.active === false
        || inviteeProfile.data()?.deleted === true) {
      throw new HttpsError('not-found', 'Player is unavailable.');
    }
    const match = matchSnap.data();
    if (!matchSnap.exists || organizerUid(match) !== inviterUid) {
      throw new HttpsError('permission-denied', 'Only the match organizer can invite.');
    }
    if (!matchIsOpen(match, now)) throw new HttpsError('failed-precondition', 'Match is no longer open.');
    if (availableSpots(match) < 1) throw new HttpsError('failed-precondition', 'Match is full.');
    if (participantUids(match).includes(inviteeUid)) {
      throw new HttpsError('failed-precondition', 'Player already joined this match.');
    }
    const eligibleFriend = friendship.data()?.status === 'accepted'
      && friendship.data()?.memberUids?.includes(inviterUid)
      && friendship.data()?.memberUids?.includes(inviteeUid);
    const eligiblePlayedWith = playedWith.exists && playedWith.data()?.completedMatchCount > 0;
    if (!eligibleFriend && !eligiblePlayedWith) {
      throw new HttpsError('permission-denied', 'Play Again is available only for friends or prior players.');
    }
    if (sourceMatchId) {
      const sourceData = source?.data();
      const scheduledAt = dateFrom(sourceData?.scheduledAt);
      if (!source?.exists || sourceData?.status === 'cancelled' || !scheduledAt
          || scheduledAt.getTime() > now.getTime()
          || !participantUids(sourceData).includes(inviterUid)
          || !participantUids(sourceData).includes(inviteeUid)) {
        throw new HttpsError('failed-precondition', 'Source match is not a valid completed shared match.');
      }
    }
    if (inviteSnap.exists) {
      if (inviteSnap.data()?.status === 'pending') return { status: 'pending', changed: false };
      throw new HttpsError('already-exists', 'This player cannot be invited to this match again.');
    }
    const existing = await transaction.get(firestore.collection(`matches/${matchId}/invites`)
      .where('status', '==', 'pending').limit(MAX_PLAY_AGAIN_INVITES_PER_MATCH));
    if (existing.size >= MAX_PLAY_AGAIN_INVITES_PER_MATCH) {
      throw new HttpsError('resource-exhausted', 'This match already has the maximum active invitations.');
    }
    const cutoff = now.getTime() - PLAY_AGAIN_RATE_WINDOW_MS;
    const recent = (Array.isArray(rate.data()?.createdAt) ? rate.data().createdAt : [])
      .map(dateFrom).filter((date) => date && date.getTime() > cutoff);
    if (recent.length >= MAX_PLAY_AGAIN_INVITES_PER_DAY) {
      throw new HttpsError('resource-exhausted', 'Too many Play Again invitations. Try again later.');
    }
    const invite = { matchId, inviterUid, inviteeUid, source: 'play_again', status: 'pending',
      createdAt: now, updatedAt: now };
    if (sourceMatchId) invite.sourceMatchId = sourceMatchId;
    transaction.create(inviteRef, invite);
    transaction.create(notificationRef, invitationNotification(
      inviterUid, inviteeUid, matchId, text(match.clubName || match.club), now));
    transaction.set(rateRef, { inviterUid, createdAt: [...recent, now], updatedAt: now });
    return { status: 'pending', changed: true };
  });
}

export async function dismissPlayAgainInvitationOperation(firestore, request) {
  assertSafeFirestore(firestore);
  const inviteeUid = await requireActiveAccount(firestore, request);
  const matchId = requireId(request?.data?.matchId, 'match');
  const inviteRef = firestore.doc(`matches/${matchId}/invites/${inviteeUid}`);
  const notificationRef = firestore.doc(`notifications/${playAgainNotificationId(matchId, inviteeUid)}`);
  const now = nowFrom(request);
  return firestore.runTransaction(async (transaction) => {
    const invite = await transaction.get(inviteRef);
    if (!invite.exists) return { status: 'missing', changed: false };
    if (invite.data()?.inviteeUid !== inviteeUid) throw new HttpsError('permission-denied', 'Invitation unavailable.');
    if (invite.data()?.status !== 'pending') return { status: invite.data()?.status, changed: false };
    transaction.update(inviteRef, { status: 'dismissed', updatedAt: now });
    transaction.delete(notificationRef);
    return { status: 'dismissed', changed: true };
  });
}

// "joined" means confirmed membership, never merely a pending join request.
export async function reconcilePlayAgainInvitesForMatch(firestore, matchId, now = new Date()) {
  assertSafeFirestore(firestore);
  const matchRef = firestore.doc(`matches/${matchId}`);
  const match = await matchRef.get();
  if (!match.exists) return;
  const data = match.data();
  const members = new Set(participantUids(data));
  const actionable = matchIsOpen(data, now) && availableSpots(data) > 0;
  const invites = await matchRef.collection('invites').where('status', '==', 'pending')
    .limit(MAX_PLAY_AGAIN_INVITES_PER_MATCH).get();
  if (invites.empty) return;
  const batch = firestore.batch();
  for (const invite of invites.docs) {
    const inviteeUid = invite.data()?.inviteeUid || invite.id;
    if (members.has(inviteeUid)) batch.update(invite.ref, { status: 'joined', updatedAt: now });
    if (members.has(inviteeUid) || !actionable) {
      batch.delete(firestore.doc(`notifications/${playAgainNotificationId(matchId, inviteeUid)}`));
    }
  }
  await batch.commit();
}
