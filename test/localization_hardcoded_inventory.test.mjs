import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import test from 'node:test';

test('hard-coded user-facing string inventory blocks localization regressions', () => {
  const report = JSON.parse(
    execFileSync(process.execPath, ['tool/localization_hardcoded_inventory.mjs'], {
      encoding: 'utf8',
    }),
  );
  assert.equal(report.count, 0, 'all P0/P1 presentation strings must be localized');
  assert.equal(report.reviewedDataOnly, 4);
  assert.deepEqual(report.files, []);
  assert.ok(!report.files.some((entry) => entry.file.startsWith('lib/l10n/')));
  assert.ok(!report.files.some((entry) => entry.file === 'lib/locale_controller.dart'));
});
