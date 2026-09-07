#!/usr/bin/env node
import { readFile, rename, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { reconcilePlayedWithMatch } from '../functions/played_with_projection.js';
import { advanceCheckpoint, establishOperatorProjectEnvironment, migrationOptions, parseCheckpoint,
  phase9ProfilePatch } from './phase9_tool_policy.mjs';

export async function loadCheckpoint(checkpointPath) {
  try {
    return parseCheckpoint(await readFile(checkpointPath, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return { usersAfter: null, matchesAfter: null, stage: 'profiles' };
    if (error.message === 'Checkpoint is invalid or unreadable.') throw error;
    throw new Error('Checkpoint is invalid or unreadable.');
  }
}

export async function saveCheckpoint(checkpointPath, checkpoint) {
  const temporaryPath = `${checkpointPath}.${process.pid}.tmp`;
  await writeFile(temporaryPath, `${JSON.stringify(checkpoint)}\n`, { mode: 0o600 });
  await rename(temporaryPath, checkpointPath);
}

export async function runMigration(options, { db, reconcile = reconcilePlayedWithMatch,
  load = loadCheckpoint, save = saveCheckpoint } = {}) {
  const { projectId, apply, validateOnly, pageSize, checkpointPath } = options;
  let checkpoint = await load(checkpointPath);
  const summary = { mode: validateOnly ? 'VALIDATE' : apply ? 'APPLY' : 'DRY RUN', project: projectId,
    scanned: 0, wouldWrite: 0, written: 0, invalid: 0, nextStage: checkpoint.stage };

  if (checkpoint.stage === 'profiles') {
    let query = db.collection('users').orderBy('__name__').limit(pageSize);
    if (checkpoint.usersAfter) query = query.startAfter(checkpoint.usersAfter);
    const page = await query.get(); const batch = db.batch();
    for (const user of page.docs) {
      summary.scanned += 1; const data = user.data(); const publicRef = db.doc(`publicProfiles/${user.id}`);
      const publicProfile = (await publicRef.get()).data() ?? {};
      const patch = phase9ProfilePatch(data, publicProfile);
      if (!patch.countryCode || !patch.city) summary.invalid += 1;
      summary.wouldWrite += 2;
      if (apply) { batch.set(user.ref, patch, { merge: true }); batch.set(publicRef, { uid: user.id, ...patch }, { merge: true }); summary.written += 2; }
    }
    if (apply && !page.empty) await batch.commit();
    checkpoint = advanceCheckpoint(checkpoint, page.docs.map((doc) => doc.id), pageSize);
  } else if (checkpoint.stage === 'matches') {
    if (apply) establishOperatorProjectEnvironment(projectId);
    let query = db.collection('matches').orderBy('__name__').limit(pageSize);
    if (checkpoint.matchesAfter) query = query.startAfter(checkpoint.matchesAfter);
    const page = await query.get(); summary.scanned = page.size; summary.wouldWrite = page.size;
    if (apply) for (const match of page.docs) { await reconcile(db, match.id); summary.written += 1; }
    checkpoint = advanceCheckpoint(checkpoint, page.docs.map((doc) => doc.id), pageSize);
  }
  summary.nextStage = checkpoint.stage;
  await save(checkpointPath, checkpoint); // Local operator state; never a Firebase write.
  return summary;
}

async function main() {
  const options = migrationOptions(process.argv.slice(2));
  const checkpoint = await loadCheckpoint(options.checkpointPath);
  const app = initializeApp({ projectId: options.projectId, credential: process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? cert(JSON.parse(await readFile(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'))) : applicationDefault() });
  console.log(JSON.stringify(await runMigration(options, {
    db: getFirestore(app), load: async () => checkpoint,
  })));
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) await main();
