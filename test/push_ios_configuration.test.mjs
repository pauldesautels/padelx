import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('staging entitlements preserve App Attest and add environment-scoped APNs', async () => {
  const entitlements = await read('ios/Runner/Runner.entitlements');
  assert.match(entitlements, /com\.apple\.developer\.devicecheck\.appattest-environment/);
  assert.match(entitlements, /<key>aps-environment<\/key>\s*<string>\$\(APS_ENVIRONMENT\)<\/string>/);
  const project = await read('ios/Runner.xcodeproj/project.pbxproj');
  assert.match(project, /Debug-staging[\s\S]*?APS_ENVIRONMENT = development;/);
  assert.match(project, /Release-staging[\s\S]*?APS_ENVIRONMENT = production;/);
});

test('default device-test requires neither APNs nor App Attest entitlements', async () => {
  const entitlements = await read('ios/Runner/RunnerDeviceTest.entitlements');
  assert.doesNotMatch(entitlements, /aps-environment/);
  assert.doesNotMatch(entitlements, /appattest/);
  const project = await read('ios/Runner.xcodeproj/project.pbxproj');
  assert.match(project, /Debug-device-test[\s\S]*?CODE_SIGN_ENTITLEMENTS = Runner\/RunnerDeviceTest\.entitlements;/);
  assert.match(project, /Profile-device-test[\s\S]*?CODE_SIGN_ENTITLEMENTS = Runner\/RunnerDeviceTest\.entitlements;/);
  assert.match(project, /Release-device-test[\s\S]*?CODE_SIGN_ENTITLEMENTS = Runner\/RunnerDeviceTest\.entitlements;/);
});

test('iOS source config enables remote notifications and UIScene registration', async () => {
  const info = await read('ios/Runner/Info.plist');
  assert.match(info, /<key>UIBackgroundModes<\/key>[\s\S]*?<string>remote-notification<\/string>/);
  const delegate = await read('ios/Runner/AppDelegate.swift');
  assert.match(delegate, /import firebase_messaging/);
  assert.match(delegate, /FLTFirebaseMessagingPlugin\.configureNotificationCenterDelegate\(\)/);
});
