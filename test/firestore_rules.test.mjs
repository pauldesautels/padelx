import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'padelx-phase-8a-rules-test';
const now = Date.now();
const future = () => Timestamp.fromMillis(now + 86_400_000);
const past = () => Timestamp.fromMillis(now - 86_400_000);

let environment;

function auth(uid, email = `${uid}@example.com`, emailVerified = false) {
  return environment.authenticatedContext(uid, {
    email,
    email_verified: emailVerified,
  }).firestore();
}

function discovery(overrides = {}) {
  return {
    country: 'Mexico',
    countryCode: 'MX',
    city: 'Mexico City',
    area: 'Roma Norte',
    latitude: 19.419,
    longitude: -99.164,
    ...overrides,
  };
}

function publicProfile(uid, overrides = {}) {
  return {
    uid,
    displayName: `Player ${uid}`,
    level: 'Level 3',
    ...overrides,
  };
}

function privateProfile(uid, overrides = {}) {
  return {
    ...publicProfile(uid),
    email: `${uid}@example.com`,
    discoveryLocation: discovery(),
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
    latitude: 19.419,
    longitude: -99.164,
    ...overrides,
  };
}

function matchData(creatorUid = 'organizer', overrides = {}) {
  return {
    title: 'Tomorrow at 6 PM',
    club: 'Roma Padel',
    clubName: 'Roma Padel',
    location: location(),
    dateTime: 'Tomorrow at 6 PM',
    scheduledAt: future(),
    level: 'Level 3',
    spotsLeft: 2,
    players: [],
    creatorUid,
    creatorDisplayName: `Player ${creatorUid}`,
    creatorLevel: 'Level 3',
    createdAt: Timestamp.fromMillis(now),
    ...overrides,
  };
}

async function seed(path, data) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

async function createProfilePair(db, uid, overrides = {}) {
  const batch = writeBatch(db);
  const createdAt = serverTimestamp();
  const updatedAt = serverTimestamp();
  const shared = {
    uid,
    displayName: `Player ${uid}`,
    level: 'Level 3',
    ...(overrides.shared ?? {}),
  };
  batch.set(doc(db, 'users', uid), {
    ...shared,
    createdAt,
    updatedAt,
    email: overrides.email ?? `${uid}@example.com`,
    discoveryLocation: overrides.discoveryLocation ?? discovery(),
    ...(overrides.privateOnly ?? {}),
  });
  batch.set(doc(db, 'publicProfiles', uid), {
    ...shared,
    ...(overrides.publicOnly ?? {}),
  });
  return batch.commit();
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile('firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

describe('private and public profiles', () => {
  test('private users are owner-only while public profiles are signed-in readable', async () => {
    await seed('users/alice', privateProfile('alice'));
    await seed('publicProfiles/alice', publicProfile('alice'));

    await assertFails(getDoc(doc(environment.unauthenticatedContext().firestore(), 'users/alice')));
    await assertFails(getDoc(doc(auth('bob'), 'users/alice')));
    await assertSucceeds(getDoc(doc(auth('alice'), 'users/alice')));
    const snapshot = await assertSucceeds(getDoc(doc(auth('bob'), 'publicProfiles/alice')));
    assert.equal(snapshot.data().email, undefined);
    await assertFails(getDoc(doc(environment.unauthenticatedContext().firestore(), 'publicProfiles/alice')));
  });

  test('owner creates synchronized private/public profiles atomically', async () => {
    await assertSucceeds(createProfilePair(auth('alice'), 'alice'));
    await assertSucceeds(getDoc(doc(auth('alice'), 'users/alice')));
    await assertSucceeds(getDoc(doc(auth('bob'), 'publicProfiles/alice')));
  });

  test('another user cannot modify private or public profile', async () => {
    await seed('users/alice', privateProfile('alice'));
    await seed('publicProfiles/alice', publicProfile('alice'));
    await assertFails(updateDoc(doc(auth('bob'), 'users/alice'), { displayName: 'Mallory' }));
    await assertFails(updateDoc(doc(auth('bob'), 'publicProfiles/alice'), { displayName: 'Mallory' }));
  });

  test('arbitrary fields, spoofed email, invalid level, and coordinates are rejected', async () => {
    await assertFails(createProfilePair(auth('alice'), 'alice', { privateOnly: { admin: true } }));
    await assertFails(createProfilePair(auth('alice'), 'alice', { publicOnly: { email: 'public@example.com' } }));
    await assertFails(createProfilePair(auth('alice'), 'alice', { email: 'victim@example.com' }));
    await assertFails(createProfilePair(auth('alice'), 'alice', { shared: { level: 'Level 99' } }));
    await assertFails(createProfilePair(auth('alice'), 'alice', {
      discoveryLocation: discovery({ latitude: 91 }),
    }));
  });

  test('shared public fields cannot diverge from the private profile', async () => {
    await assertFails(createProfilePair(auth('alice'), 'alice', {
      publicOnly: { displayName: 'Different Name' },
    }));
  });
});

describe('match creation and ownership', () => {
  test('valid match creation succeeds without email snapshots', async () => {
    await seed('publicProfiles/organizer', publicProfile('organizer'));
    const db = auth('organizer');
    const data = matchData();
    data.createdAt = serverTimestamp();
    await assertSucceeds(setDoc(doc(collection(db, 'matches')), data));
  });

  test('malformed, unexpected-field, and creator-spoofed matches are rejected', async () => {
    await seed('publicProfiles/organizer', publicProfile('organizer'));
    const db = auth('organizer');
    for (const data of [
      matchData('organizer', { club: 42 }),
      matchData('organizer', { unexpected: true }),
      matchData('victim'),
      matchData('organizer', { creatorEmail: 'organizer@example.com' }),
      matchData('organizer', { location: location({ latitude: 200 }) }),
    ]) {
      data.createdAt = serverTimestamp();
      await assertFails(setDoc(doc(collection(db, 'matches')), data));
    }
  });

  test('another user cannot edit, cancel, reassign ownership, or change players', async () => {
    await seed('matches/m1', matchData());
    const match = doc(auth('attacker'), 'matches/m1');
    await assertFails(updateDoc(match, { level: 'Level 4' }));
    await assertFails(updateDoc(match, { creatorUid: 'attacker' }));
    await assertFails(updateDoc(match, {
      players: [{ uid: 'attacker', displayName: 'Attacker', level: 'Level 3' }],
      spotsLeft: 1,
    }));
    await assertFails(deleteDoc(match));
  });

  test('completed timestamped matches cannot be edited', async () => {
    await seed('matches/m1', matchData('organizer', { scheduledAt: past() }));
    await assertFails(updateDoc(doc(auth('organizer'), 'matches/m1'), { level: 'Level 4' }));
  });

  test('unverified or verified email does not authorize email-only legacy ownership', async () => {
    const data = matchData('');
    delete data.creatorUid;
    data.creatorEmail = 'legacy@example.com';
    await seed('matches/legacy-email', data);
    await assertFails(updateDoc(doc(auth('attacker', 'legacy@example.com', false), 'matches/legacy-email'), { level: 'Level 4' }));
    await assertFails(updateDoc(doc(auth('attacker', 'legacy@example.com', true), 'matches/legacy-email'), { level: 'Level 4' }));
  });

  test('legacy createdBy UID fallback remains authorized', async () => {
    const data = matchData('', { createdBy: 'legacy-owner' });
    delete data.creatorUid;
    await seed('matches/legacy-uid', data);
    await assertSucceeds(updateDoc(doc(auth('legacy-owner'), 'matches/legacy-uid'), { level: 'Level 4' }));
  });
});

describe('join requests, notifications, and ratings', () => {
  test('requester cannot self-approve or bypass the organizer', async () => {
    await seed('matches/m1', matchData('organizer', { spotsLeft: 1 }));
    await seed('matches/m1/joinRequests/requester', {
      userId: 'requester', displayName: 'Player requester', level: 'Level 3',
      email: 'requester@example.com', status: 'pending',
      requestedAt: Timestamp.fromMillis(now), eventId: 'event-1',
    });
    const db = auth('requester');
    const batch = writeBatch(db);
    batch.update(doc(db, 'matches/m1'), {
      players: [{ uid: 'requester', displayName: 'Player requester', level: 'Level 3' }],
      spotsLeft: 0,
    });
    batch.update(doc(db, 'matches/m1/joinRequests/requester'), { status: 'approved' });
    await assertFails(batch.commit());
  });

  test('organizer approval requires matching atomic match/request state', async () => {
    await seed('matches/m1', matchData('organizer', { spotsLeft: 1 }));
    await seed('matches/m1/joinRequests/requester', {
      userId: 'requester', displayName: 'Player requester', level: 'Level 3',
      email: 'requester@example.com', status: 'pending',
      requestedAt: Timestamp.fromMillis(now), eventId: 'event-1',
    });
    const db = auth('organizer');
    await assertFails(updateDoc(doc(db, 'matches/m1/joinRequests/requester'), { status: 'approved' }));
    const batch = writeBatch(db);
    batch.update(doc(db, 'matches/m1'), {
      players: [{ uid: 'requester', displayName: 'Player requester', level: 'Level 3' }],
      spotsLeft: 0,
    });
    batch.update(doc(db, 'matches/m1/joinRequests/requester'), { status: 'approved' });
    await assertSucceeds(batch.commit());
  });

  test('another recipient notification cannot be marked read', async () => {
    await seed('notifications/n1', {
      recipientUid: 'alice', isRead: false, type: 'join_approved',
      createdAt: Timestamp.fromMillis(now),
    });
    await assertFails(updateDoc(doc(auth('bob'), 'notifications/n1'), { isRead: true }));
    await assertSucceeds(updateDoc(doc(auth('alice'), 'notifications/n1'), { isRead: true }));
  });

  test('self-rating and duplicate rating are blocked', async () => {
    await seed('matches/completed', matchData('organizer', {
      scheduledAt: past(),
      players: [
        { uid: 'rater', displayName: 'Rater', level: 'Level 3' },
        { uid: 'rated', displayName: 'Rated', level: 'Level 3' },
      ],
      spotsLeft: 0,
    }));
    const db = auth('rater');
    const self = doc(db, 'matches/completed/ratingRaters/rater/ratings/rater');
    await assertFails(setDoc(self, {
      matchId: 'completed', raterUid: 'rater', ratedUid: 'rater',
      rating: 5, createdAt: serverTimestamp(),
    }));
    const rating = doc(db, 'matches/completed/ratingRaters/rater/ratings/rated');
    await assertSucceeds(setDoc(rating, {
      matchId: 'completed', raterUid: 'rater', ratedUid: 'rated',
      rating: 5, createdAt: serverTimestamp(),
    }));
    await assertFails(setDoc(rating, {
      matchId: 'completed', raterUid: 'rater', ratedUid: 'rated',
      rating: 1, createdAt: serverTimestamp(),
    }));
  });
});
