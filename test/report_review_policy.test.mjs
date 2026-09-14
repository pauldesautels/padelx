import test from 'node:test';
import assert from 'node:assert/strict';
import {
  MODERATOR_NOTE_MAX_CODE_POINTS, canTransition, normalizeModeratorNote,
  validateActionInput, validateDismissalInput, validateReviewContext,
} from '../functions/report_review_policy.js';

const base = { actorUid: 'reviewer-one', reportId: 'report-one',
  requestId: '123e4567-e89b-42d3-a456-426614174000' };

test('review policy exposes only approved transitions', () => {
  assert.equal(canTransition('open', 'reviewing'), true);
  assert.equal(canTransition('open', 'dismissed'), true);
  assert.equal(canTransition('open', 'actioned'), true);
  assert.equal(canTransition('reviewing', 'open'), false);
  assert.equal(canTransition('reviewing', 'open', { release: true }), true);
  for (const state of ['dismissed', 'actioned']) {
    for (const next of ['open', 'reviewing', 'dismissed', 'actioned']) {
      assert.equal(canTransition(state, next), false);
    }
  }
});

test('review inputs require path-safe IDs and stable UUID request IDs', () => {
  assert.equal(validateReviewContext(base), base);
  for (const invalid of [
    { ...base, reportId: 'bad/id' }, { ...base, actorUid: '' },
    { ...base, requestId: 'generated-later' },
  ]) assert.throws(() => validateReviewContext(invalid));
});

test('dismissal and action inputs use canonical values', () => {
  assert.equal(validateDismissalInput({ ...base, outcomeCode: 'no_violation' }).outcomeCode,
    'no_violation');
  assert.equal(validateDismissalInput({ ...base,
    outcomeCode: 'insufficient_evidence' }).outcomeCode, 'insufficient_evidence');
  assert.throws(() => validateDismissalInput({ ...base, outcomeCode: 'warning_issued' }));
  assert.equal(validateActionInput({ ...base,
    resolutionActionId: 'action-one' }).resolutionActionId, 'action-one');
  assert.throws(() => validateActionInput({ ...base, resolutionActionId: 'bad/id' }));
});

test('moderator notes trim, count Unicode code points, and reject controls', () => {
  assert.equal(normalizeModeratorNote('  concise note  '), 'concise note');
  assert.equal([...normalizeModeratorNote('😀'.repeat(MODERATOR_NOTE_MAX_CODE_POINTS))].length,
    MODERATOR_NOTE_MAX_CODE_POINTS);
  assert.throws(() => normalizeModeratorNote('😀'.repeat(MODERATOR_NOTE_MAX_CODE_POINTS + 1)));
  assert.throws(() => normalizeModeratorNote('unsafe\u0000note'));
});
