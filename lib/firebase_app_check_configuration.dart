import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const stagingFirebaseProjectId = 'padelx-staging';

enum AppCheckMode { debug, attested }

class StagingWebAppCheckConfiguration {
  const StagingWebAppCheckConfiguration({
    required this.mode,
    this.enterpriseSiteKey,
  });

  final AppCheckMode mode;
  final String? enterpriseSiteKey;
}

StagingWebAppCheckConfiguration? appCheckConfigurationForCurrentEnvironment() {
  return stagingWebAppCheckConfiguration(
    environment: const String.fromEnvironment('FIREBASE_ENVIRONMENT'),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    isWeb: kIsWeb,
    mode: const String.fromEnvironment('FIREBASE_APP_CHECK_MODE'),
    enterpriseSiteKey: const String.fromEnvironment(
      'FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY',
    ),
  );
}

StagingWebAppCheckConfiguration? stagingWebAppCheckConfiguration({
  required String environment,
  required String projectId,
  required bool isWeb,
  required String mode,
  String enterpriseSiteKey = '',
}) {
  final selectedEnvironment = environment.trim();
  final selectedModeName = mode.trim();

  if (selectedEnvironment == 'production' && selectedModeName == 'debug') {
    throw StateError(
      'The debug App Check provider cannot be used in production.',
    );
  }

  if (selectedEnvironment != 'staging') {
    if (selectedModeName.isNotEmpty) {
      throw StateError(
        'This App Check configuration supports explicit modes only for '
        'staging web.',
      );
    }
    return null;
  }

  if (projectId.trim() != stagingFirebaseProjectId) {
    throw StateError(
      'Staging App Check requires FIREBASE_PROJECT_ID=padelx-staging.',
    );
  }

  if (!isWeb) {
    throw UnsupportedError(
      'The current App Check rollout supports staging web only.',
    );
  }

  final selectedMode = switch (selectedModeName) {
    'debug' => AppCheckMode.debug,
    'attested' => AppCheckMode.attested,
    _ => throw StateError(
      'Staging web requires FIREBASE_APP_CHECK_MODE=debug or attested.',
    ),
  };

  if (selectedMode == AppCheckMode.debug) {
    return const StagingWebAppCheckConfiguration(mode: AppCheckMode.debug);
  }

  final siteKey = enterpriseSiteKey.trim();
  if (siteKey.isEmpty || siteKey.startsWith('replace-with-')) {
    throw StateError(
      'Attested staging web App Check requires an explicit '
      'FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY.',
    );
  }

  return StagingWebAppCheckConfiguration(
    mode: AppCheckMode.attested,
    enterpriseSiteKey: siteKey,
  );
}

Future<void> activateAppCheckForCurrentEnvironment() async {
  final configuration = appCheckConfigurationForCurrentEnvironment();
  if (configuration == null) {
    return;
  }

  switch (configuration.mode) {
    case AppCheckMode.debug:
      await FirebaseAppCheck.instance.activate(providerWeb: WebDebugProvider());
    case AppCheckMode.attested:
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(
          configuration.enterpriseSiteKey!,
        ),
      );
  }
}
