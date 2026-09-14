#!/usr/bin/env node
import process from 'node:process';
import readline from 'node:readline/promises';
import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { applyAccountEnforcement, ENFORCEMENT_REASONS, readEffectiveAccountEnforcement,
  revokeAccountEnforcement } from '../../functions/account_enforcement.js';
import { dismissReport, getReportForReview, listReportsForReview,
  markReportActioned, releaseReportReview, startReportReview } from '../../functions/report_review.js';
import { normalizeModeratorNote, REPORT_DISMISSAL_OUTCOMES,
  validReportId } from '../../functions/report_review_policy.js';
import { changeRole, currentActor, requireEnforcer, requireReviewer,
  requireRoleAdministrator, roleClaim } from './authz.mjs';
import { listRow, reportSummary } from './format.mjs';
import { buildEnforcementInput, mutationRequested, parseArguments, requireMutation,
  requireSafeProject, requireTarget } from './policy.mjs';

function print(value) { process.stdout.write(`${JSON.stringify(value, null, 2)}\n`); }
function usage() { throw new Error('Unknown or incomplete safety administration command.'); }
async function confirmSensitive(label) {
  if (!process.stdin.isTTY || !process.stdout.isTTY) throw new Error(`${label} requires an interactive terminal.`);
  const terminal = readline.createInterface({ input: process.stdin, output: process.stderr });
  try {
    const answer = await terminal.question(`WARNING: ${label} reveals sensitive user data. Type SHOW to continue: `);
    if (answer !== 'SHOW') throw new Error('Sensitive display cancelled.');
  } finally { terminal.close(); }
}

export async function run(argv, dependencies = {}) {
  const { positionals, options } = parseArguments(argv);
  const safe = requireSafeProject(options, dependencies.env ?? process.env);
  process.env.GCLOUD_PROJECT = safe.projectId;
  process.env.GOOGLE_CLOUD_PROJECT = safe.projectId;
  process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: safe.projectId });
  const app = dependencies.app ?? (getApps().find((candidate) => candidate.name === 'padelx-safety-admin')
    ?? initializeApp({ credential: applicationDefault(), projectId: safe.projectId }, 'padelx-safety-admin'));
  if (app.options.projectId !== safe.projectId) throw new Error('Admin project mismatch.');
  const auth = dependencies.auth ?? getAuth(app);
  const firestore = dependencies.firestore ?? getFirestore(app);
  if (firestore.projectId !== safe.projectId) throw new Error('Firestore project mismatch.');
  const actor = await currentActor(auth, safe.actorUid);
  const [group, command, subject] = positionals;

  if (group === 'reports') {
    requireReviewer(actor);
    if (command?.startsWith('list-')) {
      const queue = command.slice(5);
      const reports = queue === 'urgent'
        ? await listReportsForReview(firestore, { status: 'open', urgent: true })
        : await listReportsForReview(firestore, { status: queue });
      print(reports.map(listRow)); return;
    }
    if (!subject) usage();
    if (!validReportId(subject)) throw new Error('A valid report ID is required.');
    if (command === 'show') {
      const sensitive = options['show-sensitive'] === true;
      const reporter = options['show-reporter-uid'] === true;
      if (sensitive) await confirmSensitive('report evidence');
      if (reporter) await confirmSensitive('reporter identity');
      print(reportSummary(await getReportForReview(firestore, subject), {
        showSensitive: sensitive, showReporterUid: reporter,
      })); return;
    }
    if (!['start-review', 'release-review', 'dismiss', 'action'].includes(command)) usage();
    if (command === 'dismiss' && !REPORT_DISMISSAL_OUTCOMES.includes(options.outcome)) {
      throw new Error('An explicit canonical dismissal outcome is required.');
    }
    if (command === 'action' && !validReportId(options['resolution-action-id'])) {
      throw new Error('An exact resolution action ID is required.');
    }
    normalizeModeratorNote(options.note);
    if (!mutationRequested(options)) { print({ dryRun: true, operation: command, reportId: subject }); return; }
    const requestId = requireMutation(options);
    const base = { actorUid: actor.uid, reportId: subject, requestId };
    if (command === 'start-review') print(await startReportReview(firestore, base));
    else if (command === 'release-review') print(await releaseReportReview(firestore, base));
    else if (command === 'dismiss') print(await dismissReport(firestore, {
      ...base, outcomeCode: options.outcome, moderatorNote: options.note,
    }));
    else if (command === 'action') print(await markReportActioned(firestore, {
      ...base, resolutionActionId: options['resolution-action-id'], moderatorNote: options.note,
    }));
    else usage();
    return;
  }

  if (group === 'enforcement') {
    requireEnforcer(actor);
    const targetUid = command === 'status' ? subject : requireTarget(options, subject);
    if (!targetUid) usage();
    if (command === 'status') {
      const state = await readEffectiveAccountEnforcement(firestore, targetUid);
      print({ restricted: state !== null, ...(state ? { status: state.status,
        expiryPresent: state.status === 'suspended' } : {}) }); return;
    }
    if (!['suspend', 'ban', 'revoke'].includes(command)) usage();
    const minutes = Number(options.minutes);
    if (command === 'suspend' && (!Number.isInteger(minutes) || minutes < 1)) {
      throw new Error('Suspension requires positive integer --minutes.');
    }
    if (['suspend', 'ban'].includes(command)
        && !ENFORCEMENT_REASONS.includes(options.reason)) {
      throw new Error('A canonical enforcement reason is required.');
    }
    if (!mutationRequested(options)) { print({ dryRun: true, operation: command }); return; }
    const requestId = requireMutation(options);
    if (command === 'revoke') print(await revokeAccountEnforcement(firestore, auth,
      { actorUid: actor.uid, targetUid, requestId }));
    else if (command === 'suspend' || command === 'ban') {
      print(await applyAccountEnforcement(firestore, auth, buildEnforcementInput({
        options, command, actorUid: actor.uid, targetUid, requestId,
      })));
    } else usage();
    return;
  }

  if (group === 'roles') {
    requireRoleAdministrator(actor);
    const targetUid = command === 'show' ? subject : requireTarget(options, subject);
    if (!targetUid) usage();
    if (command === 'show') {
      const user = await auth.getUser(targetUid);
      print({ reviewer: user.customClaims?.safetyReviewer === true,
        enforcer: user.customClaims?.safetyEnforcer === true }); return;
    }
    roleClaim(options.role);
    if (!mutationRequested(options)) { print({ dryRun: true, operation: command, role: options.role }); return; }
    const requestId = requireMutation(options);
    if (!['grant', 'revoke'].includes(command)) usage();
    print(await changeRole({ firestore, auth, actorUid: actor.uid, targetUid,
      role: options.role, grant: command === 'grant', requestId }));
    return;
  }
  usage();
}

if (import.meta.url === `file://${process.argv[1]}`) {
  run(process.argv.slice(2)).catch((error) => {
    process.stderr.write(`Safety admin failed: ${error?.code ?? error?.message ?? 'unknown error'}\n`);
    process.exitCode = 1;
  });
}
