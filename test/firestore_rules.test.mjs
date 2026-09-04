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
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-padelx-phase8';
const now = Date.now();
const future = () => Timestamp.fromMillis(now + 86_400_000);
const past = () => Timestamp.fromMillis(now - 86_400_000);

let environment;

function auth(uid, email = `${uid}@example.com`, emailVerified = true) {
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
    participantUids: [creatorUid],
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

describe('verified email boundary', () => {
  test('unauthenticated and unverified users cannot read application data', async () => {
    await seed('users/alice', privateProfile('alice'));
    await seed('publicProfiles/alice', publicProfile('alice'));
    await seed('matches/m1', matchData());
    await seed('matches/m1/joinRequests/alice', {
      userId: 'alice', displayName: 'Player alice', level: 'Level 3',
      email: 'alice@example.com', status: 'pending',
      requestedAt: Timestamp.fromMillis(now), eventId: 'event-1',
    });
    await seed('matches/m1/ratingRaters/bob/ratings/alice', {
      matchId: 'm1', raterUid: 'bob', ratedUid: 'alice', rating: 5,
      createdAt: Timestamp.fromMillis(now),
    });
    await seed('notifications/n1', {
      recipientUid: 'alice', isRead: false, type: 'join_approved',
      createdAt: Timestamp.fromMillis(now),
    });

    const unauthenticated = environment.unauthenticatedContext().firestore();
    const unverified = auth('alice', 'alice@example.com', false);
    for (const [db, paths] of [
      [unauthenticated, ['publicProfiles/alice', 'matches/m1']],
      [unverified, [
        'users/alice',
        'publicProfiles/alice',
        'matches/m1',
        'matches/m1/joinRequests/alice',
        'matches/m1/ratingRaters/bob/ratings/alice',
        'notifications/n1',
      ]],
    ]) {
      for (const path of paths) {
        await assertFails(getDoc(doc(db, path)));
      }
    }
  });

  test('unverified users cannot create or update application data', async () => {
    await seed('publicProfiles/alice', publicProfile('alice'));
    await seed('matches/m1', matchData());
    await seed('notifications/n1', {
      recipientUid: 'alice', isRead: false, type: 'join_approved',
      createdAt: Timestamp.fromMillis(now),
    });
    const db = auth('alice', 'alice@example.com', false);

    await assertFails(createProfilePair(db, 'alice'));
    const data = matchData('alice');
    data.createdAt = serverTimestamp();
    await assertFails(setDoc(doc(collection(db, 'matches')), data));
    await assertFails(updateDoc(doc(db, 'notifications/n1'), { isRead: true }));
  });

  test('verified users retain legitimate application access', async () => {
    const db = auth('alice');
    await assertSucceeds(createProfilePair(db, 'alice'));
    await assertSucceeds(getDoc(doc(db, 'users/alice')));
    await assertSucceeds(getDoc(doc(db, 'publicProfiles/alice')));
  });
});

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

  test('clients cannot forge server-maintained lifetime rating aggregates', async () => {
    await assertFails(createProfilePair(auth('fresh'), 'fresh', {
      publicOnly: { ratingCount: 1, ratingSum: 5, ratingAverage: 5 },
    }));
    await assertFails(createProfilePair(auth('fresh'), 'fresh', {
      publicOnly: { ratingSum: 5 },
    }));
    await seed('users/alice', privateProfile('alice'));
    await seed('publicProfiles/alice', {
      ...publicProfile('alice'), ratingCount: 2, ratingSum: 9, ratingAverage: 4.5,
    });
    await assertFails(updateDoc(doc(auth('alice'), 'publicProfiles/alice'), {
      ratingCount: 100, ratingSum: 500, ratingAverage: 5,
    }));
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
      participantUids: ['organizer', 'requester'],
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
      participantUids: ['organizer', 'requester'],
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

  test('participant query projection cannot be forged', async () => {
    await seed('publicProfiles/organizer', publicProfile('organizer'));
    const db = auth('organizer');
    const data = matchData('organizer', { participantUids: ['organizer', 'victim'] });
    data.createdAt = serverTimestamp();
    await assertFails(setDoc(doc(db, 'matches/forged'), data));

    await seed('matches/m1', matchData());
    await assertFails(updateDoc(doc(db, 'matches/m1'), {
      participantUids: ['organizer', 'victim'],
    }));
    await assertFails(updateDoc(doc(db, 'matches/m1'), {
      geoHash3: 'zzz', geoHash4: 'zzzz',
    }));
  });

  test('rating aggregation idempotency markers are backend-only', async () => {
    await seed('ratingAggregationEvents/event-1', { ratedUid: 'alice' });
    await assertFails(getDoc(doc(auth('alice'), 'ratingAggregationEvents/event-1')));
    await assertFails(setDoc(doc(auth('alice'), 'ratingAggregationEvents/forged'), {
      ratedUid: 'alice',
    }));
  });

  test('verified users can run bounded discovery and participant queries', async () => {
    await seed('matches/m1', matchData('organizer'));
    const db = auth('organizer');
    await assertSucceeds(getDocs(query(
      collection(db, 'matches'),
      where('scheduledAt', '>=', Timestamp.fromMillis(now)),
      orderBy('scheduledAt'),
      limit(60),
    )));
    await assertSucceeds(getDocs(query(
      collection(db, 'matches'),
      where('participantUids', 'array-contains', 'organizer'),
      orderBy('scheduledAt', 'desc'),
      limit(100),
    )));
  });

  test('self-rating and duplicate rating are blocked', async () => {
    await seed('publicProfiles/rated', publicProfile('rated'));
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

describe('account deletion foundation', () => {
  test('barriers, jobs, and contributions are server-owned for all users', async () => {
    for (const collectionName of ['accountDeletionBarriers', 'accountDeletionJobs', 'accountDeletionOutbox', 'ratingContributions']) {
      await seed(`${collectionName}/alice`, { status: 'deleting', schemaVersion: 1 });
      for (const uid of ['alice', 'bob']) {
        const db = auth(uid);
        await assertFails(getDoc(doc(db, `${collectionName}/alice`)));
        await assertFails(setDoc(doc(db, `${collectionName}/new`), { uid }));
        await assertFails(updateDoc(doc(db, `${collectionName}/alice`), { status: 'active' }));
        await assertFails(deleteDoc(doc(db, `${collectionName}/alice`)));
      }
    }
  });

  test('barrier denies normal writes and cannot be bypassed by another user', async () => {
    const db = auth('alice');
    await assertSucceeds(createProfilePair(db, 'alice'));
    await seed('matches/owned', matchData('alice'));
    await seed('notifications/own', { recipientUid: 'alice', isRead: false });
    await seed('accountDeletionBarriers/alice', { status: 'complete' });
    await assertFails(createProfilePair(db, 'alice'));
    await assertFails(updateDoc(doc(db, 'matches/owned'), { level: 'Level 4' }));
    await assertFails(deleteDoc(doc(db, 'matches/owned')));
    await assertFails(updateDoc(doc(db, 'notifications/own'), { isRead: true }));
    const newMatch = matchData('alice', { createdAt: serverTimestamp() });
    await assertFails(setDoc(doc(db, 'matches/new'), newMatch));
    await assertFails(createProfilePair(auth('bob'), 'alice'));
    // Other users' existing bounded reads do not acquire subject-dependent filters.
    await assertSucceeds(getDocs(query(collection(auth('bob'), 'matches'), limit(10))));
  });

  test('new ratings require an active existing target profile and active caller', async () => {
    await seed('matches/completed', matchData('alice', {
      scheduledAt: past(), players: [{ uid: 'bob' }], participantUids: ['alice', 'bob'],
    }));
    const ref = doc(auth('alice'), 'matches/completed/ratingRaters/alice/ratings/bob');
    const value = { matchId: 'completed', raterUid: 'alice', ratedUid: 'bob', rating: 5, createdAt: serverTimestamp() };
    await assertFails(setDoc(ref, value));
    await seed('publicProfiles/bob', publicProfile('bob'));
    await seed('accountDeletionBarriers/bob', { status: 'deleting' });
    await assertFails(setDoc(ref, value));
    await environment.withSecurityRulesDisabled(async (context) => deleteDoc(doc(context.firestore(), 'accountDeletionBarriers/bob')));
    await seed('accountDeletionBarriers/alice', { status: 'deleting' });
    await assertFails(setDoc(ref, value));
  });

  test('another organizer cannot approve a deleting player; requests cannot target a deleting organizer', async () => {
    await seed('matches/m1', matchData('organizer', { spotsLeft: 1 }));
    await seed('publicProfiles/requester', publicProfile('requester'));
    const request = { userId: 'requester', displayName: 'Player requester', level: 'Level 3',
      status: 'pending', requestedAt: serverTimestamp(), eventId: 'e1' };
    await assertFails(setDoc(doc(auth('requester'), 'matches/m1/joinRequests/requester'), { ...request, email: 'requester@example.com' }));
    await assertSucceeds(setDoc(doc(auth('requester'), 'matches/m1/joinRequests/requester'), request));
    await seed('accountDeletionBarriers/requester', { status: 'deleting' });
    const db = auth('organizer');
    const batch = writeBatch(db);
    batch.update(doc(db, 'matches/m1'), { players: [{ uid: 'requester', displayName: 'Player requester', level: 'Level 3' }],
      participantUids: ['organizer', 'requester'], spotsLeft: 0 });
    batch.update(doc(db, 'matches/m1/joinRequests/requester'), { status: 'approved' });
    await assertFails(batch.commit());
    await seed('publicProfiles/other', publicProfile('other'));
    await seed('accountDeletionBarriers/organizer', { status: 'deleting' });
    await assertFails(setDoc(doc(auth('other'), 'matches/m1/joinRequests/other'), {
      ...request, userId: 'other', displayName: 'Player other', email: 'other@example.com',
    }));
  });
});

test('full-capacity approval, notification and subsequent leave retain access', async () => {
  const players = ['first', 'second'].map((uid) => ({ uid, displayName: `Player ${uid}`, level: 'Level 3' }));
  await seed('matches/capacity', matchData('organizer', {
    players, participantUids: ['organizer', 'first', 'second'], spotsLeft: 1,
  }));
  await seed('matches/capacity/joinRequests/requester', {
    userId: 'requester', displayName: 'Player requester', level: 'Level 3',
    email: 'requester@example.com', status: 'pending', requestedAt: past(), eventId: 'capacity-event',
  });
  const db = auth('organizer');
  const batch = writeBatch(db);
  batch.update(doc(db, 'matches/capacity'), {
    players: [...players, { uid: 'requester', displayName: 'Player requester', level: 'Level 3' }],
    participantUids: ['organizer', 'first', 'second', 'requester'], spotsLeft: 0,
  });
  batch.update(doc(db, 'matches/capacity/joinRequests/requester'), { status: 'approved' });
  batch.set(doc(db, 'notifications/join_approved_capacity_capacity-event'), {
    type: 'join_approved', recipientUid: 'requester', actorUid: 'organizer', actorDisplayName: 'Player organizer',
    matchId: 'capacity', matchClubName: 'Roma Padel', title: 'Request approved',
    message: 'Your request to join the match at Roma Padel was approved.',
    isRead: false, createdAt: serverTimestamp(), eventId: 'capacity-event',
  });
  await assertSucceeds(batch.commit());
  const leaveDb = auth('requester');
  const leave = writeBatch(leaveDb);
  leave.update(doc(leaveDb, 'matches/capacity'), {
    players, participantUids: ['organizer', 'first', 'second'], spotsLeft: 1,
  });
  leave.update(doc(leaveDb, 'matches/capacity/joinRequests/requester'), { status: 'declined' });
  await assertSucceeds(leave.commit());
});


test('deletion barrier blocks creation of absent profiles using an old session', async () => {
  const db = auth('deleted-admission');
  await seed('accountDeletionBarriers/deleted-admission', { status: 'deleting' });
  await assertFails(createProfilePair(db, 'deleted-admission'));
  await assertFails(setDoc(doc(db, 'publicProfiles/deleted-admission'), publicProfile('deleted-admission')));
  await assertFails(setDoc(doc(db, 'users/deleted-admission'), privateProfile('deleted-admission')));
  const anonymous = environment.unauthenticatedContext().firestore();
  for (const name of ['accountDeletionBarriers', 'accountDeletionJobs', 'accountDeletionOutbox']) {
    await assertFails(getDoc(doc(anonymous, `${name}/deleted-admission`)));
    await assertFails(setDoc(doc(anonymous, `${name}/deleted-admission`), { status: 'active' }));
  }
});
