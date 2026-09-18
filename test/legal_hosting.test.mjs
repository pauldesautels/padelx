import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { legalPageRoutes, prepareHosting } from '../tool/prepare_hosting.mjs';

const repositoryRoot = path.resolve(import.meta.dirname, '..');

test('Hosting prepares all legal routes as static pages', async (t) => {
  const temporaryRoot = await mkdtemp(path.join(os.tmpdir(), 'padelx-hosting-'));
  t.after(() => rm(temporaryRoot, { recursive: true, force: true }));
  const destinationRoot = path.join(temporaryRoot, 'build', 'web');
  await mkdir(destinationRoot, { recursive: true });
  const flutterIndex =
    '<!doctype html><html><body><script src="flutter_bootstrap.js"></script></body></html>';
  await writeFile(path.join(destinationRoot, 'index.html'), flutterIndex);

  await prepareHosting({
    sourceRoot: path.join(repositoryRoot, 'web'),
    destinationRoot,
  });

  for (const page of legalPageRoutes) {
    for (const requestedPath of [`/${page.route}`, `/${page.route}/`]) {
      const resolved = path.join(
        destinationRoot,
        requestedPath.replace(/^\//, ''),
        'index.html',
      );
      const html = await readFile(resolved, 'utf8');
      assert.match(html, new RegExp(`<html lang="${page.lang}">`));
      assert.ok(html.includes(page.marker));
      assert.ok(html.includes('<title>'));
      assert.ok(!html.includes('flutter_bootstrap.js'));
      assert.ok(!html.includes('main.dart.js'));
    }
  }

  assert.equal(await readFile(path.join(destinationRoot, 'index.html'), 'utf8'), flutterIndex);
});

test('Hosting configuration prepares static files before the SPA fallback', async () => {
  const configuration = JSON.parse(
    await readFile(path.join(repositoryRoot, 'firebase.json'), 'utf8'),
  );
  assert.equal(configuration.hosting.public, 'build/web');
  assert.deepEqual(configuration.hosting.predeploy, ['npm run prepare:hosting']);
  assert.deepEqual(
    configuration.hosting.rewrites.slice(0, -1),
    legalPageRoutes.map((page) => ({
      source: `/${page.route}{,/**}`,
      destination: `/${page.route}/index.html`,
    })),
  );
  assert.deepEqual(
    configuration.hosting.headers,
    legalPageRoutes.map((page) => ({
      source: `/${page.route}{,/**}`,
      headers: [
        {
          key: 'Cache-Control',
          value: 'public, max-age=0, must-revalidate',
        },
      ],
    })),
  );
  assert.deepEqual(configuration.hosting.rewrites.at(-1), {
    source: '**',
    destination: '/index.html',
  });
});

test('legal hosting pages retain required beta disclosures', async () => {
  for (const page of legalPageRoutes) {
    const html = await readFile(
      path.join(repositoryRoot, 'web', page.route, 'index.html'),
      'utf8',
    );
    assert.match(html, /<meta name="viewport"/);
    assert.match(html, /support\.padelx@gmail\.com/);
    assert.doesNotMatch(html, /<script|fonts\.googleapis|PadelX Pay/i);
  }

  const privacy = await readFile(
    path.join(repositoryRoot, 'web', 'privacy', 'index.html'),
    'utf8',
  );
  assert.match(privacy, /privacy-beta-v2/);
  assert.match(privacy, /not end-to-end encrypted/);
  assert.match(privacy, /removes your profile from Find Players/);
  assert.match(privacy, /18 or older/);

  const terms = await readFile(
    path.join(repositoryRoot, 'web', 'terms', 'index.html'),
    'utf8',
  );
  assert.match(terms, /terms-beta-v2/);
  assert.match(terms, /Quick Match/);
  assert.doesNotMatch(terms, /does not currently provide payments or automatic matchmaking/i);

  const guidelines = await readFile(
    path.join(repositoryRoot, 'web', 'community-guidelines', 'index.html'),
    'utf8',
  );
  assert.match(guidelines, /community-beta-v2/);
  assert.match(guidelines, /good-faith disagreement/i);
  assert.doesNotMatch(guidelines, /no Reliability feature currently exists/i);

  const spanishGuidelines = await readFile(
    path.join(repositoryRoot, 'web', 'es-MX', 'community-guidelines', 'index.html'),
    'utf8',
  );
  assert.match(spanishGuidelines, /personas de 18 años o más/);
  assert.match(spanishGuidelines, /desacuerdo de buena fe/i);
  assert.doesNotMatch(spanishGuidelines, /personas mayores de 18 años/i);
});
