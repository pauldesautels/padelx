import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('production release signing is dedicated and fails closed', async () => {
  const gradle = await read('android/app/build.gradle.kts');
  assert.match(gradle, /applicationId = "com\.pabloware\.padelx"/);
  assert.match(gradle, /rootProject\.file\("key\.properties"\)/);
  assert.match(gradle, /productionReleaseRequested/);
  assert.match(gradle, /Production release signing requires ignored android\/key\.properties/);
  assert.match(gradle, /create\("upload"\)/);
  assert.doesNotMatch(gradle, /release\s*\{[\s\S]*?signingConfig = signingConfigs\.getByName\("debug"\)/);
});

test('signing secrets and keystores remain ignored', async () => {
  const ignore = await read('android/.gitignore');
  assert.match(ignore, /^key\.properties$/m);
  assert.match(ignore, /^\*\*\/\*\.keystore$/m);
  assert.match(ignore, /^\*\*\/\*\.jks$/m);

  const template = await read('android/key.properties.example');
  assert.match(template, /storeFile=\/absolute\/path\/outside\/repository/);
  assert.match(template, /storePassword=\s*$/m);
  assert.match(template, /keyPassword=\s*$/m);
  assert.doesNotMatch(template, /AIza|BEGIN .*PRIVATE KEY/);
});

test('staging identity and Firebase boundary remain isolated', async () => {
  const gradle = await read('android/app/build.gradle.kts');
  assert.match(gradle, /create\("staging"\)[\s\S]*?applicationId = "com\.example\.padelx"/);
  assert.match(gradle, /processStaging/);
  assert.match(gradle, /project_id.*padelx-staging/);
});
