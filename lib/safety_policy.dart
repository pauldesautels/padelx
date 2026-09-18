import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_localizations.dart';

typedef SupportUriLauncher = Future<bool> Function(Uri uri);

Future<bool> launchSupportUri(Uri uri) => launchUrl(uri);

class PadelXSupportConfiguration {
  final String supportEmail;

  const PadelXSupportConfiguration({required this.supportEmail});

  static const beta = PadelXSupportConfiguration(
    supportEmail: 'support.padelx@gmail.com',
  );

  String get displayLabel => supportEmail.trim();

  Uri? get mailtoUri {
    final email = displayLabel;
    if (!RegExp(
      r"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)+$",
      caseSensitive: false,
    ).hasMatch(email)) {
      return null;
    }
    return Uri(scheme: 'mailto', path: email);
  }
}

class CommunityGuidelineSection {
  final String heading;
  final List<String> paragraphs;

  const CommunityGuidelineSection(this.heading, this.paragraphs);
}

const communityGuidelineSections = <CommunityGuidelineSection>[
  CommunityGuidelineSection('Adults only', [
    'PadelX is for users 18 and older.',
  ]),
  CommunityGuidelineSection('Respect other players', [
    'Treat players respectfully. Harassment, bullying, intimidation, and targeted abuse are not allowed.',
  ]),
  CommunityGuidelineSection('Hate and discrimination', [
    'Hateful or discriminatory content and conduct are not allowed.',
  ]),
  CommunityGuidelineSection('Sexual or inappropriate conduct', [
    'Do not send unwanted sexual content or engage in sexual harassment or other inappropriate behavior.',
  ]),
  CommunityGuidelineSection('Threats and unsafe behavior', [
    'Threats, violence, intimidation, and deliberately unsafe conduct are not allowed.',
  ]),
  CommunityGuidelineSection('Spam, scams, and deception', [
    'Do not post scams, spam, deceptive listings, fraudulent payment requests, or intentionally misleading match information.',
  ]),
  CommunityGuidelineSection('Impersonation', [
    'Do not impersonate another player, venue, organization, or person.',
  ]),
  CommunityGuidelineSection('Privacy', [
    'Do not share another person’s private information without permission or improperly expose private or residential locations.',
  ]),
  CommunityGuidelineSection('Profiles and content', [
    'Display names, avatars, biographies, match information, and messages must follow these guidelines.',
  ]),
  CommunityGuidelineSection('Messaging', [
    'Do not use Direct Messages or Match Chat for harassment, threats, scams, spam, or unwanted inappropriate content.',
  ]),
  CommunityGuidelineSection('Matches', [
    'Create honest match listings. Do not intentionally misrepresent location, time, cost, level, availability, or organizer information.',
  ]),
  CommunityGuidelineSection('Blocking and reporting', [
    'Respect another player’s decision to block or stop communicating. Do not retaliate against someone for blocking or reporting, or knowingly submit malicious or fabricated reports.',
  ]),
  CommunityGuidelineSection('Real-world safety', [
    'Exercise reasonable judgment when meeting people in person. Only share a private venue when authorized, and do not misuse or unnecessarily redistribute its exact location.',
  ]),
  CommunityGuidelineSection('Reliability and attendance', [
    'Reliability is separate from skill and subjective ratings. Submit attendance information honestly. Knowingly false or coordinated submissions intended to manipulate another player’s Reliability are prohibited; good-faith disagreement is not automatically misconduct.',
  ]),
  CommunityGuidelineSection('Enforcement', [
    'PadelX may review reported conduct and restrict access when appropriate.',
  ]),
];

List<CommunityGuidelineSection> localizedCommunityGuidelineSections(
  AppLocalizations strings,
) => [
  CommunityGuidelineSection(strings.guidelineAdultsTitle, [
    strings.guidelineAdultsBody,
  ]),
  CommunityGuidelineSection(strings.guidelineRespectTitle, [
    strings.guidelineRespectBody,
  ]),
  CommunityGuidelineSection(strings.guidelineHateTitle, [
    strings.guidelineHateBody,
  ]),
  CommunityGuidelineSection(strings.guidelineSexualTitle, [
    strings.guidelineSexualBody,
  ]),
  CommunityGuidelineSection(strings.guidelineThreatsTitle, [
    strings.guidelineThreatsBody,
  ]),
  CommunityGuidelineSection(strings.guidelineSpamTitle, [
    strings.guidelineSpamBody,
  ]),
  CommunityGuidelineSection(strings.impersonation, [
    strings.guidelineImpersonationBody,
  ]),
  CommunityGuidelineSection(strings.guidelinePrivacyTitle, [
    strings.guidelinePrivacyBody,
  ]),
  CommunityGuidelineSection(strings.guidelineProfilesTitle, [
    strings.guidelineProfilesBody,
  ]),
  CommunityGuidelineSection(strings.guidelineMessagingTitle, [
    strings.guidelineMessagingBody,
  ]),
  CommunityGuidelineSection(strings.guidelineMatchesTitle, [
    strings.guidelineMatchesBody,
  ]),
  CommunityGuidelineSection(strings.guidelineBlockingTitle, [
    strings.guidelineBlockingBody,
  ]),
  CommunityGuidelineSection(strings.guidelineRealWorldTitle, [
    strings.guidelineRealWorldBody,
  ]),
  CommunityGuidelineSection(strings.guidelineReliabilityTitle, [
    strings.guidelineReliabilityBody,
  ]),
  CommunityGuidelineSection(strings.guidelineEnforcementTitle, [
    strings.guidelineEnforcementBody,
  ]),
];

const emergencySafetyGuidance =
    'If you or someone else is in immediate danger, contact local emergency services.';
const notEmergencyServiceGuidance =
    'PadelX reporting and support are not emergency services.';
