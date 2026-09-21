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
  const config = firebaseRuntimeConfig(env);
  const ids = [env.GCLOUD_PROJECT, env.GOOGLE_CLOUD_PROJECT, config.projectId].filter(Boolean);
  if (new Set(ids).size !== 1) throw new Error('Missing or conflicting backend project configuration.');
  return validateBackendEnvironment({
    projectId: ids[0], firestoreHost: env.FIRESTORE_EMULATOR_HOST,
    authHost: env.FIREBASE_AUTH_EMULATOR_HOST,
  });
}

export function firebaseRuntimeConfig(env = process.env) {
  const config = env.FIREBASE_CONFIG ? JSON.parse(env.FIREBASE_CONFIG) : {};
  if (!config || typeof config !== 'object' || Array.isArray(config)) {
    throw new Error('Invalid Firebase runtime configuration.');
  }
  return config;
}

export function authoritativeStorageBucket(environment, env = process.env) {
  const config = firebaseRuntimeConfig(env);
  if (config.projectId !== environment.projectId) {
    throw Object.assign(new Error('Storage configuration project mismatch.'), {
      code: 'storage-configuration-invalid',
    });
  }
  const bucket = config.storageBucket;
  if (typeof bucket !== 'string' || bucket.length < 3 || bucket.length > 222
      || bucket !== bucket.trim() || bucket.includes('/') || bucket.includes('://')
      || !/^[a-z0-9][a-z0-9._-]*[a-z0-9]$/i.test(bucket)) {
    throw Object.assign(new Error('Authoritative Storage bucket is unavailable.'), {
      code: 'storage-bucket-unavailable',
    });
  }
  const firebaseSuffix = ['.firebasestorage.app', '.appspot.com']
    .find((suffix) => bucket.endsWith(suffix));
  if (firebaseSuffix && bucket.slice(0, -firebaseSuffix.length) !== environment.projectId) {
    throw Object.assign(new Error('Storage configuration project mismatch.'), {
      code: 'storage-configuration-invalid',
    });
  }
  return bucket;
}

export function assertContributionAccountingReady(environment, env = process.env) {
  if (environment.mode !== 'emulator' && env.PADELX_RATING_CONTRIBUTIONS_READY !== 'true') {
    throw new Error('Rating contribution baseline must be established before enabling reconciliation.');
  }
}

export function assertPlayedWithProjectionReady(environment, env = process.env) {
  if (environment.mode !== 'emulator' && env.PADELX_PLAYED_WITH_PROJECTION_ENABLED !== 'true') {
    throw new Error('Played With projection must be explicitly enabled for this environment.');
  }
}

export function assertPhase9Enabled(environment, env = process.env) {
  if (environment.mode !== 'emulator' && env.PADELX_PHASE9_ENABLED !== 'true') {
    throw new Error('Phase 9 social backend is disabled for this environment.');
  }
}

export function assertSafeFirestore(firestore) {
  const environment = backendEnvironment();
  if (firestore.projectId !== environment.projectId) throw new Error('Firestore project does not match trusted runtime.');
  return environment;
}
