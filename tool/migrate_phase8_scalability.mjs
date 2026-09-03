import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import {
  participantUidsForMatch,
  sameStringList,
} from './migrate_phase8_scalability_safety.mjs';
import { encodeGeohash } from '../functions/aggregate_helpers.js';

const apply = process.argv.includes('--apply');
const projectArg = process.argv.find((value) => value.startsWith('--project='));
const projectId = projectArg?.slice('--project='.length);
if (!projectId) throw new Error('Pass the explicit target as --project=<firebase-project-id>.');

const app = initializeApp({ credential: applicationDefault(), projectId });
const firestore = getFirestore(app);
const matches = await firestore.collection('matches').get();
const updates = [];
const blockers = [];

for (const document of matches.docs) {
  try {
    const participantUids = participantUidsForMatch(document.data());
    const data = document.data();
    const latitude = data.location?.latitude;
    const longitude = data.location?.longitude;
    if (typeof latitude !== 'number' || typeof longitude !== 'number') {
      throw new Error('match has no coordinates for geographic discovery');
    }
    const update = {
      participantUids,
      geoHash3: encodeGeohash(latitude, longitude, 3),
      geoHash4: encodeGeohash(latitude, longitude, 4),
    };
    if (!sameStringList(data.participantUids, participantUids)
        || data.geoHash3 !== update.geoHash3 || data.geoHash4 !== update.geoHash4) {
      updates.push({ reference: document.ref, data: update });
    }
  } catch (error) {
    blockers.push(`matches/${document.id}: ${error.message}`);
  }
}

const ratingTotals = new Map();
const ratings = await firestore.collectionGroup('ratings').get();
for (const document of ratings.docs) {
  const data = document.data();
  if (!Number.isInteger(data.rating) || data.rating < 1 || data.rating > 5
      || typeof data.ratedUid !== 'string' || !data.ratedUid) {
    blockers.push(`${document.ref.path}: malformed rating`);
    continue;
  }
  const total = ratingTotals.get(data.ratedUid) ?? { count: 0, sum: 0 };
  total.count += 1; total.sum += data.rating; ratingTotals.set(data.ratedUid, total);
}
const profiles = await firestore.collection('publicProfiles').get();
for (const profile of profiles.docs) {
  const total = ratingTotals.get(profile.id) ?? { count: 0, sum: 0 };
  const expected = {
    ratingCount: total.count,
    ratingSum: total.sum,
    ratingAverage: total.count === 0 ? 0 : total.sum / total.count,
  };
  const data = profile.data();
  if (data.ratingCount !== expected.ratingCount || data.ratingSum !== expected.ratingSum
      || data.ratingAverage !== expected.ratingAverage) {
    updates.push({ reference: profile.ref, data: expected });
  }
  ratingTotals.delete(profile.id);
}
for (const uid of ratingTotals.keys()) blockers.push(`ratings for ${uid}: no public profile`);

console.log(`${apply ? 'APPLY' : 'DRY RUN'} project=${projectId}`);
console.log(`matches=${matches.size} ratings=${ratings.size} profiles=${profiles.size} queuedWrites=${updates.length}`);
for (const blocker of blockers) console.error(`BLOCKER ${blocker}`);

if (!apply) {
  console.log('No writes performed. Re-run with --apply only after reviewing every blocker.');
  process.exitCode = blockers.length === 0 ? 0 : 2;
} else if (blockers.length > 0) {
  console.error('No writes performed because unresolved blockers remain.');
  process.exitCode = 2;
} else {
  for (let index = 0; index < updates.length; index += 400) {
    const batch = firestore.batch();
    for (const update of updates.slice(index, index + 400)) {
      batch.update(update.reference, update.data);
    }
    await batch.commit();
  }
  console.log(`Applied ${updates.length} idempotent match updates.`);
}
