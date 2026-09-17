import assert from 'node:assert/strict';
import test from 'node:test';
import { MATCHMAKING_CANDIDATE_LIMIT, MATCHMAKING_LEVEL_DELTA,
  CONFIRMATION_WINDOW_MS, confirmationWindowMs, cancellationTimingCategory, canonicalCityKey, commitmentConflicts,
  assignTeams, compatibilityScore, hardCompatibility, normalizeAvailability,
  overlappingAvailability, parseLevel } from '../functions/matchmaking_policy.js';

const date = (hour, minute = 0) => new Date(Date.UTC(2030, 0, 2, hour, minute));
const base = (overrides = {}) => ({
  requestId: 'request-one', cityKey: 'MX:places-city-id', travelRadiusKm: 20,
  location: { latitude: 19.43, longitude: -99.13 }, level: '3.5',
  preferredSide: 'either', memberSides: ['either'],
  availability: [{ earliestStart: date(18), latestStart: date(22) }],
  ...overrides,
});

test('canonical city identity ignores localized display labels', () => {
  assert.equal(canonicalCityKey({ countryCode: 'mx', cityId: 'places-city-id', city: 'Mexico City' }),
    canonicalCityKey({ countryCode: 'MX', cityId: 'places-city-id', city: 'Ciudad de México' }));
  assert.notEqual(canonicalCityKey({ countryCode: 'MX', cityId: 'city-one' }),
    canonicalCityKey({ countryCode: 'MX', cityId: 'city-two' }));
  assert.equal(canonicalCityKey({ countryCode: 'MX', city: 'Mexico City' }), null);
});

test('availability is timestamp based, bounded, sorted, and deterministic', () => {
  const now = date(8);
  const windows = normalizeAvailability([
    { earliestStart: date(18), latestStart: date(22) },
    { earliestStart: date(10), latestStart: date(13) },
  ], now);
  assert.deepEqual(windows.map((window) => window.earliestStart), [date(10), date(18)]);
  assert.throws(() => normalizeAvailability([
    { earliestStart: date(10), latestStart: date(13) },
    { earliestStart: date(12), latestStart: date(14) },
  ], now));
  assert.throws(() => normalizeAvailability([
    { earliestStart: date(7), latestStart: date(9) },
  ], now));
});

test('compatibility separates hard constraints from soft ranking', () => {
  const candidate = base({ requestId: 'request-two', level: 'Level 4', preferredSide: 'right',
    memberSides: ['right'], availability: [{ earliestStart: date(19), latestStart: date(23) }] });
  assert.deepEqual(hardCompatibility(base(), candidate), { compatible: true, reason: null });
  assert.equal(overlappingAvailability([base(), candidate]).earliestStart.toISOString(), date(19).toISOString());
  assert.ok(compatibilityScore([base(), candidate]) > 0);
  assert.deepEqual(hardCompatibility(base(), candidate), { compatible: true, reason: null });
  assert.equal(hardCompatibility(base(), candidate).compatible, true);
  assert.equal(hardCompatibility(base(), { ...candidate, cityKey: 'MX:other' }).reason, 'location');
  assert.equal(hardCompatibility(base(), { ...candidate, level: String(3.5 + MATCHMAKING_LEVEL_DELTA + .5) }).reason,
    'skill');
});

test('distance, side, and conflicting commitment policies are stable', () => {
  assert.equal(hardCompatibility(base(), base({ requestId: 'far', location: {
    latitude: 20.67, longitude: -103.35,
  } })).reason, 'travel_radius');
  assert.ok(compatibilityScore([base({ memberSides: ['left'] }),
    base({ requestId: 'two', memberSides: ['right'] })])
    > compatibilityScore([base({ memberSides: ['left'] }),
      base({ requestId: 'two', memberSides: ['left'] })]));
  assert.equal(commitmentConflicts(date(18), date(20)), true);
  assert.equal(commitmentConflicts(date(18), date(21)), false);
  assert.equal(parseLevel('Level 3.5'), 3.5);
  assert.equal(parseLevel('Intermediate'), null);
});

test('cancellation timing categories are objective and boundary-stable', () => {
  assert.equal(cancellationTimingCategory(date(18), date(17)), 'under_2_hours');
  assert.equal(cancellationTimingCategory(date(18), date(16)), '2_to_6_hours');
  assert.equal(cancellationTimingCategory(date(18), date(12)), '6_to_24_hours');
  assert.equal(cancellationTimingCategory(new Date('2030-01-03T18:00:00Z'), date(18)),
    'over_24_hours');
  assert.equal(cancellationTimingCategory(date(18), date(18)), null);
});

test('bounded beta policy constants are explicit', () => {
  assert.equal(MATCHMAKING_CANDIDATE_LIMIT, 60);
  assert.deepEqual(CONFIRMATION_WINDOW_MS, {
    within24Hours: 5 * 60 * 1000,
    within72Hours: 10 * 60 * 1000,
    beyond72Hours: 15 * 60 * 1000,
  });
});

test('confirmation windows shorten conservatively as match time approaches', () => {
  const current = new Date('2030-01-01T00:00:00Z');
  assert.equal(confirmationWindowMs(new Date('2030-01-01T23:59:00Z'), current), 5 * 60 * 1000);
  assert.equal(confirmationWindowMs(new Date('2030-01-03T00:00:00Z'), current), 10 * 60 * 1000);
  assert.equal(confirmationWindowMs(new Date('2030-01-04T00:00:01Z'), current), 15 * 60 * 1000);
  assert.equal(confirmationWindowMs(current, current), null);
});

test('team assignment balances levels and sides deterministically', () => {
  const requests = ['one', 'two', 'three', 'four'].map((uid) => ({
    mode: 'solo', memberUids: [uid],
  }));
  const profiles = new Map([
    ['one', { level: '5', preferredSide: 'left' }],
    ['two', { level: '4', preferredSide: 'right' }],
    ['three', { level: '3', preferredSide: 'left' }],
    ['four', { level: '2', preferredSide: 'right' }],
  ]);
  const teams = assignTeams(requests, profiles);
  assert.equal(teams.one, teams.four);
  assert.equal(teams.two, teams.three);
  assert.notEqual(teams.one, teams.two);
});

test('team assignment keeps an explicitly consented partner pair together', () => {
  const requests = [
    { mode: 'partner', memberUids: ['one', 'two'] },
    { mode: 'solo', memberUids: ['three'] },
    { mode: 'solo', memberUids: ['four'] },
  ];
  const profiles = new Map(['one', 'two', 'three', 'four'].map((uid) => [uid, {
    level: '3.5', preferredSide: 'either',
  }]));
  const teams = assignTeams(requests, profiles);
  assert.equal(teams.one, teams.two);
  assert.notEqual(teams.one, teams.three);
  assert.equal(teams.three, teams.four);
});
