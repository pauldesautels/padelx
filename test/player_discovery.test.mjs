import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { blockId } from '../functions/friendship_policy.js';
import { discoverPlayersOperation, DISCOVERY_QUERY_WINDOW, DISCOVERY_SCAN_CAP } from '../functions/player_discovery.js';

const projectId = 'demo-padelx-player-discovery';
process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId });
process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= '127.0.0.1:9099';
const app = initializeApp({ projectId }, 'player-discovery-tests');
const db = getFirestore(app);
const request = (uid, data = {}) => ({ auth: { uid, token: { email_verified: true } }, data });
async function account(uid, profile = {}, user = {}) {
  await db.doc(`users/${uid}`).set({ uid, active: true, discoveryLocation: { countryCode: 'MX', city: 'Mexico City' }, ...user });
  const publicData = { uid, displayName: uid, level: '4', preferredSide: 'either',
    discoverable: true, countryCode: 'MX', city: 'Mexico City', area: 'Roma', ...profile };
  for (const key of Object.keys(publicData)) if (publicData[key] === undefined) delete publicData[key];
  await db.doc(`publicProfiles/${uid}`).set(publicData);
}
const discover = (data = {}) => discoverPlayersOperation(db, request('viewer', data), { throttle: false });

before(async () => db.doc('_warmup/ready').set({ ready: true }));
beforeEach(async () => {
  for (const collection of await db.listCollections()) for (const ref of await collection.listDocuments()) await db.recursiveDelete(ref);
  await account('viewer', { displayName: 'Viewer' });
});
after(async () => deleteApp(app));

test('returns only valid, discoverable, active same-city targets and omits self/deleting accounts', async () => {
  await account('good', { displayName: 'Able' });
  await account('private', { displayName: 'Private', discoverable: false });
  await account('legacy', { displayName: 'Legacy', discoverable: undefined });
  await account('away', { displayName: 'Away', city: 'Guadalajara' });
  await account('inactive', { displayName: 'Inactive' }, { active: false });
  await account('deleting', { displayName: 'Deleting' });
  await db.doc('accountDeletionBarriers/deleting').set({ status: 'deleting' });
  const result = await discover();
  assert.deepEqual(result.players.map((p) => p.uid), ['good']);
  for (const forbidden of ['email', 'latitude', 'longitude', 'placeId', 'deletionState']) {
    assert.equal(Object.hasOwn(result.players[0], forbidden), false);
  }
});

test('canonical city identity matches localized labels and excludes different or legacy identities', async () => {
  await db.doc('users/viewer').update({
    discoveryLocation: { countryCode: 'MX', city: 'Mexico City', cityId: 'places/cdmx' },
  });
  await account('spanish', { displayName: 'Ciudad', city: 'Ciudad de México', cityId: 'places/cdmx' });
  await account('different', { displayName: 'Different', city: 'Mexico City', cityId: 'places/other-city' });
  await account('legacy-city', { displayName: 'Legacy', city: 'Mexico City' });
  const result = await discover();
  assert.deepEqual(result.players.map((player) => player.uid), ['spanish']);
  assert.equal(result.players[0].city, 'Ciudad de México');
});

test('legacy viewers retain exact city-label discovery until migrated or edited', async () => {
  await account('same-label', { displayName: 'Same' });
  await account('localized', { displayName: 'Localized', city: 'Ciudad de México', cityId: 'places/cdmx' });
  assert.deepEqual((await discover()).players.map((player) => player.uid), ['same-label']);
});

test('suppresses blocks in both directions', async () => {
  await account('mine', { displayName: 'Mine' }); await account('theirs', { displayName: 'Theirs' });
  await db.doc(`blocks/${blockId('viewer', 'mine')}`).set({ blockerUid: 'viewer', blockedUid: 'mine' });
  await db.doc(`blocks/${blockId('theirs', 'viewer')}`).set({ blockerUid: 'theirs', blockedUid: 'viewer' });
  assert.deepEqual((await discover()).players, []);
  assert.deepEqual((await discover({ area: 'roma' })).players, []);
});

test('excludes effectively enforced targets without exposing enforcement', async () => {
  await account('suspended', { displayName: 'Suspended' });
  await account('expired', { displayName: 'Expired' });
  await account('banned', { displayName: 'Banned' });
  const common = { schemaVersion: 1, reasonCode: 'harassment_abuse' };
  await db.doc('accountEnforcement/suspended').set({ ...common, uid: 'suspended',
    status: 'suspended', expiresAt: new Date(Date.now() + 86_400_000) });
  await db.doc('accountEnforcement/expired').set({ ...common, uid: 'expired',
    status: 'suspended', expiresAt: new Date(Date.now() - 1) });
  await db.doc('accountEnforcement/banned').set({ ...common, uid: 'banned', status: 'banned' });
  const result = await discover();
  assert.deepEqual(result.players.map((player) => player.uid), ['expired']);
  assert.equal(JSON.stringify(result).includes('harassment_abuse'), false);
});

test('area, level, side compatibility, and Either-only semantics are explicit', async () => {
  await account('left', { displayName: 'Left', preferredSide: 'left' });
  await account('right', { displayName: 'Right', preferredSide: 'right' });
  await account('either', { displayName: 'Either', preferredSide: 'either' });
  await account('other', { displayName: 'Other', preferredSide: 'left', area: 'Condesa', level: '5' });
  assert.deepEqual((await discover({ preferredSide: 'left' })).players.map((p) => p.uid), ['either', 'left', 'other']);
  assert.deepEqual((await discover({ preferredSide: 'right' })).players.map((p) => p.uid), ['either', 'right']);
  assert.deepEqual((await discover({ preferredSide: 'either' })).players.map((p) => p.uid), ['either']);
  assert.deepEqual((await discover({ area: 'condesa', level: '5' })).players.map((p) => p.uid), ['other']);
});

test('relationship context is allowlisted and filterable', async () => {
  await account('friend', { displayName: 'Friend' }); await account('partner', { displayName: 'Partner' });
  await db.doc('users/viewer/friendViews/friend').set({ status: 'accepted', direction: 'mutual', friendshipId: 'secret' });
  await db.doc('users/viewer/playedWith/partner').set({ completedMatchCount: 3, lastMatchId: 'private-source' });
  const all = await discover();
  assert.equal(all.players.find((p) => p.uid === 'friend').isFriend, true);
  assert.equal(all.players.find((p) => p.uid === 'partner').playedTogetherCount, 3);
  assert.equal(Object.hasOwn(all.players.find((p) => p.uid === 'friend'), 'friendshipId'), false);
  assert.deepEqual((await discover({ relationship: 'friends' })).players.map((p) => p.uid), ['friend']);
  assert.deepEqual((await discover({ relationship: 'playedWith' })).players.map((p) => p.uid), ['partner']);
});

test('ordering, result limit, cursor, and candidate scan cap are stable', async () => {
  for (let i = 0; i < DISCOVERY_SCAN_CAP + 5; i += 1) await account(`p${String(i).padStart(3, '0')}`,
    { displayName: `Player ${String(i).padStart(3, '0')}` });
  const first = await discover({ limit: 20 });
  assert.equal(first.players.length, 20); assert.equal(first.hasMore, true);
  const second = await discover({ limit: 20, cursor: first.cursor });
  assert.equal(second.players[0].uid, 'p020');
  assert.equal(new Set([...first.players, ...second.players].map((player) => player.uid)).size, 40);
  const sparse = await discover({ level: 'never' });
  assert.equal(sparse.players.length, 0); assert.equal(sparse.cursor.uid, 'p119'); assert.equal(sparse.hasMore, true);
});

test('continues past an empty candidate window to return a later eligible player', async () => {
  for (let i = 0; i < DISCOVERY_QUERY_WINDOW; i += 1) await account(`filtered-${String(i).padStart(3, '0')}`,
    { displayName: `Candidate ${String(i).padStart(3, '0')}`, level: '3' });
  await account('eligible', { displayName: `Candidate ${String(DISCOVERY_QUERY_WINDOW).padStart(3, '0')}`, level: '5' });
  const result = await discover({ level: '5' });
  assert.deepEqual(result.players.map((player) => player.uid), ['eligible']);
  assert.equal(result.hasMore, false);
});

test('work cap returns a valid continuation and a later request reaches the next candidate', async () => {
  for (let i = 0; i < DISCOVERY_SCAN_CAP + 1; i += 1) await account(`bounded-${String(i).padStart(3, '0')}`,
    { displayName: `Bounded ${String(i).padStart(3, '0')}`, level: i === DISCOVERY_SCAN_CAP ? '5' : '3' });
  const capped = await discover({ level: '5' });
  assert.equal(capped.players.length, 0);
  assert.equal(capped.cursor.uid, `bounded-${String(DISCOVERY_SCAN_CAP - 1).padStart(3, '0')}`);
  assert.equal(capped.hasMore, true);
  const continued = await discover({ level: '5', cursor: capped.cursor });
  assert.deepEqual(continued.players.map((player) => player.uid), [`bounded-${String(DISCOVERY_SCAN_CAP).padStart(3, '0')}`]);
  assert.equal(continued.hasMore, false);
});

test('multiple filtered windows stop cleanly at end of query', async () => {
  for (let i = 0; i < DISCOVERY_QUERY_WINDOW + 5; i += 1) await account(`end-${String(i).padStart(3, '0')}`,
    { displayName: `End ${String(i).padStart(3, '0')}`, level: '3' });
  const result = await discover({ level: '5' });
  assert.equal(result.players.length, 0);
  assert.equal(result.hasMore, false);
  assert.equal(result.cursor.uid, 'viewer');
});

test('malformed, unauthenticated, and unverified requests are rejected; missing city is safe', async () => {
  await assert.rejects(() => discoverPlayersOperation(db, request('viewer', { limit: 21 }), { throttle: false }));
  await assert.rejects(() => discoverPlayersOperation(db, { data: {} }, { throttle: false }));
  await assert.rejects(() => discoverPlayersOperation(db, { auth: { uid: 'viewer', token: {} }, data: {} }, { throttle: false }));
  await db.doc('users/viewer').update({ discoveryLocation: { countryCode: 'MX', city: '' } });
  assert.equal((await discover()).noLocation, true);
});
