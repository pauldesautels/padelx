import { PRODUCTION_PROJECT, STAGING_PROJECT } from '../../functions/backend_environment.js';

export const OPERATIONAL_PROJECT = STAGING_PROJECT;
export const OPERATIONAL_QUERY_LIMIT = 100;

export function parseOperationalArguments(argv) {
  const options = {};
  const positionals = [];
  for (const argument of argv) {
    if (!argument.startsWith('--')) {
      positionals.push(argument);
      continue;
    }
    const [key, ...rest] = argument.slice(2).split('=');
    options[key] = rest.length === 0 ? true : rest.join('=');
  }
  return { options, positionals };
}

export function requireOperationalProject(options, env = process.env) {
  if (options.project === PRODUCTION_PROJECT || options['confirm-project'] === PRODUCTION_PROJECT) {
    throw new Error('Production is prohibited.');
  }
  if (options.project !== OPERATIONAL_PROJECT
      || options['confirm-project'] !== OPERATIONAL_PROJECT) {
    throw new Error('Explicit matching staging project confirmation is required.');
  }
  const configured = [env.GCLOUD_PROJECT, env.GOOGLE_CLOUD_PROJECT].filter(Boolean);
  if (configured.some((project) => project !== OPERATIONAL_PROJECT)) {
    throw new Error('Configured Google project does not match staging.');
  }
  if (env.FIREBASE_CONFIG) {
    let configuredProject;
    try { configuredProject = JSON.parse(env.FIREBASE_CONFIG).projectId; } catch {
      throw new Error('Firebase configuration is invalid.');
    }
    if (configuredProject && configuredProject !== OPERATIONAL_PROJECT) {
      throw new Error('Configured Firebase project does not match staging.');
    }
  }
  return OPERATIONAL_PROJECT;
}

export function requireOperationalCommand(positionals) {
  const command = positionals[0] ?? 'summary';
  if (!['summary', 'matchmaking', 'attendance', 'reliability', 'deletion', 'push', 'reports']
    .includes(command)) throw new Error('Unknown operational health command.');
  return command;
}

export function boundedCount(snapshot) {
  const count = snapshot?.size ?? snapshot?.docs?.length ?? 0;
  return { count: Math.min(count, OPERATIONAL_QUERY_LIMIT), truncated: count >= OPERATIONAL_QUERY_LIMIT };
}

export function safeFailure(error) {
  const known = new Map([
    ['Production is prohibited.', 'production-prohibited'],
    ['Explicit matching staging project confirmation is required.', 'staging-confirmation-required'],
    ['Configured Google project does not match staging.', 'environment-project-mismatch'],
    ['Configured Firebase project does not match staging.', 'environment-project-mismatch'],
    ['Firebase configuration is invalid.', 'environment-config-invalid'],
    ['Unknown operational health command.', 'unknown-command'],
  ]);
  if (known.has(error?.message)) return { status: 'unavailable', code: known.get(error.message) };
  const rawCode = typeof error?.code === 'string' ? error.code.replace(/^\d+-/, '') : '';
  const code = /^[a-z][a-z0-9-]{0,79}$/.test(rawCode) ? rawCode : 'unknown';
  return { status: 'unavailable', code };
}
