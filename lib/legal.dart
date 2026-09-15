import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static const beta = PadelXLegalConfiguration(
    productName: 'PadelX',
    operatorName: 'Paul Desautels',
    contactEmail: 'support.padelx@gmail.com',
    termsVersion: 'terms-beta-v1',
    privacyVersion: 'privacy-beta-v1',
    communityVersion: 'community-beta-v1',
    baseUrl: String.fromEnvironment('LEGAL_BASE_URL'),
  );

  Uri? uri(String path) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      return null;
    }
    return base.resolve(path);
  }
}

Future<bool> launchLegalUri(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> openLegalLink(
  BuildContext context,
  String path, {
  PadelXLegalConfiguration configuration = PadelXLegalConfiguration.beta,
  LegalUriLauncher launcher = launchLegalUri,
}) async {
  final languageCode = Localizations.localeOf(context).languageCode;
  final localizedPath = languageCode == 'es'
      ? '/es-MX/${path.replaceAll(RegExp(r'^/+|/+$'), '')}'
      : path;
  final uri = configuration.uri(localizedPath);
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
          context.l10n.couldNotOpenPage(configuration.contactEmail),
        ),
      ),
    );
  }
}
