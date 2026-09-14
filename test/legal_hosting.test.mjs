import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const routes = ['privacy', 'terms', 'community-guidelines', 'account-deletion'];
test('legal hosting pages are static, versioned, accessible content', async () => {
  for (const route of routes) {
    const html = await readFile(new URL(`../web/${route}/index.html`, import.meta.url), 'utf8');
    assert.match(html, /<meta name="viewport"/);
    assert.match(html, /support\.padelx@gmail\.com/);
    assert.match(html, /Paul Desautels|Community Guidelines|Delete your PadelX account/);
    assert.doesNotMatch(html, /<script|fonts\.googleapis|analytics|PadelX Pay/i);
  }
});
test('policy pages disclose core beta facts', async () => {
  const privacy = await readFile(new URL('../web/privacy/index.html', import.meta.url), 'utf8');
  assert.match(privacy, /privacy-beta-v1/); assert.match(privacy, /not end-to-end encrypted/);
  assert.match(privacy, /removes your profile from Find Players/); assert.match(privacy, /18 or older/);
  const terms = await readFile(new URL('../web/terms/index.html', import.meta.url), 'utf8');
  assert.match(terms, /terms-beta-v1/); assert.match(terms, /closed beta/i);
});
