import { createHash } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';
import { requireActiveAccount } from './account_state.js';
import { ACCOUNT_ELIGIBILITY, validEligibility } from './eligibility.js';
import { COMMUNITY_VERSION, LEGAL_ACCEPTANCE, LEGAL_SCHEMA_VERSION,
  PRIVACY_VERSION, TERMS_VERSION } from './legal_acceptance.js';
import { ACCOUNT_ENFORCEMENT, getEffectiveAccountEnforcement } from './account_enforcement.js';
import { DELETION_BARRIERS } from './account_state.js';
import { blockId, validRelationshipUid } from './friendship_policy.js';
import { validRequestId } from './messaging_policy.js';
import { MATCHMAKING_CANDIDATE_LIMIT, MATCHMAKING_REQUEST_TTL_MS,
  MATCHMAKING_SCAN_WINDOWS_PER_INVOCATION,
  MATCHMAKING_SCHEMA_VERSION, PARTNER_INVITATION_TTL_MS,
  REQUEST_MODES, TRAVEL_RADIUS_OPTIONS_KM,
  assignTeams, cancellationTimingCategory, canonicalCityKey, compatibilityScore,
  confirmationWindowMs, hardCompatibility,
  normalizeAvailability,
  overlappingAvailability, parseLevel, asDate } from './matchmaking_policy.js';
import { haversineKm, VENUE_TYPES } from './matchmaking_policy.js';
import { rankByReliability, reliabilityPriority } from './reliability.js';

export const MATCHMAKING_REQUESTS = 'matchmakingRequests';
export const MATCHMAKING_PROPOSALS = 'matchProposals';
export const RELIABILITY_EVENTS = 'reliabilityEvents';
export const MATCHMAKING_ACTIVE_OWNERS = 'matchmakingActiveOwners';
export const MATCH_PRIVATE_VENUES = 'matchPrivateVenues';

const text = (value, maximum = 256) => typeof value === 'string'
  && value.trim().length > 0 && value.trim().length <= maximum ? value.trim() : null;
const nowFrom = (request) => request?.rawRequest?.matchmakingNow ?? new Date();
const digest = (value) => createHash('sha256').update(value).digest('hex');
const requestRef = (firestore, id) => firestore.doc(`${MATCHMAKING_REQUESTS}/${id}`);
const proposalRef = (firestore, id) => firestore.doc(`${MATCHMAKING_PROPOSALS}/${id}`);
const requestView = (firestore, uid, id) => firestore.doc(`users/${uid}/matchmakingRequestViews/${id}`);
const proposalView = (firestore, uid, id) => firestore.doc(`users/${uid}/matchProposalViews/${id}`);
const notificationRef = (firestore, type, subjectId, uid) =>
  firestore.doc(`notifications/${type}_${digest(`${subjectId}\0${uid}`)}`);
const notificationData = ({ type, uid, eventId, matchId = '', title, message, now }) => ({
  type, recipientUid: uid, matchId, matchClubName: '', title, message,
  isRead: false, createdAt: now, eventId,
});

function participantSummaries(proposal, confirmations = proposal.confirmations) {
  const profiles = proposal.memberProfiles ?? proposal.offeredProfiles ?? {};
  return proposal.memberUids.map((memberUid) => ({
    displayName: profiles[memberUid]?.displayName ?? '',
    level: profiles[memberUid]?.level ?? '',
    preferredSide: profiles[memberUid]?.preferredSide ?? 'either',
    team: proposal.teamAssignments?.[memberUid] ?? null,
    confirmation: confirmations[memberUid] ?? 'waiting',
  }));
}

function validLegal(data, uid) {
  return data?.uid === uid && data.schemaVersion === LEGAL_SCHEMA_VERSION
    && data.termsVersion === TERMS_VERSION && data.privacyVersion === PRIVACY_VERSION
    && data.communityVersion === COMMUNITY_VERSION && data.acceptedAt?.toDate instanceof Function;
}

async function requireReadyMembers(firestore, memberUids, now) {
  const refs = memberUids.flatMap((uid) => [
    firestore.doc(`users/${uid}`), firestore.doc(`publicProfiles/${uid}`),
    firestore.doc(`${ACCOUNT_ELIGIBILITY}/${uid}`), firestore.doc(`${LEGAL_ACCEPTANCE}/${uid}`),
    firestore.doc(`${DELETION_BARRIERS}/${uid}`), firestore.doc(`${ACCOUNT_ENFORCEMENT}/${uid}`),
  ]);
  const snapshots = refs.length ? await firestore.getAll(...refs) : [];
  const profiles = new Map();
  for (let index = 0; index < memberUids.length; index++) {
    const uid = memberUids[index];
    const [user, profile, eligibility, legal, barrier, enforcement] = snapshots.slice(index * 6, index * 6 + 6);
    if (!user.exists || user.data()?.active === false || !profile.exists
        || !validEligibility(eligibility.data(), uid) || !validLegal(legal.data(), uid)
        || barrier.exists || getEffectiveAccountEnforcement(enforcement.data(), now)) {
      throw new HttpsError('failed-precondition', 'Every player must be eligible and ready.');
    }
    profiles.set(uid, profile.data());
  }
  return profiles;
}

function parseCreatePayload(data, ownerUid, profile, now) {
  if (!data || typeof data !== 'object' || Array.isArray(data)
      || Object.keys(data).some((key) => ![
        'requestId', 'mode', 'partnerUid', 'availability', 'timezone', 'travelRadiusKm',
        'preferredSide', 'sourceMatchId', 'autoFillAfterCancellation',
      ].includes(key)) || !validRequestId(data.requestId) || !REQUEST_MODES.includes(data.mode)) {
    throw new HttpsError('invalid-argument', 'Invalid matchmaking request.');
  }
  const partnerUid = data.mode === 'partner' ? text(data.partnerUid, 128) : null;
  const sourceMatchId = data.mode === 'autofill' ? text(data.sourceMatchId, 128) : null;
  if ((data.mode === 'partner' && (!validRelationshipUid(partnerUid) || partnerUid === ownerUid))
      || (data.mode === 'autofill' && !sourceMatchId)
      || (data.mode !== 'partner' && data.partnerUid !== undefined)
      || (data.mode !== 'autofill' && data.sourceMatchId !== undefined)) {
    throw new HttpsError('invalid-argument', 'Invalid matchmaking mode details.');
  }
  const timezone = text(data.timezone, 64);
  try { if (!timezone) throw new Error(); new Intl.DateTimeFormat('en', { timeZone: timezone }); }
  catch { throw new HttpsError('invalid-argument', 'A valid timezone is required.'); }
  const travelRadiusKm = data.travelRadiusKm;
  if (!TRAVEL_RADIUS_OPTIONS_KM.includes(travelRadiusKm)) {
    throw new HttpsError('invalid-argument', 'Invalid travel radius.');
  }
  const preferredSide = data.preferredSide ?? profile.preferredSide;
  if (!['left', 'right', 'either'].includes(preferredSide)) {
    throw new HttpsError('invalid-argument', 'Invalid preferred side.');
  }
  const privateLocation = profile.discoveryLocation;
  const publicLocation = profile;
  const location = privateLocation && typeof privateLocation === 'object' ? privateLocation : publicLocation;
  const cityKey = canonicalCityKey(location);
  if (!cityKey || !Number.isFinite(location.latitude) || !Number.isFinite(location.longitude)) {
    throw new HttpsError('failed-precondition', 'A canonical discovery location is required.');
  }
  if (parseLevel(profile.level) === null) throw new HttpsError('failed-precondition', 'A valid level is required.');
  return { partnerUid, sourceMatchId, timezone, travelRadiusKm, preferredSide,
    availability: normalizeAvailability(data.availability, now), cityKey,
    location: { countryCode: location.countryCode.trim().toUpperCase(), cityId: location.cityId.trim(),
      city: location.city.trim(), areaId: text(location.areaId) ?? '', area: text(location.area, 100) ?? '',
      latitude: location.latitude, longitude: location.longitude }, level: profile.level.trim(),
    autoFillAfterCancellation: data.autoFillAfterCancellation === true };
}

function requestPublicView(data, viewerUid) {
  return { schemaVersion: data.schemaVersion, requestId: data.requestId, mode: data.mode,
    status: data.status, role: viewerUid === data.ownerUid ? 'owner'
      : viewerUid === data.partnerUid ? 'partner' : 'member',
    inviterDisplayName: viewerUid === data.partnerUid ? data.ownerDisplayName ?? '' : '',
    sourceMatchId: data.sourceMatchId ?? null, availability: data.availability,
    timezone: data.timezone, travelRadiusKm: data.travelRadiusKm,
    preferredSide: data.preferredSide, city: data.location.city, area: data.location.area,
    createdAt: data.createdAt, updatedAt: data.updatedAt, expiresAt: data.expiresAt };
}

async function assertNoBlocks(firestore, memberUids) {
  const refs = [];
  for (let left = 0; left < memberUids.length; left++) for (let right = left + 1; right < memberUids.length; right++) {
    refs.push(firestore.doc(`blocks/${blockId(memberUids[left], memberUids[right])}`));
    refs.push(firestore.doc(`blocks/${blockId(memberUids[right], memberUids[left])}`));
  }
  const blocks = refs.length ? await firestore.getAll(...refs) : [];
  if (blocks.some((snapshot) => snapshot.exists)) {
    throw new HttpsError('failed-precondition', 'Matchmaking is unavailable for this group.');
  }
}

async function canonicalAutoFillLocation(firestore, sourceMatchId, sourceMatch) {
  const location = sourceMatch?.location;
  if (!location || !text(location.countryCode, 8)) return null;
  let resolved = location;
  if (!canonicalCityKey(resolved)) {
    if (sourceMatch?.source !== 'matchmaking' || !text(sourceMatch.matchmakingProposalId, 128)) return null;
    const proposal = await proposalRef(firestore, sourceMatch.matchmakingProposalId).get();
    const sourceIds = proposal.data()?.sourceRequestIds;
    if (!proposal.exists || !Array.isArray(sourceIds) || sourceIds.length < 1 || sourceIds.length > 4) return null;
    const sources = await firestore.getAll(...sourceIds.map((id) => requestRef(firestore, id)));
    if (sources.some((source) => !source.exists)) return null;
    const cityKeys = [...new Set(sources.map((source) => source.data()?.cityKey))];
    const canonical = sources[0].data()?.location;
    if (cityKeys.length !== 1 || !canonicalCityKey(canonical)
        || canonical.countryCode.trim().toUpperCase() !== location.countryCode.trim().toUpperCase()) return null;
    resolved = { ...location, cityId: canonical.cityId };
  }
  if ((!Number.isFinite(resolved.latitude) || !Number.isFinite(resolved.longitude))
      && sourceMatch.venueType === 'private_free') {
    const protectedVenue = await firestore.doc(`${MATCH_PRIVATE_VENUES}/${sourceMatchId}`).get();
    const exact = protectedVenue.data();
    if (!protectedVenue.exists || !Number.isFinite(exact?.latitude)
        || !Number.isFinite(exact?.longitude)) return null;
    resolved = { ...resolved, latitude: exact.latitude, longitude: exact.longitude };
  }
  return resolved;
}

async function conflictingCommitment(firestore, uid, overlap) {
  const query = await firestore.collection('matches').where('participantUids', 'array-contains', uid)
    .where('scheduledAt', '>=', new Date(overlap.earliestStart.getTime() - 150 * 60 * 1000))
    .where('scheduledAt', '<=', new Date(overlap.latestStart.getTime() + 150 * 60 * 1000)).limit(1).get();
  return !query.empty;
}

async function createProposal(firestore, requests, now) {
  const memberUids = requests.flatMap((item) => item.memberUids);
  if (new Set(memberUids).size !== memberUids.length || memberUids.length !== 4) return null;
  const overlap = overlappingAvailability(requests);
  if (!overlap) return null;
  for (const left of requests) for (const right of requests) {
    if (left.requestId !== right.requestId && !hardCompatibility(left, right).compatible) return null;
  }
  const profiles = await requireReadyMembers(firestore, memberUids, now);
  await assertNoBlocks(firestore, memberUids);
  for (const uid of memberUids) if (await conflictingCommitment(firestore, uid, overlap)) return null;
  const proposalId = digest(requests.map((item) => item.requestId).sort().join('\0'));
  const reference = proposalRef(firestore, proposalId);
  const expiresAt = new Date(now.getTime() + confirmationWindowMs(overlap.earliestStart, now));
  const teamAssignments = assignTeams(requests, profiles);
  if (!teamAssignments) return null;
  const proposal = { schemaVersion: MATCHMAKING_SCHEMA_VERSION, proposalId, status: 'confirming',
    memberUids, sourceRequestIds: requests.map((item) => item.requestId),
    coordinatorUid: [...requests].sort((a, b) => asDate(a.createdAt) - asDate(b.createdAt))[0].ownerUid,
    memberProfiles: Object.fromEntries(memberUids.map((uid) => [uid, {
      displayName: profiles.get(uid)?.displayName ?? '', level: profiles.get(uid)?.level ?? '',
      preferredSide: profiles.get(uid)?.preferredSide ?? 'either',
    }])),
    teamAssignments,
    confirmations: Object.fromEntries(memberUids.map((uid) => [uid, 'offered'])),
    availability: overlap, scheduledAt: overlap.earliestStart, timezone: requests[0].timezone,
    location: { countryCode: requests[0].location.countryCode, cityId: requests[0].location.cityId,
      city: requests[0].location.city, area: requests[0].location.area },
    venueStatus: 'needed', compatibilityScore: compatibilityScore(requests),
    createdAt: now, updatedAt: now, expiresAt };
  const result = await firestore.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(reference, ...requests.map((item) => requestRef(firestore, item.requestId)));
    if (snapshots[0].exists) return false;
    if (snapshots.slice(1).some((snapshot) => !snapshot.exists || snapshot.data().status !== 'active')) return false;
    transaction.create(reference, proposal);
    for (const request of requests) {
      transaction.update(requestRef(firestore, request.requestId), { status: 'matched', proposalId, updatedAt: now });
      for (const uid of request.memberUids) transaction.set(requestView(firestore, uid, request.requestId),
        { ...requestPublicView(request, uid), status: 'matched', proposalId, updatedAt: now });
    }
    for (const uid of memberUids) transaction.create(proposalView(firestore, uid, proposalId), {
      schemaVersion: 1, proposalId, status: 'confirming', confirmation: 'offered',
      memberCount: memberUids.length, scheduledAt: proposal.scheduledAt, timezone: proposal.timezone,
      city: proposal.location.city, cityId: proposal.location.cityId,
      area: proposal.location.area, venueStatus: 'needed', expiresAt,
      participants: participantSummaries(proposal), coordinator: uid === proposal.coordinatorUid,
      createdAt: now, updatedAt: now,
    });
    for (const uid of memberUids) transaction.create(
      notificationRef(firestore, 'matchmaking_match_found', proposalId, uid),
      notificationData({ type: 'matchmaking_match_found', uid, eventId: proposalId,
        title: 'Match found', message: 'A matchmaking offer is ready for your confirmation.', now }));
    return true;
  });
  return result ? proposalId : null;
}

async function createAutofillProposal(firestore, autofill, candidate, now) {
  const offeredUids = candidate.memberUids;
  if (!offeredUids.length || offeredUids.length > autofill.vacancyCount) return null;
  const allMembers = [...autofill.memberUids, ...offeredUids];
  if (new Set(allMembers).size !== allMembers.length
      || !hardCompatibility(autofill, candidate).compatible) return null;
  await requireReadyMembers(firestore, allMembers, now);
  await assertNoBlocks(firestore, allMembers);
  const replacementScheduledAt = asDate(autofill.sourceScheduledAt);
  if (!replacementScheduledAt) return null;
  const replacementWindow = { earliestStart: replacementScheduledAt,
    latestStart: replacementScheduledAt };
  for (const uid of offeredUids) {
    if (await conflictingCommitment(firestore, uid, replacementWindow)) return null;
  }
  const profiles = await firestore.getAll(...offeredUids.map((uid) => firestore.doc(`publicProfiles/${uid}`)));
  const proposalId = digest(`${autofill.requestId}\0${candidate.requestId}`);
  const expiresAt = new Date(now.getTime()
    + confirmationWindowMs(autofill.sourceScheduledAt, now));
  const proposal = { schemaVersion: 1, proposalId, status: 'confirming', memberUids: offeredUids,
    lockedMemberUids: autofill.memberUids, sourceRequestIds: [autofill.requestId, candidate.requestId],
    sourceMatchId: autofill.sourceMatchId,
    offeredProfiles: Object.fromEntries(offeredUids.map((uid, index) => [uid, {
      displayName: profiles[index].data()?.displayName ?? '', level: profiles[index].data()?.level ?? '',
    }])),
    confirmations: Object.fromEntries(offeredUids.map((uid) => [uid, 'offered'])),
    scheduledAt: autofill.sourceScheduledAt, timezone: autofill.timezone,
    location: { countryCode: autofill.location.countryCode, cityId: autofill.location.cityId,
      city: autofill.location.city, area: autofill.location.area }, venueStatus: 'confirmed',
    compatibilityScore: compatibilityScore([autofill, candidate]),
    createdAt: now, updatedAt: now, expiresAt };
  const created = await firestore.runTransaction(async (transaction) => {
    const [existing, vacancy, candidateSnapshot, match] = await transaction.getAll(
      proposalRef(firestore, proposalId), requestRef(firestore, autofill.requestId),
      requestRef(firestore, candidate.requestId), firestore.doc(`matches/${autofill.sourceMatchId}`));
    if (existing.exists) return false;
    const matchData = match.data();
    if (vacancy.data()?.status !== 'active' || candidateSnapshot.data()?.status !== 'active'
        || !match.exists || matchData.status === 'cancelled'
        || matchData.scheduledAt?.toDate() <= now
        || matchData.autoFillEnabled !== true
        || matchData.autoFillRequestId !== autofill.requestId
        || !Number.isSafeInteger(matchData.spotsLeft)
        || matchData.spotsLeft < offeredUids.length
        || matchData.spotsLeft !== vacancy.data()?.vacancyCount
        || JSON.stringify(matchData.participantUids ?? [])
          !== JSON.stringify(vacancy.data()?.memberUids ?? [])) return false;
    transaction.create(proposalRef(firestore, proposalId), proposal);
    for (const item of [autofill, candidate]) {
      transaction.update(requestRef(firestore, item.requestId), { status: 'matched', proposalId, updatedAt: now });
      for (const uid of item.memberUids) transaction.set(requestView(firestore, uid, item.requestId),
        { ...requestPublicView(item, uid), status: 'matched', proposalId, updatedAt: now });
    }
    for (const uid of offeredUids) transaction.create(proposalView(firestore, uid, proposalId), {
      schemaVersion: 1, proposalId, status: 'confirming', confirmation: 'offered',
      sourceMatchId: autofill.sourceMatchId, memberCount: offeredUids.length,
      scheduledAt: proposal.scheduledAt, timezone: proposal.timezone, city: proposal.location.city,
      cityId: proposal.location.cityId,
      area: proposal.location.area, venueStatus: 'confirmed', expiresAt, createdAt: now, updatedAt: now,
      participants: participantSummaries(proposal), coordinator: false,
    });
    for (const uid of offeredUids) transaction.create(
      notificationRef(firestore, 'matchmaking_replacement_found', proposalId, uid),
      notificationData({ type: 'matchmaking_replacement_found', uid, eventId: proposalId,
        matchId: autofill.sourceMatchId, title: 'Match spot found',
        message: 'A spot is ready for your confirmation.', now }));
    return true;
  });
  return created ? proposalId : null;
}

async function candidateWindows(firestore, request, visit, { persistCursor = true } = {}) {
  let afterCreatedAt = persistCursor ? request.scanAfterCreatedAt ?? null : null;
  let afterId = persistCursor ? text(request.scanAfterId, 128) : null;
  let lastDocument = null;
  let inspected = 0;
  for (let window = 0; window < MATCHMAKING_SCAN_WINDOWS_PER_INVOCATION; window++) {
    let query = firestore.collection(MATCHMAKING_REQUESTS)
      .where('status', '==', 'active').where('cityKey', '==', request.cityKey)
      .orderBy('createdAt').orderBy('__name__').limit(MATCHMAKING_CANDIDATE_LIMIT);
    if (afterCreatedAt && afterId) query = query.startAfter(afterCreatedAt, afterId);
    const page = await query.get();
    if (page.empty) break;
    const rankedData = rankByReliability(page.docs.map((document) => ({
      document,
      status: 'established',
      percent: document.data().reliabilityRank ?? 0,
    })));
    for (const ranked of rankedData) {
      const document = ranked.document;
      inspected++;
      const result = await visit(document.data());
      if (result) return { result, inspected };
    }
    lastDocument = page.docs.at(-1);
    afterCreatedAt = lastDocument.data().createdAt;
    afterId = lastDocument.id;
    if (page.size < MATCHMAKING_CANDIDATE_LIMIT) break;
  }
  if (persistCursor && lastDocument) {
    await requestRef(firestore, request.requestId).update({
      scanAfterCreatedAt: lastDocument.data().createdAt,
      scanAfterId: lastDocument.id,
    }).catch(() => {});
  } else if (persistCursor && (request.scanAfterCreatedAt || request.scanAfterId)) {
    // A completed pass wraps once so old requests are not permanently skipped
    // after candidates change, while each invocation remains strictly bounded.
    await requestRef(firestore, request.requestId).update({
      scanAfterCreatedAt: null, scanAfterId: null,
    }).catch(() => {});
  }
  return { result: null, inspected };
}

async function attemptAutofill(firestore, autofill, now) {
  const scan = await candidateWindows(firestore, autofill, async (candidate) => {
    if (candidate.mode === 'autofill' || candidate.requestId === autofill.requestId
        || candidate.memberUids.length > autofill.vacancyCount || candidate.expiresAt.toDate() <= now) return null;
    return createAutofillProposal(firestore, autofill, candidate, now);
  });
  return scan.result;
}

async function attemptSoloIntoAutofill(firestore, candidate, now) {
  if (candidate.mode !== 'solo' || candidate.memberUids.length !== 1) return null;
  const scan = await candidateWindows(firestore, candidate, async (autofill) => {
    if (autofill.mode !== 'autofill' || autofill.requestId === candidate.requestId
        || autofill.expiresAt?.toDate() <= now
        || candidate.memberUids.length > autofill.vacancyCount) return null;
    return createAutofillProposal(firestore, autofill, candidate, now);
  }, { persistCursor: false });
  return scan.result;
}

export async function attemptMatchmaking(firestore, createdRequest, now = new Date()) {
  if (createdRequest.status !== 'active') return null;
  if (createdRequest.mode === 'autofill') return attemptAutofill(firestore, createdRequest, now);
  // Preserve an already-confirmed match before forming a new group. This pass
  // remains bounded, and incompatible/unavailable AutoFill requests fall
  // through immediately to ordinary matchmaking so Solo players cannot be
  // stranded or indefinitely starved.
  const replacementProposal = await attemptSoloIntoAutofill(firestore, createdRequest, now);
  if (replacementProposal) return replacementProposal;
  const selected = [createdRequest];
  let seats = createdRequest.memberUids.length;
  const scan = await candidateWindows(firestore, createdRequest, async (candidate) => {
    if (candidate.mode === 'autofill' || candidate.expiresAt?.toDate() <= now) return null;
    if (candidate.requestId === createdRequest.requestId
        || seats + candidate.memberUids.length > 4) return null;
    if (selected.every((existing) => hardCompatibility(existing, candidate).compatible)) {
      selected.push(candidate); seats += candidate.memberUids.length;
      if (seats === 4) return createProposal(firestore, selected, now);
    }
    return null;
  });
  return scan.result;
}

export async function createMatchmakingRequestOperation(firestore, request) {
  const now = nowFrom(request);
  const ownerUid = await requireActiveAccount(firestore, request);
  const [privateProfile, publicProfile, reliabilityProfile] = await firestore.getAll(
    firestore.doc(`users/${ownerUid}`), firestore.doc(`publicProfiles/${ownerUid}`),
    firestore.doc(`reliabilityProfiles/${ownerUid}`));
  if (!privateProfile.exists || privateProfile.data()?.active === false || !publicProfile.exists) {
    throw new HttpsError('failed-precondition', 'Complete your profile first.');
  }
  await requireReadyMembers(firestore, [ownerUid], now);
  const parsed = parseCreatePayload(request.data, ownerUid,
    { ...publicProfile.data(), discoveryLocation: privateProfile.data().discoveryLocation }, now);
  if (parsed.partnerUid) {
    await requireReadyMembers(firestore, [parsed.partnerUid], now);
    await assertNoBlocks(firestore, [ownerUid, parsed.partnerUid]);
  }
  const partnerReliability = parsed.partnerUid
    ? await firestore.doc(`reliabilityProfiles/${parsed.partnerUid}`).get()
    : null;
  const reliabilityRank = partnerReliability
    ? Math.min(
        reliabilityPriority(reliabilityProfile.data()),
        reliabilityPriority(partnerReliability.data()),
      )
    : reliabilityPriority(reliabilityProfile.data());
  let sourceMatch = null;
  if (parsed.sourceMatchId) {
    const match = await firestore.doc(`matches/${parsed.sourceMatchId}`).get();
    sourceMatch = match.data();
    if (!match.exists || sourceMatch?.creatorUid !== ownerUid || sourceMatch.status === 'cancelled'
        || sourceMatch.scheduledAt?.toDate() <= now
        || !Number.isSafeInteger(sourceMatch.spotsLeft) || sourceMatch.spotsLeft < 1) {
      throw new HttpsError('failed-precondition', 'This match is not eligible for AutoFill.');
    }
    const matchLocation = await canonicalAutoFillLocation(firestore, parsed.sourceMatchId, sourceMatch);
    const matchCityKey = canonicalCityKey(matchLocation);
    if (!matchCityKey || !Number.isFinite(matchLocation?.latitude)
        || !Number.isFinite(matchLocation?.longitude) || parseLevel(sourceMatch.level) === null) {
      throw new HttpsError('failed-precondition', 'This match needs a canonical location and level.');
    }
    parsed.cityKey = matchCityKey;
    parsed.location = {
      countryCode: matchLocation.countryCode.trim().toUpperCase(),
      cityId: matchLocation.cityId.trim(),
      city: text(matchLocation.city, 100) ?? '',
      areaId: text(matchLocation.areaId) ?? '',
      area: text(matchLocation.area, 100) ?? '',
      latitude: matchLocation.latitude,
      longitude: matchLocation.longitude,
    };
    const sourceScheduledAt = sourceMatch.scheduledAt.toDate();
    parsed.availability = [{ earliestStart: sourceScheduledAt,
      latestStart: new Date(sourceScheduledAt.getTime() + 60 * 60 * 1000) }];
  }
  const id = digest(`${ownerUid}\0${request.data.requestId}`);
  const status = parsed.partnerUid ? 'awaiting_partner' : 'active';
  const expiresAt = new Date(now.getTime() + (parsed.partnerUid
    ? PARTNER_INVITATION_TTL_MS : MATCHMAKING_REQUEST_TTL_MS));
  const sourceMembers = sourceMatch ? [...new Set(sourceMatch.participantUids ?? [])]
    .filter(validRelationshipUid).slice(0, 4) : null;
  const data = { schemaVersion: 1, requestId: id, clientRequestId: request.data.requestId,
    ownerUid, ownerDisplayName: publicProfile.data().displayName ?? '',
    memberUids: sourceMembers ?? (parsed.partnerUid ? [ownerUid, parsed.partnerUid] : [ownerUid]),
    mode: request.data.mode, status, partnerUid: parsed.partnerUid, sourceMatchId: parsed.sourceMatchId,
    availability: parsed.availability, timezone: parsed.timezone, location: parsed.location,
    cityKey: parsed.cityKey, travelRadiusKm: parsed.travelRadiusKm, level: parsed.level,
    preferredSide: parsed.preferredSide, memberSides: [parsed.preferredSide],
    reliabilityRank,
    autoFillAfterCancellation: parsed.autoFillAfterCancellation,
    ...(sourceMatch ? { vacancyCount: sourceMatch.spotsLeft,
      sourceScheduledAt: sourceMatch.scheduledAt.toDate(),
      level: sourceMatch.level } : {}),
    createdAt: now, updatedAt: now, expiresAt };
  const reference = requestRef(firestore, id);
  const activeOwner = firestore.doc(`${MATCHMAKING_ACTIVE_OWNERS}/${ownerUid}`);
  const sourceMatchReference = parsed.sourceMatchId
    ? firestore.doc(`matches/${parsed.sourceMatchId}`) : null;
  const creation = await firestore.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(reference, activeOwner,
      ...(sourceMatchReference ? [sourceMatchReference] : []));
    const [existing, duplicate, currentSourceMatch] = snapshots;
    if (existing.exists) return { created: false, request: existing.data() };
    if (duplicate.exists && ['awaiting_partner', 'active', 'matched'].includes(duplicate.data()?.status)) {
      throw new HttpsError('already-exists', 'An overlapping matchmaking request is already active.');
    }
    if (sourceMatchReference) {
      const current = currentSourceMatch?.data();
      if (!currentSourceMatch?.exists || current.creatorUid !== ownerUid || current.status === 'cancelled'
          || current.scheduledAt?.toDate() <= now || current.spotsLeft !== sourceMatch.spotsLeft
          || JSON.stringify(current.participantUids) !== JSON.stringify(sourceMatch.participantUids)
          || current.autoFillEnabled === true) {
        throw new HttpsError('failed-precondition', 'This match is not eligible for AutoFill.');
      }
      transaction.update(sourceMatchReference, {
        autoFillEnabled: parsed.autoFillAfterCancellation,
        autoFillRequestId: id,
      });
    }
    transaction.create(reference, data);
    transaction.set(requestView(firestore, ownerUid, id), requestPublicView(data, ownerUid));
    if (parsed.partnerUid) transaction.set(requestView(firestore, parsed.partnerUid, id),
      requestPublicView(data, parsed.partnerUid));
    if (parsed.partnerUid) transaction.create(
      notificationRef(firestore, 'matchmaking_partner_invite', id, parsed.partnerUid),
      notificationData({ type: 'matchmaking_partner_invite', uid: parsed.partnerUid,
        eventId: id, title: 'Partner invitation',
        message: 'You have a matchmaking partner invitation.', now }));
    // A stable owner marker prevents concurrent overlapping active requests.
    transaction.set(activeOwner, { ownerUid, activeRequestId: id, status, updatedAt: now });
    return { created: true, request: data };
  });
  const proposalId = creation.created ? await attemptMatchmaking(firestore, data, now)
    : creation.request?.proposalId ?? null;
  return { requestId: id, status: creation.request?.status ?? status, proposalId };
}

export async function respondPartnerInvitationOperation(firestore, request) {
  const now = nowFrom(request);
  const uid = await requireActiveAccount(firestore, request);
  const id = text(request?.data?.requestId, 128);
  const accept = request?.data?.accept;
  if (!id || typeof accept !== 'boolean' || Object.keys(request.data).length !== 2) {
    throw new HttpsError('invalid-argument', 'Invalid partner response.');
  }
  await requireReadyMembers(firestore, [uid], now);
  const reference = requestRef(firestore, id);
  const updated = await firestore.runTransaction(async (transaction) => {
    const partnerLock = firestore.doc(`${MATCHMAKING_ACTIVE_OWNERS}/${uid}`);
    const [snapshot, lock] = await transaction.getAll(reference, partnerLock);
    const data = snapshot.data();
    if (!snapshot.exists || data.partnerUid !== uid || data.status !== 'awaiting_partner') {
      throw new HttpsError('failed-precondition', 'Partner invitation is unavailable.');
    }
    const status = accept && data.expiresAt.toDate() > now ? 'active' : accept ? 'expired' : 'cancelled';
    if (status === 'active' && lock.exists
        && lock.data().activeRequestId !== id
        && ['awaiting_partner', 'active', 'matched'].includes(lock.data().status)) {
      throw new HttpsError('already-exists', 'An overlapping matchmaking request is already active.');
    }
    transaction.update(reference, { status, updatedAt: now,
      expiresAt: status === 'active' ? new Date(now.getTime() + MATCHMAKING_REQUEST_TTL_MS) : data.expiresAt });
    for (const memberUid of data.memberUids) transaction.set(requestView(firestore, memberUid, id),
      { ...requestPublicView(data, memberUid), status, updatedAt: now }, { merge: true });
    transaction.set(partnerLock, { ownerUid: uid, activeRequestId: id, status, updatedAt: now });
    return { ...data, status, updatedAt: now };
  });
  if (updated.status === 'active') {
    await assertNoBlocks(firestore, updated.memberUids);
    await requireReadyMembers(firestore, updated.memberUids, now);
    await attemptMatchmaking(firestore, updated, now);
  }
  return { requestId: id, status: updated.status };
}

async function refillQuickMatchLobby(firestore, proposalId, now) {
  const currentSnapshot = await proposalRef(firestore, proposalId).get();
  const current = currentSnapshot.data();
  if (!currentSnapshot.exists || current.status !== 'confirming'
      || current.sourceMatchId || current.memberUids.length >= 4
      || current.sourceRequestIds.length === 0) return null;
  const sourceSnapshots = await firestore.getAll(...current.sourceRequestIds
    .map((id) => requestRef(firestore, id)));
  if (sourceSnapshots.some((snapshot) => !snapshot.exists)) return null;
  const sources = sourceSnapshots.map((snapshot) => snapshot.data());
  const anchor = sources[0];
  if (!anchor) return null;
  const missing = 4 - current.memberUids.length;
  const scan = await candidateWindows(firestore, anchor, async (candidate) => {
    if (candidate.mode === 'autofill' || candidate.requestId === anchor.requestId
        || current.sourceRequestIds.includes(candidate.requestId)
        || candidate.memberUids.length > missing || candidate.expiresAt?.toDate() <= now
        || !sources.every((source) => hardCompatibility(source, candidate).compatible)) return null;
    const combinedUids = [...current.memberUids, ...candidate.memberUids];
    if (new Set(combinedUids).size !== combinedUids.length) return null;
    const profiles = await requireReadyMembers(firestore, combinedUids, now);
    await assertNoBlocks(firestore, combinedUids);
    const overlap = overlappingAvailability([...sources, candidate]);
    if (!overlap) return null;
    for (const uid of candidate.memberUids) {
      if (await conflictingCommitment(firestore, uid, overlap)) return null;
    }
    const candidateProfiles = Object.fromEntries(candidate.memberUids.map((uid) => [uid, {
      displayName: profiles.get(uid)?.displayName ?? '', level: profiles.get(uid)?.level ?? '',
      preferredSide: profiles.get(uid)?.preferredSide ?? 'either',
    }]));
    const expiresAt = new Date(now.getTime() + confirmationWindowMs(current.scheduledAt, now));
    const added = await firestore.runTransaction(async (transaction) => {
      const [freshProposal, freshCandidate] = await transaction.getAll(
        proposalRef(firestore, proposalId), requestRef(firestore, candidate.requestId));
      const lobby = freshProposal.data();
      if (!freshProposal.exists || lobby.status !== 'confirming' || lobby.sourceMatchId
          || lobby.memberUids.length !== current.memberUids.length
          || freshCandidate.data()?.status !== 'active'
          || lobby.memberUids.length + candidate.memberUids.length > 4) return false;
      const memberUids = [...lobby.memberUids, ...candidate.memberUids];
      const sourceRequestIds = [...lobby.sourceRequestIds, candidate.requestId];
      const confirmations = { ...lobby.confirmations,
        ...Object.fromEntries(candidate.memberUids.map((uid) => [uid, 'offered'])) };
      const memberProfiles = { ...(lobby.memberProfiles ?? {}), ...candidateProfiles };
      const requestData = [...sources, candidate];
      const teamAssignments = memberUids.length === 4 ? assignTeams(requestData, profiles) : null;
      transaction.update(freshProposal.ref, { memberUids, sourceRequestIds, confirmations,
        memberProfiles, teamAssignments: teamAssignments ?? {}, availability: overlap,
        scheduledAt: overlap.earliestStart, expiresAt, updatedAt: now });
      transaction.update(freshCandidate.ref, { status: 'matched', proposalId, updatedAt: now });
      for (const memberUid of candidate.memberUids) transaction.set(
        requestView(firestore, memberUid, candidate.requestId),
        { ...requestPublicView(candidate, memberUid), status: 'matched', proposalId, updatedAt: now },
        { merge: true });
      const projected = { ...lobby, memberUids, confirmations, memberProfiles, teamAssignments };
      for (const memberUid of memberUids) transaction.set(proposalView(firestore, memberUid, proposalId), {
        schemaVersion: 1, proposalId, status: 'confirming',
        confirmation: confirmations[memberUid], memberCount: memberUids.length,
        scheduledAt: overlap.earliestStart, timezone: lobby.timezone,
        city: lobby.location.city, cityId: lobby.location.cityId, area: lobby.location.area,
        venueStatus: 'needed', expiresAt, participants: participantSummaries(projected),
        coordinator: memberUid === lobby.coordinatorUid, updatedAt: now,
      }, { merge: true });
      for (const memberUid of candidate.memberUids) transaction.create(
        notificationRef(firestore, 'matchmaking_match_found', proposalId, memberUid),
        notificationData({ type: 'matchmaking_match_found', uid: memberUid, eventId: proposalId,
          title: 'Quick Match spot found', message: 'A spot is ready for your confirmation.', now }));
      return true;
    });
    return added ? proposalId : null;
  }, { persistCursor: false });
  return scan.result;
}

async function releaseQuickMatchReservation(firestore, { proposalId, uid, response, eventId, now }) {
  const released = await firestore.runTransaction(async (transaction) => {
    const reference = proposalRef(firestore, proposalId);
    const [snapshot, priorEvent] = await transaction.getAll(reference,
      firestore.doc(`${RELIABILITY_EVENTS}/${eventId}`));
    const data = snapshot.data();
    if (priorEvent.exists) return { changed: false, status: data?.status };
    if (!snapshot.exists || data.sourceMatchId || data.status !== 'confirming'
        || !data.memberUids.includes(uid)) {
      throw new HttpsError('failed-precondition', 'Proposal is unavailable.');
    }
    const sources = await transaction.getAll(...data.sourceRequestIds
      .map((id) => requestRef(firestore, id)));
    const releasedSource = sources.find((source) => source.data()?.memberUids?.includes(uid));
    if (!releasedSource) throw new HttpsError('failed-precondition', 'Proposal is unavailable.');
    const releasedMembers = releasedSource.data().memberUids;
    const memberUids = data.memberUids.filter((memberUid) => !releasedMembers.includes(memberUid));
    const sourceRequestIds = data.sourceRequestIds.filter((id) => id !== releasedSource.id);
    const confirmations = Object.fromEntries(Object.entries(data.confirmations)
      .filter(([memberUid]) => memberUids.includes(memberUid)));
    const memberProfiles = Object.fromEntries(Object.entries(data.memberProfiles ?? {})
      .filter(([memberUid]) => memberUids.includes(memberUid)));
    const proposalStatus = memberUids.length === 0 ? response : 'confirming';
    transaction.update(reference, { memberUids, sourceRequestIds, confirmations, memberProfiles,
      status: proposalStatus, teamAssignments: {}, updatedAt: now });
    transaction.update(releasedSource.ref, { status: response, proposalId: null, updatedAt: now });
    transaction.set(firestore.doc(`${MATCHMAKING_ACTIVE_OWNERS}/${releasedSource.data().ownerUid}`),
      { ownerUid: releasedSource.data().ownerUid, activeRequestId: releasedSource.id,
        status: response, updatedAt: now });
    for (const memberUid of releasedMembers) {
      transaction.set(requestView(firestore, memberUid, releasedSource.id),
        { status: response, proposalId: null, updatedAt: now }, { merge: true });
      transaction.set(proposalView(firestore, memberUid, proposalId),
        { status: response, confirmation: response, updatedAt: now }, { merge: true });
    }
    for (const source of sources) {
      if (source.id === releasedSource.id) continue;
      const requestData = source.data();
      const locked = requestData.memberUids.every((memberUid) => confirmations[memberUid] === 'accepted');
      if (locked) {
        transaction.update(source.ref, { status: 'locked', updatedAt: now });
        transaction.set(firestore.doc(`${MATCHMAKING_ACTIVE_OWNERS}/${requestData.ownerUid}`),
          { ownerUid: requestData.ownerUid, activeRequestId: source.id, status: 'locked', updatedAt: now });
      }
    }
    const projected = { ...data, memberUids, confirmations, memberProfiles, teamAssignments: {} };
    for (const memberUid of memberUids) transaction.set(proposalView(firestore, memberUid, proposalId),
      { status: 'confirming', confirmation: confirmations[memberUid], memberCount: memberUids.length,
        participants: participantSummaries(projected), updatedAt: now }, { merge: true });
    transaction.create(firestore.doc(`${RELIABILITY_EVENTS}/${eventId}`), {
      schemaVersion: 1, eventId, uid, type: `proposal_${response}`,
      proposalId, occurredAt: now, source: 'matchmaking',
    });
    return { changed: true, status: proposalStatus };
  });
  if (released.changed && released.status === 'confirming') {
    await refillQuickMatchLobby(firestore, proposalId, now);
  }
  return released;
}

export async function cancelMatchmakingRequestOperation(firestore, request) {
  const now = nowFrom(request);
  const uid = await requireActiveAccount(firestore, request);
  const id = text(request?.data?.requestId, 128);
  if (!id || Object.keys(request.data).length !== 1) throw new HttpsError('invalid-argument', 'Invalid request.');
  await firestore.runTransaction(async (transaction) => {
    const reference = requestRef(firestore, id);
    const snapshot = await transaction.get(reference);
    const data = snapshot.data();
    if (!snapshot.exists || !data.memberUids?.includes(uid)) {
      throw new HttpsError('not-found', 'Request unavailable.');
    }
    if (!['awaiting_partner', 'active', 'paused'].includes(data.status)) return;
    const sourceMatch = data.mode === 'autofill' && data.sourceMatchId
      ? await transaction.get(firestore.doc(`matches/${data.sourceMatchId}`)) : null;
    transaction.update(reference, { status: 'cancelled', updatedAt: now });
    for (const memberUid of data.memberUids) {
      transaction.set(firestore.doc(`${MATCHMAKING_ACTIVE_OWNERS}/${memberUid}`),
        { ownerUid: memberUid, activeRequestId: id, status: 'cancelled', updatedAt: now });
      transaction.set(requestView(firestore, memberUid, id),
        { status: 'cancelled', updatedAt: now }, { merge: true });
    }
    if (sourceMatch?.exists && sourceMatch.data()?.creatorUid === uid
        && sourceMatch.data()?.autoFillRequestId === id) {
      transaction.update(sourceMatch.ref, { autoFillEnabled: false, autoFillRequestId: null });
    }
  });
  return { requestId: id, status: 'cancelled' };
}

export async function respondMatchProposalOperation(firestore, request) {
  const now = nowFrom(request);
  const uid = await requireActiveAccount(firestore, request);
  const id = text(request?.data?.proposalId, 128);
  const accept = request?.data?.accept;
  const clientRequestId = request?.data?.requestId;
  if (!id || typeof accept !== 'boolean' || !validRequestId(clientRequestId)
      || Object.keys(request.data).length !== 3) {
    throw new HttpsError('invalid-argument', 'Invalid proposal response.');
  }
  await requireReadyMembers(firestore, [uid], now);
  const preliminary = await proposalRef(firestore, id).get();
  const preliminaryData = preliminary.data();
  if (preliminary.exists && !preliminaryData.sourceMatchId
      && preliminaryData.status === 'confirming'
      && preliminaryData.memberUids?.includes(uid)) {
    const expired = preliminaryData.expiresAt.toDate() <= now;
    if (!accept || expired) {
      const response = expired ? 'expired' : 'declined';
      const eventId = digest(`${id}\0${uid}\0${clientRequestId}`);
      await releaseQuickMatchReservation(firestore,
        { proposalId: id, uid, response, eventId, now });
      return { proposalId: id, status: 'confirming', confirmation: response };
    }
  }
  const result = await firestore.runTransaction(async (transaction) => {
    const reference = proposalRef(firestore, id);
    const eventId = digest(`${id}\0${uid}\0${clientRequestId}`);
    const eventRef = firestore.doc(`${RELIABILITY_EVENTS}/${eventId}`);
    const [snapshot, priorEvent] = await transaction.getAll(reference, eventRef);
    const data = snapshot.data();
    if (priorEvent.exists) return { status: data?.status, confirmation: data?.confirmations?.[uid] };
    if (!snapshot.exists || !data.memberUids?.includes(uid) || data.status !== 'confirming') {
      throw new HttpsError('failed-precondition', 'Proposal is unavailable.');
    }
    const expired = data.expiresAt.toDate() <= now;
    const response = expired ? 'expired' : accept ? 'accepted' : 'declined';
    const confirmations = { ...data.confirmations, [uid]: response };
    const allAccepted = (data.sourceMatchId || data.memberUids.length === 4)
      && Object.values(confirmations).every((value) => value === 'accepted');
    const status = expired ? 'expired' : !accept ? 'declined' : allAccepted ? 'venue_needed' : 'confirming';
    let matchData = null;
    if (allAccepted && data.sourceMatchId) {
      const match = await transaction.get(firestore.doc(`matches/${data.sourceMatchId}`));
      matchData = match.data();
      if (!match.exists || !Number.isSafeInteger(matchData.spotsLeft)
          || matchData.spotsLeft < data.memberUids.length
          || matchData.scheduledAt?.toDate() <= now) {
        throw new HttpsError('failed-precondition', 'The AutoFill vacancy is no longer available.');
      }
    }
    const sourceRequests = await transaction.getAll(
      ...data.sourceRequestIds.map((sourceRequestId) => requestRef(firestore, sourceRequestId)),
    );
    if (allAccepted && data.sourceMatchId) {
      if (sourceRequests.length !== 2 || sourceRequests.some((source) => !source.exists
          || source.data().status !== 'matched')) {
        throw new HttpsError('failed-precondition', 'The AutoFill offer changed.');
      }
      const vacancy = sourceRequests.find((source) => source.data().mode === 'autofill')?.data();
      const candidate = sourceRequests.find((source) => source.data().mode !== 'autofill')?.data();
      if (!vacancy || !candidate || !hardCompatibility(vacancy, candidate).compatible
          || vacancy.sourceMatchId !== data.sourceMatchId
          || data.memberUids.some((memberUid) => matchData.participantUids?.includes(memberUid))) {
        throw new HttpsError('failed-precondition', 'The AutoFill offer changed.');
      }
      const readinessRefs = data.memberUids.flatMap((memberUid) => [
        firestore.doc(`users/${memberUid}`), firestore.doc(`publicProfiles/${memberUid}`),
        firestore.doc(`${ACCOUNT_ELIGIBILITY}/${memberUid}`),
        firestore.doc(`${LEGAL_ACCEPTANCE}/${memberUid}`),
        firestore.doc(`${DELETION_BARRIERS}/${memberUid}`),
        firestore.doc(`${ACCOUNT_ENFORCEMENT}/${memberUid}`),
      ]);
      const blockRefs = data.memberUids.flatMap((memberUid) => (data.lockedMemberUids ?? [])
        .flatMap((lockedUid) => [
          firestore.doc(`blocks/${blockId(memberUid, lockedUid)}`),
          firestore.doc(`blocks/${blockId(lockedUid, memberUid)}`),
        ]));
      const validation = await transaction.getAll(...readinessRefs, ...blockRefs);
      for (let index = 0; index < data.memberUids.length; index++) {
        const memberUid = data.memberUids[index];
        const [user, profile, eligibility, legal, barrier, enforcement] = validation
          .slice(index * 6, index * 6 + 6);
        if (!user.exists || user.data()?.active === false || !profile.exists
            || !validEligibility(eligibility.data(), memberUid) || !validLegal(legal.data(), memberUid)
            || barrier.exists || getEffectiveAccountEnforcement(enforcement.data(), now)) {
          throw new HttpsError('failed-precondition', 'The AutoFill offer is no longer available.');
        }
        const conflicts = await transaction.get(firestore.collection('matches')
          .where('participantUids', 'array-contains', memberUid)
          .where('scheduledAt', '>=', new Date(matchData.scheduledAt.toDate().getTime() - 150 * 60 * 1000))
          .where('scheduledAt', '<=', new Date(matchData.scheduledAt.toDate().getTime() + 150 * 60 * 1000))
          .limit(1));
        if (!conflicts.empty) throw new HttpsError('failed-precondition', 'A player has a conflicting match.');
      }
      if (validation.slice(readinessRefs.length).some((block) => block.exists)) {
        throw new HttpsError('failed-precondition', 'The AutoFill offer is no longer available.');
      }
    }
    transaction.update(reference, { confirmations, status, updatedAt: now });
    for (const memberUid of data.memberUids) transaction.set(proposalView(firestore, memberUid, id),
      { status, confirmation: confirmations[memberUid],
        participants: participantSummaries(data, confirmations), updatedAt: now }, { merge: true });
    transaction.create(eventRef, {
      schemaVersion: 1, eventId, uid, type: `proposal_${response}`,
      proposalId: id, occurredAt: now, source: 'matchmaking',
    });
    let reactivatedAutofill = null;
    const acceptedMatchMembers = data.sourceMatchId && matchData
      ? [...new Set([...(matchData.participantUids ?? []), ...data.memberUids])]
      : null;
    if (status !== 'confirming') for (const source of sourceRequests) {
      const requestData = source.data();
      const remainingSpots = data.sourceMatchId && matchData
        ? matchData.spotsLeft - data.memberUids.length : 0;
      const requestStatus = allAccepted
        ? (data.sourceMatchId
          ? (requestData.mode === 'autofill' && remainingSpots > 0 ? 'active' : 'confirmed')
          : 'matched') : 'active';
      transaction.update(source.ref, { status: requestStatus, proposalId: null,
        ...(requestData.mode === 'autofill' && data.sourceMatchId ? { vacancyCount: remainingSpots } : {}),
        ...(requestData.mode === 'autofill' && allAccepted && acceptedMatchMembers
          ? { memberUids: acceptedMatchMembers } : {}),
        updatedAt: now });
      transaction.set(firestore.doc(`${MATCHMAKING_ACTIVE_OWNERS}/${requestData.ownerUid}`),
        { ownerUid: requestData.ownerUid, activeRequestId: source.id, status: requestStatus, updatedAt: now });
      for (const memberUid of requestData.memberUids) transaction.set(requestView(firestore, memberUid, source.id),
        { status: requestStatus, proposalId: null, updatedAt: now }, { merge: true });
      if (requestData.mode === 'autofill' && requestStatus === 'active') {
        reactivatedAutofill = { ...requestData, status: 'active', proposalId: null,
          memberUids: acceptedMatchMembers, vacancyCount: remainingSpots, updatedAt: now };
      }
    }
    if (allAccepted && data.sourceMatchId) {
      const matchRef = firestore.doc(`matches/${data.sourceMatchId}`);
      const profiles = data.offeredProfiles ?? {};
      transaction.update(matchRef, {
        players: [...(matchData.players ?? []), ...data.memberUids.map((memberUid) => ({ uid: memberUid,
          displayName: profiles[memberUid]?.displayName ?? '', level: profiles[memberUid]?.level ?? '' }))],
        participantUids: [...new Set([...(matchData.participantUids ?? []), ...data.memberUids])],
        spotsLeft: matchData.spotsLeft - data.memberUids.length,
        autoFillEnabled: matchData.spotsLeft - data.memberUids.length > 0,
        autoFillRequestId: matchData.spotsLeft - data.memberUids.length > 0
          ? matchData.autoFillRequestId : null,
      });
      for (const memberUid of data.memberUids) {
        const replacementEventId = digest(`${data.sourceMatchId}\0${memberUid}\0replacement_found`);
        transaction.create(firestore.doc(`${RELIABILITY_EVENTS}/${replacementEventId}`), {
          schemaVersion: 1, eventId: replacementEventId, uid: memberUid,
          type: 'replacement_found', matchId: data.sourceMatchId,
          occurredAt: now, source: 'matchmaking',
        });
        const commitmentEventId = digest(
          `${data.sourceMatchId}\0${memberUid}\0confirmed_match_committed`,
        );
        transaction.create(firestore.doc(`${RELIABILITY_EVENTS}/${commitmentEventId}`), {
          schemaVersion: 1,
          eventId: commitmentEventId,
          uid: memberUid,
          type: 'confirmed_match_committed',
          matchId: data.sourceMatchId,
          scheduledAt: matchData.scheduledAt,
          occurredAt: now,
          source: 'matchmaking',
          policyVersion: 'objective-reliability-v2-attendance',
        });
      }
    }
    return { status, confirmation: response, reactivatedAutofill };
  });
  if (result.reactivatedAutofill) await attemptMatchmaking(firestore, result.reactivatedAutofill, now);
  return { proposalId: id, status: result.status, confirmation: result.confirmation };
}

export async function resolveMatchmakingVenueOperation(firestore, request, resolvePlace = null) {
  const now = nowFrom(request);
  const uid = await requireActiveAccount(firestore, request);
  const data = request?.data;
  if (!data || typeof data !== 'object' || Array.isArray(data)
      || Object.keys(data).some((key) => !['proposalId', 'requestId', 'venue'].includes(key))
      || !validRequestId(data.requestId) || !text(data.proposalId, 128)
      || !data.venue || typeof data.venue !== 'object' || Array.isArray(data.venue)) {
    throw new HttpsError('invalid-argument', 'Invalid venue request.');
  }
  const venue = data.venue;
  if (Object.keys(venue).some((key) => !['type', 'label', 'placeId', 'address', 'latitude',
    'longitude', 'country', 'countryCode', 'cityId', 'city', 'areaId', 'area'].includes(key))
      || !VENUE_TYPES.includes(venue.type) || !text(venue.label, 120) || !text(venue.placeId)
      || !text(venue.countryCode, 8) || !text(venue.cityId) || !text(venue.city, 100)
      || !Number.isFinite(venue.latitude) || !Number.isFinite(venue.longitude)
      || (venue.type === 'private_free' && !text(venue.address, 300))) {
    throw new HttpsError('invalid-argument', 'Invalid venue.');
  }
  const proposalReference = proposalRef(firestore, data.proposalId);
  const proposalSnapshot = await proposalReference.get();
  const proposal = proposalSnapshot.data();
  if (!proposalSnapshot.exists || proposal.coordinatorUid !== uid
      || !['venue_needed', 'promoted'].includes(proposal.status)) {
    throw new HttpsError('failed-precondition', 'Venue selection is unavailable.');
  }
  if (proposal.status === 'promoted') return { matchId: proposal.matchId, status: 'promoted' };
  if (!Object.values(proposal.confirmations).every((value) => value === 'accepted')) {
    throw new HttpsError('failed-precondition', 'Player confirmations are incomplete.');
  }
  const trustedPlace = resolvePlace
    ? await resolvePlace(venue.placeId)
    : { placeId: venue.placeId, latitude: venue.latitude, longitude: venue.longitude,
        formattedAddress: venue.address ?? '', countryCode: venue.countryCode };
  if (trustedPlace.countryCode && trustedPlace.countryCode !== venue.countryCode.trim().toUpperCase()
      || haversineKm(trustedPlace, venue) > 0.25) {
    throw new HttpsError('failed-precondition', 'That venue could not be verified.');
  }
  const verifiedVenue = { ...venue, latitude: trustedPlace.latitude,
    longitude: trustedPlace.longitude, address: trustedPlace.formattedAddress,
    placeId: trustedPlace.placeId };
  // expiresAt is the confirmation deadline. Once every player accepted and
  // the proposal advanced to venue_needed, venue resolution must not be
  // invalidated by that already-completed phase's deadline.
  const sourceSnapshots = await firestore.getAll(...proposal.sourceRequestIds
    .map((id) => requestRef(firestore, id)));
  const venuePoint = { latitude: verifiedVenue.latitude, longitude: verifiedVenue.longitude };
  if (sourceSnapshots.some((snapshot) => {
    const source = snapshot.data();
    const distance = haversineKm(source?.location, venuePoint);
    return !snapshot.exists || canonicalCityKey(verifiedVenue) !== source.cityKey
      || distance === null || distance > source.travelRadiusKm;
  })) throw new HttpsError('failed-precondition', 'The venue is outside the accepted area.');
  const matchId = `matchmaking_${proposal.proposalId}`;
  const matchRef = firestore.doc(`matches/${matchId}`);
  const privateRef = firestore.doc(`${MATCH_PRIVATE_VENUES}/${matchId}`);
  const result = await firestore.runTransaction(async (transaction) => {
    const memberRefs = proposal.memberUids.flatMap((memberUid) => [
      firestore.doc(`users/${memberUid}`), firestore.doc(`publicProfiles/${memberUid}`),
      firestore.doc(`${ACCOUNT_ELIGIBILITY}/${memberUid}`),
      firestore.doc(`${LEGAL_ACCEPTANCE}/${memberUid}`),
      firestore.doc(`${DELETION_BARRIERS}/${memberUid}`),
      firestore.doc(`${ACCOUNT_ENFORCEMENT}/${memberUid}`),
    ]);
    const blockRefs = [];
    for (let left = 0; left < proposal.memberUids.length; left++) {
      for (let right = left + 1; right < proposal.memberUids.length; right++) {
        blockRefs.push(firestore.doc(`blocks/${blockId(proposal.memberUids[left], proposal.memberUids[right])}`));
        blockRefs.push(firestore.doc(`blocks/${blockId(proposal.memberUids[right], proposal.memberUids[left])}`));
      }
    }
    const allRefs = [proposalReference, matchRef,
      ...proposal.sourceRequestIds.map((sourceId) => requestRef(firestore, sourceId)),
      ...memberRefs, ...blockRefs];
    const snapshots = await transaction.getAll(...allRefs);
    const fresh = snapshots[0];
    const existing = snapshots[1];
    const current = fresh.data();
    if (existing.exists && current?.status === 'promoted' && current.matchId === matchId) return matchId;
    if (!fresh.exists || current.status !== 'venue_needed'
        || current.coordinatorUid !== uid
        || current.memberUids.length !== 4 || new Set(current.memberUids).size !== 4
        || !current.memberUids.includes(current.coordinatorUid)
        || Object.keys(current.confirmations).length !== 4
        || !current.memberUids.every((memberUid) => current.confirmations[memberUid] === 'accepted')) {
      throw new HttpsError('failed-precondition', 'Proposal changed.');
    }
    const freshSources = snapshots.slice(2, 2 + current.sourceRequestIds.length);
    if (freshSources.some((source) => !source.exists
        || !['confirmed', 'matched', 'locked'].includes(source.data().status)
        || canonicalCityKey(verifiedVenue) !== source.data().cityKey
        || haversineKm(source.data().location, venuePoint) > source.data().travelRadiusKm)) {
      throw new HttpsError('failed-precondition', 'The venue is outside the accepted area.');
    }
    const sourceMembers = [...new Set(freshSources.flatMap((source) => source.data().memberUids))];
    if (sourceMembers.length !== 4 || current.memberUids.some((memberUid) => !sourceMembers.includes(memberUid))) {
      throw new HttpsError('failed-precondition', 'Proposal membership changed.');
    }
    const memberOffset = 2 + current.sourceRequestIds.length;
    for (let index = 0; index < current.memberUids.length; index++) {
      const [user, profile, eligibility, legal, barrier, enforcement] = snapshots
        .slice(memberOffset + index * 6, memberOffset + index * 6 + 6);
      const memberUid = current.memberUids[index];
      if (!user.exists || user.data()?.active === false || !profile.exists
          || !validEligibility(eligibility.data(), memberUid) || !validLegal(legal.data(), memberUid)
          || barrier.exists || getEffectiveAccountEnforcement(enforcement.data(), now)) {
        throw new HttpsError('failed-precondition', 'The proposal is no longer available.');
      }
      const conflict = await transaction.get(firestore.collection('matches')
        .where('participantUids', 'array-contains', memberUid)
        .where('scheduledAt', '>=', new Date(current.scheduledAt.toDate().getTime() - 150 * 60 * 1000))
        .where('scheduledAt', '<=', new Date(current.scheduledAt.toDate().getTime() + 150 * 60 * 1000))
        .limit(1));
      if (!conflict.empty) throw new HttpsError('failed-precondition', 'A player has a conflicting match.');
    }
    const blockOffset = memberOffset + current.memberUids.length * 6;
    if (snapshots.slice(blockOffset).some((block) => block.exists)) {
      throw new HttpsError('failed-precondition', 'The proposal is no longer available.');
    }
    const profiles = current.memberProfiles ?? {};
    const safeLocation = { clubName: verifiedVenue.label,
      countryCode: verifiedVenue.countryCode.toUpperCase(),
      country: text(verifiedVenue.country, 80) ?? verifiedVenue.countryCode.toUpperCase(), region: '',
      cityId: verifiedVenue.cityId, city: verifiedVenue.city,
      areaId: text(verifiedVenue.areaId) ?? '', area: verifiedVenue.area ?? '',
      ...(verifiedVenue.type === 'club_public' ? { placeId: verifiedVenue.placeId,
        formattedAddress: verifiedVenue.address,
        latitude: verifiedVenue.latitude, longitude: verifiedVenue.longitude } : {}) };
    transaction.create(matchRef, { source: 'matchmaking', matchmakingProposalId: current.proposalId,
      venueType: venue.type, title: current.scheduledAt.toISOString?.() ?? current.scheduledAt.toDate().toISOString(),
      dateTime: current.scheduledAt.toISOString?.() ?? current.scheduledAt.toDate().toISOString(),
      scheduledAt: current.scheduledAt, club: venue.label, clubName: venue.label, location: safeLocation,
      level: `Level ${parseLevel(freshSources[0].data().level)}`, spotsLeft: 0,
      creatorUid: current.coordinatorUid,
      creatorDisplayName: profiles[current.coordinatorUid]?.displayName ?? '',
      creatorLevel: profiles[current.coordinatorUid]?.level ?? '',
      participantUids: current.memberUids,
      teams: [1, 2].map((team) => ({ team,
        participantUids: current.memberUids.filter((memberUid) => current.teamAssignments?.[memberUid] === team) })),
      players: current.memberUids.filter((memberUid) => memberUid !== current.coordinatorUid)
        .map((memberUid) => ({ uid: memberUid, displayName: profiles[memberUid]?.displayName ?? '',
          level: profiles[memberUid]?.level ?? '' })), createdAt: now });
    if (verifiedVenue.type === 'private_free') transaction.create(privateRef, { schemaVersion: 1, matchId,
      placeId: verifiedVenue.placeId, address: verifiedVenue.address,
      latitude: verifiedVenue.latitude, longitude: verifiedVenue.longitude,
      createdAt: now, updatedAt: now });
    transaction.update(proposalReference, { status: 'promoted', matchId, venueStatus: 'selected', updatedAt: now });
    for (const memberUid of current.memberUids) transaction.set(proposalView(firestore, memberUid, current.proposalId),
      { status: 'promoted', matchId, venueStatus: 'selected', updatedAt: now }, { merge: true });
    for (const source of freshSources) {
      transaction.update(source.ref, { status: 'confirmed', matchId,
        proposalId: current.proposalId, updatedAt: now });
      for (const memberUid of source.data().memberUids) transaction.set(
        requestView(firestore, memberUid, source.id),
        { status: 'confirmed', matchId, proposalId: current.proposalId, updatedAt: now }, { merge: true });
    }
    for (const memberUid of current.memberUids) transaction.set(
      firestore.doc(`${MATCHMAKING_ACTIVE_OWNERS}/${memberUid}`),
      { ownerUid: memberUid, activeRequestId: null, status: 'confirmed', matchId, updatedAt: now });
    for (const memberUid of current.memberUids) transaction.create(
      notificationRef(firestore, 'matchmaking_match_confirmed', matchId, memberUid),
      notificationData({ type: 'matchmaking_match_confirmed', uid: memberUid,
        eventId: current.proposalId, matchId, title: 'Match confirmed',
        message: 'Your match is confirmed.', now }));
    for (const memberUid of current.memberUids) {
      const eventId = digest(`${matchId}\0${memberUid}\0confirmed_match_committed`);
      transaction.create(firestore.doc(`${RELIABILITY_EVENTS}/${eventId}`), {
        schemaVersion: 1, eventId, uid: memberUid, type: 'confirmed_match_committed',
        matchId, scheduledAt: current.scheduledAt, occurredAt: now, source: 'matchmaking',
        policyVersion: 'objective-reliability-v2-attendance',
      });
    }
    return matchId;
  });
  return { matchId: result, status: 'promoted' };
}

export async function leaveMatchOperation(firestore, request) {
  const now = nowFrom(request);
  const uid = await requireActiveAccount(firestore, request);
  const data = request?.data;
  if (!data || typeof data !== 'object' || Array.isArray(data)
      || Object.keys(data).some((key) => !['matchId', 'requestId'].includes(key))
      || !validRequestId(data.requestId) || !text(data.matchId, 200)
      || data.matchId.includes('/')) {
    throw new HttpsError('invalid-argument', 'Invalid leave request.');
  }
  const matchRef = firestore.doc(`matches/${data.matchId}`);
  const eventId = digest(`${data.matchId}\0${uid}\0confirmed_match_cancelled`);
  const eventRef = firestore.doc(`${RELIABILITY_EVENTS}/${eventId}`);
  const joinRequestRef = firestore.doc(`matches/${data.matchId}/joinRequests/${uid}`);
  return firestore.runTransaction(async (transaction) => {
    const [matchSnapshot, eventSnapshot, joinRequestSnapshot] = await transaction.getAll(
      matchRef, eventRef, joinRequestRef,
    );
    if (eventSnapshot.exists && eventSnapshot.data()?.uid === uid
        && eventSnapshot.data()?.matchId === data.matchId) {
      return { matchId: data.matchId, status: 'left' };
    }
    if (!matchSnapshot.exists) throw new HttpsError('not-found', 'Match unavailable.');
    const match = matchSnapshot.data();
    if (match.status === 'cancelled') {
      throw new HttpsError('failed-precondition', 'This match can no longer be changed.');
    }
    const organizerUid = text(match.creatorUid) ?? text(match.createdBy);
    if (organizerUid === uid) {
      throw new HttpsError('failed-precondition', 'The organizer must cancel the match.');
    }
    const scheduledAt = match.scheduledAt?.toDate?.()
      ?? (typeof match.dateTime === 'string' ? new Date(match.dateTime) : null);
    if (!(scheduledAt instanceof Date) || !Number.isFinite(scheduledAt.getTime())
        || scheduledAt <= now) {
      throw new HttpsError('failed-precondition', 'This match can no longer be changed.');
    }
    const players = Array.isArray(match.players) ? [...match.players] : [];
    const playerUid = (player) => text(player?.uid) ?? text(player?.userId);
    const playerIndex = players.findIndex((player) => playerUid(player) === uid);
    if (playerIndex < 0) {
      throw new HttpsError('failed-precondition', 'You are not a current participant.');
    }
    players.splice(playerIndex, 1);
    const participantUids = [organizerUid, ...players.map(playerUid)]
      .filter((memberUid, index, values) => memberUid && values.indexOf(memberUid) === index);
    if (!organizerUid || participantUids.length !== players.length + 1) {
      throw new HttpsError('failed-precondition', 'Match membership is unavailable.');
    }
    const spotsLeft = Number.isSafeInteger(match.spotsLeft) ? match.spotsLeft : 0;
    const nextSpotsLeft = Math.min(spotsLeft + 1, 3 - players.length);
    transaction.update(matchRef, { players, participantUids, spotsLeft: nextSpotsLeft });
    if (joinRequestSnapshot.exists && joinRequestSnapshot.data()?.status === 'approved') {
      transaction.update(joinRequestRef, { status: 'declined' });
    }
    transaction.create(eventRef, {
      schemaVersion: 1, eventId, uid, type: 'confirmed_match_cancelled',
      matchId: data.matchId, scheduledAt,
      timingCategory: cancellationTimingCategory(scheduledAt, now),
      occurredAt: now, source: 'match_lifecycle',
    });
    return { matchId: data.matchId, status: 'left' };
  });
}

export async function getMatchmakingStateOperation(firestore, request) {
  const uid = await requireActiveAccount(firestore, request);
  const [requests, proposals] = await Promise.all([
    firestore.collection(`users/${uid}/matchmakingRequestViews`).orderBy('updatedAt', 'desc').limit(20).get(),
    firestore.collection(`users/${uid}/matchProposalViews`).orderBy('updatedAt', 'desc').limit(20).get(),
  ]);
  const proposalViews = proposals.docs.map((document) => document.data());
  const enrichedProposals = await Promise.all(proposalViews.map(async (view) => {
    if (view.status !== 'venue_needed' || view.coordinator !== true) return view;
    const canonical = await proposalRef(firestore, view.proposalId).get();
    const proposal = canonical.data();
    if (!canonical.exists || proposal?.status !== 'venue_needed'
        || proposal.coordinatorUid !== uid || !Array.isArray(proposal.sourceRequestIds)) return view;
    const sources = await firestore.getAll(...proposal.sourceRequestIds
      .slice(0, 4).map((id) => requestRef(firestore, id)));
    if (sources.some((source) => !source.exists)) return view;
    const coordinatorSource = sources.find((source) => source.data().ownerUid === uid)
      ?? sources.find((source) => source.data().memberUids?.includes(uid));
    const center = coordinatorSource?.data()?.location;
    if (!center || !Number.isFinite(center.latitude) || !Number.isFinite(center.longitude)) return view;
    const radiusKm = Math.min(...sources.map((source) => {
      const data = source.data();
      const distance = haversineKm(center, data.location);
      return Number.isFinite(distance) && Number.isFinite(data.travelRadiusKm)
        ? data.travelRadiusKm - distance : -1;
    }));
    if (!Number.isFinite(radiusKm) || radiusKm <= 0) return view;
    return { ...view, venueSearch: {
      countryCode: center.countryCode, cityId: center.cityId, city: center.city,
      latitude: center.latitude, longitude: center.longitude,
      radiusKm: Math.floor(radiusKm * 100) / 100,
    } };
  }));
  return { requests: requests.docs.map((document) => document.data()),
    proposals: enrichedProposals };
}

async function writeReliabilityEvent(firestore, event) {
  const reference = firestore.doc(`${RELIABILITY_EVENTS}/${event.eventId}`);
  await firestore.runTransaction(async (transaction) => {
    if (!(await transaction.get(reference)).exists) transaction.create(reference, event);
  });
}

// Trigger handler: records only objective committed changes. It never infers a
// no-show and never assigns financial or public scoring consequences.
export async function handleMatchCommitmentWritten(firestore, event, now = new Date()) {
  const before = event.data?.before?.data?.() ?? null;
  const after = event.data?.after?.data?.() ?? null;
  if (!before) return;
  if (!after) await firestore.doc(`${MATCH_PRIVATE_VENUES}/${event.params.matchId}`).delete();
  const beforeMembers = [...new Set(before.participantUids ?? [])].filter(validRelationshipUid);
  const afterMembers = [...new Set(after?.participantUids ?? [])].filter(validRelationshipUid);
  const removed = beforeMembers.filter((uid) => !afterMembers.includes(uid));
  const scheduledAt = before.scheduledAt?.toDate?.();
  if (!scheduledAt || scheduledAt <= now || removed.length === 0) return;
  const type = after ? 'confirmed_match_cancelled' : 'match_cancelled';
  for (const uid of removed) {
    const eventId = digest(`${event.params.matchId}\0${uid}\0${type}`);
    await writeReliabilityEvent(firestore, { schemaVersion: 1, eventId, uid, type,
      matchId: event.params.matchId, scheduledAt,
      timingCategory: cancellationTimingCategory(scheduledAt, now),
      occurredAt: now, source: 'match_lifecycle' });
  }
  if (!after || after.autoFillEnabled !== true || !text(after.autoFillRequestId, 128)
      || !Number.isSafeInteger(after.spotsLeft) || after.spotsLeft < 1) return;
  const reference = requestRef(firestore, after.autoFillRequestId);
  const reactivated = await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data();
    if (!snapshot.exists || data.mode !== 'autofill' || data.sourceMatchId !== event.params.matchId) return null;
    const remainsOffered = data.status === 'matched' && text(data.proposalId, 128);
    const update = { status: remainsOffered ? 'matched' : 'active', memberUids: afterMembers,
      vacancyCount: after.spotsLeft, ...(remainsOffered ? {} : { proposalId: null }), updatedAt: now };
    transaction.update(reference, update);
    for (const memberUid of afterMembers) transaction.set(requestView(firestore, memberUid, reference.id),
      { status: update.status, ...(remainsOffered ? {} : { proposalId: null }), updatedAt: now }, { merge: true });
    return remainsOffered ? null : { ...data, ...update };
  });
  if (reactivated) await attemptMatchmaking(firestore, reactivated, now);
}

export async function recoverExpiredMatchmaking(firestore, now = new Date(), limit = 50) {
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 50) throw new Error('Invalid recovery limit.');
  const [proposalPage, requestPage] = await Promise.all([
    firestore.collection(MATCHMAKING_PROPOSALS).where('status', '==', 'confirming')
      .where('expiresAt', '<=', now).orderBy('expiresAt').limit(limit).get(),
    firestore.collection(MATCHMAKING_REQUESTS).where('status', 'in', ['awaiting_partner', 'active'])
      .where('expiresAt', '<=', now).orderBy('expiresAt').limit(limit).get(),
  ]);
  for (const proposalDocument of proposalPage.docs) {
    const current = proposalDocument.data();
    if (!current.sourceMatchId) {
      const expiredMembers = current.memberUids.filter((uid) => current.confirmations?.[uid] === 'offered');
      for (const uid of expiredMembers) {
        const latest = (await proposalDocument.ref.get()).data();
        if (latest?.status !== 'confirming' || !latest.memberUids?.includes(uid)
            || latest.confirmations?.[uid] !== 'offered') continue;
        await releaseQuickMatchReservation(firestore, { proposalId: proposalDocument.id, uid,
          response: 'expired', eventId: digest(`${proposalDocument.id}\0${uid}\0expired`), now });
      }
      continue;
    }
    await firestore.runTransaction(async (transaction) => {
      const proposal = await transaction.get(proposalDocument.ref);
      const data = proposal.data();
      if (!proposal.exists || data.status !== 'confirming' || data.expiresAt.toDate() > now) return;
      const sourceRequests = await transaction.getAll(
        ...data.sourceRequestIds.map((sourceRequestId) => requestRef(firestore, sourceRequestId)),
      );
      const confirmations = { ...data.confirmations };
      for (const uid of data.memberUids) if (confirmations[uid] === 'offered') confirmations[uid] = 'expired';
      transaction.update(proposal.ref, { status: 'expired', confirmations, updatedAt: now });
      for (const uid of data.memberUids) {
        transaction.set(proposalView(firestore, uid, proposal.id),
          { status: 'expired', confirmation: confirmations[uid], updatedAt: now }, { merge: true });
        if (confirmations[uid] === 'expired') {
          const eventId = digest(`${proposal.id}\0${uid}\0expired`);
          const eventRef = firestore.doc(`${RELIABILITY_EVENTS}/${eventId}`);
          transaction.create(eventRef, {
            schemaVersion: 1, eventId, uid, type: 'proposal_expired', proposalId: proposal.id,
            occurredAt: now, source: 'matchmaking',
          });
        }
      }
      for (const source of sourceRequests) {
        const requestData = source.data();
        transaction.update(source.ref, { status: 'active', proposalId: null, updatedAt: now });
        for (const uid of requestData.memberUids) transaction.set(requestView(firestore, uid, source.id),
          { status: 'active', proposalId: null, updatedAt: now }, { merge: true });
      }
    });
  }
  for (const requestDocument of requestPage.docs) {
    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(requestDocument.ref);
      const data = snapshot.data();
      if (!snapshot.exists || !['awaiting_partner', 'active'].includes(data.status)
          || data.expiresAt.toDate() > now) return;
      transaction.update(snapshot.ref, { status: 'expired', updatedAt: now });
      transaction.set(firestore.doc(`${MATCHMAKING_ACTIVE_OWNERS}/${data.ownerUid}`),
        { ownerUid: data.ownerUid, activeRequestId: snapshot.id, status: 'expired', updatedAt: now });
      for (const uid of data.memberUids) transaction.set(requestView(firestore, uid, snapshot.id),
        { status: 'expired', updatedAt: now }, { merge: true });
    });
  }
  const activePage = await firestore.collection(MATCHMAKING_REQUESTS)
    .where('status', '==', 'active').where('expiresAt', '>', now)
    .orderBy('expiresAt').limit(Math.min(limit, 5)).get();
  for (const document of activePage.docs) await attemptMatchmaking(firestore, document.data(), now);
  return { proposals: proposalPage.size, requests: requestPage.size,
    matchmakingAttempts: activePage.size };
}
