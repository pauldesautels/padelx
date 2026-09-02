import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/firebase_app_check_configuration.dart';

void main() {
  group('staging web App Check configuration', () {
    test('staging debug is accepted without an Enterprise site key', () {
      final configuration = _configuration(mode: 'debug');

      expect(configuration!.mode, AppCheckMode.debug);
      expect(configuration.enterpriseSiteKey, isNull);
    });

    test('staging attested is accepted with an Enterprise site key', () {
      final configuration = _configuration(
        mode: 'attested',
        siteKey: 'test-enterprise-site-key',
      );

      expect(configuration!.mode, AppCheckMode.attested);
      expect(configuration.enterpriseSiteKey, 'test-enterprise-site-key');
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

    test('non-web staging fails closed', () {
      expect(
        () => _configuration(isWeb: false, mode: 'debug'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

StagingWebAppCheckConfiguration? _configuration({
  String environment = 'staging',
  String projectId = stagingFirebaseProjectId,
  bool isWeb = true,
  required String mode,
  String siteKey = '',
}) {
  return stagingWebAppCheckConfiguration(
    environment: environment,
    projectId: projectId,
    isWeb: isWeb,
    mode: mode,
    enterpriseSiteKey: siteKey,
  );
}
