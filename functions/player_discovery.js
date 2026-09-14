import { HttpsError } from 'firebase-functions/v2/https';
import { DELETION_BARRIERS, requireActiveAccount } from './account_state.js';
import { blockId } from './friendship_policy.js';
import { ACCOUNT_ENFORCEMENT, getEffectiveAccountEnforcement } from './account_enforcement.js';

export const DISCOVERY_RESULT_LIMIT = 20;
export const DISCOVERY_QUERY_WINDOW = 60;
export const DISCOVERY_SCAN_CAP = 120;
export const DISCOVERY_THROTTLE_MS = 750;
const recentRequests = new Map();

const text = (value, max = 80) => typeof value === 'string' && value.trim().length <= max
  ? value.trim() : null;
const allowedKeys = new Set(['area', 'areaId', 'level', 'preferredSide', 'relationship', 'cursor', 'limit']);

function payload(data) {
  const value = data ?? {};
  if (typeof value !== 'object' || Array.isArray(value)
      || Object.keys(value).some((key) => !allowedKeys.has(key))) {
    throw new HttpsError('invalid-argument', 'Invalid discovery filters.');
  }
  const area = value.area === undefined ? '' : text(value.area);
  const areaId = value.areaId === undefined ? '' : text(value.areaId, 256);
  const level = value.level === undefined ? '' : text(value.level, 30);
  const side = value.preferredSide ?? 'any';
  const relationship = value.relationship ?? 'all';
  const limit = value.limit ?? DISCOVERY_RESULT_LIMIT;
  const cursor = value.cursor ?? null;
  if (area === null || areaId === null || level === null || !['any', 'left', 'right', 'either'].includes(side)
      || !['all', 'friends', 'playedWith'].includes(relationship)
      || !Number.isSafeInteger(limit) || limit < 1 || limit > DISCOVERY_RESULT_LIMIT
      || (cursor !== null && (typeof cursor !== 'object' || Array.isArray(cursor)
        || text(cursor.displayName) === null || text(cursor.uid, 128) === null))) {
    throw new HttpsError('invalid-argument', 'Invalid discovery filters.');
  }
  return { area, areaId, level, side, relationship, limit, cursor };
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
  const cityId = text(location.cityId, 256) ?? '';
  if (!viewer.exists || viewer.data()?.active === false || !countryCode || (!cityId && !city)) {
    return { players: [], cursor: null, hasMore: false, noLocation: !countryCode || !city };
  }
  const baseQuery = firestore.collection('publicProfiles').where('discoverable', '==', true)
    .where('countryCode', '==', countryCode)
    .where(cityId ? 'cityId' : 'city', '==', cityId || city)
    .orderBy('displayName').orderBy('uid');
  const players = [];
  let inspected = 0;
  let continuation = filters.cursor;
  let hasMore = false;
  while (players.length < filters.limit && inspected < DISCOVERY_SCAN_CAP) {
    const windowSize = Math.min(DISCOVERY_QUERY_WINDOW, DISCOVERY_SCAN_CAP - inspected);
    let query = baseQuery;
    if (continuation) query = query.startAfter(continuation.displayName, continuation.uid);
    const page = await query.limit(windowSize + 1).get();
    const scanned = page.docs.slice(0, windowSize);
    const uids = scanned.map((doc) => doc.id).filter((uid) => uid !== viewerUid);
    const refs = uids.flatMap((uid) => [firestore.doc(`users/${uid}`), firestore.doc(`${DELETION_BARRIERS}/${uid}`),
      firestore.doc(`${ACCOUNT_ENFORCEMENT}/${uid}`),
      firestore.doc(`blocks/${blockId(viewerUid, uid)}`), firestore.doc(`blocks/${blockId(uid, viewerUid)}`),
      firestore.doc(`users/${viewerUid}/friendViews/${uid}`), firestore.doc(`users/${viewerUid}/playedWith/${uid}`)]);
    const states = refs.length ? await firestore.getAll(...refs) : [];
    const offsets = new Map(uids.map((uid, index) => [uid, index * 7]));
    let consumed = 0;
    for (const doc of scanned) {
      consumed += 1;
      inspected += 1;
      continuation = { displayName: doc.data().displayName, uid: doc.id };
      if (doc.id === viewerUid) continue;
      const offset = offsets.get(doc.id);
      const [user, barrier, enforcement, mine, theirs, friend, played] = states.slice(offset, offset + 7);
      const data = doc.data();
      if (!user?.exists || user.data()?.active === false || barrier?.exists
        || getEffectiveAccountEnforcement(enforcement?.data(), new Date(now))
        || mine?.exists || theirs?.exists
        || !validPublic(data) || data.uid !== doc.id) continue;
      if (filters.areaId && text(data.areaId, 256) !== filters.areaId) continue;
      if (!filters.areaId && filters.area
        && (text(data.area) ?? '').toLocaleLowerCase() !== filters.area.toLocaleLowerCase()) continue;
      if (filters.level && data.level !== filters.level) continue;
      if (filters.side !== 'any' && (filters.side === 'either' ? data.preferredSide !== 'either'
        : ![filters.side, 'either'].includes(data.preferredSide))) continue;
      if (filters.relationship === 'friends' && friend.data()?.status !== 'accepted') continue;
      if (filters.relationship === 'playedWith' && !(played.data()?.completedMatchCount > 0)) continue;
      players.push(publicResult(doc.id, data, friend.data(), played.data()));
      if (players.length >= filters.limit) break;
    }
    hasMore = page.docs.length > consumed;
    if (players.length >= filters.limit || !hasMore || scanned.length === 0) break;
  }
  return { players, cursor: continuation ?? null, hasMore, noLocation: false };
}
