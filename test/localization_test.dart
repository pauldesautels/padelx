import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/auth_landing.dart';
import 'package:padelx/auth_language.dart';
import 'package:padelx/l10n/app_localizations.dart';
import 'package:padelx/legal.dart';
import 'package:padelx/level.dart';
import 'package:padelx/locale_controller.dart';
import 'package:padelx/locale_formatting.dart';
import 'package:padelx/reporting.dart';
import 'package:padelx/social_profile.dart';

class _MemoryLocaleStore implements LocalePreferenceStore {
  _MemoryLocaleStore([this.value]);
  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
    writes++;
  }
}

Widget _localizedApp(
  PadelXLocaleController controller,
  Widget child, {
  Size? size,
  double textScale = 1,
}) => PadelXLocaleScope(
  controller: controller,
  child: AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      locale: controller.locale,
      supportedLocales: supportedPadelXLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: size ?? const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  ),
);

void main() {
  group('locale resolution and persistence', () {
    test(
      'Spanish devices resolve to es-MX and unsupported locales to English',
      () {
        expect(
          PadelXLocaleController.resolveSystemLocale(const [
            Locale('es', 'ES'),
          ]),
          const Locale('es', 'MX'),
        );
        expect(
          PadelXLocaleController.resolveSystemLocale(const [Locale('fr')]),
          const Locale('en'),
        );
      },
    );

    test(
      'saved overrides, system mode, and corrupt values resolve safely',
      () async {
        final english = PadelXLocaleController(
          store: _MemoryLocaleStore('en'),
          systemLocales: const [Locale('es')],
        );
        await english.load();
        expect(english.locale, const Locale('en'));

        final spanish = PadelXLocaleController(
          store: _MemoryLocaleStore('es-MX'),
          systemLocales: const [Locale('en')],
        );
        await spanish.load();
        expect(spanish.locale, const Locale('es', 'MX'));

        for (final stored in ['system', 'corrupt-value']) {
          final system = PadelXLocaleController(
            store: _MemoryLocaleStore(stored),
            systemLocales: const [Locale('es', 'AR')],
          );
          await system.load();
          expect(system.preference, PadelXLocalePreference.system);
          expect(system.locale, const Locale('es', 'MX'));
        }
      },
    );

    test('manual choice persists independently of account lifecycle', () async {
      final store = _MemoryLocaleStore();
      final controller = PadelXLocaleController(
        store: store,
        systemLocales: const [Locale('en')],
      );
      await controller.select(PadelXLocalePreference.spanishMexico);
      expect(store.value, 'es-MX');
      expect(store.writes, 1);

      // Authentication, logout, and account switching have no input into the
      // local-only controller. A fresh controller reads the same preference.
      final afterAccountChange = PadelXLocaleController(
        store: store,
        systemLocales: const [Locale('en')],
      );
      await afterAccountChange.load();
      expect(afterAccountChange.locale, const Locale('es', 'MX'));
    });
  });

  testWidgets('English and es-MX roots render generated strings', (
    tester,
  ) async {
    final controller = PadelXLocaleController(
      store: _MemoryLocaleStore('en'),
      systemLocales: const [Locale('en')],
    );
    await controller.load();
    await tester.pumpWidget(
      _localizedApp(controller, AuthLandingScreen(onEmail: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Find your next match.'), findsOneWidget);

    await controller.select(PadelXLocalePreference.spanishMexico);
    await tester.pumpAndSettle();
    expect(find.text('Encuentra tu próximo partido.'), findsOneWidget);
    expect(find.text('Continuar con correo'), findsOneWidget);
  });

  testWidgets('signed-out selector switches immediately and is localized', (
    tester,
  ) async {
    final controller = PadelXLocaleController(
      store: _MemoryLocaleStore('en'),
      systemLocales: const [Locale('en')],
    );
    await controller.load();
    await tester.pumpWidget(
      _localizedApp(controller, AuthLandingScreen(onEmail: () {})),
    );
    await tester.tap(find.byKey(const Key('auth-language-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Choose language'), findsOneWidget);
    await tester.tap(find.byKey(const Key('language-option-es-MX')));
    await tester.pumpAndSettle();
    expect(find.text('Encuentra tu próximo partido.'), findsOneWidget);

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(tooltip.message, 'Cambiar idioma');
  });

  testWidgets('Settings language tile uses the shared selector', (
    tester,
  ) async {
    final controller = PadelXLocaleController(
      store: _MemoryLocaleStore('en'),
      systemLocales: const [Locale('en')],
    );
    await controller.load();
    await tester.pumpWidget(
      _localizedApp(
        controller,
        const Scaffold(body: PadelXLanguageSettingsTile()),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-option-es-MX')));
    await tester.pumpAndSettle();
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Español (México)'), findsOneWidget);
  });

  testWidgets('language controls fit 320pt at 1.6x text scale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = PadelXLocaleController(
      store: _MemoryLocaleStore('es-MX'),
      systemLocales: const [Locale('en')],
    );
    await controller.load();
    await tester.pumpWidget(
      _localizedApp(
        controller,
        AuthLandingScreen(onEmail: () {}),
        size: const Size(320, 568),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-language-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Usar idioma del dispositivo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('ARB files have matching keys, placeholders, and valid generation', () {
    Map<String, dynamic> load(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final english = load('lib/l10n/app_en.arb');
    final spanish = load('lib/l10n/app_es_MX.arb');
    Set<String> messageKeys(Map<String, dynamic> value) =>
        value.keys.where((key) => !key.startsWith('@')).toSet();
    expect(messageKeys(spanish), messageKeys(english));
    for (final key in english.keys.where(
      (key) => key.startsWith('@') && !key.startsWith('@@'),
    )) {
      expect(spanish[key], english[key]);
    }
    expect(
      AppLocalizations.supportedLocales,
      contains(const Locale('es', 'MX')),
    );
  });

  test('interpolation, plurals, and locale-aware formatting work', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final es = await AppLocalizations.delegate.load(const Locale('es', 'MX'));
    expect(en.welcomePlayer('Alex'), 'Welcome, Alex');
    expect(es.welcomePlayer('Alex'), 'Te damos la bienvenida, Alex');
    expect(en.matchCount(1), '1 match');
    expect(es.matchCount(2), '2 partidos');
    final date = DateTime(2026, 9, 14);
    expect(
      formatPadelXFoundationDate(date, const Locale('en')),
      contains('Sep'),
    );
    expect(
      formatPadelXFoundationDate(date, const Locale('es', 'MX')),
      contains('sep'),
    );
    expect(formatPadelXDecimal(1234.5, const Locale('en')), isNotEmpty);
    expect(formatPadelXDecimal(1234.5, const Locale('es', 'MX')), isNotEmpty);
  });

  test('locale switching does not alter canonical backend values', () {
    expect(ReportReason.harassmentBullying.value, 'harassment_bullying');
    expect(PreferredSide.left.value, 'left');
    expect(matchLevelStorageValue('3.5'), 'Level 3.5');
    expect(PadelXLegalConfiguration.beta.termsVersion, 'terms-beta-v1');
    expect(PadelXLegalConfiguration.beta.privacyVersion, 'privacy-beta-v1');
    expect(PadelXLegalConfiguration.beta.communityVersion, 'community-beta-v1');
    expect(firebaseAuthLanguageCode(const Locale('es', 'MX')), 'es');
    expect(firebaseAuthLanguageCode(const Locale('en')), 'en');
  });
}
