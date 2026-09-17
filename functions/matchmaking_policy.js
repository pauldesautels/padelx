import { HttpsError } from 'firebase-functions/v2/https';

export const MATCHMAKING_SCHEMA_VERSION = 1;
export const MATCHMAKING_REQUEST_TTL_MS = 7 * 24 * 60 * 60 * 1000;
export const PARTNER_INVITATION_TTL_MS = 24 * 60 * 60 * 1000;
export const CONFIRMATION_WINDOW_POLICY_VERSION = 'quick-match-confirmation-v1';
export const CONFIRMATION_WINDOW_MS = Object.freeze({
  within24Hours: 5 * 60 * 1000,
  within72Hours: 10 * 60 * 1000,
  beyond72Hours: 15 * 60 * 1000,
});
export const MINIMUM_OVERLAP_MS = 60 * 60 * 1000;
export const COMMITMENT_BUFFER_MS = 30 * 60 * 1000;
export const MATCHMAKING_CANDIDATE_LIMIT = 60;
export const MATCHMAKING_MAX_WINDOWS = 5;
export const MATCHMAKING_SCAN_WINDOWS_PER_INVOCATION = 5;
export const MATCHMAKING_LEVEL_DELTA = 1.5;
export const TRAVEL_RADIUS_OPTIONS_KM = Object.freeze([5, 10, 20, 25]);
export const REQUEST_MODES = Object.freeze(['solo', 'partner', 'autofill']);
export const REQUEST_STATUSES = Object.freeze([
  'awaiting_partner', 'active', 'matched', 'locked', 'confirmed', 'paused', 'cancelled', 'expired',
]);
export const PROPOSAL_STATUSES = Object.freeze([
  'confirming', 'venue_needed', 'promoted', 'declined', 'cancelled', 'expired',
]);
export const VENUE_TYPES = Object.freeze(['club_public', 'private_free']);

const text = (value, maximum = 256) => typeof value === 'string'
  && value.trim().length > 0 && value.trim().length <= maximum ? value.trim() : null;

export function asDate(value) {
  if (value instanceof Date) return Number.isFinite(value.getTime()) ? value : null;
  if (typeof value?.toDate === 'function') {
    const date = value.toDate();
    return date instanceof Date && Number.isFinite(date.getTime()) ? date : null;
  }
  if (typeof value === 'string') {
    const date = new Date(value);
    return Number.isFinite(date.getTime()) ? date : null;
  }
  return null;
}

export function parseLevel(value) {
  if (typeof value !== 'string') return null;
  const match = value.trim().match(/^(?:Level )?([1-7](?:\.5)?)$/);
  if (!match) return null;
  const level = Number(match[1]);
  return level >= 1 && level <= 7 && level * 2 === Math.round(level * 2) ? level : null;
}

export function normalizeAvailability(value, now = new Date()) {
  if (!Array.isArray(value) || value.length < 1 || value.length > MATCHMAKING_MAX_WINDOWS) {
    throw new HttpsError('invalid-argument', 'One to five availability windows are required.');
  }
  const windows = value.map((window) => {
    if (!window || typeof window !== 'object' || Array.isArray(window)
        || Object.keys(window).some((key) => !['earliestStart', 'latestStart'].includes(key))) {
      throw new HttpsError('invalid-argument', 'Invalid availability window.');
    }
    const earliestStart = asDate(window.earliestStart);
    const latestStart = asDate(window.latestStart);
    if (!earliestStart || !latestStart || earliestStart <= now
        || latestStart <= earliestStart || latestStart.getTime() - earliestStart.getTime() > 24 * 60 * 60 * 1000) {
      throw new HttpsError('invalid-argument', 'Availability must be a future window of at most 24 hours.');
    }
    return { earliestStart, latestStart };
  }).sort((left, right) => left.earliestStart - right.earliestStart);
  for (let index = 1; index < windows.length; index++) {
    if (windows[index].earliestStart < windows[index - 1].latestStart) {
      throw new HttpsError('invalid-argument', 'Availability windows cannot overlap.');
    }
  }
  return windows;
}

export function overlappingAvailability(requests) {
  if (!Array.isArray(requests) || requests.length === 0) return null;
  let best = null;
  const visit = (index, earliest, latest) => {
    if (index === requests.length) {
      if (latest.getTime() - earliest.getTime() >= MINIMUM_OVERLAP_MS
          && (!best || earliest < best.earliestStart)) best = { earliestStart: earliest, latestStart: latest };
      return;
    }
    for (const window of requests[index].availability ?? []) {
      const start = asDate(window.earliestStart);
      const end = asDate(window.latestStart);
      if (!start || !end) continue;
      const nextStart = earliest && earliest > start ? earliest : start;
      const nextEnd = latest && latest < end ? latest : end;
      if (nextEnd.getTime() - nextStart.getTime() >= MINIMUM_OVERLAP_MS) {
        visit(index + 1, nextStart, nextEnd);
      }
    }
  };
  visit(0, null, null);
  return best;
}

export function canonicalCityKey(location) {
  const countryCode = text(location?.countryCode, 8)?.toUpperCase();
  const cityId = text(location?.cityId);
  if (!countryCode || !cityId) return null;
  return `${countryCode}:${cityId}`;
}

export function haversineKm(left, right) {
  if (![left?.latitude, left?.longitude, right?.latitude, right?.longitude].every(Number.isFinite)) return null;
  const radians = (degrees) => degrees * Math.PI / 180;
  const dLat = radians(right.latitude - left.latitude);
  const dLon = radians(right.longitude - left.longitude);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(radians(left.latitude))
    * Math.cos(radians(right.latitude)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function hardCompatibility(left, right) {
  if (left.cityKey !== right.cityKey) return { compatible: false, reason: 'location' };
  if (!overlappingAvailability([left, right])) return { compatible: false, reason: 'availability' };
  const distance = haversineKm(left.location, right.location);
  if (distance !== null && (distance > left.travelRadiusKm || distance > right.travelRadiusKm)) {
    return { compatible: false, reason: 'travel_radius' };
  }
  const leftLevel = parseLevel(left.level);
  const rightLevel = parseLevel(right.level);
  if (leftLevel === null || rightLevel === null
      || Math.abs(leftLevel - rightLevel) > MATCHMAKING_LEVEL_DELTA) {
    return { compatible: false, reason: 'skill' };
  }
  return { compatible: true, reason: null };
}

export function compatibilityScore(requests) {
  const levels = requests.map((request) => parseLevel(request.level));
  if (levels.some((level) => level === null)) return 0;
  const levelSpread = Math.max(...levels) - Math.min(...levels);
  let score = 100 - levelSpread * 20;
  const sides = requests.flatMap((request) => request.memberSides ?? [request.preferredSide]);
  const left = sides.filter((side) => side === 'left').length;
  const right = sides.filter((side) => side === 'right').length;
  score -= Math.abs(left - right) * 4;
  return Math.max(0, Math.round(score));
}

export function assignTeams(requests, profiles) {
  const members = requests.flatMap((request) => request.memberUids ?? []);
  if (members.length !== 4 || new Set(members).size !== 4) return null;
  const pairings = [
    [[members[0], members[1]], [members[2], members[3]]],
    [[members[0], members[2]], [members[1], members[3]]],
    [[members[0], members[3]], [members[1], members[2]]],
  ];
  const lockedGroups = requests.filter((request) => request.mode === 'partner')
    .map((request) => request.memberUids);
  const valid = pairings.filter((teams) => lockedGroups.every((group) =>
    teams.some((team) => group.every((uid) => team.includes(uid)))));
  const scored = valid.map((teams) => {
    const level = (uid) => parseLevel(profiles.get(uid)?.level) ?? 0;
    const levelDifference = Math.abs(teams[0].reduce((sum, uid) => sum + level(uid), 0)
      - teams[1].reduce((sum, uid) => sum + level(uid), 0));
    const sidePenalty = teams.reduce((total, team) => {
      const sides = team.map((uid) => profiles.get(uid)?.preferredSide ?? 'either')
        .filter((side) => side !== 'either');
      return total + (sides.length === 2 && sides[0] === sides[1] ? 1 : 0);
    }, 0);
    return { teams, levelDifference, sidePenalty,
      signature: teams.map((team) => [...team].sort().join(':')).join('|') };
  }).sort((left, right) => left.levelDifference - right.levelDifference
    || left.sidePenalty - right.sidePenalty || left.signature.localeCompare(right.signature));
  const selected = scored[0]?.teams;
  if (!selected) return null;
  return Object.fromEntries(selected.flatMap((team, index) =>
    team.map((uid) => [uid, index + 1])));
}

export function commitmentConflicts(scheduledAt, existingScheduledAt) {
  const left = asDate(scheduledAt);
  const right = asDate(existingScheduledAt);
  return Boolean(left && right
    && Math.abs(left.getTime() - right.getTime()) < 2 * 60 * 60 * 1000 + COMMITMENT_BUFFER_MS);
}

export function cancellationTimingCategory(scheduledAt, occurredAt) {
  const scheduled = asDate(scheduledAt);
  const occurred = asDate(occurredAt);
  if (!scheduled || !occurred || scheduled <= occurred) return null;
  const leadMinutes = Math.floor((scheduled.getTime() - occurred.getTime()) / 60000);
  if (leadMinutes < 120) return 'under_2_hours';
  if (leadMinutes < 360) return '2_to_6_hours';
  if (leadMinutes < 1440) return '6_to_24_hours';
  return 'over_24_hours';
}

export function confirmationWindowMs(scheduledAt, now = new Date()) {
  const scheduled = asDate(scheduledAt);
  const current = asDate(now);
  if (!scheduled || !current || scheduled <= current) return null;
  const lead = scheduled.getTime() - current.getTime();
  if (lead <= 24 * 60 * 60 * 1000) return CONFIRMATION_WINDOW_MS.within24Hours;
  if (lead <= 72 * 60 * 60 * 1000) return CONFIRMATION_WINDOW_MS.within72Hours;
  return CONFIRMATION_WINDOW_MS.beyond72Hours;
}
