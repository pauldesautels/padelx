import assert from 'node:assert/strict';
import test from 'node:test';

import { legalPageRoutes } from '../tool/prepare_hosting.mjs';

async function hostingOrigin() {
  if (process.env.FIREBASE_HOSTING_EMULATOR_HOST) {
    return `http://${process.env.FIREBASE_HOSTING_EMULATOR_HOST}`;
  }
  if (process.env.FIREBASE_EMULATOR_HUB) {
    const response = await fetch(
      `http://${process.env.FIREBASE_EMULATOR_HUB}/emulators`,
    );
    const emulators = await response.json();
    const hosting = emulators.hosting;
    if (hosting?.host && hosting?.port) {
      return `http://${hosting.host}:${hosting.port}`;
    }
  }
  return 'http://127.0.0.1:5000';
}

test('Hosting emulator serves all legal paths without Flutter', async () => {
  const emulatorOrigin = await hostingOrigin();
  for (const page of legalPageRoutes) {
    for (const suffix of ['', '/']) {
      const response = await fetch(`${emulatorOrigin}/${page.route}${suffix}`);
      assert.equal(response.status, 200, `${page.route}${suffix} should resolve`);
      assert.match(response.headers.get('content-type') ?? '', /^text\/html\b/);
      assert.match(
        response.headers.get('cache-control') ?? '',
        /max-age=0.*must-revalidate/,
      );
      const html = await response.text();
      assert.match(html, new RegExp(`<html lang="${page.lang}">`));
      assert.ok(html.includes(page.marker));
      assert.ok(html.includes('<title>'));
      assert.ok(!html.includes('flutter_bootstrap.js'));
      assert.ok(!html.includes('main.dart.js'));
    }
  }
});

test('Hosting emulator keeps the Flutter application at the root', async () => {
  const emulatorOrigin = await hostingOrigin();
  const response = await fetch(`${emulatorOrigin}/`);
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.ok(html.includes('flutter_bootstrap.js'));
});
