import { readFile, stat } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const read = (path) => readFile(path, 'utf8');
const readPngSize = async (path) => {
  const png = await readFile(path);
  assert.equal(png.toString('ascii', 1, 4), 'PNG');
  return {
    width: png.readUInt32BE(16),
    height: png.readUInt32BE(20),
  };
};

test('canonical mark is the only Flutter image branding asset', async () => {
  await stat('assets/branding/padelx-mark.png');
  const pubspec = await read('pubspec.yaml');
  assert.match(pubspec, /assets\/branding\/padelx-mark\.png/);
  assert.doesNotMatch(pubspec, /padelx-wordmark\.png/);
  assert.doesNotMatch(pubspec, /mocku|composite/i);
});

test('iOS native launch uses the canonical branded image and dark background', async () => {
  const storyboard = await read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
  assert.match(storyboard, /image="PadelXLaunchMark"/);
  assert.doesNotMatch(storyboard, /image="LaunchImage"/);
  assert.match(storyboard, /red="0\.007843137255"/);
  assert.match(storyboard, /firstAttribute="centerX"/);
  assert.match(storyboard, /firstAttribute="centerY"/);
  assert.match(storyboard, /firstAttribute="width" constant="168"/);
  assert.match(storyboard, /firstAttribute="height" constant="168"/);

  const imageSet = 'ios/Runner/Assets.xcassets/PadelXLaunchMark.imageset';
  const contents = await read(`${imageSet}/Contents.json`);
  for (const [filename, scale] of [
    ['PadelXLaunchMark.png', 1],
    ['PadelXLaunchMark@2x.png', 2],
    ['PadelXLaunchMark@3x.png', 3],
  ]) {
    assert.match(contents, new RegExp(filename.replace('.', '\\.') + `[^}]+"scale" : "${scale}x"`, 's'));
    assert.deepEqual(await readPngSize(`${imageSet}/${filename}`), {
      width: 168 * scale,
      height: 168 * scale,
    });
  }

  const branding = await read('lib/branding.dart');
  assert.match(branding, /padelXBackground = Color\(0xFF021812\)/);

  const mainStoryboard = await read('ios/Runner/Base.lproj/Main.storyboard');
  assert.match(mainStoryboard, /customClass="FlutterViewController"/);
  assert.match(mainStoryboard, /image="PadelXLaunchMark"/);
  assert.match(mainStoryboard, /red="0\.007843137255"/);
  assert.match(mainStoryboard, /firstAttribute="centerX"/);
  assert.match(mainStoryboard, /firstAttribute="centerY"/);

  const sceneDelegate = await read('ios/Runner/SceneDelegate.swift');
  assert.match(sceneDelegate, /loadDefaultSplashScreenView\(\)/);
  assert.match(sceneDelegate, /super\.scene\(scene, willConnectTo:/);

  const info = await read('ios/Runner/Info.plist');
  assert.match(info, /<key>UILaunchStoryboardName<\/key>\s*<string>LaunchScreen<\/string>/);
  assert.match(info, /<key>UISceneStoryboardFile<\/key>\s*<string>Main<\/string>/);
  const entitlements = await read('ios/Runner/RunnerDeviceTest.entitlements');
  assert.doesNotMatch(entitlements, /aps-environment|appattest/);
});

test('device-test supports standalone AOT builds without production resources', async () => {
  const project = await read('ios/Runner.xcodeproj/project.pbxproj');
  const scheme = await read(
    'ios/Runner.xcodeproj/xcshareddata/xcschemes/device-test.xcscheme',
  );
  const firebaseScript = await read('ios/scripts/copy_firebase_config.sh');
  assert.match(project, /Profile-device-test/);
  assert.match(project, /Release-device-test/);
  assert.match(scheme, /ProfileAction buildConfiguration="Profile-device-test"/);
  assert.match(scheme, /ArchiveAction buildConfiguration="Release-device-test"/);
  assert.match(
    firebaseScript,
    /\*-device-test\)[\s\S]*?rm -f "\$\{destination\}"[\s\S]*?exit 0[\s\S]*?;;/,
  );
});

test('Android and web launch surfaces use PadelX branding', async () => {
  const android = await read('android/app/src/main/res/drawable/launch_background.xml');
  const android21 = await read('android/app/src/main/res/drawable-v21/launch_background.xml');
  const colors = await read('android/app/src/main/res/values/colors.xml');
  assert.match(android, /padelx_launch_mark/);
  assert.match(android21, /padelx_launch_mark/);
  assert.match(colors, /#021812/);
  await stat('android/app/src/main/res/drawable-nodpi/padelx_launch_mark.png');
  const manifest = await read('web/manifest.json');
  assert.match(manifest, /"background_color": "#021812"/);
});
