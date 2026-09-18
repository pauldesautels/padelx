#!/usr/bin/env node
import process from 'node:process';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { collectOperationalHealth } from './health.mjs';
import { OPERATIONAL_QUERY_LIMIT, parseOperationalArguments, requireOperationalCommand,
  requireOperationalProject, safeFailure } from './policy.mjs';

const { options, positionals } = parseOperationalArguments(process.argv.slice(2));

try {
  const projectId = requireOperationalProject(options);
  const command = requireOperationalCommand(positionals);
  const app = initializeApp({ credential: applicationDefault(), projectId });
  const health = await collectOperationalHealth(getFirestore(app), new Date(), command);
  process.stdout.write(`${JSON.stringify({ project: 'staging', readOnly: true,
    queryLimit: OPERATIONAL_QUERY_LIMIT, health }, null, 2)}\n`);
  if (Object.values(health).some((value) => value.status !== 'ok')) process.exitCode = 1;
} catch (error) {
  process.stderr.write(`${safeFailure(error).code}\n`);
  process.exitCode = 2;
}
