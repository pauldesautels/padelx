import test from 'node:test';
import assert from 'node:assert/strict';
import { ATTENDANCE_STATES, adjudicateAttendance, attendanceWindow } from '../functions/attendance_policy.js';

const roster = ['a', 'b', 'c', 'd'];
const submission = (observerUid, attendedUids, matchHappened = true) =>
  ({ observerUid, attendedUids, matchHappened });

test('attendance window is centralized at two hours plus 72 hours', () => {
  const scheduled = new Date('2030-01-01T10:00:00Z');
  const window = attendanceWindow(scheduled);
  assert.equal(window.opensAt.toISOString(), '2030-01-01T12:00:00.000Z');
  assert.equal(window.closesAt.toISOString(), '2030-01-04T12:00:00.000Z');
});

test('resolution waits for all observers unless window recovery is final', () => {
  assert.equal(adjudicateAttendance({ roster, submissions: [submission('a', roster)] }), null);
});

test('corroborated attendance resolves each player without organizer weighting', () => {
  const result = adjudicateAttendance({ roster, submissions: roster.map((uid) => submission(uid, roster)) });
  assert.equal(result.matchState, 'played');
  assert.deepEqual(result.subjects, Object.fromEntries(roster.map((uid) => [uid, 'attended'])));
});

test('one negative peer claim never establishes a no-show', () => {
  const result = adjudicateAttendance({ roster, final: true, submissions: [
    submission('a', ['a', 'b', 'c']), submission('b', roster),
  ] });
  assert.notEqual(result.subjects.d, ATTENDANCE_STATES.noShow);
});

test('subject evidence follows conservative peer-corroboration precedence', () => {
  const subject = 'd';
  const state = (submissions) => adjudicateAttendance({ roster, submissions, final: true })
    .subjects[subject];
  assert.equal(state([submission(subject, roster)]), ATTENDANCE_STATES.insufficient,
    'self-positive alone is insufficient');
  assert.equal(state([submission(subject, roster), submission('a', roster)]),
    ATTENDANCE_STATES.attended, 'one peer positive plus self-positive attends');
  assert.equal(state([submission('a', roster), submission('b', roster)]),
    ATTENDANCE_STATES.attended, 'two peer positives attend');
  assert.equal(state([submission('a', ['a', 'b', 'c'])]),
    ATTENDANCE_STATES.insufficient, 'one peer negative is insufficient');
  assert.equal(state([submission(subject, roster), submission('a', ['a', 'b', 'c'])]),
    ATTENDANCE_STATES.insufficient, 'one peer negative plus self-positive is insufficient');
  assert.equal(state([submission('a', ['a', 'b', 'c']), submission('b', roster)]),
    ATTENDANCE_STATES.insufficient, 'one negative and one positive remain insufficient');
  assert.equal(state([submission('a', ['a', 'b', 'c']), submission('b', ['a', 'b', 'c'])]),
    ATTENDANCE_STATES.noShow, 'two peer negatives establish no-show');
  assert.equal(state([submission(subject, roster), submission('a', ['a', 'b', 'c']),
    submission('b', ['a', 'b', 'c'])]), ATTENDANCE_STATES.noShow,
  'self-positive cannot defeat two peer negatives');
  assert.equal(state([submission('a', ['a', 'b', 'c']), submission('b', ['a', 'b', 'c']),
    submission('c', roster)]), ATTENDANCE_STATES.disputed,
  'independent peer disagreement is disputed');
  assert.equal(state([submission(subject, roster), submission('a', ['a', 'b', 'c']),
    submission('b', ['a', 'b', 'c']), submission('c', ['a', 'b', 'c'])]),
  ATTENDANCE_STATES.noShow, 'self-positive cannot defeat three peer negatives');
  assert.equal(state([submission(subject, roster), submission('a', ['a', 'b', 'c']),
    submission('b', ['a', 'b', 'c']), submission('c', roster)]),
  ATTENDANCE_STATES.disputed, 'peer conflict remains disputed even with self-positive');
});

test('organizer has no special weight and missing submissions add no evidence', () => {
  const organizerNegative = adjudicateAttendance({ roster, final: true, submissions: [
    submission('a', ['a', 'b', 'c']),
  ] });
  const otherNegative = adjudicateAttendance({ roster, final: true, submissions: [
    submission('b', ['a', 'b', 'c']),
  ] });
  assert.equal(organizerNegative.subjects.d, otherNegative.subjects.d);
  assert.equal(organizerNegative.subjects.d, ATTENDANCE_STATES.insufficient);
  assert.equal(adjudicateAttendance({ roster, final: true, submissions: [] }).subjects.d,
    ATTENDANCE_STATES.insufficient);
});

test('two independent uncontradicted peer claims establish a no-show', () => {
  const result = adjudicateAttendance({ roster, final: true, submissions: [
    submission('a', ['a', 'b', 'c']), submission('b', ['a', 'b', 'c']),
    submission('c', ['a', 'b', 'c']),
  ] });
  assert.equal(result.subjects.d, ATTENDANCE_STATES.noShow);
  assert.equal(result.subjects.a, ATTENDANCE_STATES.attended);
});

test('contradictory independent peer evidence is disputed rather than punished', () => {
  const result = adjudicateAttendance({ roster, submissions: [
    submission('a', roster), submission('b', ['a', 'b', 'c']),
    submission('c', ['a', 'b', 'c']), submission('d', roster),
  ] });
  assert.equal(result.subjects.d, ATTENDANCE_STATES.disputed);
});

test('corroborated match-not-played prevents mass no-show outcomes', () => {
  const result = adjudicateAttendance({ roster, final: true, submissions: [
    submission('a', [], false), submission('b', [], false),
  ] });
  assert.equal(result.matchState, ATTENDANCE_STATES.matchNotPlayed);
  assert.ok(Object.values(result.subjects).every((state) => state === ATTENDANCE_STATES.matchNotPlayed));
});

test('conflicting match-level evidence remains disputed', () => {
  const result = adjudicateAttendance({ roster, submissions: [
    submission('a', roster), submission('b', [], false),
    submission('c', roster), submission('d', [], false),
  ] });
  assert.equal(result.matchState, ATTENDANCE_STATES.disputed);
});
