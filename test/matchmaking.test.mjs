import { after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { blockId } from '../functions/friendship_policy.js';
import { cancelMatchmakingRequestOperation, createMatchmakingRequestOperation, getMatchmakingStateOperation,
  handleMatchCommitmentWritten, leaveMatchOperation, respondMatchProposalOperation,
  recoverExpiredMatchmaking, respondPartnerInvitationOperation,
  resolveMatchmakingVenueOperation } from '../functions/matchmaking.js';

assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Firestore emulator is required');
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'Auth emulator is required');
const projectId = 'demo-padelx-matchmaking';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
const app = initializeApp({ projectId }, 'matchmaking-tests');
const db = getFirestore(app);
after(() => deleteApp(app));

const now = new Date('2030-01-01T12:00:00Z');
const request = (uid, data) => ({ auth: { uid, token: { email_verified: true } }, data,
  rawRequest: { matchmakingNow: now } });
const availability = [{ earliestStart: '2030-01-02T18:00:00Z', latestStart: '2030-01-02T22:00:00Z' }];
const payload = (suffix, overrides = {}) => ({ requestId: `request_${suffix}_12345678`, mode: 'solo',
  availability, timezone: 'America/Mexico_City', travelRadiusKm: 20,
  preferredSide: 'either', ...overrides });

async function seed(uid, { level = '3.5', side = 'either' } = {}) {
  const location = { country: 'Mexico', countryCode: 'MX', city: 'Ciudad de México',
    cityId: 'places-mexico-city', area: '', latitude: 19.43, longitude: -99.13 };
  await Promise.all([
    db.doc(`users/${uid}`).set({ uid, active: true, discoveryLocation: location }),
    db.doc(`publicProfiles/${uid}`).set({ uid, displayName: `Player ${uid.at(-1)}`, level,
      preferredSide: side, countryCode: 'MX', city: 'Mexico City', cityId: 'places-mexico-city',
      area: '', discoverable: true }),
    db.doc(`accountEligibility/${uid}`).set({ uid, schemaVersion: 1, age18Confirmed: true,
      ageEligibilityVersion: '18-plus-v1', confirmedAt: Timestamp.fromDate(now) }),
    db.doc(`accountLegalAcceptance/${uid}`).set({ uid, schemaVersion: 1,
      termsVersion: 'terms-beta-v2', privacyVersion: 'privacy-beta-v2',
      communityVersion: 'community-beta-v2', acceptedAt: Timestamp.fromDate(now) }),
  ]);
}

beforeEach(async () => {
  const collections = ['users', 'publicProfiles', 'accountEligibility', 'accountLegalAcceptance',
    'accountDeletionBarriers', 'accountEnforcement', 'blocks', 'matches', 'matchmakingRequests',
    'matchmakingActiveOwners', 'matchProposals', 'matchPrivateVenues', 'reliabilityEvents',
    'reliabilityProfiles', 'notifications'];
  for (const name of collections) {
    const documents = await db.collection(name).listDocuments();
    await Promise.all(documents.map((document) => document.delete()));
  }
});

test('four eligible solo requests form one bounded free proposal', async () => {
  for (const uid of ['player-1', 'player-2', 'player-3', 'player-4']) await seed(uid);
  const results = [];
  for (const [index, uid] of ['player-1', 'player-2', 'player-3', 'player-4'].entries()) {
    results.push(await createMatchmakingRequestOperation(db, request(uid, payload(`solo_${index}`))));
  }
  assert.equal((await db.collection('matchProposals').get()).size, 1);
  const proposal = (await db.collection('matchProposals').get()).docs[0];
  assert.equal('paymentRequirement' in proposal.data(), false);
  assert.equal(proposal.data().venueStatus, 'needed');
  assert.equal(proposal.data().memberUids.length, 4);
  assert.ok(results.at(-1).proposalId);
  for (const [index, uid] of ['player-1', 'player-2', 'player-3', 'player-4'].entries()) {
    const response = await respondMatchProposalOperation(db, request(uid, {
      proposalId: proposal.id, accept: true, requestId: `accept_${index}_123456789`,
    }));
    assert.equal(response.confirmation, 'accepted');
  }
  assert.equal((await proposal.ref.get()).data().status, 'venue_needed');
  assert.equal((await db.collection('reliabilityEvents').get()).size, 4);
  const coordinatorUid = (await proposal.ref.get()).data().coordinatorUid;
  const coordinatorState = await getMatchmakingStateOperation(db, request(coordinatorUid, {}));
  const coordinatorProposal = coordinatorState.proposals.find((item) => item.proposalId === proposal.id);
  assert.deepEqual(coordinatorProposal.venueSearch, {
    countryCode: 'MX', cityId: 'places-mexico-city', city: 'Ciudad de México',
    latitude: 19.43, longitude: -99.13, radiusKm: 20,
  });
  const otherUid = ['player-1', 'player-2', 'player-3', 'player-4']
    .find((uid) => uid !== coordinatorUid);
  const otherState = await getMatchmakingStateOperation(db, request(otherUid, {}));
  assert.equal('venueSearch' in otherState.proposals.find((item) => item.proposalId === proposal.id), false);
  // The confirmation deadline may pass while an already-confirmed group is
  // choosing a venue. That completed phase must not invalidate promotion.
  await proposal.ref.update({ expiresAt: Timestamp.fromDate(new Date('2029-12-31T23:59:00Z')) });
  const promoted = await resolveMatchmakingVenueOperation(db, request(coordinatorUid, {
    proposalId: proposal.id, requestId: 'venue_public_12345678', venue: {
      type: 'club_public', label: 'Central Padel Club', placeId: 'place-central',
      address: 'Central Padel Club, Mexico City',
      latitude: 19.431, longitude: -99.131, countryCode: 'MX', cityId: 'places-mexico-city',
      city: 'Mexico City', area: 'Centro',
    },
  }));
  const match = (await db.doc(`matches/${promoted.matchId}`).get()).data();
  assert.equal(match.source, 'matchmaking');
  assert.equal(match.venueType, 'club_public');
  assert.equal(match.location.placeId, 'place-central');
  assert.equal(match.location.formattedAddress, 'Central Padel Club, Mexico City');
  assert.equal(match.location.latitude, 19.431);
  assert.equal(match.location.cityId, 'places-mexico-city');
  assert.equal(match.participantUids.length, 4);
  assert.equal(match.teams.length, 2);
  assert.deepEqual(match.teams.map((team) => team.participantUids.length), [2, 2]);
  assert.deepEqual(new Set(match.teams.flatMap((team) => team.participantUids)),
    new Set(match.participantUids));
  assert.equal((await db.collection('matchPrivateVenues').get()).empty, true);
  const commitmentEvents = await db.collection('reliabilityEvents')
    .where('type', '==', 'confirmed_match_committed').get();
  assert.equal(commitmentEvents.size, 4);
  assert.deepEqual(new Set(commitmentEvents.docs.map((document) => document.data().uid)),
    new Set(match.participantUids));
  const notifications = await db.collection('notifications').get();
  assert.equal(notifications.docs.filter((document) =>
    document.data().type === 'matchmaking_match_found').length, 4);
  assert.equal(notifications.docs.filter((document) =>
    document.data().type === 'matchmaking_match_confirmed').length, 4);
  assert.ok(notifications.docs.every((document) => !JSON.stringify(document.data()).includes('address')));
  const replay = await resolveMatchmakingVenueOperation(db, request(coordinatorUid, {
    proposalId: proposal.id, requestId: 'venue_public_replay_12345678', venue: {
      type: 'club_public', label: 'Central Padel Club', placeId: 'place-central',
      latitude: 19.431, longitude: -99.131, countryCode: 'MX', cityId: 'places-mexico-city',
      city: 'Mexico City', area: 'Centro',
    },
  }));
  assert.equal(replay.matchId, promoted.matchId);
  assert.equal((await db.collection('matches').get()).size, 1);
});

test('promoted canonical match can activate AutoFill after a participant leaves', async () => {
  const uids = ['promoted-1', 'promoted-2', 'promoted-3', 'promoted-4'];
  for (const uid of uids) await seed(uid);
  for (const [index, uid] of uids.entries()) {
    await createMatchmakingRequestOperation(db, request(uid, payload(`promoted_${index}`)));
  }
  const proposal = (await db.collection('matchProposals').get()).docs[0];
  for (const [index, uid] of uids.entries()) await respondMatchProposalOperation(db, request(uid, {
    proposalId: proposal.id, accept: true, requestId: `promoted_accept_${index}_123456`,
  }));
  const coordinatorUid = (await proposal.ref.get()).data().coordinatorUid;
  const promoted = await resolveMatchmakingVenueOperation(db, request(coordinatorUid, {
    proposalId: proposal.id, requestId: 'promoted_venue_12345678', venue: {
      type: 'club_public', label: 'Promotion Regression Club', placeId: 'promotion-place',
      latitude: 19.431, longitude: -99.131, countryCode: 'MX', cityId: 'places-mexico-city',
      city: 'Ciudad de México', areaId: 'area-centro', area: 'Centro',
    },
  }));
  const promotedReference = db.doc(`matches/${promoted.matchId}`);
  const promotedMatch = (await promotedReference.get()).data();
  assert.equal(promotedMatch.location.cityId, 'places-mexico-city');
  assert.equal(promotedMatch.location.areaId, 'area-centro');
  const legacyLocation = { ...promotedMatch.location };
  delete legacyLocation.cityId;
  delete legacyLocation.areaId;
  await promotedReference.update({ location: legacyLocation });
  const departingUid = uids.find((uid) => uid !== coordinatorUid);
  await leaveMatchOperation(db, request(departingUid, {
    matchId: promoted.matchId, requestId: 'promoted_leave_12345678',
  }));
  await seed('promoted-replacement');
  await createMatchmakingRequestOperation(db,
    request('promoted-replacement', payload('promoted_replacement')));

  const autofillInput = payload('promoted_autofill', {
    mode: 'autofill', sourceMatchId: promoted.matchId, autoFillAfterCancellation: true,
  });
  const autofill = await createMatchmakingRequestOperation(db, request(coordinatorUid, autofillInput));
  assert.ok(autofill.proposalId);
  const replay = await createMatchmakingRequestOperation(db, request(coordinatorUid, autofillInput));
  assert.equal(replay.requestId, autofill.requestId);
  assert.equal(replay.proposalId, autofill.proposalId);

  const match = (await promotedReference.get()).data();
  assert.equal(match.participantUids.length, 3);
  assert.equal(match.spotsLeft, 1);
  assert.equal(match.autoFillEnabled, true);
  assert.equal((await db.collection('matchmakingRequests')
    .where('sourceMatchId', '==', promoted.matchId).get()).size, 1);
  assert.equal((await db.collection('matchProposals')
    .where('sourceMatchId', '==', promoted.matchId).get()).size, 1);
  const requestSnapshot = await db.collection('matchmakingRequests')
    .where('sourceMatchId', '==', promoted.matchId).limit(1).get();
  assert.equal(requestSnapshot.docs[0].data().cityKey, 'MX:places-mexico-city');
});

test('private venue promotion is atomic, minimized, and race-idempotent', async () => {
  const uids = ['private-1', 'private-2', 'private-3', 'private-4'];
  for (const uid of uids) await seed(uid);
  for (const [index, uid] of uids.entries()) {
    await createMatchmakingRequestOperation(db, request(uid, payload(`private_${index}`)));
  }
  const proposal = (await db.collection('matchProposals').get()).docs[0];
  for (const [index, uid] of uids.entries()) await respondMatchProposalOperation(db, request(uid, {
    proposalId: proposal.id, accept: true, requestId: `private_accept_${index}_123456`,
  }));
  const coordinatorUid = (await proposal.ref.get()).data().coordinatorUid;
  const input = { proposalId: proposal.id, requestId: 'private_venue_12345678', venue: {
    type: 'private_free', label: 'Private court', placeId: 'private-address-place',
    address: 'Synthetic test address',
    latitude: 19.432, longitude: -99.132, countryCode: 'MX', cityId: 'places-mexico-city',
    city: 'Ciudad de México', areaId: 'area-test', area: 'Polanco',
  } };
  const [left, right] = await Promise.all([
    resolveMatchmakingVenueOperation(db, request(coordinatorUid, input)),
    resolveMatchmakingVenueOperation(db, request(coordinatorUid, { ...input,
      requestId: 'private_venue_race_12345678' })),
  ]);
  assert.equal(left.matchId, right.matchId);
  assert.equal((await db.collection('matches').get()).size, 1);
  assert.equal((await db.collection('matchPrivateVenues').get()).size, 1);
  const match = (await db.doc(`matches/${left.matchId}`).get()).data();
  assert.equal(match.venueType, 'private_free');
  assert.equal('address' in match.location, false);
  assert.equal('latitude' in match.location, false);
  assert.equal('longitude' in match.location, false);
  const exact = (await db.doc(`matchPrivateVenues/${left.matchId}`).get()).data();
  assert.equal(exact.address, 'Synthetic test address');
  assert.equal(Object.keys(exact).some((key) => /email|gate|access|message/i.test(key)), false);
  for (const uid of uids) {
    assert.equal((await db.doc(`matchmakingActiveOwners/${uid}`).get()).data().status, 'confirmed');
  }
  const publicState = JSON.stringify({ match,
    proposalViews: (await db.collectionGroup('matchProposalViews').get()).docs.map((doc) => doc.data()),
    events: (await db.collection('reliabilityEvents').get()).docs.map((doc) => doc.data()),
    notifications: (await db.collection('notifications').get()).docs.map((doc) => doc.data()) });
  assert.equal(publicState.includes('Synthetic test address'), false);
  assert.equal(publicState.includes('19.432'), false);

  const departingUid = uids.find((uid) => uid !== coordinatorUid);
  await leaveMatchOperation(db, request(departingUid, {
    matchId: left.matchId, requestId: 'private_leave_12345678',
  }));
  await seed('private-replacement');
  await createMatchmakingRequestOperation(db,
    request('private-replacement', payload('private_replacement')));
  const autofill = await createMatchmakingRequestOperation(db, request(coordinatorUid,
    payload('private_autofill', { mode: 'autofill', sourceMatchId: left.matchId,
      autoFillAfterCancellation: true })));
  assert.ok(autofill.proposalId);
  const replacementView = (await db.doc(
    `users/private-replacement/matchProposalViews/${autofill.proposalId}`,
  ).get()).data();
  assert.equal(JSON.stringify(replacementView).includes('Synthetic test address'), false);
  assert.equal(JSON.stringify(replacementView).includes('19.432'), false);
});

test('promotion rechecks enforcement, deletion, blocks, conflicts, and travel', async () => {
  const uids = ['guard-1', 'guard-2', 'guard-3', 'guard-4'];
  for (const uid of uids) await seed(uid);
  for (const [index, uid] of uids.entries()) {
    await createMatchmakingRequestOperation(db, request(uid, payload(`guard_${index}`)));
  }
  const proposal = (await db.collection('matchProposals').get()).docs[0];
  for (const [index, uid] of uids.entries()) await respondMatchProposalOperation(db, request(uid, {
    proposalId: proposal.id, accept: true, requestId: `guard_accept_${index}_123456`,
  }));
  const coordinatorUid = (await proposal.ref.get()).data().coordinatorUid;
  const venue = { type: 'club_public', label: 'Guard Test Club', placeId: 'guard-place',
    latitude: 19.432, longitude: -99.132, countryCode: 'MX', cityId: 'places-mexico-city',
    city: 'Mexico City', area: '', };
  const promote = (suffix) => resolveMatchmakingVenueOperation(db, request(coordinatorUid, {
    proposalId: proposal.id, requestId: `guard_venue_${suffix}_12345678`, venue,
  }));

  await db.doc('accountEnforcement/guard-2').set({ schemaVersion: 1, uid: 'guard-2',
    status: 'banned', reasonCode: 'other_policy_violation' });
  await assert.rejects(promote('enforced'), { code: 'failed-precondition' });
  await db.doc('accountEnforcement/guard-2').delete();
  await db.doc('accountDeletionBarriers/guard-2').set({ uid: 'guard-2' });
  await assert.rejects(promote('deleting'), { code: 'failed-precondition' });
  await db.doc('accountDeletionBarriers/guard-2').delete();
  await db.doc(`blocks/${blockId('guard-2', 'guard-3')}`).set({ blockerUid: 'guard-2', blockedUid: 'guard-3' });
  await assert.rejects(promote('blocked'), { code: 'failed-precondition' });
  await db.doc(`blocks/${blockId('guard-2', 'guard-3')}`).delete();
  await db.doc('matches/conflicting').set({ participantUids: ['guard-2'],
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:30:00Z')) });
  await assert.rejects(promote('conflict'), { code: 'failed-precondition' });
  await db.doc('matches/conflicting').delete();
  await assert.rejects(resolveMatchmakingVenueOperation(db, request(coordinatorUid, {
    proposalId: proposal.id, requestId: 'guard_venue_far_12345678',
    venue: { ...venue, latitude: 20.7, longitude: -103.3 },
  })), { code: 'failed-precondition' });
  await assert.rejects(resolveMatchmakingVenueOperation(db, request(coordinatorUid, {
    proposalId: proposal.id, requestId: 'guard_venue_forged_12345678', venue,
  }), async () => ({ placeId: venue.placeId, formattedAddress: 'Verified address',
    countryCode: 'MX', latitude: 20.7, longitude: -103.3 })),
  { code: 'failed-precondition' });
  assert.equal((await db.collection('matches').get()).size, 0);
  assert.equal((await proposal.ref.get()).data().status, 'venue_needed');
  for (const uid of uids) {
    const lock = (await db.doc(`matchmakingActiveOwners/${uid}`).get()).data();
    assert.notEqual(lock.activeRequestId, null);
  }
  const guardedSources = await db.collection('matchmakingRequests').get();
  assert.ok(guardedSources.docs.every((source) => source.data().status === 'matched'));
});

test('partner request requires explicit consent and respects blocks', async () => {
  await seed('owner-1'); await seed('partner-2');
  const created = await createMatchmakingRequestOperation(db, request('owner-1', payload('partner', {
    mode: 'partner', partnerUid: 'partner-2',
  })));
  assert.equal(created.status, 'awaiting_partner');
  const invitation = (await db.collection('notifications')
    .where('type', '==', 'matchmaking_partner_invite').get()).docs[0].data();
  assert.equal(invitation.recipientUid, 'partner-2');
  assert.equal('actorUid' in invitation, false);
  const accepted = await respondPartnerInvitationOperation(db, request('partner-2', {
    requestId: created.requestId, accept: true,
  }));
  assert.equal(accepted.status, 'active');

  await seed('owner-3'); await seed('partner-4');
  await db.doc(`blocks/${blockId('partner-4', 'owner-3')}`).set({ blockerUid: 'partner-4', blockedUid: 'owner-3' });
  await assert.rejects(createMatchmakingRequestOperation(db, request('owner-3', payload('blocked_partner', {
    mode: 'partner', partnerUid: 'partner-4',
  }))), { code: 'failed-precondition' });
});

test('consented partner pair reaches canonical match together with two solo players', async () => {
  const uids = ['pair-owner', 'pair-partner', 'pair-solo-one', 'pair-solo-two'];
  for (const uid of uids) await seed(uid);
  const pair = await createMatchmakingRequestOperation(db, request('pair-owner', payload('pair_e2e', {
    mode: 'partner', partnerUid: 'pair-partner',
  })));
  assert.equal((await db.collection('matchProposals').get()).empty, true);
  await respondPartnerInvitationOperation(db, request('pair-partner', {
    requestId: pair.requestId, accept: true,
  }));
  await createMatchmakingRequestOperation(db, request('pair-solo-one', payload('pair_solo_one')));
  const finalSolo = await createMatchmakingRequestOperation(db,
    request('pair-solo-two', payload('pair_solo_two')));
  assert.ok(finalSolo.proposalId);
  const proposalRef = db.doc(`matchProposals/${finalSolo.proposalId}`);
  const proposal = (await proposalRef.get()).data();
  assert.equal(proposal.teamAssignments['pair-owner'], proposal.teamAssignments['pair-partner']);
  for (const [index, uid] of uids.entries()) await respondMatchProposalOperation(db, request(uid, {
    proposalId: finalSolo.proposalId, accept: true, requestId: `pair_accept_${index}_12345678`,
  }));
  assert.equal((await proposalRef.get()).data().status, 'venue_needed');
  const promoted = await resolveMatchmakingVenueOperation(db, request(proposal.coordinatorUid, {
    proposalId: finalSolo.proposalId, requestId: 'pair_venue_12345678', venue: {
      type: 'club_public', label: 'Partner Test Club', placeId: 'partner-test-place',
      latitude: 19.431, longitude: -99.131, countryCode: 'MX', cityId: 'places-mexico-city',
      city: 'Ciudad de México', area: '',
    },
  }));
  const match = (await db.doc(`matches/${promoted.matchId}`).get()).data();
  const pairTeam = match.teams.find((team) => team.participantUids.includes('pair-owner'));
  assert.ok(pairTeam.participantUids.includes('pair-partner'));
  for (const uid of uids) {
    assert.equal((await db.doc(`matchmakingActiveOwners/${uid}`).get()).data().status, 'confirmed');
  }
});

test('deletion and enforcement exclude request creation', async () => {
  await seed('deleting-1');
  await db.doc('accountDeletionBarriers/deleting-1').set({ uid: 'deleting-1' });
  await assert.rejects(createMatchmakingRequestOperation(db, request('deleting-1', payload('deleting'))),
    { code: 'permission-denied' });
  await seed('banned-2');
  await db.doc('accountEnforcement/banned-2').set({ schemaVersion: 1, uid: 'banned-2',
    status: 'banned', reasonCode: 'other_policy_violation' });
  await assert.rejects(createMatchmakingRequestOperation(db, request('banned-2', payload('banned'))),
    { code: 'permission-denied' });
});

test('AutoFill preserves existing participants and fills only an open spot', async () => {
  await seed('candidate-1'); await seed('organizer-2');
  const candidate = await createMatchmakingRequestOperation(db,
    request('candidate-1', payload('candidate')));
  await db.doc('matches/match-one').set({ creatorUid: 'organizer-2', participantUids: ['organizer-2'],
    players: [], spotsLeft: 3, scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', location: { countryCode: 'MX', cityId: 'places-mexico-city',
      city: 'Mexico City', area: '', latitude: 19.43, longitude: -99.13 } });
  const autofill = await createMatchmakingRequestOperation(db, request('organizer-2', payload('autofill', {
    mode: 'autofill', sourceMatchId: 'match-one', autoFillAfterCancellation: true,
  })));
  assert.ok(autofill.proposalId);
  assert.equal((await db.collection('notifications')
    .where('type', '==', 'matchmaking_replacement_found').get()).size, 1);
  const autofillRequest = (await db.doc(`matchmakingRequests/${autofill.requestId}`).get()).data();
  assert.equal(autofillRequest.cityKey, 'MX:places-mexico-city');
  assert.equal(autofillRequest.availability[0].earliestStart.toDate().toISOString(),
    '2030-01-02T18:00:00.000Z');
  await respondMatchProposalOperation(db, request('candidate-1', {
    proposalId: autofill.proposalId, accept: true, requestId: 'accept_autofill_123456',
  }));
  const match = (await db.doc('matches/match-one').get()).data();
  assert.deepEqual(match.participantUids, ['organizer-2', 'candidate-1']);
  assert.equal(match.spotsLeft, 2);
  assert.equal(match.players[0].uid, 'candidate-1');
  assert.equal((await db.doc(`matchmakingRequests/${candidate.requestId}`).get()).data().status, 'confirmed');
  assert.equal((await db.collection('reliabilityEvents')
    .where('type', '==', 'replacement_found').get()).size, 1);
});

test('active AutoFill immediately claims a compatible Solo request that arrives later', async () => {
  await seed('later-organizer'); await seed('later-candidate');
  await db.doc('matches/autofill-later').set({ creatorUid: 'later-organizer',
    participantUids: ['later-organizer'], players: [], spotsLeft: 1,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', autoFillEnabled: false, autoFillRequestId: null,
    location: { countryCode: 'MX', cityId: 'places-mexico-city', city: 'Mexico City',
      area: '', latitude: 19.43, longitude: -99.13 } });
  const autofill = await createMatchmakingRequestOperation(db, request('later-organizer',
    payload('autofill_later', { mode: 'autofill', sourceMatchId: 'autofill-later',
      autoFillAfterCancellation: true })));
  assert.equal(autofill.proposalId, null);
  const candidate = await createMatchmakingRequestOperation(db,
    request('later-candidate', payload('candidate_later')));
  assert.ok(candidate.proposalId);
  const proposal = (await db.doc(`matchProposals/${candidate.proposalId}`).get()).data();
  assert.equal(proposal.sourceMatchId, 'autofill-later');
  assert.deepEqual(proposal.memberUids, ['later-candidate']);
  assert.equal((await db.doc(`matchmakingRequests/${autofill.requestId}`).get()).data().status, 'matched');
});

test('AutoFill priority does not split a pair or starve ordinary Solo formation', async () => {
  for (const uid of ['priority-organizer', 'pair-owner-priority', 'pair-partner-priority',
    'ordinary-1', 'ordinary-2', 'ordinary-3', 'ordinary-4']) await seed(uid);
  await db.doc('matches/autofill-priority').set({ creatorUid: 'priority-organizer',
    participantUids: ['priority-organizer'], players: [], spotsLeft: 1,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', autoFillEnabled: false, autoFillRequestId: null,
    location: { countryCode: 'MX', cityId: 'places-mexico-city', city: 'Mexico City',
      area: '', latitude: 19.43, longitude: -99.13 } });
  const autofill = await createMatchmakingRequestOperation(db, request('priority-organizer',
    payload('autofill_priority', { mode: 'autofill', sourceMatchId: 'autofill-priority',
      autoFillAfterCancellation: true })));
  const pair = await createMatchmakingRequestOperation(db, request('pair-owner-priority',
    payload('pair_priority', { mode: 'partner', partnerUid: 'pair-partner-priority' })));
  await respondPartnerInvitationOperation(db, request('pair-partner-priority', {
    requestId: pair.requestId, accept: true,
  }));
  assert.equal((await db.doc(`matchmakingRequests/${autofill.requestId}`).get()).data().status, 'active');
  assert.equal((await db.doc(`matchmakingRequests/${pair.requestId}`).get()).data().status, 'active');
  await cancelMatchmakingRequestOperation(db,
    request('pair-owner-priority', { requestId: pair.requestId }));

  // Make the urgent vacancy incompatible; ordinary compatible Solos must still
  // form their own proposal instead of being held behind AutoFill.
  await db.doc(`matchmakingRequests/${autofill.requestId}`).update({ level: 'Level 7' });
  let final;
  for (let index = 1; index <= 4; index++) final = await createMatchmakingRequestOperation(db,
    request(`ordinary-${index}`, payload(`ordinary_priority_${index}`)));
  assert.ok(final.proposalId);
  const normal = (await db.doc(`matchProposals/${final.proposalId}`).get()).data();
  assert.equal(normal.sourceMatchId, undefined);
  assert.equal(normal.memberUids.length, 4);
});

test('concurrent Solo arrivals claim at most one final AutoFill vacancy', async () => {
  for (const uid of ['race-fill-organizer', 'race-fill-one', 'race-fill-two']) await seed(uid);
  await db.doc('matches/autofill-race-final').set({ creatorUid: 'race-fill-organizer',
    participantUids: ['race-fill-organizer'], players: [], spotsLeft: 1,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', autoFillEnabled: false, autoFillRequestId: null,
    location: { countryCode: 'MX', cityId: 'places-mexico-city', city: 'Mexico City',
      area: '', latitude: 19.43, longitude: -99.13 } });
  await createMatchmakingRequestOperation(db, request('race-fill-organizer',
    payload('autofill_race_final', { mode: 'autofill', sourceMatchId: 'autofill-race-final',
      autoFillAfterCancellation: true })));
  const results = await Promise.all([
    createMatchmakingRequestOperation(db, request('race-fill-one', payload('race_fill_one'))),
    createMatchmakingRequestOperation(db, request('race-fill-two', payload('race_fill_two'))),
  ]);
  const proposals = await db.collection('matchProposals')
    .where('sourceMatchId', '==', 'autofill-race-final').get();
  assert.equal(proposals.size, 1);
  assert.equal(results.filter((result) => result.proposalId).length, 1);
  const requests = await db.collection('matchmakingRequests').where('mode', '==', 'solo').get();
  assert.equal(requests.docs.filter((document) => document.data().status === 'matched').length, 1);
  assert.equal(requests.docs.filter((document) => document.data().status === 'active').length, 1);
});

test('recovery joins pre-existing compatible AutoFill and Solo requests safely', async () => {
  await seed('recover-fill-organizer'); await seed('recover-fill-candidate', { level: '7' });
  await db.doc('matches/autofill-recover-existing').set({ creatorUid: 'recover-fill-organizer',
    participantUids: ['recover-fill-organizer'], players: [], spotsLeft: 1,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', autoFillEnabled: false, autoFillRequestId: null,
    location: { countryCode: 'MX', cityId: 'places-mexico-city', city: 'Mexico City',
      area: '', latitude: 19.43, longitude: -99.13 } });
  const autofill = await createMatchmakingRequestOperation(db, request('recover-fill-organizer',
    payload('autofill_recover_existing', { mode: 'autofill',
      sourceMatchId: 'autofill-recover-existing', autoFillAfterCancellation: true })));
  const candidate = await createMatchmakingRequestOperation(db,
    request('recover-fill-candidate', payload('recover_fill_candidate')));
  assert.equal(candidate.proposalId, null);
  await db.doc(`matchmakingRequests/${candidate.requestId}`).update({ level: '3.5' });
  await recoverExpiredMatchmaking(db, now);
  const recovered = (await db.doc(`matchmakingRequests/${candidate.requestId}`).get()).data();
  assert.equal(recovered.status, 'matched');
  assert.equal(typeof recovered.proposalId, 'string');
  assert.equal((await db.doc(`matchmakingRequests/${autofill.requestId}`).get()).data().status, 'matched');
});

test('manual vacancy fill wins safely before a late Solo request', async () => {
  await seed('filled-organizer'); await seed('filled-candidate');
  await db.doc('matches/autofill-manually-filled').set({ creatorUid: 'filled-organizer',
    participantUids: ['filled-organizer'], players: [], spotsLeft: 1,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', autoFillEnabled: false, autoFillRequestId: null,
    location: { countryCode: 'MX', cityId: 'places-mexico-city', city: 'Mexico City',
      area: '', latitude: 19.43, longitude: -99.13 } });
  await createMatchmakingRequestOperation(db, request('filled-organizer',
    payload('autofill_manually_filled', { mode: 'autofill',
      sourceMatchId: 'autofill-manually-filled', autoFillAfterCancellation: true })));
  await db.doc('matches/autofill-manually-filled').update({ spotsLeft: 0,
    participantUids: ['filled-organizer', 'manual-player'], autoFillEnabled: false,
    autoFillRequestId: null });
  const candidate = await createMatchmakingRequestOperation(db,
    request('filled-candidate', payload('candidate_after_manual_fill')));
  assert.equal(candidate.proposalId, null);
  assert.equal((await db.doc(`matchmakingRequests/${candidate.requestId}`).get()).data().status, 'active');
  assert.equal((await db.collection('matchProposals')
    .where('sourceMatchId', '==', 'autofill-manually-filled').get()).size, 0);
});

test('AutoFill activation denies non-organizer, full, cancelled, and past matches atomically', async () => {
  for (const uid of ['autofill-owner', 'autofill-other']) await seed(uid);
  const eligible = {
    creatorUid: 'autofill-owner', participantUids: ['autofill-owner'], players: [], spotsLeft: 1,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', autoFillEnabled: false, autoFillRequestId: null,
    location: { countryCode: 'MX', cityId: 'places-mexico-city', city: 'Mexico City',
      area: '', latitude: 19.43, longitude: -99.13 },
  };
  for (const [id, changes] of Object.entries({
    eligible: {}, full: { spotsLeft: 0 }, cancelled: { status: 'cancelled' },
    past: { scheduledAt: Timestamp.fromDate(new Date('2029-12-31T18:00:00Z')) },
  })) await db.doc(`matches/autofill-${id}`).set({ ...eligible, ...changes });

  const create = (uid, id) => createMatchmakingRequestOperation(db, request(uid,
    payload(`guard_${uid}_${id}`, { mode: 'autofill', sourceMatchId: `autofill-${id}` })));
  await assert.rejects(create('autofill-other', 'eligible'), { code: 'failed-precondition' });
  await assert.rejects(create('autofill-owner', 'full'), { code: 'failed-precondition' });
  await assert.rejects(create('autofill-owner', 'cancelled'), { code: 'failed-precondition' });
  await assert.rejects(create('autofill-owner', 'past'), { code: 'failed-precondition' });

  assert.equal((await db.collection('matchmakingRequests')
    .where('mode', '==', 'autofill').get()).size, 0);
  assert.equal((await db.doc('matchmakingActiveOwners/autofill-owner').get()).exists, false);
  for (const id of ['eligible', 'full', 'cancelled', 'past']) {
    const match = (await db.doc(`matches/autofill-${id}`).get()).data();
    assert.equal(match.autoFillEnabled, false);
    assert.equal(match.autoFillRequestId, null);
  }
});

test('AutoFill continues until every vacancy is filled without overlapping offers', async () => {
  for (const uid of ['candidate-one', 'candidate-two', 'organizer-full']) await seed(uid);
  const firstCandidate = await createMatchmakingRequestOperation(db,
    request('candidate-one', payload('candidate_one')));
  const secondCandidate = await createMatchmakingRequestOperation(db,
    request('candidate-two', payload('candidate_two')));
  await db.doc('matches/autofill-full').set({ creatorUid: 'organizer-full',
    participantUids: ['organizer-full'], players: [], spotsLeft: 2,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', location: { countryCode: 'MX', cityId: 'places-mexico-city',
      city: 'Mexico City', area: '', latitude: 19.43, longitude: -99.13 } });
  const autofill = await createMatchmakingRequestOperation(db, request('organizer-full',
    payload('autofill_full', { mode: 'autofill', sourceMatchId: 'autofill-full',
      autoFillAfterCancellation: true })));
  assert.ok(autofill.proposalId);

  const firstProposal = (await db.doc(`matchProposals/${autofill.proposalId}`).get()).data();
  const firstOfferedUid = firstProposal.memberUids[0];
  await Promise.all([
    respondMatchProposalOperation(db, request(firstOfferedUid, {
      proposalId: autofill.proposalId, accept: true, requestId: 'fill_first_12345678',
    })),
    respondMatchProposalOperation(db, request(firstOfferedUid, {
      proposalId: autofill.proposalId, accept: true, requestId: 'fill_first_12345678',
    })),
  ]);
  const nextAutofill = (await db.doc(`matchmakingRequests/${autofill.requestId}`).get()).data();
  assert.equal(nextAutofill.status, 'matched');
  assert.notEqual(nextAutofill.proposalId, autofill.proposalId);
  const secondProposal = (await db.doc(`matchProposals/${nextAutofill.proposalId}`).get()).data();
  const secondOfferedUid = secondProposal.memberUids[0];
  assert.notEqual(secondOfferedUid, firstOfferedUid);
  await respondMatchProposalOperation(db, request(secondOfferedUid, {
    proposalId: nextAutofill.proposalId, accept: true, requestId: 'fill_second_12345678',
  }));

  const match = (await db.doc('matches/autofill-full').get()).data();
  assert.equal(match.spotsLeft, 0);
  assert.deepEqual(new Set(match.participantUids),
    new Set(['organizer-full', 'candidate-one', 'candidate-two']));
  assert.equal((await db.doc(`matchmakingRequests/${autofill.requestId}`).get()).data().status,
    'confirmed');
  assert.equal((await db.doc(`matchmakingRequests/${firstCandidate.requestId}`).get()).data().status,
    'confirmed');
  assert.equal((await db.doc(`matchmakingRequests/${secondCandidate.requestId}`).get()).data().status,
    'confirmed');
  assert.equal((await db.collection('matchProposals').get()).size, 2);
});

test('AutoFill acceptance rechecks block and enforcement changes', async () => {
  for (const uid of ['candidate-a', 'organizer-a']) await seed(uid);
  await createMatchmakingRequestOperation(db, request('candidate-a', payload('candidate_guard')));
  await db.doc('matches/autofill-guard').set({ creatorUid: 'organizer-a',
    participantUids: ['organizer-a'], players: [], spotsLeft: 1,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', location: { countryCode: 'MX', cityId: 'places-mexico-city',
      city: 'Mexico City', area: '', latitude: 19.43, longitude: -99.13 } });
  const autofill = await createMatchmakingRequestOperation(db, request('organizer-a',
    payload('autofill_guard', { mode: 'autofill', sourceMatchId: 'autofill-guard',
      autoFillAfterCancellation: true })));
  await db.doc(`blocks/${blockId('organizer-a', 'candidate-a')}`).set({
    blockerUid: 'organizer-a', blockedUid: 'candidate-a',
  });
  await assert.rejects(respondMatchProposalOperation(db, request('candidate-a', {
    proposalId: autofill.proposalId, accept: true, requestId: 'autofill_blocked_12345678',
  })), { code: 'failed-precondition' });
  await db.doc(`blocks/${blockId('organizer-a', 'candidate-a')}`).delete();
  await db.doc('accountEnforcement/candidate-a').set({ schemaVersion: 1, uid: 'candidate-a',
    status: 'banned', reasonCode: 'other_policy_violation' });
  await assert.rejects(respondMatchProposalOperation(db, request('candidate-a', {
    proposalId: autofill.proposalId, accept: true, requestId: 'autofill_enforced_12345678',
  })), { code: 'permission-denied' });
  assert.equal((await db.doc('matches/autofill-guard').get()).data().spotsLeft, 1);
});

test('cancelling AutoFill disables the canonical match setting', async () => {
  await seed('organizer-cancel');
  await db.doc('matches/autofill-cancel').set({ creatorUid: 'organizer-cancel',
    participantUids: ['organizer-cancel'], players: [], spotsLeft: 2,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-02T18:00:00Z')),
    level: 'Level 3.5', location: { countryCode: 'MX', cityId: 'places-mexico-city',
      city: 'Mexico City', area: '', latitude: 19.43, longitude: -99.13 } });
  const created = await createMatchmakingRequestOperation(db, request('organizer-cancel',
    payload('autofill_cancel', { mode: 'autofill', sourceMatchId: 'autofill-cancel',
      autoFillAfterCancellation: true })));
  await cancelMatchmakingRequestOperation(db, request('organizer-cancel', { requestId: created.requestId }));
  const match = (await db.doc('matches/autofill-cancel').get()).data();
  assert.equal(match.autoFillEnabled, false);
  assert.equal(match.autoFillRequestId, null);
});

test('only private per-user projections are returned to the client', async () => {
  await seed('viewer-1');
  const created = await createMatchmakingRequestOperation(db, request('viewer-1', payload('state')));
  const state = await getMatchmakingStateOperation(db, request('viewer-1', {}));
  assert.equal(state.requests[0].requestId, created.requestId);
  assert.equal('ownerUid' in state.requests[0], false);
  assert.equal('location' in state.requests[0], false);
});

test('match cancellation records an objective event without inventing a no-show', async () => {
  const before = { participantUids: ['organizer-1', 'player-2'],
    scheduledAt: Timestamp.fromDate(new Date('2030-01-03T18:00:00Z')) };
  await db.doc('matchPrivateVenues/cancelled-match').set({ matchId: 'cancelled-match',
    address: 'Synthetic address', latitude: 19.4, longitude: -99.1 });
  await handleMatchCommitmentWritten(db, {
    params: { matchId: 'cancelled-match' },
    data: { before: { data: () => before }, after: { data: () => null } },
  }, now);
  const events = await db.collection('reliabilityEvents').get();
  assert.equal(events.size, 2);
  assert.ok(events.docs.every((document) => document.data().type === 'match_cancelled'));
  assert.ok(events.docs.every((document) => document.data().timingCategory === 'over_24_hours'));
  assert.ok(events.docs.every((document) => document.data().scheduledAt.toDate().toISOString()
    === '2030-01-03T18:00:00.000Z'));
  assert.ok(events.docs.every((document) => !document.data().type.includes('no_show')));
  assert.equal((await db.doc('matchPrivateVenues/cancelled-match').get()).exists, false);
  await handleMatchCommitmentWritten(db, {
    params: { matchId: 'cancelled-match' },
    data: { before: { data: () => before }, after: { data: () => null } },
  }, now);
  assert.equal((await db.collection('reliabilityEvents').get()).size, 2);
});

test('server-authoritative leave preserves a manual match and records one objective event', async () => {
  for (const uid of ['leave-organizer', 'leave-player', 'leave-other']) await seed(uid);
  const scheduledAt = new Date('2030-01-03T18:00:00Z');
  await db.doc('matches/leave-match').set({
    creatorUid: 'leave-organizer',
    createdBy: 'leave-organizer',
    players: [
      { uid: 'leave-player', displayName: 'Leaving player', level: '3.5' },
      { uid: 'leave-other', displayName: 'Remaining player', level: '3.5' },
    ],
    participantUids: ['leave-organizer', 'leave-player', 'leave-other'],
    spotsLeft: 1,
    scheduledAt: Timestamp.fromDate(scheduledAt),
    dateTime: scheduledAt.toISOString(),
    autoFillEnabled: false,
  });
  await db.doc('matches/leave-match/joinRequests/leave-player').set({
    userId: 'leave-player', status: 'approved',
  });

  const result = await leaveMatchOperation(db, request('leave-player', {
    matchId: 'leave-match', requestId: 'leave_request_12345678',
  }));
  assert.deepEqual(result, { matchId: 'leave-match', status: 'left' });
  const match = (await db.doc('matches/leave-match').get()).data();
  assert.deepEqual(match.participantUids, ['leave-organizer', 'leave-other']);
  assert.deepEqual(match.players.map((player) => player.uid), ['leave-other']);
  assert.equal(match.spotsLeft, 2);
  assert.equal(match.autoFillEnabled, false);
  assert.equal((await db.doc('matches/leave-match/joinRequests/leave-player').get()).data().status,
    'declined');

  let events = await db.collection('reliabilityEvents').get();
  assert.equal(events.size, 1);
  const event = events.docs[0].data();
  assert.equal(event.uid, 'leave-player');
  assert.equal(event.matchId, 'leave-match');
  assert.equal(event.type, 'confirmed_match_cancelled');
  assert.equal(event.timingCategory, 'over_24_hours');
  assert.equal(event.source, 'match_lifecycle');
  assert.ok(!event.type.includes('no_show'));

  const replay = await leaveMatchOperation(db, request('leave-player', {
    matchId: 'leave-match', requestId: 'leave_retry_12345678',
  }));
  assert.deepEqual(replay, { matchId: 'leave-match', status: 'left' });
  events = await db.collection('reliabilityEvents').get();
  assert.equal(events.size, 1);
});

test('matchmaking departure opens exactly one organizer-controlled AutoFill vacancy', async () => {
  const uids = ['mm-organizer', 'mm-leaver', 'mm-second', 'mm-third'];
  for (const uid of uids) await seed(uid);
  await db.doc('matches/mm-leave').set({
    creatorUid: 'mm-organizer',
    players: uids.slice(1).map((uid) => ({ uid, displayName: uid, level: '3.5' })),
    participantUids: uids,
    spotsLeft: 0,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-03T18:00:00Z')),
    source: 'matchmaking',
    autoFillEnabled: false,
    autoFillRequestId: null,
  });

  await leaveMatchOperation(db, request('mm-leaver', {
    matchId: 'mm-leave', requestId: 'mm_leave_request_12345678',
  }));

  const match = (await db.doc('matches/mm-leave').get()).data();
  assert.equal(match.source, 'matchmaking');
  assert.deepEqual(match.participantUids, ['mm-organizer', 'mm-second', 'mm-third']);
  assert.deepEqual(match.players.map((player) => player.uid), ['mm-second', 'mm-third']);
  assert.equal(match.spotsLeft, 1);
  assert.equal(match.autoFillEnabled, false);
  assert.equal(match.autoFillRequestId, null);
  assert.equal((await db.collection('reliabilityEvents').get()).size, 1);
});

test('leaveMatch authenticates the actor and rejects organizer, outsider, and past match', async () => {
  for (const uid of ['guard-organizer', 'guard-player', 'guard-outsider']) await seed(uid);
  const match = {
    creatorUid: 'guard-organizer',
    players: [{ uid: 'guard-player', displayName: 'Player', level: '3.5' }],
    participantUids: ['guard-organizer', 'guard-player'],
    spotsLeft: 2,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-03T18:00:00Z')),
  };
  await db.doc('matches/guard-match').set(match);

  await assert.rejects(leaveMatchOperation(db, request('guard-organizer', {
    matchId: 'guard-match', requestId: 'organizer_leave_12345678',
  })), { code: 'failed-precondition' });
  await assert.rejects(leaveMatchOperation(db, request('guard-outsider', {
    matchId: 'guard-match', requestId: 'outsider_leave_12345678',
  })), { code: 'failed-precondition' });
  await assert.rejects(leaveMatchOperation(db, request('guard-player', {
    matchId: 'guard-match', requestId: 'extra_field_12345678', participantUid: 'guard-outsider',
  })), { code: 'invalid-argument' });

  await db.doc('matches/guard-match').update({
    scheduledAt: Timestamp.fromDate(new Date('2029-12-31T18:00:00Z')),
  });
  await assert.rejects(leaveMatchOperation(db, request('guard-player', {
    matchId: 'guard-match', requestId: 'past_leave_12345678',
  })), { code: 'failed-precondition' });
  const unchanged = (await db.doc('matches/guard-match').get()).data();
  assert.deepEqual(unchanged.participantUids, ['guard-organizer', 'guard-player']);
  assert.equal((await db.collection('reliabilityEvents').get()).size, 0);
});

test('concurrent leave retries remove one participant and create one event', async () => {
  for (const uid of ['race-organizer', 'race-player']) await seed(uid);
  await db.doc('matches/race-leave').set({
    creatorUid: 'race-organizer',
    players: [{ uid: 'race-player', displayName: 'Player', level: '3.5' }],
    participantUids: ['race-organizer', 'race-player'],
    spotsLeft: 2,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-03T18:00:00Z')),
  });
  const responses = await Promise.all([
    leaveMatchOperation(db, request('race-player', {
      matchId: 'race-leave', requestId: 'race_leave_one_12345678',
    })),
    leaveMatchOperation(db, request('race-player', {
      matchId: 'race-leave', requestId: 'race_leave_two_12345678',
    })),
  ]);
  assert.ok(responses.every((response) => response.status === 'left'));
  const match = (await db.doc('matches/race-leave').get()).data();
  assert.deepEqual(match.participantUids, ['race-organizer']);
  assert.equal(match.spotsLeft, 3);
  assert.equal((await db.collection('reliabilityEvents').get()).size, 1);
});

test('organizer cancellation racing departure cannot leave a corrupted match', async () => {
  for (const uid of ['cancel-race-organizer', 'cancel-race-player']) await seed(uid);
  const reference = db.doc('matches/cancel-race');
  await reference.set({
    creatorUid: 'cancel-race-organizer',
    players: [{ uid: 'cancel-race-player', displayName: 'Player', level: '3.5' }],
    participantUids: ['cancel-race-organizer', 'cancel-race-player'],
    spotsLeft: 2,
    scheduledAt: Timestamp.fromDate(new Date('2030-01-03T18:00:00Z')),
  });
  const outcomes = await Promise.allSettled([
    leaveMatchOperation(db, request('cancel-race-player', {
      matchId: 'cancel-race', requestId: 'cancel_race_leave_12345678',
    })),
    reference.delete(),
  ]);
  assert.ok(outcomes.some((outcome) => outcome.status === 'fulfilled'));
  assert.equal((await reference.get()).exists, false);
  const events = await db.collection('reliabilityEvents').get();
  assert.ok(events.size <= 1);
  if (events.size === 1) {
    assert.equal(events.docs[0].data().type, 'confirmed_match_cancelled');
  }
});

test('bounded recovery expires stale requests without TTL', async () => {
  await db.doc('matchmakingRequests/expired-request').set({ requestId: 'expired-request',
    ownerUid: 'owner-1', memberUids: ['owner-1'], mode: 'solo', status: 'active',
    expiresAt: Timestamp.fromDate(new Date('2029-12-31T12:00:00Z')) });
  await db.doc('users/owner-1/matchmakingRequestViews/expired-request').set({ status: 'active' });
  const result = await recoverExpiredMatchmaking(db, now);
  assert.equal(result.requests, 1);
  assert.equal((await db.doc('matchmakingRequests/expired-request').get()).data().status, 'expired');
  assert.equal((await db.doc('users/owner-1/matchmakingRequestViews/expired-request').get()).data().status,
    'expired');
});

test('proposal expiry releases requests and records objective expiry events', async () => {
  for (const uid of ['expiry-1', 'expiry-2', 'expiry-3', 'expiry-4']) await seed(uid);
  for (const [index, uid] of ['expiry-1', 'expiry-2', 'expiry-3', 'expiry-4'].entries()) {
    await createMatchmakingRequestOperation(db, request(uid, payload(`expiry_${index}`)));
  }
  const proposal = (await db.collection('matchProposals').get()).docs[0];
  await proposal.ref.update({ expiresAt: Timestamp.fromDate(new Date('2029-12-31T12:00:00Z')) });
  const result = await recoverExpiredMatchmaking(db, now);
  assert.equal(result.proposals, 1);
  assert.equal((await proposal.ref.get()).data().status, 'expired');
  const events = await db.collection('reliabilityEvents').get();
  assert.equal(events.size, 4);
  assert.ok(events.docs.every((document) => document.data().type === 'proposal_expired'));
  const requests = await db.collection('matchmakingRequests').get();
  assert.ok(requests.docs.every((document) => document.data().status === 'expired'));
  assert.equal(events.docs.some((document) =>
    document.data().type === 'confirmed_match_cancelled'), false);
});

test('recovery expires one partner reservation atomically without double release', async () => {
  for (const uid of ['expiry-pair-owner', 'expiry-pair-partner', 'expiry-pair-solo-1',
    'expiry-pair-solo-2']) await seed(uid);
  const pair = await createMatchmakingRequestOperation(db,
    request('expiry-pair-owner', payload('expiry_pair', {
      mode: 'partner', partnerUid: 'expiry-pair-partner',
    })));
  await respondPartnerInvitationOperation(db, request('expiry-pair-partner', {
    requestId: pair.requestId, accept: true,
  }));
  await createMatchmakingRequestOperation(db,
    request('expiry-pair-solo-1', payload('expiry_pair_solo_1')));
  const formed = await createMatchmakingRequestOperation(db,
    request('expiry-pair-solo-2', payload('expiry_pair_solo_2')));
  const proposal = db.doc(`matchProposals/${formed.proposalId}`);
  await proposal.update({ expiresAt: Timestamp.fromDate(new Date('2029-12-31T12:00:00Z')) });
  await recoverExpiredMatchmaking(db, now);
  assert.equal((await proposal.get()).data().status, 'expired');
  assert.equal((await db.doc(`matchmakingRequests/${pair.requestId}`).get()).data().status, 'expired');
  assert.equal((await db.collection('reliabilityEvents')
    .where('type', '==', 'confirmed_match_cancelled').get()).size, 0);
});

test('accepted lobby spots stay locked while a declined Solo is replaced', async () => {
  const uids = ['lobby-1', 'lobby-2', 'lobby-3', 'lobby-4', 'lobby-replacement'];
  for (const uid of uids) await seed(uid);
  const requests = [];
  for (let index = 0; index < 4; index++) requests.push(await createMatchmakingRequestOperation(db,
    request(uids[index], payload(`lobby_${index}`))));
  const proposalId = requests[3].proposalId;
  const replacement = await createMatchmakingRequestOperation(db,
    request('lobby-replacement', payload('lobby_replacement')));
  for (let index = 0; index < 3; index++) await respondMatchProposalOperation(db, request(uids[index], {
    proposalId, accept: true, requestId: `lobby_accept_${index}_12345678`,
  }));
  await respondMatchProposalOperation(db, request('lobby-4', {
    proposalId, accept: false, requestId: 'lobby_decline_12345678',
  }));
  const lobby = (await db.doc(`matchProposals/${proposalId}`).get()).data();
  assert.deepEqual(new Set(lobby.memberUids),
    new Set(['lobby-1', 'lobby-2', 'lobby-3', 'lobby-replacement']));
  for (const uid of ['lobby-1', 'lobby-2', 'lobby-3']) {
    assert.equal(lobby.confirmations[uid], 'accepted');
  }
  assert.equal(lobby.confirmations['lobby-replacement'], 'offered');
  assert.equal((await db.doc(`matchmakingRequests/${replacement.requestId}`).get()).data().status, 'matched');
  assert.equal((await db.doc(`matchmakingRequests/${requests[3].requestId}`).get()).data().status, 'declined');
  assert.equal((await db.collection('reliabilityEvents')
    .where('type', '==', 'confirmed_match_cancelled').get()).size, 0);
  await respondMatchProposalOperation(db, request('lobby-replacement', {
    proposalId, accept: true, requestId: 'lobby_replacement_accept_12345678',
  }));
  assert.equal((await db.doc(`matchProposals/${proposalId}`).get()).data().status, 'venue_needed');
});

test('accepted lobby spots stay locked while an expired reservation is replaced', async () => {
  const uids = ['expiry-lock-1', 'expiry-lock-2', 'expiry-lock-3', 'expiry-lock-4',
    'expiry-lock-replacement'];
  for (const uid of uids) await seed(uid);
  const requests = [];
  for (let index = 0; index < 4; index++) requests.push(await createMatchmakingRequestOperation(db,
    request(uids[index], payload(`expiry_lock_${index}`))));
  const proposalId = requests[3].proposalId;
  await createMatchmakingRequestOperation(db,
    request('expiry-lock-replacement', payload('expiry_lock_replacement')));
  for (let index = 0; index < 3; index++) await respondMatchProposalOperation(db, request(uids[index], {
    proposalId, accept: true, requestId: `expiry_lock_accept_${index}_12345678`,
  }));
  await db.doc(`matchProposals/${proposalId}`).update({
    expiresAt: Timestamp.fromDate(new Date('2029-12-31T12:00:00Z')),
  });
  await recoverExpiredMatchmaking(db, now);
  const lobby = (await db.doc(`matchProposals/${proposalId}`).get()).data();
  assert.equal(lobby.status, 'confirming');
  assert.equal(lobby.confirmations['expiry-lock-replacement'], 'offered');
  for (const uid of ['expiry-lock-1', 'expiry-lock-2', 'expiry-lock-3']) {
    assert.equal(lobby.confirmations[uid], 'accepted');
  }
  assert.equal((await db.collection('reliabilityEvents')
    .where('type', '==', 'proposal_expired').get()).size, 1);
  assert.equal((await db.collection('reliabilityEvents')
    .where('type', '==', 'confirmed_match_cancelled').get()).size, 0);
});

test('request idempotency prevents duplicate active intent', async () => {
  await seed('repeat-1');
  const input = payload('repeat');
  const first = await createMatchmakingRequestOperation(db, request('repeat-1', input));
  const replay = await createMatchmakingRequestOperation(db, request('repeat-1', input));
  assert.equal(replay.requestId, first.requestId);
  assert.equal((await db.collection('matchmakingRequests').get()).size, 1);
  await assert.rejects(createMatchmakingRequestOperation(db,
    request('repeat-1', payload('second'))), { code: 'already-exists' });
});

test('bounded candidate windows reach compatible players beyond the first 60', async () => {
  const desired = ['window-1', 'window-2', 'window-3', 'window-4'];
  for (const uid of desired) await seed(uid);
  const first = await createMatchmakingRequestOperation(db,
    request(desired[0], payload('window_first')));
  const template = (await db.doc(`matchmakingRequests/${first.requestId}`).get()).data();
  const earlier = Timestamp.fromDate(new Date(now.getTime() - 60_000));
  await Promise.all(Array.from({ length: 61 }, (_, index) => {
    const id = `decoy-${String(index).padStart(2, '0')}`;
    return db.doc(`matchmakingRequests/${id}`).set({ ...template,
      requestId: id, clientRequestId: `decoy_client_${index}_12345678`, ownerUid: id,
      memberUids: [id], level: '7', createdAt: earlier, updatedAt: earlier,
    });
  }));
  for (let index = 1; index < 3; index++) {
    const id = `desired-${index}`;
    await db.doc(`matchmakingRequests/${id}`).set({ ...template,
      requestId: id, clientRequestId: `desired_client_${index}_12345678`,
      ownerUid: desired[index], memberUids: [desired[index]],
    });
  }
  const result = await createMatchmakingRequestOperation(db,
    request(desired[3], payload('window_last')));
  assert.ok(result.proposalId);
  const proposal = (await db.doc(`matchProposals/${result.proposalId}`).get()).data();
  assert.deepEqual(new Set(proposal.memberUids), new Set(desired));
});
