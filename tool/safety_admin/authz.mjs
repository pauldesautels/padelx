import { createHash } from 'node:crypto';

export async function currentActor(auth, actorUid) {
  const user = await auth.getUser(actorUid);
  return { uid: actorUid, claims: user.customClaims ?? {} };
}

export function requireReviewer(actor) {
  if (actor.claims.safetyReviewer !== true) throw new Error('Reviewer authorization required.');
}

export function requireEnforcer(actor) {
  if (actor.claims.safetyEnforcer !== true) throw new Error('Enforcer authorization required.');
}

export function requireRoleAdministrator(actor) {
  requireReviewer(actor);
  requireEnforcer(actor);
}

export const roleClaim = (role) => {
  if (role === 'reviewer') return 'safetyReviewer';
  if (role === 'enforcer') return 'safetyEnforcer';
  throw new Error('Role must be reviewer or enforcer.');
};

const roleAuditId = ({ actorUid, targetUid, role, type, requestId }) => createHash('sha256')
  .update(`safety-role\0${type}\0${actorUid}\0${targetUid}\0${role}\0${requestId}`)
  .digest('hex');

export async function changeRole({ firestore, auth, actorUid, targetUid, role,
  grant, requestId, now = new Date() }) {
  const claim = roleClaim(role);
  const target = await auth.getUser(targetUid);
  const claims = { ...(target.customClaims ?? {}) };
  if (grant) claims[claim] = true;
  else delete claims[claim];
  const type = grant ? 'safety_role_granted' : 'safety_role_revoked';
  const auditRef = firestore.doc(`moderationActions/${roleAuditId({
    actorUid, targetUid, role, type, requestId,
  })}`);
  const prior = await auditRef.get();
  if (prior.exists) {
    const data = prior.data();
    if (data.actorUid !== actorUid || data.targetUid !== targetUid || data.role !== role
        || data.type !== type || data.requestId !== requestId) throw new Error('Role request conflict.');
  } else {
    await auth.setCustomUserClaims(targetUid, claims);
    const verified = await auth.getUser(targetUid);
    if ((verified.customClaims?.[claim] === true) !== grant) throw new Error('Role verification failed.');
    await auth.revokeRefreshTokens(targetUid);
    await auditRef.create({ schemaVersion: 1, type, actorUid, targetUid, role, requestId, createdAt: now });
  }
  return { changed: !prior.exists, granted: grant };
}
