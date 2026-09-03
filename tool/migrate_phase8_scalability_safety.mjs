export function participantUidsForMatch(data) {
  if (data == null || typeof data !== 'object' || Array.isArray(data)) {
    throw new Error('match data is not an object');
  }
  const creatorUid = typeof data.creatorUid === 'string' && data.creatorUid.trim()
    ? data.creatorUid.trim()
    : typeof data.createdBy === 'string' ? data.createdBy.trim() : '';
  if (!creatorUid) throw new Error('match has no UID-based organizer');
  if (!Array.isArray(data.players) || data.players.length > 3) {
    throw new Error('match players must be a list of at most three');
  }
  const result = [creatorUid];
  for (const player of data.players) {
    const uid = player && typeof player === 'object'
      ? String(player.uid ?? player.userId ?? '').trim()
      : '';
    if (!uid) throw new Error('player has no UID');
    if (result.includes(uid)) throw new Error('duplicate participant UID');
    result.push(uid);
  }
  return result;
}

export function sameStringList(left, right) {
  return Array.isArray(left) && Array.isArray(right)
    && left.length === right.length
    && left.every((value, index) => value === right[index]);
}
