import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        defaultTargetPlatform,
        kDebugMode,
        kIsWeb,
        kProfileMode,
        kReleaseMode;

import 'firebase_environment.dart' show stagingFirebaseProjectId;

enum AppCheckMode { debug, attested }

enum AppCheckPlatform { web, ios, android }

class StagingAppCheckConfiguration {
  const StagingAppCheckConfiguration({
    required this.mode,
    required this.platform,
    this.enterpriseSiteKey,
    this.debugToken,
  });

  final AppCheckMode mode;
  final AppCheckPlatform platform;
  final String? enterpriseSiteKey;
  final String? debugToken;
}

StagingAppCheckConfiguration? appCheckConfigurationForCurrentEnvironment() {
  return stagingAppCheckConfiguration(
    environment: const String.fromEnvironment('FIREBASE_ENVIRONMENT'),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    isWeb: kIsWeb,
    isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    isDebugBuild: kDebugMode,
    isProfileBuild: kProfileMode,
    isReleaseBuild: kReleaseMode,
    isDeviceTestBuild: const bool.fromEnvironment('PADELX_IOS_DEVICE_TEST'),
    mode: const String.fromEnvironment('FIREBASE_APP_CHECK_MODE'),
    enterpriseSiteKey: const String.fromEnvironment(
      'FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY',
    ),
    debugToken: const String.fromEnvironment('FIREBASE_APP_CHECK_DEBUG_TOKEN'),
  );
}

StagingAppCheckConfiguration? stagingAppCheckConfiguration({
  required String environment,
  required String projectId,
  required bool isWeb,
  bool isIos = false,
  bool isAndroid = false,
  bool isDebugBuild = false,
  bool isProfileBuild = false,
  bool isReleaseBuild = false,
  bool isDeviceTestBuild = false,
  required String mode,
  String enterpriseSiteKey = '',
  String debugToken = '',
}) {
  final selectedEnvironment = environment.trim();
  final selectedModeName = mode.trim();
  final selectedDebugToken = debugToken.trim();

  if (selectedEnvironment == 'production' &&
      (selectedModeName == 'debug' || selectedDebugToken.isNotEmpty)) {
    throw StateError(
      'The App Check debug provider or token cannot be used in production.',
    );
  }

  if (selectedEnvironment == 'production' && (isIos || isAndroid)) {
    if (!isReleaseBuild) {
      throw StateError(
        'Production native App Check requires a release build.',
      );
    }
    if (selectedModeName.isNotEmpty) {
      throw StateError(
        'Production native App Check provider selection is automatic.',
      );
    }
    return StagingAppCheckConfiguration(
      mode: AppCheckMode.attested,
      platform: isIos ? AppCheckPlatform.ios : AppCheckPlatform.android,
    );
  }

  if (selectedEnvironment != 'staging') {
    if (selectedModeName.isNotEmpty) {
      throw StateError(
        'Explicit App Check modes are supported only for staging.',
      );
    }
    return null;
  }

  if (projectId.trim() != stagingFirebaseProjectId) {
    throw StateError(
      'Staging App Check requires FIREBASE_PROJECT_ID=padelx-staging.',
    );
  }

  if (!isWeb && !isIos && !isAndroid) {
    throw UnsupportedError(
      'Staging App Check supports web, iOS, and Android only.',
    );
  }

  final selectedMode = switch (selectedModeName) {
    'debug' => AppCheckMode.debug,
    'attested' => AppCheckMode.attested,
    _ => throw StateError(
      'Staging requires FIREBASE_APP_CHECK_MODE=debug or attested.',
    ),
  };

  if (isIos && selectedMode == AppCheckMode.debug && !isDeviceTestBuild) {
    throw StateError(
      'iOS debug App Check requires PADELX_IOS_DEVICE_TEST=true.',
    );
  }
  if (isIos && selectedMode == AppCheckMode.debug && isReleaseBuild) {
    throw StateError(
      'Release device-test builds cannot use the App Check debug provider.',
    );
  }
  if (isIos &&
      selectedMode == AppCheckMode.debug &&
      isProfileBuild &&
      selectedDebugToken.isEmpty) {
    throw StateError(
      'Profile device-test requires an explicit staging App Check debug token.',
    );
  }
  if (isIos && selectedMode == AppCheckMode.attested && isDeviceTestBuild) {
    throw StateError('The iOS device-test build requires debug App Check.');
  }
  if (isAndroid && selectedMode == AppCheckMode.debug && !isDebugBuild) {
    throw StateError('Android debug App Check requires a debug build.');
  }

  if (selectedMode == AppCheckMode.debug) {
    if (selectedDebugToken.startsWith('replace-with-')) {
      throw StateError(
        'FIREBASE_APP_CHECK_DEBUG_TOKEN still contains an example placeholder.',
      );
    }
    return StagingAppCheckConfiguration(
      mode: AppCheckMode.debug,
      platform: isIos
          ? AppCheckPlatform.ios
          : isAndroid
          ? AppCheckPlatform.android
          : AppCheckPlatform.web,
      debugToken: (isWeb || isIos) && selectedDebugToken.isNotEmpty
          ? selectedDebugToken
          : null,
    );
  }

  if (isIos) {
    return const StagingAppCheckConfiguration(
      mode: AppCheckMode.attested,
      platform: AppCheckPlatform.ios,
    );
  }
  if (isAndroid) {
    return const StagingAppCheckConfiguration(
      mode: AppCheckMode.attested,
      platform: AppCheckPlatform.android,
    );
  }

  final siteKey = enterpriseSiteKey.trim();
  if (siteKey.isEmpty || siteKey.startsWith('replace-with-')) {
    throw StateError(
      'Attested staging web App Check requires an explicit '
      'FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY.',
    );
  }

  return StagingAppCheckConfiguration(
    mode: AppCheckMode.attested,
    platform: AppCheckPlatform.web,
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
      switch (configuration.platform) {
        case AppCheckPlatform.web:
          await FirebaseAppCheck.instance.activate(
            providerWeb: WebDebugProvider(debugToken: configuration.debugToken),
          );
        case AppCheckPlatform.ios:
          await FirebaseAppCheck.instance.activate(
            providerApple: AppleDebugProvider(
              debugToken: configuration.debugToken,
            ),
          );
        case AppCheckPlatform.android:
          await FirebaseAppCheck.instance.activate(
            providerAndroid: const AndroidDebugProvider(),
          );
      }
    case AppCheckMode.attested:
      switch (configuration.platform) {
        case AppCheckPlatform.web:
          await FirebaseAppCheck.instance.activate(
            providerWeb: ReCaptchaEnterpriseProvider(
              configuration.enterpriseSiteKey!,
            ),
          );
        case AppCheckPlatform.ios:
          await FirebaseAppCheck.instance.activate(
            providerApple:
                const AppleAppAttestWithDeviceCheckFallbackProvider(),
          );
        case AppCheckPlatform.android:
          await FirebaseAppCheck.instance.activate(
            providerAndroid: const AndroidPlayIntegrityProvider(),
          );
      }
  }
}
