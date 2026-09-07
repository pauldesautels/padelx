#!/usr/bin/env node
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export function indexCheckerOptions(argv) {
  const projectId = argv.find((arg) => arg.startsWith('--project='))?.split('=')[1];
  if (!projectId) throw new Error('--project is required.');
  if (projectId !== 'padelx-staging') throw new Error('Index readiness check refuses every project except padelx-staging.');
  return { projectId };
}

export function parseIndexManifest(source) {
  const parsed = JSON.parse(source);
  if (!Array.isArray(parsed.indexes) || !Array.isArray(parsed.fieldOverrides)) throw new Error('Malformed index manifest.');
  return parsed;
}

const fields = (values = []) => values.filter((field) => field.fieldPath !== '__name__')
  .map((field) => `${field.fieldPath}:${field.order ?? field.arrayConfig}`).join(',');

export function classifyCompositeIndexes(spec, response) {
  if (!Array.isArray(response)) throw new Error('Malformed index response.');
  return spec.indexes.map((expected) => {
    const expectedFields = fields(expected.fields);
    const found = response.find((candidate) => candidate && candidate.collectionGroup === expected.collectionGroup
      && candidate.queryScope === expected.queryScope && fields(candidate.fields) === expectedFields);
    const status = found?.state === 'READY' ? 'READY' : found?.state === 'CREATING' ? 'CREATING' : 'missing';
    return { collectionGroup: expected.collectionGroup, fields: expectedFields,
      expectedScope: expected.queryScope, status };
  });
}

export async function checkPhase9Indexes(argv = process.argv.slice(2), { run = promisify(execFile), manifestSource } = {}) {
  const { projectId } = indexCheckerOptions(argv);
  const source = manifestSource ?? await readFile(new URL('../firestore.indexes.json', import.meta.url), 'utf8');
  const spec = parseIndexManifest(source);
  const { stdout } = await run('gcloud', ['firestore', 'indexes', 'composite', 'list',
    `--project=${projectId}`, '--database=(default)', '--format=json'], { maxBuffer: 4 * 1024 * 1024 });
  const rows = classifyCompositeIndexes(spec, JSON.parse(stdout));
  for (const override of spec.fieldOverrides.filter((item) => item.indexes?.some((index) => index.queryScope === 'COLLECTION_GROUP'))) {
    let status = 'missing';
    try {
      const result = await run('gcloud', ['firestore', 'indexes', 'fields', 'describe',
        override.fieldPath, `--collection-group=${override.collectionGroup}`, `--project=${projectId}`,
        '--database=(default)', '--format=json']);
      const configured = JSON.parse(result.stdout).indexConfig?.indexes;
      if (!Array.isArray(configured)) throw new Error('Malformed field index response.');
      const match = configured.find((index) => index.queryScope === 'COLLECTION_GROUP');
      status = match?.state === 'CREATING' ? 'CREATING' : match ? 'READY' : 'missing';
    } catch { status = 'missing'; }
    rows.push({ collectionGroup: override.collectionGroup, fields: `${override.fieldPath}:ASCENDING`,
      expectedScope: 'COLLECTION_GROUP', status });
  }
  return rows;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  for (const row of await checkPhase9Indexes()) console.log(JSON.stringify(row));
}
