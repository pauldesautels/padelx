// Match schema has one organizer and at most three additional players.
export const DELETED_PLAYER = Object.freeze({ deleted: true, displayName: 'Deleted player' });
const validUid = (v) => typeof v === 'string' && v.length > 0 && v.length <= 128 && !v.includes('/');
export const validDeletionTimestamp = (v) => Number.isInteger(v?.seconds)
  && v.seconds >= -62135596800 && v.seconds <= 253402300799
  && Number.isInteger(v?.nanoseconds) && v.nanoseconds >= 0 && v.nanoseconds < 1e9
  && Number.isFinite(v?.toMillis?.());
const invalid = () => { throw new Error('Ambiguous match state.'); };
function identity(a, b) {
  if ([a, b].some((v) => v !== undefined && v !== '' && !validUid(v))) invalid();
  if (a && b && a !== b) invalid();
  return a || b || '';
}
function deleted(v) {
  return v?.deleted === true && v.displayName === 'Deleted player'
    && Object.keys(v).length === 2;
}
export function cleanDeletionMatch(data, uid, cutoff) {
  if (!validDeletionTimestamp(data.scheduledAt) || !validDeletionTimestamp(cutoff)) invalid();
  const owner = identity(data.creatorUid, data.createdBy);
  if (!owner && !deleted(data.organizer)) invalid();
  if (!Array.isArray(data.players) || data.players.length > 3) invalid();
  const ids = data.players.map((p) => {
    if (!p || typeof p !== 'object' || Array.isArray(p)) invalid();
    if (deleted(p)) return '';
    const id = identity(p.uid, p.userId);
    if (!id) invalid();
    return id;
  });
  const members = [owner, ...ids].filter(Boolean);
  if (new Set(members).size !== members.length) invalid();
  // Missing legacy projection can be rebuilt for a targeted ownership hit.
  if (data.participantUids !== undefined && (!Array.isArray(data.participantUids)
      || data.participantUids.some((id) => !validUid(id))
      || new Set(data.participantUids).size !== data.participantUids.length
      || data.participantUids.length !== members.length
      || members.some((id) => !data.participantUids.includes(id)))) invalid();
  let spots = data.spotsLeft;
  if (typeof spots === 'string' && /^[123]( spot(s)?( left)?)?$/.test(spots)) spots = Number(spots[0]);
  if (!Number.isInteger(spots) || spots < 0 || spots > 3 - data.players.length) invalid();
  // No alternate capacity schema is currently supported.
  if (['capacity', 'totalCapacity', 'totalPlayers'].some((key) => key in data)) invalid();
  const organized = owner === uid;
  const index = ids.indexOf(uid);
  if (!organized && index < 0) invalid();
  const future = data.scheduledAt.seconds > cutoff.seconds
    || (data.scheduledAt.seconds === cutoff.seconds && data.scheduledAt.nanoseconds > cutoff.nanoseconds);
  const result = { ...data, participantUids: members.filter((id) => id !== uid) };
  if (organized) {
    for (const key of ['creatorUid', 'createdBy', 'creatorDisplayName', 'creatorName', 'creatorEmail',
      'creatorLevel', 'createdByName', 'createdByDisplayName', 'createdByEmail', 'createdByLevel']) delete result[key];
    result.organizer = { ...DELETED_PLAYER };
    if (future) { result.status = 'cancelled'; result.cancellationReason = 'organizer_deleted'; }
  }
  if (index >= 0) {
    result.players = [...data.players];
    if (future) {
      result.players.splice(index, 1);
      result.spotsLeft = Math.min(spots + 1, 3 - result.players.length);
    } else result.players[index] = { ...DELETED_PLAYER };
  }
  return { data: result, organized, future };
}
