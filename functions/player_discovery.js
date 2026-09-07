import { HttpsError } from 'firebase-functions/v2/https';
import { DELETION_BARRIERS, requireActiveAccount } from './account_state.js';
import { blockId } from './friendship_policy.js';

export const DISCOVERY_RESULT_LIMIT = 20;
export const DISCOVERY_SCAN_CAP = 60;
export const DISCOVERY_THROTTLE_MS = 750;
const recentRequests = new Map();

const text = (value, max = 80) => typeof value === 'string' && value.trim().length <= max
  ? value.trim() : null;
const allowedKeys = new Set(['area', 'level', 'preferredSide', 'relationship', 'cursor', 'limit']);

function payload(data) {
  const value = data ?? {};
  if (typeof value !== 'object' || Array.isArray(value)
      || Object.keys(value).some((key) => !allowedKeys.has(key))) {
    throw new HttpsError('invalid-argument', 'Invalid discovery filters.');
  }
  const area = value.area === undefined ? '' : text(value.area);
  const level = value.level === undefined ? '' : text(value.level, 30);
  const side = value.preferredSide ?? 'any';
  const relationship = value.relationship ?? 'all';
  const limit = value.limit ?? DISCOVERY_RESULT_LIMIT;
  const cursor = value.cursor ?? null;
  if (area === null || level === null || !['any', 'left', 'right', 'either'].includes(side)
      || !['all', 'friends', 'playedWith'].includes(relationship)
      || !Number.isSafeInteger(limit) || limit < 1 || limit > DISCOVERY_RESULT_LIMIT
      || (cursor !== null && (typeof cursor !== 'object' || Array.isArray(cursor)
        || text(cursor.displayName) === null || text(cursor.uid, 128) === null))) {
    throw new HttpsError('invalid-argument', 'Invalid discovery filters.');
  }
  return { area, level, side, relationship, limit, cursor };
}

const validPublic = (profile) => profile?.discoverable === true
  && typeof profile.uid === 'string' && profile.uid.length > 0
  && typeof profile.displayName === 'string' && profile.displayName.trim().length > 0
  && typeof profile.level === 'string' && profile.level.trim().length > 0
  && ['left', 'right', 'either'].includes(profile.preferredSide)
  && typeof profile.countryCode === 'string' && profile.countryCode.trim().length > 0
  && typeof profile.city === 'string' && profile.city.trim().length > 0;

function publicResult(uid, data, friend, playedWith) {
  const ratingCount = Number.isSafeInteger(data.ratingCount) && data.ratingCount >= 0 ? data.ratingCount : 0;
  const ratingAverage = Number.isFinite(data.ratingAverage) && data.ratingAverage >= 0 ? data.ratingAverage : 0;
  const completedMatchCount = Number.isSafeInteger(data.completedMatchCount) && data.completedMatchCount >= 0
    ? data.completedMatchCount : 0;
  const playedTogetherCount = Number.isSafeInteger(playedWith?.completedMatchCount)
    && playedWith.completedMatchCount > 0 ? playedWith.completedMatchCount : 0;
  return { uid, displayName: data.displayName.trim(), level: data.level.trim(), preferredSide: data.preferredSide,
    avatarVersion: Number.isSafeInteger(data.avatarVersion) && data.avatarVersion > 0 ? data.avatarVersion : 0,
    countryCode: data.countryCode.trim().toUpperCase(), city: data.city.trim(), area: text(data.area) ?? '',
    ratingCount, ratingAverage, completedMatchCount, isFriend: friend?.status === 'accepted',
    friendStatus: friend?.status === 'accepted' ? 'accepted' : friend?.status === 'pending' ? 'pending' : 'none',
    friendDirection: friend?.status === 'pending' ? friend.direction === 'incoming' ? 'incoming' : 'outgoing' : 'none',
    playedTogetherCount, canPlayAgain: friend?.status === 'accepted' || playedTogetherCount > 0 };
}

export async function discoverPlayersOperation(firestore, request, { now = Date.now(), throttle = true } = {}) {
  const viewerUid = await requireActiveAccount(firestore, request);
  const filters = payload(request?.data);
  if (throttle) {
    if (recentRequests.size > 10000) {
      for (const [uid, requestedAt] of recentRequests) if (now - requestedAt > DISCOVERY_THROTTLE_MS) recentRequests.delete(uid);
    }
    const last = recentRequests.get(viewerUid) ?? 0;
    if (now - last < DISCOVERY_THROTTLE_MS) throw new HttpsError('resource-exhausted', 'Please wait before refreshing.');
    recentRequests.set(viewerUid, now);
  }
  const [viewer, viewerProfile] = await firestore.getAll(
    firestore.doc(`users/${viewerUid}`), firestore.doc(`publicProfiles/${viewerUid}`));
  const location = viewer.data()?.discoveryLocation ?? viewerProfile.data() ?? {};
  const countryCode = text(location.countryCode, 8)?.toUpperCase() ?? '';
  const city = text(location.city) ?? '';
  if (!viewer.exists || viewer.data()?.active === false || !countryCode || !city) {
    return { players: [], cursor: null, hasMore: false, noLocation: !countryCode || !city };
  }
  let query = firestore.collection('publicProfiles').where('discoverable', '==', true)
    .where('countryCode', '==', countryCode).where('city', '==', city)
    .orderBy('displayName').orderBy('uid');
  if (filters.cursor) query = query.startAfter(filters.cursor.displayName, filters.cursor.uid);
  const page = await query.limit(DISCOVERY_SCAN_CAP + 1).get();
  const scanned = page.docs.slice(0, DISCOVERY_SCAN_CAP);
  const uids = scanned.map((doc) => doc.id).filter((uid) => uid !== viewerUid);
  const refs = uids.flatMap((uid) => [firestore.doc(`users/${uid}`), firestore.doc(`${DELETION_BARRIERS}/${uid}`),
    firestore.doc(`blocks/${blockId(viewerUid, uid)}`), firestore.doc(`blocks/${blockId(uid, viewerUid)}`),
    firestore.doc(`users/${viewerUid}/friendViews/${uid}`), firestore.doc(`users/${viewerUid}/playedWith/${uid}`)]);
  const states = refs.length ? await firestore.getAll(...refs) : [];
  const players = [];
  let consumed = 0;
  for (const doc of scanned) {
    consumed += 1;
    if (doc.id === viewerUid) continue;
    const offset = uids.indexOf(doc.id) * 6;
    const [user, barrier, mine, theirs, friend, played] = states.slice(offset, offset + 6);
    const data = doc.data();
    if (!user?.exists || user.data()?.active === false || barrier?.exists || mine?.exists || theirs?.exists
      || !validPublic(data) || data.uid !== doc.id) continue;
    if (filters.area && (text(data.area) ?? '').toLocaleLowerCase() !== filters.area.toLocaleLowerCase()) continue;
    if (filters.level && data.level !== filters.level) continue;
    if (filters.side !== 'any' && (filters.side === 'either' ? data.preferredSide !== 'either'
      : ![filters.side, 'either'].includes(data.preferredSide))) continue;
    if (filters.relationship === 'friends' && friend.data()?.status !== 'accepted') continue;
    if (filters.relationship === 'playedWith' && !(played.data()?.completedMatchCount > 0)) continue;
    players.push(publicResult(doc.id, data, friend.data(), played.data()));
    if (players.length >= filters.limit) break;
  }
  const last = scanned[consumed - 1];
  return { players, cursor: last ? { displayName: last.data().displayName, uid: last.id } : null,
    hasMore: page.docs.length > consumed, noLocation: false };
}
