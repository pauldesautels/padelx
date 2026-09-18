import test from 'node:test';
import assert from 'node:assert/strict';
import {
  RELIABILITY_MINIMUM_SAMPLE,
  RELIABILITY_POLICY_VERSION,
  calculateReliability,
  rankByReliability,
  reliabilityPriority,
  RELIABILITY_NO_SHOW_PENALTY,
} from '../functions/reliability.js';

const committed = (matchId) => ({
  type: 'confirmed_match_committed', matchId, scheduledAt: new Date('2029-01-01T12:00:00Z'),
});
const cancelled = (matchId, timingCategory) =>
  ({ type: 'confirmed_match_cancelled', matchId, timingCategory });

test('new players do not receive a misleading perfect percentage', () => {
  const result = calculateReliability(Array.from({ length: RELIABILITY_MINIMUM_SAMPLE - 1 },
    (_, index) => committed(`match-${index}`)), new Date('2030-01-01T00:00:00Z'));
  assert.equal(result.status, 'new_player');
  assert.equal(result.percent, null);
  assert.equal(result.policyVersion, RELIABILITY_POLICY_VERSION);
  assert.equal(reliabilityPriority(result), 0);
});

test('future commitments do not inflate the evidence sample', () => {
  const events = Array.from({ length: 8 }, (_, index) => ({
    type: 'confirmed_match_committed', matchId: `future-${index}`,
    scheduledAt: new Date('2031-01-01T12:00:00Z'),
  }));
  const result = calculateReliability(events, new Date('2030-01-01T00:00:00Z'));
  assert.equal(result.status, 'new_player');
  assert.equal(result.sampleSize, 0);
});

test('objective cancellation severity is graduated and proposal outcomes are free', () => {
  const matches = Array.from({ length: 5 }, (_, index) => committed(`match-${index}`));
  const now = new Date('2030-01-01T00:00:00Z');
  const early = calculateReliability([...matches, cancelled('match-0', 'over_24_hours')], now);
  const late = calculateReliability([...matches, cancelled('match-0', 'under_2_hours')], now);
  const proposalOnly = calculateReliability([...matches,
    { type: 'proposal_declined', proposalId: 'proposal' },
    { type: 'proposal_expired', proposalId: 'proposal' },
  ], now);
  assert.equal(early.status, 'established');
  assert.ok(early.percent > late.percent);
  assert.equal(proposalOnly.percent, 100);
});

test('a secured replacement mitigates but does not erase cancellation impact', () => {
  const matches = Array.from({ length: 5 }, (_, index) => committed(`match-${index}`));
  const now = new Date('2030-01-01T00:00:00Z');
  const unfilled = calculateReliability([...matches, cancelled('match-0', 'under_2_hours')], now);
  const filled = calculateReliability([...matches, cancelled('match-0', 'under_2_hours'),
    { type: 'replacement_secured', matchId: 'match-0' }], now);
  assert.ok(filled.percent > unfilled.percent);
  assert.ok(filled.percent < 100);
});

test('uncommitted cancellations, subjective ratings, and no-show guesses are ignored', () => {
  const matches = Array.from({ length: 5 }, (_, index) => committed(`match-${index}`));
  const result = calculateReliability([...matches,
    cancelled('not-committed', 'under_2_hours'),
    { type: 'rating_submitted', matchId: 'match-0' },
    { type: 'inferred_no_show', matchId: 'match-0' },
  ], new Date('2030-01-01T00:00:00Z'));
  assert.equal(result.percent, 100);
});

test('soft ranking uses established projection only', () => {
  assert.equal(reliabilityPriority({ status: 'new_player', percent: null }), 0);
  assert.equal(reliabilityPriority({ status: 'established', percent: 85 }), 85);
  assert.equal(reliabilityPriority({ status: 'established', percent: 101 }), 100);
});

test('soft ranking orders compatible candidates without excluding new players', () => {
  const ranked = rankByReliability([
    { id: 'new', status: 'new_player', percent: null },
    { id: 'lower', status: 'established', percent: 75 },
    { id: 'higher', status: 'established', percent: 95 },
  ]);
  assert.deepEqual(ranked.map((candidate) => candidate.id), ['higher', 'lower', 'new']);
});

test('V2 attendance resolves sample and no-show exceeds very-late cancellation', () => {
  const now = new Date('2030-01-01T00:00:00Z');
  const commitments = Array.from({ length: 5 }, (_, index) => ({
    ...committed(`v2-${index}`), policyVersion: RELIABILITY_POLICY_VERSION,
  }));
  const attended = commitments.map((event) => ({ type: 'attendance_confirmed', matchId: event.matchId }));
  const good = calculateReliability([...commitments, ...attended], now);
  const noShow = calculateReliability([...commitments, ...attended.filter((_, index) => index > 0),
    { type: 'no_show_confirmed', matchId: 'v2-0' }], now);
  const late = calculateReliability([...commitments, ...attended,
    cancelled('v2-0', 'under_2_hours')], now);
  assert.equal(good.percent, 100);
  assert.ok(RELIABILITY_NO_SHOW_PENALTY > 35);
  assert.ok(noShow.percent < late.percent);
});

test('disputed evidence does not resolve or penalize a V2 commitment', () => {
  const now = new Date('2030-01-01T00:00:00Z');
  const commitments = Array.from({ length: 5 }, (_, index) => ({
    ...committed(`v2-${index}`), policyVersion: RELIABILITY_POLICY_VERSION,
  }));
  const events = commitments.slice(1).map((event) => ({ type: 'attendance_confirmed', matchId: event.matchId }));
  const result = calculateReliability([...commitments, ...events,
    { type: 'attendance_disputed', matchId: 'v2-0' }], now);
  assert.equal(result.status, 'new_player');
  assert.equal(result.sampleSize, 4);
});

test('cancellation takes precedence and cannot double-penalize with no-show', () => {
  const now = new Date('2030-01-01T00:00:00Z');
  const commitments = Array.from({ length: 5 }, (_, index) => committed(`match-${index}`));
  const cancellationOnly = calculateReliability([...commitments,
    cancelled('match-0', 'under_2_hours')], now);
  const duplicateOutcome = calculateReliability([...commitments,
    cancelled('match-0', 'under_2_hours'), { type: 'no_show_confirmed', matchId: 'match-0' }], now);
  assert.equal(duplicateOutcome.percent, cancellationOnly.percent);
  assert.equal(duplicateOutcome.sampleSize, cancellationOnly.sampleSize);
});
