import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { buildStagingPreparationRules, stagingPreparationOptions } from '../tool/staging_preparation_rules.mjs';

const source = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const { rules, guarded } = buildStagingPreparationRules(source);

test('overlay preserves normal rules outside the matches block and all read conditions', () => {
  const marker = 'match /matches/{matchId} {';
  assert.equal(rules.slice(0, rules.indexOf(marker)), source.slice(0, source.indexOf(marker)));
  const reads = value => value.match(/\ballow\s+(?:read|get|list)(?:\s*,\s*(?:read|get|list))*\s*:\s*if\s+[^;]+;/g);
  assert.deepEqual(reads(rules), reads(source));
  assert.ok(guarded >= 6, 'Expected match, join-request and rating write declarations.');
  assert.match(rules, /function stagingPreparationClientWritesAllowed\(\) \{ return false; \}/);
});

test('every match-subtree write is conjoined with the lock without losing its original predicate', () => {
  const tail = source.slice(source.indexOf('match /matches/{matchId} {'));
  for (const match of tail.matchAll(/\ballow\s+([a-z,\s]+):\s*if\s+([^;]+);/g)) {
    if (!/\b(write|create|update|delete)\b/.test(match[1])) continue;
    assert.ok(rules.includes(`allow ${match[1]}: if stagingPreparationClientWritesAllowed() && (${match[2]});`));
  }
});

test('guard covers OR branches and rejects ambiguous inputs and non-staging targets', () => {
  const fixture = 'match /matches/{matchId} { allow update: if false || true; }';
  assert.match(buildStagingPreparationRules(fixture).rules, /\(false \|\| true\)/);
  assert.throws(() => buildStagingPreparationRules('allow write: if true;'));
  assert.throws(() => buildStagingPreparationRules(fixture + fixture));
  assert.throws(() => buildStagingPreparationRules('match /matches/{matchId} { allow read, write: if true; }'));
  assert.throws(() => buildStagingPreparationRules(rules));
  assert.throws(() => stagingPreparationOptions([]));
  assert.throws(() => stagingPreparationOptions(['--project=not-staging', '--out=/tmp/unused']));
  assert.throws(() => stagingPreparationOptions(['--project=padelx-staging', '--project=other', '--out=/tmp/unused']));
  assert.ok(stagingPreparationOptions(['--project=padelx-staging', '--out=/tmp/unused']).output);
});

let environment;
after(async () => { if (environment) await environment.cleanup(); });

test('emulator: client match/rating writes are denied, reads and Admin-like writes remain available',
  { skip: !process.env.FIRESTORE_EMULATOR_HOST }, async () => {
    const { initializeTestEnvironment, assertFails, assertSucceeds } = await import('@firebase/rules-unit-testing');
    const { doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc } = await import('firebase/firestore');
    environment = await initializeTestEnvironment({
      projectId: 'demo-padelx-maintenance', firestore: { rules },
    });
    await environment.clearFirestore();
    const paths = [
      'matches/maintenance-match',
      'matches/maintenance-match/joinRequests/viewer',
      'matches/maintenance-match/ratingRaters/viewer/ratings/other',
    ];
    await environment.withSecurityRulesDisabled(async context => {
      for (const path of paths) await setDoc(doc(context.firestore(), path), {
        creatorUid: 'viewer', userId: 'viewer', matchId: 'maintenance-match',
        raterUid: 'viewer', ratedUid: 'other', status: 'pending', rating: 4,
      });
      await setDoc(doc(context.firestore(), 'publicProfiles/viewer'), {
        uid: 'viewer', displayName: 'Viewer', level: '3',
      });
    });
    const db = environment.authenticatedContext('viewer', { email_verified: true, email: 'viewer@example.com' }).firestore();
    await assertSucceeds(getDoc(doc(db, paths[0])));
    await assertSucceeds(getDocs(collection(db, 'matches')));
    await assertSucceeds(getDoc(doc(db, 'publicProfiles/viewer')));
    await assertFails(updateDoc(doc(db, paths[0]), {
      players: [{ uid: 'viewer' }], participantUids: ['viewer'], spotsLeft: 2,
    }));
    await assertFails(updateDoc(doc(db, paths[1]), { status: 'accepted' }));
    await assertFails(updateDoc(doc(db, paths[2]), { rating: 5 }));
    for (const path of paths) {
      await assertFails(updateDoc(doc(db, path), { status: 'changed' }));
      await assertFails(deleteDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path + '-new'), { userId: 'viewer' }));
    }
    await environment.withSecurityRulesDisabled(async context => {
      await updateDoc(doc(context.firestore(), paths[0]), { participantUids: ['viewer', 'other'] });
      await updateDoc(doc(context.firestore(), 'publicProfiles/viewer'), { ratingCount: 1, ratingSum: 4, ratingAverage: 4 });
    });
  });
