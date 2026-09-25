import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('Android applies the release Crashlytics mapping plugin', async () => {
  const settings = await read('android/settings.gradle.kts');
  const app = await read('android/app/build.gradle.kts');

  assert.match(
    settings,
    /id\("com\.google\.firebase\.crashlytics"\) version\("3\.0\.8"\) apply false/,
  );
  assert.match(
    settings,
    /id\("com\.google\.gms\.google-services"\) version\("4\.4\.1"\) apply false/,
  );
  assert.match(app, /id\("com\.google\.firebase\.crashlytics"\)/);
});

test('Crash collection is release-only and metadata stays non-identifying', async () => {
  const reporting = await read('lib/crash_reporting.dart');

  assert.match(
    reporting,
    /bool crashCollectionEnabled[\s\S]*=>\s*!isDebug && !isWeb;/,
  );
  assert.match(
    reporting,
    /=> \{'environment': environment, 'build_number': buildNumber\};/,
  );
  assert.doesNotMatch(
    reporting,
    /setUserIdentifier|setCustomKey\([^\n]*(?:email|uid|location|token|apiKey)/i,
  );
});
