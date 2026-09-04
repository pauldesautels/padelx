import { PRODUCTION_PROJECT, validateBackendEnvironment } from '../functions/backend_environment.js';
export const productionProjectId = PRODUCTION_PROJECT;

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
  validateBackendEnvironment({ projectId,
    firestoreHost: process.env.FIRESTORE_EMULATOR_HOST,
    authHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
  });
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
