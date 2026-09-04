import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeApp } from 'firebase-admin/app';
import {
  handlePlayerRatingWritten,
} from '../functions/index.js';
import { ratingIdentity, reconcileRating } from '../functions/rating_contributions.js';
import { requireActiveAccount } from '../functions/account_state.js';
import { getAuth } from 'firebase-admin/auth';
import { encodeGeohash } from '../functions/aggregate_helpers.js';

const projectId = 'demo-padelx-phase8';
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
assert.ok(emulatorHost, 'Firestore emulator is required');
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'Auth emulator is required');
const [host, portText] = emulatorHost.split(':');
const port = Number(portText);
let environment;
initializeApp({ projectId });

function auth(uid) {
  return environment.authenticatedContext(uid, {
    email: `${uid}@example.com`,
    email_verified: true,
  }).firestore();
}

function profile(uid, overrides = {}) {
  return {
    uid,
    displayName: `Player ${uid}`,
    level: 'Level 3',
    ...overrides,
  };
}

function location(overrides = {}) {
  return {
    clubName: 'Roma Padel',
    countryCode: 'MX',
    country: 'Mexico',
    region: 'CDMX',
    city: 'Mexico City',
    area: 'Roma Norte',
    placeId: 'place-1',
    latitude: 19.4326,
    longitude: -99.1332,
    ...overrides,
  };
}

function matchData(creatorUid, overrides = {}) {
  return {
    title: 'Tomorrow at 6 PM',
    club: 'Roma Padel',
    clubName: 'Roma Padel',
    location: location(),
    dateTime: 'Tomorrow at 6 PM',
    scheduledAt: Timestamp.fromMillis(Date.now() + 86_400_000),
    level: 'Level 3',
    spotsLeft: 3,
    players: [],
    participantUids: [creatorUid],
    creatorUid,
    creatorDisplayName: `Player ${creatorUid}`,
    creatorLevel: 'Level 3',
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

async function seed(path, data) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

async function waitFor(description, read, predicate, timeoutMs = 20_000) {
  const deadline = Date.now() + timeoutMs;
  let value;
  while (Date.now() < deadline) {
    value = await read();
    if (predicate(value)) return value;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  assert.fail(`Timed out waiting for ${description}; last value: ${JSON.stringify(value)}`);
}

async function adminData(path) {
  const snapshot = await getFirestore().doc(path).get();
  return snapshot.exists ? snapshot.data() : undefined;
}

before(async () => {
  assert.match(projectId, /^demo-/, 'tests must use an offline Firebase demo project');
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile('firestore.rules', 'utf8'),
      host,
      port,
    },
  });
  await environment.clearFirestore();
});

after(async () => environment.cleanup());

test('deployed-style geo indexing and lifetime rating aggregation', async () => {
  await seed('publicProfiles/organizer', profile('organizer'));
  const organizer = auth('organizer');
  const matchRef = doc(organizer, 'matches/geo-match');

  await assertSucceeds(setDoc(matchRef, matchData('organizer')));
  let indexed = await waitFor(
    'initial match geohashes',
    () => adminData('matches/geo-match'),
    (data) => data?.geoHash3 === '9g3' && data?.geoHash4 === '9g3w',
  );
  assert.equal(indexed.geoHash3, encodeGeohash(19.4326, -99.1332, 3));
  assert.equal(indexed.geoHash4, encodeGeohash(19.4326, -99.1332, 4));

  const changedLocation = location({
    city: 'Guadalajara',
    region: 'Jalisco',
    area: 'Americana',
    placeId: 'place-2',
    latitude: 20.6736,
    longitude: -103.344,
  });
  await assertSucceeds(updateDoc(matchRef, { location: changedLocation }));
  indexed = await waitFor(
    'updated match geohashes',
    () => adminData('matches/geo-match'),
    (data) => data?.geoHash4 === encodeGeohash(20.6736, -103.344, 4),
  );
  const updatedHashes = [indexed.geoHash3, indexed.geoHash4];
  await assertSucceeds(updateDoc(matchRef, { title: 'Updated title' }));
  await waitFor(
    'unrelated match edit',
    () => adminData('matches/geo-match'),
    (data) => data?.title === 'Updated title',
  );
  indexed = await adminData('matches/geo-match');
  assert.deepEqual([indexed.geoHash3, indexed.geoHash4], updatedHashes);
  await assertFails(updateDoc(matchRef, { geoHash3: 'zzz', geoHash4: 'zzzz' }));

  await seed('publicProfiles/rated', profile('rated', {
    ratingCount: 0,
    ratingSum: 0,
    ratingAverage: 0,
  }));
  await seed('publicProfiles/rater1', profile('rater1'));
  await seed('publicProfiles/rater2', profile('rater2'));
  await seed('publicProfiles/outsider', profile('outsider'));
  await seed('matches/completed', {
    ...matchData('rater1'),
    scheduledAt: Timestamp.fromMillis(Date.now() - 86_400_000),
    createdAt: Timestamp.fromMillis(Date.now() - 172_800_000),
    players: [
      { uid: 'rated', displayName: 'Player rated', level: 'Level 3' },
      { uid: 'rater2', displayName: 'Player rater2', level: 'Level 3' },
    ],
    participantUids: ['rater1', 'rated', 'rater2'],
    spotsLeft: 1,
  });

  const firstPath = 'matches/completed/ratingRaters/rater1/ratings/rated';
  const firstRef = doc(auth('rater1'), firstPath);
  await assertSucceeds(setDoc(firstRef, {
    matchId: 'completed',
    raterUid: 'rater1',
    ratedUid: 'rated',
    rating: 5,
    createdAt: serverTimestamp(),
  }));
  let aggregate = await waitFor(
    'first rating aggregate',
    () => adminData('publicProfiles/rated'),
    (data) => data?.ratingCount === 1,
  );
  assert.deepEqual(
    [aggregate.ratingCount, aggregate.ratingSum, aggregate.ratingAverage],
    [1, 5, 5],
  );

  const secondPath = 'matches/completed/ratingRaters/rater2/ratings/rated';
  await assertSucceeds(setDoc(doc(auth('rater2'), secondPath), {
    matchId: 'completed',
    raterUid: 'rater2',
    ratedUid: 'rated',
    rating: 3,
    createdAt: serverTimestamp(),
  }));
  aggregate = await waitFor(
    'multiple rating aggregate',
    () => adminData('publicProfiles/rated'),
    (data) => data?.ratingCount === 2,
  );
  assert.deepEqual(
    [aggregate.ratingCount, aggregate.ratingSum, aggregate.ratingAverage],
    [2, 8, 4],
  );

  const contribution = await adminData(`ratingContributions/${ratingIdentity(firstPath).contributionId}`);
  assert.equal(contribution.score, 5);
  const replayEvent = { params: { matchId: 'completed', raterUid: 'rater1', ratedUid: 'rated' } };
  await handlePlayerRatingWritten(replayEvent);
  await handlePlayerRatingWritten(replayEvent);
  aggregate = await adminData('publicProfiles/rated');
  assert.deepEqual(
    [aggregate.ratingCount, aggregate.ratingSum, aggregate.ratingAverage],
    [2, 8, 4],
  );

  await assertFails(updateDoc(doc(auth('rated'), 'publicProfiles/rated'), {
    ratingCount: 999,
    ratingSum: 4995,
    ratingAverage: 5,
  }));
  await assertFails(setDoc(
    doc(auth('outsider'), 'matches/completed/ratingRaters/outsider/ratings/rated'),
    {
      matchId: 'completed',
      raterUid: 'outsider',
      ratedUid: 'rated',
      rating: 1,
      createdAt: serverTimestamp(),
    },
  ));
  assert.equal(
    (await getDoc(doc(auth('outsider'),
      'matches/completed/ratingRaters/outsider/ratings/rated'))).exists(),
    false,
  );
  aggregate = await adminData('publicProfiles/rated');
  assert.deepEqual(
    [aggregate.ratingCount, aggregate.ratingSum, aggregate.ratingAverage],
    [2, 8, 4],
  );
});

test('rating reconciliation converges across updates, deletions, barriers and missing profiles', async () => {
  const firestore = getFirestore();
  const target = 'cleanup-rated';
  const path = 'matches/cleanup/ratingRaters/cleanup-rater/ratings/cleanup-rated';
  const otherPath = 'matches/cleanup/ratingRaters/cleanup-other/ratings/cleanup-rated';
  const profilePath = `publicProfiles/${target}`;
  const contributionPath = `ratingContributions/${ratingIdentity(path).contributionId}`;
  await seed(profilePath, profile(target));
  await seed('matches/cleanup', { ...matchData('cleanup-rater'),
    scheduledAt: Timestamp.fromMillis(Date.now() - 10000),
    players: [{ uid: target }, { uid: 'cleanup-other' }] });
  const rating = { matchId: 'cleanup', raterUid: 'cleanup-rater', ratedUid: target, rating: 5 };
  await seed(path, rating);
  await Promise.all(Array.from({ length: 4 }, () => reconcileRating(firestore, path)));
  assert.equal((await adminData(profilePath)).ratingSum, 5);
  await seed(otherPath, { ...rating, raterUid: 'cleanup-other', rating: 3 });
  await reconcileRating(firestore, otherPath);
  assert.equal((await adminData(profilePath)).ratingAverage, 4);
  await firestore.doc(path).update({ rating: 1 });
  await reconcileRating(firestore, path);
  assert.equal((await adminData(profilePath)).ratingSum, 4);
  await firestore.doc(path).delete();
  await Promise.all([reconcileRating(firestore, path), reconcileRating(firestore, path)]);
  await handlePlayerRatingWritten({ params: { matchId: 'cleanup', raterUid: 'cleanup-rater', ratedUid: target },
    data: { after: { data: () => rating } } });
  assert.equal(await adminData(contributionPath), undefined);
  assert.equal((await adminData(profilePath)).ratingCount, 1);
  assert.equal((await adminData(profilePath)).ratingSum, 3);
  await firestore.doc(otherPath).delete();
  await reconcileRating(firestore, otherPath);
  const zero = await adminData(profilePath);
  assert.deepEqual([zero.ratingCount, zero.ratingSum, zero.ratingAverage], [0, 0, 0]);

  await seed(path, rating);
  await reconcileRating(firestore, path);
  await seed(`accountDeletionBarriers/${target}`, { status: 'deleting', schemaVersion: 1 });
  await reconcileRating(firestore, path);
  assert.equal((await adminData(profilePath)).ratingCount, 0);
  assert.equal(await adminData(contributionPath), undefined);
  await firestore.doc(profilePath).delete();
  await reconcileRating(firestore, path);
  assert.equal(await adminData(profilePath), undefined);
});

test('Auth emulator and shared active-account authorization', async () => {
  const user = await getAuth().createUser({ uid: 'auth-fixture', email: 'auth-fixture@example.com', emailVerified: true });
  assert.equal(user.uid, 'auth-fixture');
  const request = { auth: { uid: user.uid, token: { email_verified: true } } };
  assert.equal(await requireActiveAccount(getFirestore(), request), user.uid);
  await seed(`accountDeletionBarriers/${user.uid}`, { status: 'deleting' });
  await assert.rejects(requireActiveAccount(getFirestore(), request), /deletion is in progress/);
  await assert.rejects(requireActiveAccount(getFirestore(), { auth: { uid: 'unverified', token: {} } }), /Verified email/);
  await getAuth().deleteUser(user.uid);
});

test('rater barrier removes only its contribution and absent targets stay absent', async () => {
  const firestore = getFirestore();
  const target = 'barrier-target';
  const paths = ['barrier-a', 'barrier-b'].map((uid) => `matches/barrier-match/ratingRaters/${uid}/ratings/${target}`);
  await seed(`publicProfiles/${target}`, profile(target));
  await seed('matches/barrier-match', { ...matchData('barrier-a'),
    scheduledAt: Timestamp.fromMillis(Date.now() - 10000), players: [{ uid: 'barrier-b' }, { uid: target }] });
  for (const [index, path] of paths.entries()) {
    await seed(path, { matchId: 'barrier-match', raterUid: `barrier-${index === 0 ? 'a' : 'b'}`, ratedUid: target, rating: index + 3 });
  }
  await Promise.all(paths.map((path) => reconcileRating(firestore, path)));
  assert.equal((await adminData(`publicProfiles/${target}`)).ratingSum, 7);
  await seed('accountDeletionBarriers/barrier-a', { status: 'deleting' });
  await Promise.all(paths.map((path) => reconcileRating(firestore, path)));
  assert.equal((await adminData(`publicProfiles/${target}`)).ratingSum, 4);
  assert.equal((await adminData(`publicProfiles/${target}`)).ratingCount, 1);
  await firestore.doc(`publicProfiles/${target}`).delete();
  await reconcileRating(firestore, paths[1]);
  assert.equal(await adminData(`publicProfiles/${target}`), undefined);
  assert.equal(await adminData(`ratingContributions/${ratingIdentity(paths[1]).contributionId}`), undefined);
});
