import { pathToFileURL } from 'node:url';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { validateBackendEnvironment } from '../functions/backend_environment.js';
import { cleanDeletionMatch, validDeletionTimestamp } from '../functions/account_deletion_matches.js';
import { ratingIdentity } from '../functions/rating_contributions.js';

export function preparationOptions(args, env = process.env) {
  const projectId = args.find(a => a.startsWith('--project='))?.slice(10);
  const apply = args.includes('--apply');
  validateBackendEnvironment({ projectId, firestoreHost: env.FIRESTORE_EMULATOR_HOST,
    authHost: env.FIREBASE_AUTH_EMULATOR_HOST });
  if (apply && !args.includes('--writers-paused')) throw new Error('Apply requires --writers-paused after stopping client writes and both rating triggers.');
  return { projectId, apply };
}

// Bounded network reads and a hard inventory ceiling: never silently truncate.
async function inventory(query, budget) {
  const docs = [];
  let after;
  for (;;) {
    let page = query.orderBy('__name__').limit(200);
    if (after) page = page.startAfter(after);
    const snapshot = await page.get();
    budget.count += snapshot.size;
    if (budget.count > 100000) throw new Error('Inventory exceeds reviewed local capacity; no writes performed.');
    docs.push(...snapshot.docs);
    if (snapshot.size < 200) return docs;
    after = snapshot.docs.at(-1);
  }
}

export async function prepareDeletion(db, { apply = false, writersPaused = false } = {}) {
  validateBackendEnvironment({ projectId: db.projectId, firestoreHost: process.env.FIRESTORE_EMULATOR_HOST, authHost: process.env.FIREBASE_AUTH_EMULATOR_HOST });
  if (apply && !writersPaused) throw new Error('Writers must be paused.');
  const budget = { count: 0 }, blockers = [], writes = [];
  const matches = new Map((await inventory(db.collection('matches'), budget)).map(d => [d.id, d]));
  const profiles = new Map((await inventory(db.collection('publicProfiles'), budget)).map(d => [d.id, d]));
  const barriers = await inventory(db.collection('accountDeletionBarriers'), budget);
  if (barriers.some(d => d.data().status !== 'deleted')) blockers.push('Active deletion jobs must finish or be repaired before preparation.');
  const blockedUids = new Set(barriers.map(d => d.id));
  const patch = (doc, data) => writes.push({ doc, data });
  for (const doc of matches.values()) {
    const data = doc.data();
    try {
      const owner = data.creatorUid || data.createdBy;
      const members = [owner, ...(data.players ?? []).map(p => p.deleted === true ? null : p.uid || p.userId)].filter(Boolean);
      // Reuse worker validation, but do not apply its cleanup effect.
      if (members.length) cleanDeletionMatch({ ...data, participantUids: undefined }, members[0], data.scheduledAt);
      else {
        const anonymous = p => p?.deleted === true && p.displayName === 'Deleted player' && Object.keys(p).length === 2;
        if (!anonymous(data.organizer) || !Array.isArray(data.players) || data.players.length > 3
            || !data.players.every(anonymous) || !validDeletionTimestamp(data.scheduledAt)
            || !Number.isInteger(data.spotsLeft) || data.spotsLeft < 0 || data.spotsLeft > 3-data.players.length) throw new Error();
      }
      if (members.some(uid => blockedUids.has(uid))) throw new Error();
      if (JSON.stringify(data.participantUids) !== JSON.stringify(members)) patch(doc, { participantUids: members });
    } catch { blockers.push(`${doc.ref.path}: ambiguous match identity, date or capacity`); }
  }
  for (const doc of await inventory(db.collectionGroup('joinRequests'), budget)) {
    const parts = doc.ref.path.split('/'), data = doc.data();
    if (parts.length !== 4 || parts[0] !== 'matches' || !matches.has(parts[1])
        || (data.userId && data.userId !== doc.id) || (data.uid && data.uid !== doc.id)) {
      blockers.push(`${doc.ref.path}: orphan or conflicting request identity`); continue;
    }
    if (blockedUids.has(doc.id)) { blockers.push(`${doc.ref.path}: deleted request identity`); continue; }
    const update = {};
    if (data.userId !== doc.id) update.userId = doc.id;
    if ('email' in data) update.email = FieldValue.delete();
    if (Object.keys(update).length) patch(doc, update);
  }
  for (const doc of await inventory(db.collectionGroup('ratingRaters'), budget)) {
    const parts = doc.ref.path.split('/');
    if (parts.length !== 4 || parts[0] !== 'matches' || !matches.has(parts[1]) || Object.keys(doc.data()).length) {
      blockers.push(`${doc.ref.path}: orphan or unsupported materialized rating parent`);
    } else writes.push({ doc, remove: true });
  }
  const desired = new Map(), totals = new Map();
  for (const doc of await inventory(db.collectionGroup('ratings'), budget)) {
    try {
      const identity = ratingIdentity(doc.ref.path), data = doc.data();
      const { matchId, raterUid, ratedUid, contributionId } = identity;
      const match = matches.get(matchId)?.data();
      const members = [match?.creatorUid || match?.createdBy,
        ...(match?.players ?? []).map(p => p.uid || p.userId)];
      if (!match || ['matchId', 'raterUid', 'ratedUid'].some(k => data[k] !== identity[k])
          || !Number.isInteger(data.rating) || data.rating < 1 || data.rating > 5
          || raterUid === ratedUid || !members.includes(raterUid) || !members.includes(ratedUid)
          || !profiles.has(ratedUid) || blockedUids.has(raterUid) || blockedUids.has(ratedUid)
          || !match.scheduledAt?.toMillis || match.scheduledAt.toMillis() > Date.now()
          || match.status === 'cancelled') throw new Error();
      desired.set(contributionId, { schemaVersion: 1, ratingPath: doc.ref.path,
        matchId, raterUid, ratedUid, score: data.rating });
      const total = totals.get(ratedUid) ?? { count: 0, sum: 0 };
      total.count++; total.sum += data.rating; totals.set(ratedUid, total);
    } catch { blockers.push(`${doc.ref.path}: malformed, orphaned or ineligible rating`); }
  }
  const existing = new Map((await inventory(db.collection('ratingContributions'), budget)).map(d => [d.id, d]));
  for (const [id, doc] of existing) {
    try {
      const data = doc.data(), identity = ratingIdentity(data.ratingPath);
      if (identity.contributionId !== id || data.schemaVersion !== 1
          || ['matchId','raterUid','ratedUid'].some(k => data[k] !== identity[k])
          || !Number.isInteger(data.score) || data.score < 1 || data.score > 5) throw new Error();
    } catch { blockers.push(`${doc.ref.path}: malformed contribution identity`); }
  }
  for (const [id, data] of desired) {
    const doc = existing.get(id);
    if (!doc || Object.keys(data).some(k => doc.data()[k] !== data[k])) writes.push({ ref: db.collection('ratingContributions').doc(id), data, replace: true });
  }
  for (const [id, doc] of existing) if (!desired.has(id)) writes.push({ doc, remove: true });
  for (const [uid, doc] of profiles) {
    const total = totals.get(uid) ?? { count: 0, sum: 0 };
    const data = { ratingCount: total.count, ratingSum: total.sum,
      ratingAverage: total.count ? total.sum / total.count : 0 };
    if (Object.keys(data).some(k => doc.data()[k] !== data[k])) patch(doc, data);
  }
  for (const doc of await inventory(db.collection('ratingAggregationEvents'), budget)) {
    writes.push({ doc, remove: true });
  }
  for (const doc of await inventory(db.collection('notifications'), budget)) {
    const data = doc.data();
    if (data.matchId && !matches.has(data.matchId)) blockers.push(`${doc.ref.path}: orphan notification`);
    if (!data.recipientUid || ((data.actorDisplayName || data.actorEmail) && !data.actorUid)) {
      blockers.push(`${doc.ref.path}: ambiguous notification identity`);
    }
  }
  // Report before writing; never partially apply a known blocked inventory.
  const report = { scanned: budget.count, plannedWrites: writes.length, blockers, applied: 0 };
  if (!apply || blockers.length) return report;
  // Restartable exact projections; a stopped apply must finish before writers resume.
  for (let offset = 0; offset < writes.length; offset += 200) {
    const batch = db.batch();
    for (const item of writes.slice(offset, offset + 200)) {
      const ref = item.ref ?? item.doc.ref;
      if (item.remove) batch.delete(ref);
      else if (item.replace) batch.set(ref, item.data);
      else batch.update(ref, item.data, { lastUpdateTime: item.doc.updateTime });
    }
    await batch.commit(); report.applied += Math.min(200, writes.length - offset);
  }
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const options = preparationOptions(process.argv.slice(2));
  const app = initializeApp({ projectId: options.projectId });
  try {
    const report = await prepareDeletion(getFirestore(app), { ...options, writersPaused: process.argv.includes('--writers-paused') });
    console.log(JSON.stringify({ project: options.projectId, mode: options.apply ? 'apply' : 'dry-run', ...report }, null, 2));
    if (report.blockers.length) process.exitCode = 2;
  } finally { await deleteApp(app); }
}
