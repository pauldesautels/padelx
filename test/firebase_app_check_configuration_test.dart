import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/firebase_app_check_configuration.dart';
import 'package:padelx/firebase_environment.dart' show stagingFirebaseProjectId;

void main() {
  group('staging web App Check configuration', () {
    test('staging debug is accepted without an Enterprise site key', () {
      final configuration = _configuration(mode: 'debug');

      expect(configuration!.mode, AppCheckMode.debug);
      expect(configuration.enterpriseSiteKey, isNull);
      expect(configuration.platform, AppCheckPlatform.web);
      expect(configuration.debugToken, isNull);
    });

    test('staging web debug passes an explicit local debug token', () {
      final configuration = _configuration(
        mode: 'debug',
        debugToken: 'local-debug-token',
      );

      expect(configuration!.debugToken, 'local-debug-token');
    });

    test('staging attested is accepted with an Enterprise site key', () {
      final configuration = _configuration(
        mode: 'attested',
        siteKey: 'test-enterprise-site-key',
      );

      expect(configuration!.mode, AppCheckMode.attested);
      expect(configuration.enterpriseSiteKey, 'test-enterprise-site-key');
      expect(configuration.debugToken, isNull);
    });

    test('attested mode never uses a supplied debug token', () {
      final configuration = _configuration(
        mode: 'attested',
        siteKey: 'test-enterprise-site-key',
        debugToken: 'local-debug-token',
      );

      expect(configuration!.debugToken, isNull);
    });

    test('attested without a real Enterprise site key is rejected', () {
      for (final siteKey in ['', 'replace-with-staging-enterprise-site-key']) {
        expect(
          () => _configuration(mode: 'attested', siteKey: siteKey),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('RECAPTCHA_ENTERPRISE_SITE_KEY'),
            ),
          ),
        );
      }
    });

    test('production debug is rejected', () {
      expect(
        () => _configuration(
          environment: 'production',
          projectId: 'padelx-f168f',
          mode: 'debug',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('cannot be used in production'),
          ),
        ),
      );
    });

    test('production rejects a debug token even without debug mode', () {
      expect(
        () => _configuration(
          environment: 'production',
          projectId: 'padelx-f168f',
          mode: '',
          debugToken: 'local-debug-token',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('development without an App Check mode keeps existing behavior', () {
      expect(
        _configuration(
          environment: 'development',
          projectId: 'padelx-development',
          mode: '',
        ),
        isNull,
      );
    });

    test('development rejects staging-only App Check modes', () {
      expect(
        () => _configuration(
          environment: 'development',
          projectId: 'padelx-development',
          mode: 'debug',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('staging requires an explicit supported mode', () {
      for (final mode in ['', 'automatic']) {
        expect(() => _configuration(mode: mode), throwsA(isA<StateError>()));
      }
    });

    test('staging refuses any project other than padelx-staging', () {
      expect(
        () => _configuration(projectId: 'another-project', mode: 'debug'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('FIREBASE_PROJECT_ID=padelx-staging'),
          ),
        ),
      );
    });

    test('iOS staging selects native Apple attestation', () {
      final configuration = _configuration(
        isWeb: false,
        isIos: true,
        mode: 'attested',
      );
      expect(configuration!.platform, AppCheckPlatform.ios);
      expect(configuration.mode, AppCheckMode.attested);
      expect(configuration.enterpriseSiteKey, isNull);
    });

    test('iOS staging rejects debug App Check', () {
      expect(
        () => _configuration(isWeb: false, isIos: true, mode: 'debug'),
        throwsA(isA<StateError>()),
      );
    });

    test('non-debug staging rejects iOS debug App Check', () {
      expect(
        () => _configuration(
          isWeb: false,
          isIos: true,
          mode: 'debug',
          isDeviceTestBuild: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('in a debug build'),
          ),
        ),
      );
    });

    test('debug device-test iOS selects Apple debug provider', () {
      final configuration = _configuration(
        isWeb: false,
        isIos: true,
        mode: 'debug',
        isDebugBuild: true,
        isDeviceTestBuild: true,
      );
      expect(configuration!.platform, AppCheckPlatform.ios);
      expect(configuration.mode, AppCheckMode.debug);
      expect(configuration.debugToken, isNull);
    });

    test('iOS device-test ignores the web debug token define', () {
      final configuration = _configuration(
        isWeb: false,
        isIos: true,
        mode: 'debug',
        isDebugBuild: true,
        isDeviceTestBuild: true,
        debugToken: 'web-only-token',
      );
      expect(configuration!.platform, AppCheckPlatform.ios);
      expect(configuration.debugToken, isNull);
    });

    test('Android staging supports debug and Play Integrity providers', () {
      final debug = _configuration(
        isWeb: false,
        isAndroid: true,
        isDebugBuild: true,
        mode: 'debug',
      );
      final attested = _configuration(
        isWeb: false,
        isAndroid: true,
        mode: 'attested',
      );
      expect(debug!.platform, AppCheckPlatform.android);
      expect(debug.mode, AppCheckMode.debug);
      expect(attested!.platform, AppCheckPlatform.android);
      expect(attested.mode, AppCheckMode.attested);
    });

    test('unsupported native staging platform fails closed', () {
      expect(
        () => _configuration(isWeb: false, mode: 'debug'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

StagingAppCheckConfiguration? _configuration({
  String environment = 'staging',
  String projectId = stagingFirebaseProjectId,
  bool isWeb = true,
  bool isIos = false,
  bool isAndroid = false,
  bool isDebugBuild = false,
  bool isDeviceTestBuild = false,
  required String mode,
  String siteKey = '',
  String debugToken = '',
}) {
  return stagingAppCheckConfiguration(
    environment: environment,
    projectId: projectId,
    isWeb: isWeb,
    isIos: isIos,
    isAndroid: isAndroid,
    isDebugBuild: isDebugBuild,
    isDeviceTestBuild: isDeviceTestBuild,
    mode: mode,
    enterpriseSiteKey: siteKey,
    debugToken: debugToken,
  );
}
