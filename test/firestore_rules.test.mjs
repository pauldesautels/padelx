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
  deleteField,
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
    countryCode: 'MX',
    city: 'Mexico City',
    area: 'Roma Norte',
    preferredSide: 'either',
    playFrequency: 'weekly',
    bio: '',
    discoverable: false,
    ...overrides,
  };
}

function privateProfile(uid, overrides = {}) {
  return {
    uid,
    displayName: `Player ${uid}`,
    level: 'Level 3',
    preferredSide: 'either',
    playFrequency: 'weekly',
    bio: '',
    discoverable: false,
    email: `${uid}@example.com`,
    discoveryLocation: discovery(),
    createdAt: Timestamp.fromMillis(now),
    updatedAt: Timestamp.fromMillis(now),
    ...overrides,
  };
}

function notificationSettings(overrides = {}) {
  return {
    pushEnabled: false,
    matchMessages: true,
    joinRequests: true,
    friendRequests: true,
    friendAccepted: true,
    matchUpdates: true,
    playAgain: true,
    updatedAt: serverTimestamp(),
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
    preferredSide: 'either',
    playFrequency: 'weekly',
    bio: '',
    discoverable: false,
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
    countryCode: overrides.discoveryLocation?.countryCode ?? 'MX',
    city: overrides.discoveryLocation?.city ?? 'Mexico City',
    area: overrides.discoveryLocation?.area ?? 'Roma Norte',
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

describe('account enforcement boundary', () => {
  async function enforcementFixture(status, expiresAt) {
    await seed('users/restricted', privateProfile('restricted'));
    await seed('publicProfiles/restricted', publicProfile('restricted'));
    await seed('publicProfiles/other', publicProfile('other'));
    await seed('matches/enforcement-match', matchData('other'));
    await seed('matches/enforcement-match/joinRequests/restricted', {
      userId: 'restricted', displayName: 'Player restricted', level: 'Level 3',
      email: 'restricted@example.com', status: 'pending',
      requestedAt: Timestamp.fromMillis(now), eventId: 'event-enforcement',
    });
    await seed('matches/enforcement-match/ratingRaters/restricted/ratings/other', {
      matchId: 'enforcement-match', raterUid: 'restricted', ratedUid: 'other',
      rating: 5, createdAt: Timestamp.fromMillis(now),
    });
    await seed('notifications/enforcement-notification', {
      recipientUid: 'restricted', isRead: false, type: 'join_approved',
      createdAt: Timestamp.fromMillis(now),
    });
    await seed('users/restricted/friendViews/other', {
      otherUid: 'other', status: 'accepted', acceptedAt: Timestamp.fromMillis(now),
    });
    await seed('users/restricted/playedWith/other', {
      otherUid: 'other', completedMatchCount: 1,
    });
    await seed('users/restricted/settings/notifications', {
      ...notificationSettings(), updatedAt: Timestamp.fromMillis(now),
    });
    await seed('accountEnforcement/restricted', {
      schemaVersion: 1, uid: 'restricted', status,
      reasonCode: 'harassment_abuse', createdAt: Timestamp.fromMillis(now),
      updatedAt: Timestamp.fromMillis(now), actionedBy: 'trusted-actor',
      sourceReportIds: [], ...(expiresAt ? { expiresAt } : {}),
    });
  }

  for (const status of ['suspended', 'banned']) {
    test(`${status} requester is denied across direct client surfaces`, async () => {
      await enforcementFixture(status, status === 'suspended' ? future() : null);
      const db = auth('restricted');
      for (const path of [
        'users/restricted', 'publicProfiles/other', 'matches/enforcement-match',
        'matches/enforcement-match/joinRequests/restricted',
        'matches/enforcement-match/ratingRaters/restricted/ratings/other',
        'notifications/enforcement-notification', 'users/restricted/friendViews/other',
        'users/restricted/playedWith/other', 'users/restricted/settings/notifications',
      ]) await assertFails(getDoc(doc(db, path)));
      await assertFails(updateDoc(doc(db, 'users/restricted/settings/notifications'), notificationSettings()));
    });
  }

  test('expired suspension restores existing authorized access', async () => {
    await enforcementFixture('suspended', past());
    const db = auth('restricted');
    await assertSucceeds(getDoc(doc(db, 'users/restricted')));
    await assertSucceeds(getDoc(doc(db, 'publicProfiles/other')));
    await assertSucceeds(getDoc(doc(db, 'matches/enforcement-match')));
    await assertSucceeds(getDoc(doc(db, 'notifications/enforcement-notification')));
  });

  test('enforcement and moderation records are completely server-only', async () => {
    await enforcementFixture('banned');
    await seed('moderationActions/action-one', {
      schemaVersion: 1, type: 'ban_applied', targetUid: 'restricted',
      actorUid: 'trusted-actor', reasonCode: 'harassment_abuse',
      sourceReportIds: [], createdAt: Timestamp.fromMillis(now), requestId: 'request_1234567890',
    });
    for (const db of [environment.unauthenticatedContext().firestore(), auth('restricted'), auth('other')]) {
      await assertFails(getDoc(doc(db, 'accountEnforcement/restricted')));
      await assertFails(getDocs(collection(db, 'accountEnforcement')));
      await assertFails(setDoc(doc(db, 'accountEnforcement/forged'), { status: 'banned' }));
      await assertFails(updateDoc(doc(db, 'accountEnforcement/restricted'), { status: 'banned' }));
      await assertFails(deleteDoc(doc(db, 'accountEnforcement/restricted')));
      await assertFails(getDoc(doc(db, 'moderationActions/action-one')));
      await assertFails(getDocs(collection(db, 'moderationActions')));
      await assertFails(setDoc(doc(db, 'moderationActions/forged'), { type: 'ban_applied' }));
      await assertFails(updateDoc(doc(db, 'moderationActions/action-one'), { type: 'ban_revoked' }));
      await assertFails(deleteDoc(doc(db, 'moderationActions/action-one')));
    }
  });
});

describe('private and public profiles', () => {
  test('avatar version is synchronized and cannot reference another user path', async () => {
    const db = auth('alice');
    await assertSucceeds(createProfilePair(db, 'alice'));
    const batch = writeBatch(db);
    batch.update(doc(db, 'users/alice'), {
      avatarVersion: 42,
      updatedAt: serverTimestamp(),
    });
    batch.update(doc(db, 'publicProfiles/alice'), { avatarVersion: 42 });
    await assertSucceeds(batch.commit());
    await assertFails(updateDoc(doc(db, 'publicProfiles/alice'), {
      avatarPath: 'profileAvatars/bob/avatar-42.jpg',
    }));
    await assertFails(updateDoc(doc(db, 'publicProfiles/alice'), {
      avatarVersion: -1,
    }));
    await assertFails(updateDoc(doc(db, 'publicProfiles/alice'), {
      avatarVersion: 43,
    }));
  });

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

  test('clients cannot forge server-maintained played-with aggregates', async () => {
    await assertFails(createProfilePair(auth('fresh'), 'fresh', {
      publicOnly: { completedMatchCount: 1, repeatPlayerCount: 1 },
    }));
    await seed('users/alice', privateProfile('alice'));
    await seed('publicProfiles/alice', {
      ...publicProfile('alice'), completedMatchCount: 3, repeatPlayerCount: 1,
    });
    await assertFails(updateDoc(doc(auth('alice'), 'publicProfiles/alice'), {
      completedMatchCount: 99,
    }));
    await assertFails(updateDoc(doc(auth('alice'), 'publicProfiles/alice'), {
      repeatPlayerCount: 99,
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

  test('social profile fields and coarse public location stay synchronized', async () => {
    await assertSucceeds(createProfilePair(auth('alice'), 'alice', {
      shared: {
        preferredSide: 'left', playFrequency: 'several_per_week',
        bio: 'Competitive but friendly.', discoverable: true,
      },
    }));
    await assertFails(createProfilePair(auth('bob'), 'bob', {
      shared: { preferredSide: 'middle' },
    }));
    await assertFails(createProfilePair(auth('carol'), 'carol', {
      shared: { playFrequency: 'daily' },
    }));
    await assertFails(createProfilePair(auth('dave'), 'dave', {
      shared: { bio: 'x'.repeat(161) },
    }));
    await assertFails(createProfilePair(auth('erin'), 'erin', {
      shared: { discoverable: 'yes' },
    }));
    await assertFails(createProfilePair(auth('frank'), 'frank', {
      publicOnly: { city: 'Guadalajara' },
    }));
  });

  test('public profiles reject all private and precise location fields', async () => {
    for (const prohibited of [
      { email: 'alice@example.com' },
      { latitude: 19.4 },
      { longitude: -99.1 },
      { placeId: 'secret-place' },
    ]) {
      await assertFails(createProfilePair(auth('alice'), 'alice', {
        publicOnly: prohibited,
      }));
    }
  });

  test('owner can edit social fields atomically without changing aggregates', async () => {
    await seed('users/alice', privateProfile('alice'));
    await seed('publicProfiles/alice', {
      ...publicProfile('alice'), ratingCount: 2, ratingSum: 9, ratingAverage: 4.5,
    });
    const db = auth('alice');
    const batch = writeBatch(db);
    batch.update(doc(db, 'users/alice'), {
      preferredSide: 'right', playFrequency: 'several_per_week',
      bio: 'Right-side player', discoverable: true, updatedAt: serverTimestamp(),
    });
    batch.update(doc(db, 'publicProfiles/alice'), {
      preferredSide: 'right', playFrequency: 'several_per_week',
      bio: 'Right-side player', discoverable: true,
    });
    await assertSucceeds(batch.commit());
  });

  test('modern profile save removes only known legacy location fields', async () => {
    const uid = 'legacy-location';
    const nestedLocation = discovery({ area: '' });
    await seed(`users/${uid}`, privateProfile(uid, {
      level: '3', playFrequency: 'occasionally', avatarVersion: 7,
      discoveryLocation: nestedLocation,
      countryCode: 'MX', city: 'Mexico City', area: '',
    }));
    await seed(`publicProfiles/${uid}`, {
      ...publicProfile(uid, {
        level: '3', playFrequency: 'occasionally', discoverable: false,
        area: '', avatarVersion: 7,
      }),
      ratingCount: 2, ratingSum: 9, ratingAverage: 4.5,
    });

    const db = auth(uid);
    const batch = writeBatch(db);
    batch.set(doc(db, 'users', uid), {
      uid, displayName: `Player ${uid}`, level: '3', email: `${uid}@example.com`,
      discoveryLocation: nestedLocation,
      countryCode: deleteField(), city: deleteField(), area: deleteField(),
      createdAt: Timestamp.fromMillis(now), updatedAt: serverTimestamp(),
      preferredSide: 'either', playFrequency: 'occasional', bio: '',
      discoverable: true,
    }, { merge: true });
    batch.set(doc(db, 'publicProfiles', uid), {
      uid, displayName: `Player ${uid}`, level: '3', countryCode: 'MX',
      city: 'Mexico City', area: '', preferredSide: 'either',
      playFrequency: 'occasional', bio: '', discoverable: true,
    }, { merge: true });
    await assertSucceeds(batch.commit());

    const savedPrivate = (await getDoc(doc(db, 'users', uid))).data();
    const savedPublic = (await getDoc(doc(db, 'publicProfiles', uid))).data();
    assert.equal('countryCode' in savedPrivate, false);
    assert.equal('city' in savedPrivate, false);
    assert.equal('area' in savedPrivate, false);
    assert.deepEqual(savedPrivate.discoveryLocation, nestedLocation);
    assert.equal(savedPrivate.discoverable, true);
    assert.equal(savedPrivate.playFrequency, 'occasional');
    assert.equal(savedPrivate.avatarVersion, 7);
    for (const key of ['uid', 'displayName', 'level', 'preferredSide',
      'playFrequency', 'bio', 'discoverable', 'avatarVersion']) {
      assert.equal(savedPrivate[key], savedPublic[key]);
    }
    assert.equal(savedPublic.ratingCount, 2);
    assert.equal(savedPublic.ratingSum, 9);
    assert.equal(savedPublic.ratingAverage, 4.5);
  });

  test('modern clean profile still saves with legacy cleanup sentinels', async () => {
    const uid = 'modern-clean';
    await seed(`users/${uid}`, privateProfile(uid, { level: '3' }));
    await seed(`publicProfiles/${uid}`, publicProfile(uid, { level: '3' }));
    const db = auth(uid);
    const batch = writeBatch(db);
    batch.set(doc(db, 'users', uid), {
      countryCode: deleteField(), city: deleteField(), area: deleteField(),
      discoverable: true, updatedAt: serverTimestamp(),
    }, { merge: true });
    batch.set(doc(db, 'publicProfiles', uid), {
      discoverable: true,
    }, { merge: true });
    await assertSucceeds(batch.commit());
    assert.equal((await getDoc(doc(db, 'users', uid))).data().discoverable, true);
    assert.equal((await getDoc(doc(db, 'publicProfiles', uid))).data().discoverable, true);
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
  test('reports and report rate limits are inaccessible to every client', async () => {
    await seed('reports/report-1', { reporterUid: 'alice', subjectOwnerUid: 'bob', status: 'open' });
    await seed('reportRateLimits/rate-1', { submittedAt: [past()] });
    const clients = [environment.unauthenticatedContext().firestore(), auth('alice'), auth('bob'), auth('charlie')];
    for (const db of clients) {
      for (const collectionName of ['reports', 'reportRateLimits']) {
        const reference = doc(db, `${collectionName}/${collectionName === 'reports' ? 'report-1' : 'rate-1'}`);
        await assertFails(getDoc(reference));
        await assertFails(getDocs(collection(db, collectionName)));
        await assertFails(setDoc(doc(db, `${collectionName}/new`), { status: 'open' }));
        await assertFails(updateDoc(reference, { status: 'changed' }));
        await assertFails(deleteDoc(reference));
      }
    }
  });

  test('eligibility evidence is inaccessible to every client', async () => {
    await seed('accountEligibility/alice', {
      uid: 'alice', age18Confirmed: true, ageEligibilityVersion: '18-plus-v1',
      confirmedAt: past(), schemaVersion: 1,
    });
    const clients = [environment.unauthenticatedContext().firestore(), auth('alice'), auth('bob')];
    for (const db of clients) {
      await assertFails(getDoc(doc(db, 'accountEligibility/alice')));
      await assertFails(setDoc(doc(db, 'accountEligibility/new'), { age18Confirmed: true }));
      await assertFails(updateDoc(doc(db, 'accountEligibility/alice'), { age18Confirmed: false }));
      await assertFails(deleteDoc(doc(db, 'accountEligibility/alice')));
    }
  });

  test('barriers, jobs, and contributions are server-owned for all users', async () => {
    for (const collectionName of ['accountDeletionBarriers', 'accountDeletionJobs', 'accountDeletionOutbox',
      'accountEligibility',
      'ratingContributions', 'playedWithMatchContributions', 'playedWithContributions',
      'playedWithPairs', 'socialProjectionState']) {
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

describe('played-with access boundary', () => {
  test('owners can read only their own projection and no client can write it', async () => {
    const value = { otherUid: 'bob', completedMatchCount: 1, projectionVersion: 1,
      firstPlayedAt: past(), lastPlayedAt: past(), lastMatchId: 'm1', updatedAt: past() };
    await seed('users/alice/playedWith/bob', value);
    await assertSucceeds(getDoc(doc(auth('alice'), 'users/alice/playedWith/bob')));
    await assertFails(getDoc(doc(auth('bob'), 'users/alice/playedWith/bob')));
    await assertFails(getDoc(doc(environment.unauthenticatedContext().firestore(), 'users/alice/playedWith/bob')));
    for (const db of [auth('alice'), auth('bob')]) {
      await assertFails(setDoc(doc(db, 'users/alice/playedWith/new'), value));
      await assertFails(updateDoc(doc(db, 'users/alice/playedWith/bob'), { completedMatchCount: 2 }));
      await assertFails(deleteDoc(doc(db, 'users/alice/playedWith/bob')));
    }
  });
});

describe('friend and block access boundary', () => {
  test('friend views are owner-readable and all social records are server-written', async () => {
    const view = { otherUid: 'bob', friendshipId: 'pair', status: 'pending',
      direction: 'incoming', createdAt: past(), updatedAt: past() };
    await seed('users/alice/friendViews/bob', view);
    await assertSucceeds(getDoc(doc(auth('alice'), 'users/alice/friendViews/bob')));
    await assertFails(getDoc(doc(auth('bob'), 'users/alice/friendViews/bob')));
    for (const db of [auth('alice'), auth('bob')]) {
      await assertFails(setDoc(doc(db, 'users/alice/friendViews/new'), view));
      await assertFails(setDoc(doc(db, 'friendships/pair'), { memberUids: ['alice', 'bob'] }));
      await assertFails(getDoc(doc(db, 'friendships/pair')));
    }
  });

  test('a blocker can get only their own block and cannot list or write blocks', async () => {
    await seed('blocks/owned', { blockerUid: 'alice', blockedUid: 'bob', createdAt: past() });
    await assertSucceeds(getDoc(doc(auth('alice'), 'blocks/owned')));
    await assertFails(getDoc(doc(auth('bob'), 'blocks/owned')));
    await assertFails(getDocs(query(collection(auth('alice'), 'blocks'), where('blockerUid', '==', 'alice'))));
    await assertFails(setDoc(doc(auth('alice'), 'blocks/new'), { blockerUid: 'alice', blockedUid: 'bob' }));
  });
});

describe('messaging access boundary', () => {
  test('canonical conversations, messages, views, and rate limits are server-only', async () => {
    await seed('conversations/direct_pair', { type: 'direct', memberUids: ['alice', 'bob'] });
    await seed('conversations/direct_pair/messages/message', {
      senderUid: 'alice', text: 'hello', createdAt: past(), requestId: 'request_123456789',
    });
    await seed('users/alice/conversationViews/direct_pair', {
      conversationId: 'direct_pair', type: 'direct', otherUid: 'bob', unreadCount: 1,
    });
    await seed('messagingRateLimits/alice', { count: 1, windowStartedAt: past() });
    for (const db of [auth('alice'), auth('bob')]) {
      await assertFails(getDoc(doc(db, 'conversations/direct_pair')));
      await assertFails(getDoc(doc(db, 'conversations/direct_pair/messages/message')));
      await assertFails(setDoc(doc(db, 'conversations/new'), { type: 'direct' }));
      await assertFails(setDoc(doc(db, 'conversations/direct_pair/messages/new'), { text: 'x' }));
      await assertFails(getDoc(doc(db, 'users/alice/conversationViews/direct_pair')));
      await assertFails(setDoc(doc(db, 'users/alice/conversationViews/new'), { unreadCount: 0 }));
      await assertFails(getDoc(doc(db, 'messagingRateLimits/alice')));
    }
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

describe('notification preferences and push devices', () => {
  test('owner can read and write only the exact notification preference schema', async () => {
    const alice = auth('alice');
    const own = doc(alice, 'users/alice/settings/notifications');
    await assertSucceeds(setDoc(own, notificationSettings()));
    await assertSucceeds(getDoc(own));
    await assertSucceeds(setDoc(own, notificationSettings({ pushEnabled: true })));
    await assertFails(getDoc(doc(auth('bob'), 'users/alice/settings/notifications')));
    await assertFails(setDoc(
      doc(auth('bob'), 'users/alice/settings/notifications'),
      notificationSettings(),
    ));
    await assertFails(setDoc(own, notificationSettings({ token: 'secret' })));
    await assertFails(setDoc(own, notificationSettings({ matchMessages: 'yes' })));
    await assertFails(setDoc(own, {
      ...notificationSettings(),
      updatedAt: Timestamp.fromMillis(now),
    }));
    await assertFails(deleteDoc(own));
  });

  test('push device registrations are inaccessible to clients', async () => {
    await seed('pushDevices/hash', { uid: 'alice', token: 'private-token' });
    for (const db of [auth('alice'), auth('bob'), environment.unauthenticatedContext().firestore()]) {
      await assertFails(getDoc(doc(db, 'pushDevices/hash')));
      await assertFails(getDocs(collection(db, 'pushDevices')));
      await assertFails(setDoc(doc(db, 'pushDevices/new'), { uid: 'alice', token: 'value' }));
      await assertFails(deleteDoc(doc(db, 'pushDevices/hash')));
    }
  });
});
