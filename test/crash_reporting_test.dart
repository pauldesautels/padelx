import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/crash_reporting.dart';

void main() {
  test('crash collection is release-native only', () {
    expect(crashCollectionEnabled(isDebug: true, isWeb: false), false);
    expect(crashCollectionEnabled(isDebug: false, isWeb: true), false);
    expect(crashCollectionEnabled(isDebug: false, isWeb: false), true);
  });

  test('crash metadata is bounded to environment and build identity', () {
    expect(crashMetadata(environment: 'staging', buildNumber: '42'), {
      'environment': 'staging',
      'build_number': '42',
    });
  });
}
