import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import test from 'node:test';

test('hard-coded user-facing string inventory remains available during migration', () => {
  const report = JSON.parse(
    execFileSync(process.execPath, ['tool/localization_hardcoded_inventory.mjs'], {
      encoding: 'utf8',
    }),
  );
  assert.ok(report.count > 0, 'legacy inventory should remain visible');
  assert.ok(report.files.some((entry) => entry.file === 'lib/main.dart'));
  assert.ok(!report.files.some((entry) => entry.file.startsWith('lib/l10n/')));
  assert.ok(!report.files.some((entry) => entry.file === 'lib/locale_controller.dart'));
});
