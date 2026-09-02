import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  canonicalEmail,
  classifyExistingUser,
  validateEnrollmentEmail,
  validateEnrollmentTarget,
} from '../tool/beta_enrollment_safety.mjs';

describe('Phase 8C beta enrollment safety checks', () => {
  test('canonicalizes and validates a tester email', () => {
    assert.equal(canonicalEmail(' Tester@Example.COM '), 'tester@example.com');
    assert.equal(validateEnrollmentEmail(' Tester@Example.COM '), 'tester@example.com');
    assert.throws(() => validateEnrollmentEmail('not-an-email'), /valid tester email/);
    assert.throws(() => validateEnrollmentEmail(''), /valid tester email/);
  });

  test('requires an exact project confirmation and refuses production', () => {
    assert.doesNotThrow(() => validateEnrollmentTarget('padelx-staging', 'padelx-staging'));
    assert.throws(
      () => validateEnrollmentTarget('padelx-staging', 'another-project'),
      /does not match/,
    );
    assert.throws(
      () => validateEnrollmentTarget('padelx-f168f', 'padelx-f168f'),
      /refuses the production project/,
    );
  });

  test('is idempotent for the same existing Auth email', () => {
    assert.equal(classifyExistingUser(undefined, 'tester@example.com'), 'create');
    assert.equal(
      classifyExistingUser({ email: 'Tester@Example.com' }, 'tester@example.com'),
      'already-enrolled',
    );
    assert.equal(
      classifyExistingUser({ email: 'other@example.com' }, 'tester@example.com'),
      'conflict',
    );
  });
});
