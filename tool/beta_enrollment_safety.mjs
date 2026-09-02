export const productionProjectId = 'padelx-f168f';

export function canonicalEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

export function validateEnrollmentTarget(projectId, expectedProjectId) {
  if (!projectId || !expectedProjectId) {
    throw new Error(
      'Pass both --project=<id> and --confirm-project=<same-id>.',
    );
  }
  if (projectId !== expectedProjectId) {
    throw new Error('Project confirmation does not match the target project.');
  }
  if (projectId === productionProjectId) {
    throw new Error('This Phase 8C utility refuses the production project.');
  }
}

export function validateEnrollmentEmail(value) {
  const email = canonicalEmail(value);
  if (
    email.length > 254
    || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    throw new Error('Pass one valid tester email with --email=<address>.');
  }
  return email;
}

export function classifyExistingUser(user, email) {
  if (!user) return 'create';
  return canonicalEmail(user.email) === canonicalEmail(email)
    ? 'already-enrolled'
    : 'conflict';
}
