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
  handlePlayerRatingCreated,
} from '../functions/index.js';
import { encodeGeohash } from '../functions/aggregate_helpers.js';

const projectId = 'demo-padelx-phase8';
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
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

  const markers = await getFirestore()
    .collection('ratingAggregationEvents')
    .where('ratingPath', '==', firstPath)
    .get();
  assert.equal(markers.size, 1);
  const firstRating = await getFirestore().doc(firstPath).get();
  const replayEvent = {
    id: markers.docs[0].id,
    params: { ratedUid: 'rated' },
    data: firstRating,
  };
  await handlePlayerRatingCreated(replayEvent);
  await handlePlayerRatingCreated(replayEvent);
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
