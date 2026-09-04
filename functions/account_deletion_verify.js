import { validDeletionTimestamp } from './account_deletion_matches.js';

export class DeletionVerificationFailure extends Error {
  constructor(code) { super('Account deletion verification failed.'); this.verificationCode = code; }
}
export function failVerification(code) { throw new DeletionVerificationFailure(code); }
const validUid = (value) => typeof value === 'string' && value.length > 0
  && value.length <= 128 && !value.includes('/');
const anonymous = (value) => value?.deleted === true && value.displayName === 'Deleted player'
  && Object.keys(value).length === 2;

// Only inspect deterministically associated manifest matches. Never infer an
// identity from text, names, email, or the position of an unrelated player.
export function verifyManifestMatch(data, entry, uid, cutoff) {
  if (!data) return; // Removed parents do not excuse residual descendants.
  const bad = () => failVerification('verify-match-anonymization');
  if (!validDeletionTimestamp(data.scheduledAt)) bad();
  const future = data.scheduledAt.seconds > cutoff.seconds
    || (data.scheduledAt.seconds === cutoff.seconds && data.scheduledAt.nanoseconds > cutoff.nanoseconds);
  if (future !== entry.future || !Array.isArray(data.players) || data.players.length > 3
      || !Array.isArray(data.participantUids)) bad();
  const identity = (a, b) => {
    if ([a, b].some((value) => value !== undefined && value !== '' && !validUid(value))
        || (a && b && a !== b) || a === uid || b === uid) bad();
    return a || b || '';
  };
  const owner = identity(data.creatorUid, data.createdBy);
  if (entry.organized) {
    if (!anonymous(data.organizer)
        || ['creatorUid', 'createdBy', 'creatorDisplayName', 'creatorName', 'creatorEmail',
          'creatorLevel', 'createdByName', 'createdByDisplayName', 'createdByEmail', 'createdByLevel']
          .some((key) => key in data)) bad();
    if (future && (data.status !== 'cancelled' || data.cancellationReason !== 'organizer_deleted')) bad();
  } else if (!owner && !anonymous(data.organizer)) bad();
  // Any deleted slot must be exactly the shared tombstone: no UID, userId,
  // email, level, or extra snapshot fields may coexist with it.
  let deletedSlots = 0;
  const players = data.players.map((player) => {
    if (!player || typeof player !== 'object' || Array.isArray(player)) bad();
    if (player.deleted === true) {
      if (!anonymous(player)) bad();
      deletedSlots++;
      return '';
    }
    const id = identity(player.uid, player.userId);
    if (!id) bad(); // An unidentifiable snapshot cannot prove anonymization.
    return id;
  });
  if (!future && !entry.organized && deletedSlots === 0) bad();
  if (data.organizer) {
    if (data.organizer.deleted === true && !anonymous(data.organizer)) bad();
    identity(data.organizer.uid, data.organizer.userId);
  }
  const members = [owner, ...players].filter(Boolean);
  if (new Set(members).size !== members.length
      || data.participantUids.length !== members.length
      || new Set(data.participantUids).size !== members.length
      || data.participantUids.some((id) => !validUid(id) || id === uid || !members.includes(id))) bad();
}
