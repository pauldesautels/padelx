export function canonicalEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

export function publicProfileMatches(existing, expected) {
  if (existing == null || typeof existing !== 'object' || Array.isArray(existing)) {
    return false;
  }
  const keys = Object.keys(existing).sort();
  return keys.length === 3
    && keys[0] === 'displayName'
    && keys[1] === 'level'
    && keys[2] === 'uid'
    && existing.uid === expected.uid
    && existing.displayName === expected.displayName
    && existing.level === expected.level;
}

export async function resolveMatchOwner(data, { getUser, getUserByEmail }) {
  const creatorUid = typeof data.creatorUid === 'string' ? data.creatorUid.trim() : '';
  const createdBy = typeof data.createdBy === 'string' ? data.createdBy.trim() : '';
  const creatorEmail = canonicalEmail(data.creatorEmail);
  const createdByEmail = canonicalEmail(data.createdByEmail);

  if (creatorUid && createdBy && creatorUid !== createdBy) {
    throw new Error('conflicting creatorUid and createdBy ownership');
  }
  if (creatorEmail && createdByEmail && creatorEmail !== createdByEmail) {
    throw new Error('conflicting creatorEmail and createdByEmail ownership');
  }

  const ownerUid = creatorUid || createdBy;
  const legacyEmail = creatorEmail || createdByEmail;
  let authUser;
  if (ownerUid) {
    try {
      authUser = await getUser(ownerUid);
    } catch {
      throw new Error('UID owner has no matching Firebase Auth user');
    }
  } else if (legacyEmail) {
    try {
      authUser = await getUserByEmail(legacyEmail);
    } catch {
      throw new Error('email-only owner could not be mapped to an Auth UID');
    }
  } else {
    throw new Error('no UID or email owner');
  }

  if (!authUser?.uid) {
    throw new Error('resolved Auth owner has no UID');
  }
  if (legacyEmail && canonicalEmail(authUser.email) !== legacyEmail) {
    throw new Error('legacy owner email does not match the Auth user');
  }
  return { ownerUid: authUser.uid, mappedFromEmail: !ownerUid };
}
