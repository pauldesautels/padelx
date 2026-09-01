import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import {
  publicProfileMatches,
  resolveMatchOwner,
} from './migrate_phase8a_safety.mjs';

const apply = process.argv.includes('--apply');
const projectIdArgument = process.argv.find((value) => value.startsWith('--project='));
const projectId = projectIdArgument?.slice('--project='.length);

if (!projectId) {
  throw new Error('Pass the explicit target as --project=<firebase-project-id>.');
}

const app = initializeApp({ credential: applicationDefault(), projectId });
const firestore = getFirestore(app);
const auth = getAuth(app);
const validLevel = /^(Level )?([1-6](\.5)?|7)$|^(Beginner|Intermediate|Advanced)$/;
const blockers = [];
const writes = [];
const privateUserFields = new Set([
  'uid', 'displayName', 'level', 'email', 'discoveryLocation',
  'createdAt', 'updatedAt',
]);

function queue(reference, data, options = undefined, operation = 'set') {
  writes.push({ reference, data, options, operation });
}

const users = await firestore.collection('users').get();
const publicProfiles = await firestore.collection('publicProfiles').get();
const publicProfilesByUid = new Map(
  publicProfiles.docs.map((document) => [document.id, document.data()]),
);
const userIds = new Set(users.docs.map((document) => document.id));
for (const document of publicProfiles.docs) {
  if (!userIds.has(document.id)) {
    blockers.push(`publicProfiles/${document.id}: no matching private users document`);
  }
}
for (const document of users.docs) {
  const data = document.data();
  const uid = document.id;
  const displayName = typeof data.displayName === 'string' ? data.displayName.trim() : '';
  const level = typeof data.level === 'string' ? data.level.trim() : '';
  const unexpectedFields = Object.keys(data).filter((field) => !privateUserFields.has(field));
  let authUser;
  try {
    authUser = await auth.getUser(uid);
  } catch {
    blockers.push(`users/${uid}: no matching Firebase Auth user`);
    continue;
  }
  if (
    data.uid !== uid
    || displayName.length < 2
    || displayName.length > 40
    || !validLevel.test(level)
    || typeof data.email !== 'string'
    || data.email !== authUser.email
    || unexpectedFields.length > 0
  ) {
    blockers.push(`users/${uid}: schema/auth-email mismatch; repair manually`);
    continue;
  }
  const createdAt = data.createdAt instanceof Timestamp ? data.createdAt : Timestamp.now();
  const updatedAt = data.updatedAt instanceof Timestamp ? data.updatedAt : createdAt;
  const expectedPublicProfile = {
    uid,
    displayName,
    level,
  };
  const existingPublicProfile = publicProfilesByUid.get(uid);
  if (existingPublicProfile === undefined) {
    queue(
      firestore.collection('publicProfiles').doc(uid),
      expectedPublicProfile,
      undefined,
      'create',
    );
  } else if (!publicProfileMatches(existingPublicProfile, expectedPublicProfile)) {
    blockers.push(`publicProfiles/${uid}: existing data is unexpected or differs from users/${uid}`);
    continue;
  }
  if (!(data.createdAt instanceof Timestamp) || !(data.updatedAt instanceof Timestamp)) {
    queue(document.ref, { createdAt, updatedAt }, { merge: true });
  }
}

const matches = await firestore.collection('matches').get();
for (const document of matches.docs) {
  const data = document.data();
  const update = {};
  let owner;
  try {
    owner = await resolveMatchOwner(data, {
      getUser: (uid) => auth.getUser(uid),
      getUserByEmail: (email) => auth.getUserByEmail(email),
    });
  } catch (error) {
    blockers.push(`matches/${document.id}: ${error.message}`);
    continue;
  }
  if (owner.mappedFromEmail) update.creatorUid = owner.ownerUid;

  if ('creatorEmail' in data) update.creatorEmail = FieldValue.delete();
  if ('createdByEmail' in data) update.createdByEmail = FieldValue.delete();
  if (Array.isArray(data.players)) {
    const players = data.players.map((player) => {
      if (player == null || typeof player !== 'object' || !('email' in player)) return player;
      const { email: _email, ...publicPlayer } = player;
      return publicPlayer;
    });
    update.players = players;
  }
  if (Object.keys(update).length > 0) queue(document.ref, update, { merge: true });
}

console.log(`${apply ? 'APPLY' : 'DRY RUN'} project=${projectId}`);
console.log(`users=${users.size} publicProfiles=${publicProfiles.size} matches=${matches.size} queuedWrites=${writes.length}`);
for (const blocker of blockers) console.error(`BLOCKER ${blocker}`);

if (!apply) {
  console.log('No writes performed. Re-run with --apply only after reviewing every blocker.');
  process.exitCode = blockers.length === 0 ? 0 : 2;
} else if (blockers.length > 0) {
  console.error('No writes performed because unresolved blockers remain.');
  process.exitCode = 2;
} else {
  for (let index = 0; index < writes.length; index += 400) {
    const batch = firestore.batch();
    for (const write of writes.slice(index, index + 400)) {
      if (write.operation === 'create') {
        batch.create(write.reference, write.data);
      } else {
        batch.set(write.reference, write.data, write.options ?? {});
      }
    }
    await batch.commit();
  }
  console.log(`Applied ${writes.length} writes.`);
}
