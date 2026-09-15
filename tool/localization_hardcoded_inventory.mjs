import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('../lib/', import.meta.url);
const excluded = new Set([
  'firebase_options.dart',
  'firebase_environment.dart',
  'firebase_diagnostics.dart',
]);
const presentationPattern = /\b(?:Text|Tooltip|SnackBar|AlertDialog|InputDecoration)\s*\([\s\n]*(?:const\s+)?(['"])(.*?)\1/gs;
const reviewedDataOnly = new Set([
  'PADELX',
  'PadelX',
  '${profile.discoveryLocation.city}, ${profile.discoveryLocation.country}',
  '${c.unreadCount}',
]);

let count = 0;
let reviewedCount = 0;
const files = [];
for (const name of readdirSync(root)) {
  if (!name.endsWith('.dart') || excluded.has(name)) continue;
  const source = readFileSync(join(root.pathname, name), 'utf8')
    .replace(/debugPrint\s*\([\s\S]*?\);/g, '');
  const candidates = [...source.matchAll(presentationPattern)];
  const matches = candidates.filter((match) => !reviewedDataOnly.has(match[2])).length;
  reviewedCount += candidates.length - matches;
  if (matches > 0) files.push({ file: `lib/${name}`, count: matches });
  count += matches;
}

process.stdout.write(`${JSON.stringify({ count, reviewedDataOnly: reviewedCount, files }, null, 2)}\n`);
