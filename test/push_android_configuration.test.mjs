import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('Android declares notification permission without custom messaging services', async () => {
  const manifest = await read('android/app/src/main/AndroidManifest.xml');
  assert.match(manifest, /android\.permission\.POST_NOTIFICATIONS/);
  assert.doesNotMatch(manifest, /FirebaseMessagingService|<service/);
});

test('Android push registration uses the repository application identity', async () => {
  const gradle = await read('android/app/build.gradle.kts');
  const server = await read('functions/push_devices.js');
  assert.match(gradle, /create\("staging"\)[\s\S]*?applicationId = "com\.example\.padelx"/);
  assert.match(gradle, /create\("production"\)[\s\S]*?applicationId = "com\.pabloware\.padelx"/);
  assert.match(gradle, /namespace = "com\.example\.padelx"/);
  assert.match(server, /STAGING_ANDROID_PACKAGES = Object\.freeze\(\['com\.example\.padelx'\]\)/);
  assert.match(server, /PRODUCTION_ANDROID_PACKAGES = Object\.freeze\(\['com\.pabloware\.padelx'\]\)/);
  assert.match(gradle, /create\("staging"\)/);
  assert.match(gradle, /create\("production"\)/);
  assert.match(gradle, /processStaging/);
  assert.match(gradle, /project_id.*padelx-staging/);
});

test('production Android and iOS identities remain platform-specific', async () => {
  const environment = await read('lib/firebase_environment.dart');
  const server = await read('functions/push_devices.js');
  assert.match(environment, /productionIosBundleId = 'com\.padelx\.app'/);
  assert.match(environment, /productionAndroidPackageName = 'com\.pabloware\.padelx'/);
  assert.match(server, /PRODUCTION_IOS_BUNDLES = Object\.freeze\(\['com\.padelx\.app'\]\)/);
  assert.match(server, /PRODUCTION_ANDROID_PACKAGES = Object\.freeze\(\['com\.pabloware\.padelx'\]\)/);
  assert.doesNotMatch(server, /PRODUCTION_ANDROID_PACKAGES = Object\.freeze\(\['com\.padelx\.app'\]\)/);
});

test('checked-in Android Firebase config remains production and blocks staging validation', async () => {
  const configuration = JSON.parse(await read('android/app/google-services.json'));
  assert.equal(configuration.project_info.project_id, 'padelx-f168f');
  assert.notEqual(configuration.project_info.project_id, 'padelx-staging');
});
