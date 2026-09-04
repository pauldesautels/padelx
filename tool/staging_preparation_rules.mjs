// TEMPORARY: remove this file and its test after the staging accounting transition.
// Generates a staging-only overlay; never edits the normal rules or Firebase config.
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const marker = 'match /matches/{matchId} {';
const helper = 'stagingPreparationClientWritesAllowed';

// Find the end of a rules block, ignoring braces in comments and quoted strings.
function blockEnd(source, start) {
  let depth = 0, quote = null, lineComment = false, blockComment = false;
  for (let i = start; i < source.length; i++) {
    const char = source[i], next = source[i + 1];
    if (lineComment) { if (char === '\n') lineComment = false; continue; }
    if (blockComment) { if (char === '*' && next === '/') { blockComment = false; i++; } continue; }
    if (quote) {
      if (char === '\\') i++;
      else if (char === quote) quote = null;
      continue;
    }
    if (char === '/' && next === '/') { lineComment = true; i++; continue; }
    if (char === '/' && next === '*') { blockComment = true; i++; continue; }
    if (char === "'" || char === '"') { quote = char; continue; }
    if (char === '{') depth++;
    if (char === '}' && --depth === 0) return i;
  }
  throw new Error('Unterminated matches rules block.');
}

export function buildStagingPreparationRules(source) {
  const start = source.indexOf(marker);
  if (start < 0 || source.indexOf(marker, start + marker.length) !== -1 || source.includes(helper)) {
    throw new Error('Expected one unmodified matches rules block.');
  }
  const open = start + marker.length - 1;
  const end = blockEnd(source, open);
  const original = source.slice(open + 1, end);
  let guarded = 0;
  const body = original.replace(/\ballow\s+([a-z,\s]+):\s*if\s+([^;]+);/g,
    (statement, methods, condition) => {
      const names = methods.split(',').map(method => method.trim());
      if (!names.every(name => ['read', 'get', 'list', 'write', 'create', 'update', 'delete'].includes(name))) {
        throw new Error('Unsupported allow declaration.');
      }
      if (!names.some(name => ['write', 'create', 'update', 'delete'].includes(name))) return statement;
      if (names.some(name => ['read', 'get', 'list'].includes(name))) {
        throw new Error('Combined read/write declaration requires explicit review.');
      }
      guarded++;
      // Parentheses preserve every existing condition, including OR branches.
      return `allow ${methods}: if ${helper}() && (${condition});`;
    });
  if (guarded === 0) throw new Error('No match writes found; refusing an ineffective overlay.');
  const temporaryHelper = `
      // TEMPORARY STAGING PREPARATION LOCK. Restore the normal firestore.rules
      // after baseline verification and deployment of the new reconciler.
      // Reads retain their original conditions. Admin SDK bypasses these rules.
      function ${helper}() { return false; }
`;
  return {
    rules: source.slice(0, open + 1) + temporaryHelper + body + source.slice(end),
    guarded,
  };
}

export function stagingPreparationOptions(args) {
  if (args.some(arg => !arg.startsWith('--project=') && !arg.startsWith('--out='))
      || args.filter(arg => arg.startsWith('--project=')).length !== 1
      || args.filter(arg => arg.startsWith('--out=')).length !== 1
      || !args.includes('--project=padelx-staging')) {
    throw new Error('Requires --project=padelx-staging and --out=<temporary-directory> only.');
  }
  const output = args.find(arg => arg.startsWith('--out=')).slice(6);
  if (!output) throw new Error('An explicit temporary output directory is required.');
  return { output: resolve(output) };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const { output } = stagingPreparationOptions(process.argv.slice(2));
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  if (output === root) throw new Error('Output must not overwrite the repository configuration.');
  const { rules, guarded } = buildStagingPreparationRules(await readFile(join(root, 'firestore.rules'), 'utf8'));
  // Exclusive files prevent accidental replacement of an existing config/overlay.
  await mkdir(output, { recursive: true });
  await writeFile(join(output, 'firestore.rules'), rules, { flag: 'wx' });
  await writeFile(join(output, 'firebase.json'), JSON.stringify({
    firestore: { rules: join(output, 'firestore.rules') },
  }, null, 2) + '\n', { flag: 'wx' });
  console.log(`Prepared staging-only rules overlay: ${guarded} guarded allow declarations.`);
  console.log(`Config: ${join(output, 'firebase.json')}`);
  console.log('No Firebase request or deployment was performed. Normal rules/config are unchanged.');
}
