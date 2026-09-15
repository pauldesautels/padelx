import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('../lib/', import.meta.url);
const excluded = new Set([
  'firebase_options.dart',
  'firebase_environment.dart',
  'firebase_diagnostics.dart',
]);
const presentationPattern = /\b(?:Text|Tooltip|SnackBar|AlertDialog|InputDecoration)\s*\([\s\n]*(?:const\s+)?['"]/g;

let count = 0;
const files = [];
for (const name of readdirSync(root)) {
  if (!name.endsWith('.dart') || excluded.has(name)) continue;
  const source = readFileSync(join(root.pathname, name), 'utf8')
    .replace(/debugPrint\s*\([\s\S]*?\);/g, '');
  const matches = [...source.matchAll(presentationPattern)].length;
  if (matches > 0) files.push({ file: `lib/${name}`, count: matches });
  count += matches;
}

process.stdout.write(`${JSON.stringify({ count, files }, null, 2)}\n`);
