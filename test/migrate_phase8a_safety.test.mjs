import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  publicProfileMatches,
  resolveMatchOwner,
} from '../tool/migrate_phase8a_safety.mjs';

const users = new Map([
  ['owner', { uid: 'owner', email: 'Owner@Example.com' }],
  ['other', { uid: 'other', email: 'other@example.com' }],
]);
const lookup = {
  getUser: async (uid) => {
    if (!users.has(uid)) throw new Error('not found');
    return users.get(uid);
  },
  getUserByEmail: async (email) => {
    const user = [...users.values()].find(
      (candidate) => candidate.email.toLowerCase() === email.toLowerCase(),
    );
    if (!user) throw new Error('not found');
    return user;
  },
};

describe('Phase 8A migration safety checks', () => {
  test('accepts only the exact intended public profile', () => {
    const expected = { uid: 'owner', displayName: 'Owner', level: 'Level 3' };
    assert.equal(publicProfileMatches({ ...expected }, expected), true);
    assert.equal(publicProfileMatches({ ...expected, email: 'private@example.com' }, expected), false);
    assert.equal(publicProfileMatches({ ...expected, level: 'Level 4' }, expected), false);
  });

  test('maps an email-only owner and normalizes email case', async () => {
    assert.deepEqual(
      await resolveMatchOwner({ creatorEmail: ' OWNER@example.com ' }, lookup),
      { ownerUid: 'owner', mappedFromEmail: true },
    );
  });

  test('validates UID owners and any retained legacy email', async () => {
    assert.deepEqual(
      await resolveMatchOwner({ creatorUid: 'owner', creatorEmail: 'owner@example.com' }, lookup),
      { ownerUid: 'owner', mappedFromEmail: false },
    );
    await assert.rejects(
      resolveMatchOwner({ creatorUid: 'missing' }, lookup),
      /no matching Firebase Auth user/,
    );
    await assert.rejects(
      resolveMatchOwner({ creatorUid: 'owner', creatorEmail: 'other@example.com' }, lookup),
      /does not match the Auth user/,
    );
  });

  test('rejects conflicting legacy ownership fields', async () => {
    await assert.rejects(
      resolveMatchOwner({ creatorUid: 'owner', createdBy: 'other' }, lookup),
      /conflicting creatorUid and createdBy/,
    );
    await assert.rejects(
      resolveMatchOwner({ creatorEmail: 'owner@example.com', createdByEmail: 'other@example.com' }, lookup),
      /conflicting creatorEmail and createdByEmail/,
    );
  });
});
