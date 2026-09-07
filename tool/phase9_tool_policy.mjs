export function migrationOptions(argv) {
  const args = new Map(argv.map((arg) => {
    const [key, ...rest] = arg.split('='); return [key, rest.length ? rest.join('=') : true];
  }));
  const projectId = args.get('--project');
  if (!projectId) throw new Error('--project is required.');
  if (projectId !== 'padelx-staging') throw new Error('Phase 9 migration refuses every project except padelx-staging.');
  const apply = args.has('--apply'); const validateOnly = args.has('--validate-only');
  if (apply && validateOnly) throw new Error('--apply and --validate-only are mutually exclusive.');
  const pageSize = Number(args.get('--page-size') ?? 50);
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) throw new Error('--page-size must be 1..100.');
  const checkpoint = args.get('--checkpoint');
  if (checkpoint === true || (typeof checkpoint === 'string' && checkpoint.length === 0)) {
    throw new Error('--checkpoint requires a local file path.');
  }
  return { projectId, apply, validateOnly, pageSize,
    checkpointPath: String(checkpoint ?? '.phase9-backfill-checkpoint.json') };
}

export function establishOperatorProjectEnvironment(projectId, env = process.env) {
  if (projectId !== 'padelx-staging') {
    throw new Error('Phase 9 migration refuses every project except padelx-staging.');
  }
  let config = {};
  if (env.FIREBASE_CONFIG) {
    try {
      config = JSON.parse(env.FIREBASE_CONFIG);
    } catch {
      throw new Error('Missing or conflicting backend project configuration.');
    }
    if (config === null || Array.isArray(config) || typeof config !== 'object') {
      throw new Error('Missing or conflicting backend project configuration.');
    }
  }
  const configuredIds = [env.GCLOUD_PROJECT, env.GOOGLE_CLOUD_PROJECT, config.projectId].filter(Boolean);
  if (configuredIds.some((configuredId) => configuredId !== projectId)) {
    throw new Error('Missing or conflicting backend project configuration.');
  }
  env.GCLOUD_PROJECT = projectId;
  env.GOOGLE_CLOUD_PROJECT = projectId;
  env.FIREBASE_CONFIG = JSON.stringify({ ...config, projectId });
  return env;
}

const checkpointKeys = new Set(['stage', 'usersAfter', 'matchesAfter']);
const checkpointStages = new Set(['profiles', 'matches', 'complete']);

export function parseCheckpoint(contents) {
  let parsed;
  try {
    parsed = JSON.parse(contents);
  } catch {
    throw new Error('Checkpoint is invalid or unreadable.');
  }
  if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object'
      || Object.keys(parsed).some((key) => !checkpointKeys.has(key))
      || ('stage' in parsed && !checkpointStages.has(parsed.stage))
      || ('usersAfter' in parsed && parsed.usersAfter !== null
        && (typeof parsed.usersAfter !== 'string' || parsed.usersAfter.length === 0))
      || ('matchesAfter' in parsed && parsed.matchesAfter !== null
        && (typeof parsed.matchesAfter !== 'string' || parsed.matchesAfter.length === 0))) {
    throw new Error('Checkpoint is invalid or unreadable.');
  }
  const checkpoint = { usersAfter: null, matchesAfter: null, stage: 'profiles', ...parsed };
  if ((checkpoint.stage === 'profiles' && checkpoint.matchesAfter !== null)
      || (checkpoint.stage !== 'profiles' && checkpoint.usersAfter !== null)) {
    throw new Error('Checkpoint is invalid or unreadable.');
  }
  return checkpoint;
}

export function phase9ProfilePatch(data = {}, publicProfile = {}) {
  const location = data.discoveryLocation ?? {};
  return {
    preferredSide: ['left', 'right', 'either'].includes(data.preferredSide) ? data.preferredSide : 'either',
    playFrequency: typeof data.playFrequency === 'string' ? data.playFrequency : 'occasionally',
    bio: typeof data.bio === 'string' ? data.bio : '',
    discoverable: data.discoverable === true,
    countryCode: String(location.countryCode ?? publicProfile.countryCode ?? '').toUpperCase(),
    city: String(location.city ?? publicProfile.city ?? ''), area: String(location.area ?? publicProfile.area ?? ''),
    avatarVersion: Number.isSafeInteger(data.avatarVersion) ? data.avatarVersion : 0,
  };
}

export function publicSummary(summary) {
  return JSON.stringify(summary);
}

export function advanceCheckpoint(checkpoint, documentIds, pageSize) {
  const next = { usersAfter: null, matchesAfter: null, stage: 'profiles', ...checkpoint };
  const last = documentIds.at(-1);
  if (next.stage === 'profiles') {
    if (last) next.usersAfter = last;
    if (documentIds.length < pageSize) { next.stage = 'matches'; next.usersAfter = null; }
  } else if (next.stage === 'matches') {
    if (last) next.matchesAfter = last;
    if (documentIds.length < pageSize) next.stage = 'complete';
  }
  return next;
}
