import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('Android app data backup and transfer are explicitly disabled', async () => {
  const manifest = await read('android/app/src/main/AndroidManifest.xml');
  assert.match(manifest, /android:allowBackup="false"/);
  assert.match(manifest, /android:fullBackupContent="false"/);
  assert.match(
    manifest,
    /android:dataExtractionRules="@xml\/data_extraction_rules"/,
  );

  const rules = await read(
    'android/app/src/main/res/xml/data_extraction_rules.xml',
  );
  for (const section of ['cloud-backup', 'device-transfer']) {
    assert.match(rules, new RegExp(`<${section}>[\\s\\S]*<\\/${section}>`));
  }
  for (const domain of [
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
  ]) {
    assert.equal(
      (rules.match(new RegExp(`domain="${domain}"`, 'g')) ?? []).length,
      2,
    );
  }
});
