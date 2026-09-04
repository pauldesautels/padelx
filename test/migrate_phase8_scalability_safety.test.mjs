import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  participantUidsForMatch,
  sameStringList,
} from '../tool/migrate_phase8_scalability_safety.mjs';
import { encodeGeohash } from '../functions/aggregate_helpers.js';

describe('Phase 8 scalability migration safety', () => {
  test('builds organizer-first participant index for current and legacy UID fields', () => {
    assert.deepEqual(participantUidsForMatch({
      creatorUid: 'owner', players: [{ uid: 'alice' }, { userId: 'bob' }],
    }), ['owner', 'alice', 'bob']);
    assert.deepEqual(participantUidsForMatch({ createdBy: 'owner', players: [] }), ['owner']);
  });

  test('blocks malformed and ambiguous membership', () => {
    assert.throws(() => participantUidsForMatch({ players: [] }), /organizer/);
    assert.throws(() => participantUidsForMatch({ creatorUid: 'owner', players: [{}] }), /player/);
    assert.throws(() => participantUidsForMatch({ creatorUid: 'owner', players: [{ uid: 'owner' }] }), /duplicate/);
  });

  test('detects already migrated documents for idempotent reruns', () => {
    assert.equal(sameStringList(['owner', 'alice'], ['owner', 'alice']), true);
    assert.equal(sameStringList(['alice', 'owner'], ['owner', 'alice']), false);
  });

  test('geohashes are deterministic', () => {
    assert.equal(encodeGeohash(19.4326, -99.1332, 3), '9g3');
    assert.equal(encodeGeohash(19.4326, -99.1332, 4), '9g3w');
  });
});
