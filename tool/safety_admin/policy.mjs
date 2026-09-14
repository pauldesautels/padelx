import { PRODUCTION_PROJECT, STAGING_PROJECT } from '../../functions/backend_environment.js';

export const ALLOWED_PROJECT = STAGING_PROJECT;

export function parseArguments(argv) {
  const positionals = [];
  const options = {};
  for (const argument of argv) {
    if (!argument.startsWith('--')) {
      positionals.push(argument);
      continue;
    }
    const [key, ...rest] = argument.slice(2).split('=');
    options[key] = rest.length ? rest.join('=') : true;
  }
  return { positionals, options };
}

export function requireSafeProject(options, env = process.env) {
  if (options.project === PRODUCTION_PROJECT || options['confirm-project'] === PRODUCTION_PROJECT) {
    throw new Error('Production is prohibited.');
  }
  if (options.project !== ALLOWED_PROJECT || options['confirm-project'] !== ALLOWED_PROJECT) {
    throw new Error('Explicit matching staging project confirmation is required.');
  }
  if (env.FIRESTORE_EMULATOR_HOST || env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Emulators are accepted only by automated tests.');
  }
  const configured = [env.GCLOUD_PROJECT, env.GOOGLE_CLOUD_PROJECT]
    .filter(Boolean);
  if (configured.some((projectId) => projectId !== ALLOWED_PROJECT)) {
    throw new Error('Configured Google project does not match staging.');
  }
  if (env.FIREBASE_CONFIG) {
    let configuredProject;
    try { configuredProject = JSON.parse(env.FIREBASE_CONFIG).projectId; } catch {
      throw new Error('Firebase configuration is invalid.');
    }
    if (configuredProject && configuredProject !== ALLOWED_PROJECT) {
      throw new Error('Configured Firebase project does not match staging.');
    }
  }
  if (!options['actor-uid'] || typeof options['actor-uid'] !== 'string') {
    throw new Error('An exact actor UID is required.');
  }
  return { projectId: ALLOWED_PROJECT, actorUid: options['actor-uid'] };
}

export function requireMutation(options) {
  if (options.apply !== true) throw new Error('Dry run only. Add --apply to mutate.');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(options['request-id'] ?? '')) throw new Error('A stable UUID request ID is required.');
  return options['request-id'];
}

export function requireTarget(options, positionalTarget) {
  const targetUid = options['target-uid'] ?? positionalTarget;
  if (!targetUid || options['confirm-target-uid'] !== targetUid) {
    throw new Error('Exact matching target UID confirmation is required.');
  }
  return targetUid;
}

export function sourceReportIdsFromOptions(options) {
  const singular = options['source-report-id'];
  const plural = options['source-report-ids'];
  const values = [
    ...(typeof singular === 'string' ? [singular] : singular === undefined ? [] : [singular]),
    ...(typeof plural === 'string' ? plural.split(',') : plural === undefined ? [] : [plural]),
  ].map((value) => typeof value === 'string' ? value.trim() : value).filter(Boolean);
  if (values.some((value) => typeof value !== 'string' || value.length > 128
      || value.includes('/') || /[\u0000-\u001f\u007f]/.test(value))) {
    throw new Error('Source report IDs are invalid.');
  }
  const deduplicated = [...new Set(values)];
  if (deduplicated.length > 20) throw new Error('Too many source report IDs.');
  return deduplicated;
}

export function buildEnforcementInput({ options, command, actorUid, targetUid,
  requestId, now = new Date() }) {
  const sourceReportIds = sourceReportIdsFromOptions(options);
  return {
    actorUid, targetUid, requestId,
    status: command === 'ban' ? 'banned' : 'suspended',
    reasonCode: options.reason,
    sourceReportIds,
    ...(command === 'suspend'
      ? { expiresAt: new Date(now.getTime() + Number(options.minutes) * 60_000) }
      : {}),
  };
}

export function mutationRequested(options) { return options.apply === true; }
