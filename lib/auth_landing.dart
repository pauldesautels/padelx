import 'package:flutter/material.dart';

import 'branding.dart';
import 'legal.dart';
import 'l10n/app_localizations.dart';
import 'locale_controller.dart';

class AuthLandingScreen extends StatelessWidget {
  final VoidCallback onEmail;

  const AuthLandingScreen({super.key, required this.onEmail});

  @override
  Widget build(BuildContext context) {
    final localeController = PadelXLocaleScope.maybeOf(context);
    final strings = localeController == null
        ? null
        : AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: padelXBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: ConstrainedBox(
              key: const Key('auth-landing-content'),
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (localeController != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        label: strings!.languageSelectorSemantics,
                        button: true,
                        child: IconButton(
                          key: const Key('auth-language-selector'),
                          tooltip: strings.languageSelectorTooltip,
                          onPressed: () => showPadelXLanguageSelector(context),
                          icon: const Icon(Icons.language),
                        ),
                      ),
                    ),
                  const PadelXBrandMark(size: 104),
                  const SizedBox(height: 8),
                  const PadelXWordmark(),
                  const SizedBox(height: 38),
                  Text(
                    strings?.authHeadline ?? 'Find your next match.',
                    key: const Key('auth-landing-headline'),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings?.authSubtitle ??
                        'Play more padel with players near you.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 34),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      key: const Key('continue-with-email'),
                      onPressed: onEmail,
                      style: FilledButton.styleFrom(
                        backgroundColor: padelXSurface,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.mail_outline),
                      label: Text(
                        strings?.continueWithEmail ?? 'Continue with email',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    key: Key('auth-legal-copy'),
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => openLegalLink(context, '/terms'),
                        child: Text(strings?.termsOfUse ?? 'Terms of Use'),
                      ),
                      TextButton(
                        onPressed: () => openLegalLink(context, '/privacy'),
                        child: Text(strings?.privacyPolicy ?? 'Privacy Policy'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
