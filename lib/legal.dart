import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_environment.dart';
import 'l10n/l10n.dart';

typedef LegalUriLauncher = Future<bool> Function(Uri uri);

class PadelXLegalConfiguration {
  final String productName;
  final String operatorName;
  final String contactEmail;
  final String termsVersion;
  final String privacyVersion;
  final String communityVersion;
  final String baseUrl;

  const PadelXLegalConfiguration({
    required this.productName,
    required this.operatorName,
    required this.contactEmail,
    required this.termsVersion,
    required this.privacyVersion,
    required this.communityVersion,
    required this.baseUrl,
  });

  static final beta = PadelXLegalConfiguration(
    productName: 'PadelX',
    operatorName: 'Paul Desautels',
    contactEmail: 'support.padelx@gmail.com',
    termsVersion: 'terms-beta-v2',
    privacyVersion: 'privacy-beta-v2',
    communityVersion: 'community-beta-v2',
    baseUrl: legalBaseUrlForEnvironment(
      configuredBaseUrl: const String.fromEnvironment('LEGAL_BASE_URL'),
      firebaseEnvironment: const String.fromEnvironment('FIREBASE_ENVIRONMENT'),
      firebaseProjectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    ),
  );

  Uri? uri(String path) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      return null;
    }
    return base.resolve(path);
  }
}

const stagingLegalBaseUrl = 'https://padelx-staging.web.app';

String legalBaseUrlForEnvironment({
  required String configuredBaseUrl,
  required String firebaseEnvironment,
  required String firebaseProjectId,
}) {
  final environment = firebaseEnvironment.trim();
  final projectId = firebaseProjectId.trim();
  final configured = configuredBaseUrl.trim();

  if (environment == 'staging') {
    if (projectId != stagingFirebaseProjectId) return '';
    if (configured.isEmpty) return stagingLegalBaseUrl;
    final uri = Uri.tryParse(configured);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host == 'padelx-staging.web.app'
        ? configured
        : '';
  }

  if (environment == 'production') {
    if (projectId != productionFirebaseProjectId || configured.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(configured);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host == 'padelx-staging.web.app') {
      return '';
    }
    return configured;
  }

  return configured;
}

Future<bool> launchLegalUri(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> openLegalLink(
  BuildContext context,
  String path, {
  PadelXLegalConfiguration? configuration,
  LegalUriLauncher launcher = launchLegalUri,
}) async {
  final selectedConfiguration = configuration ?? PadelXLegalConfiguration.beta;
  final languageCode = Localizations.localeOf(context).languageCode;
  final localizedPath = languageCode == 'es'
      ? '/es-MX/${path.replaceAll(RegExp(r'^/+|/+$'), '')}'
      : path;
  final uri = selectedConfiguration.uri(localizedPath);
  var opened = false;
  try {
    if (uri != null) opened = await launcher(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.couldNotOpenPage(selectedConfiguration.contactEmail),
        ),
      ),
    );
  }
}
