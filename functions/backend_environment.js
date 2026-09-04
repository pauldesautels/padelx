export const STAGING_PROJECT = 'padelx-staging';
export const PRODUCTION_PROJECT = 'padelx-f168f';

// No project selection is accepted from callable payloads. Production is
// recognized, but deliberately not enabled by this development slice.
export function validateBackendEnvironment({ projectId, firestoreHost, authHost }) {
  if (projectId === PRODUCTION_PROJECT) throw new Error('Production backend access is disabled in this slice.');
  if (typeof projectId !== 'string') throw new Error('Explicit backend project is required.');
  const localHost = (value) => typeof value === 'string'
    && /^(127\.0\.0\.1|localhost|\[::1\]):[0-9]{1,5}$/.test(value);
  if (projectId.startsWith('demo-')) {
    if (!localHost(firestoreHost) || !localHost(authHost)) {
      throw new Error('Demo backend requires local Firestore and Auth emulators.');
    }
    return { projectId, mode: 'emulator' };
  }
  if (projectId === STAGING_PROJECT && !firestoreHost && !authHost) {
    return { projectId, mode: 'staging' };
  }
  throw new Error('Unknown or mixed backend environment.');
}

export function backendEnvironment(env = process.env) {
  const config = env.FIREBASE_CONFIG ? JSON.parse(env.FIREBASE_CONFIG) : {};
  const ids = [env.GCLOUD_PROJECT, env.GOOGLE_CLOUD_PROJECT, config.projectId].filter(Boolean);
  if (new Set(ids).size !== 1) throw new Error('Missing or conflicting backend project configuration.');
  return validateBackendEnvironment({
    projectId: ids[0], firestoreHost: env.FIRESTORE_EMULATOR_HOST,
    authHost: env.FIREBASE_AUTH_EMULATOR_HOST,
  });
}

export function assertContributionAccountingReady(environment, env = process.env) {
  if (environment.mode !== 'emulator' && env.PADELX_RATING_CONTRIBUTIONS_READY !== 'true') {
    throw new Error('Rating contribution baseline must be established before enabling reconciliation.');
  }
}

export function assertSafeFirestore(firestore) {
  const environment = backendEnvironment();
  if (firestore.projectId !== environment.projectId) throw new Error('Firestore project does not match trusted runtime.');
  return environment;
}
