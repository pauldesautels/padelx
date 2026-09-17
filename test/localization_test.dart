import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/auth_landing.dart';
import 'package:padelx/auth_language.dart';
import 'package:padelx/l10n/app_localizations.dart';
import 'package:padelx/legal.dart';
import 'package:padelx/level.dart';
import 'package:padelx/locale_controller.dart';
import 'package:padelx/locale_formatting.dart';
import 'package:padelx/main.dart' as app;
import 'package:padelx/messaging.dart';
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

  testWidgets(
    'bottom navigation labels stay single-line in English and es-MX',
    (tester) async {
      Future<void> verify({
        required String preference,
        required Size size,
        required double textScale,
        required List<String> labels,
      }) async {
        await tester.binding.setSurfaceSize(size);
        final controller = PadelXLocaleController(
          store: _MemoryLocaleStore(preference),
          systemLocales: const [Locale('en')],
        );
        await controller.load();
        await tester.pumpWidget(
          _localizedApp(
            controller,
            app.PadelXBottomNavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
            size: size,
            textScale: textScale,
          ),
        );
        await tester.pumpAndSettle();

        for (final label in labels) {
          final labelFinder = find.text(label);
          expect(labelFinder, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(labelFinder);
          expect(
            paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: label.length),
            ),
            hasLength(1),
            reason: '$label should remain on one line at $size / $textScale',
          );
        }
        expect(tester.takeException(), isNull);
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
      const english = [
        'Home',
        'Matches',
        'Players',
        'Notifications',
        'Profile',
      ];
      const spanish = [
        'Inicio',
        'Partidos',
        'Jugadores',
        'Notificaciones',
        'Perfil',
      ];

      for (final size in const [Size(390, 844), Size(320, 568)]) {
        await verify(
          preference: 'en',
          size: size,
          textScale: 1,
          labels: english,
        );
        await verify(
          preference: 'es-MX',
          size: size,
          textScale: 1,
          labels: spanish,
        );
        await verify(
          preference: 'en',
          size: size,
          textScale: 1.6,
          labels: english,
        );
        await verify(
          preference: 'es-MX',
          size: size,
          textScale: 1.6,
          labels: spanish,
        );
      }
    },
  );

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

  testWidgets('canonical match time renders in es-MX without leaking ISO', (
    tester,
  ) async {
    final controller = PadelXLocaleController(
      store: _MemoryLocaleStore(),
      systemLocales: const [Locale('es', 'MX')],
    );
    const match = app.Match(
      id: 'localized-time',
      title: '2030-09-12T18:30:00.000Z',
      club: 'Padel Club',
      level: 'Level 3',
      spotsLeft: 0,
      creatorUid: 'creator',
      creatorEmail: '',
      players: [],
      scheduledAt: null,
    );
    final dated = app.Match(
      id: match.id,
      title: match.title,
      club: match.club,
      level: match.level,
      spotsLeft: match.spotsLeft,
      creatorUid: match.creatorUid,
      creatorEmail: match.creatorEmail,
      players: match.players,
      scheduledAt: DateTime(2030, 9, 12, 18, 30),
    );
    await tester.pumpWidget(
      _localizedApp(
        controller,
        app.MatchDetailsSummary(match: dated, completed: false),
      ),
    );
    expect(find.textContaining('sep'), findsOneWidget);
    expect(find.textContaining('2030-09-12T'), findsNothing);
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
    expect(
      app.AppNotificationType.matchmakingMatchFound.storageValue,
      'matchmaking_match_found',
    );
  });

  test(
    'matchmaking notifications localize without storing translated state',
    () async {
      final es = await AppLocalizations.delegate.load(const Locale('es', 'MX'));
      final item = app.AppNotification(
        id: 'safe-notification',
        type: app.AppNotificationType.matchmakingMatchFound,
        recipientUid: 'recipient',
        matchId: '',
        title: 'Match found',
        message: 'A matchmaking offer is ready for your confirmation.',
        read: false,
        createdAt: DateTime.utc(2030),
        eventId: 'proposal',
      );
      expect(app.localizedNotificationTitle(item, es), 'Partido encontrado');
      expect(
        app.localizedNotificationMessage(item, es),
        'Hay una propuesta de partido lista para que la confirmes.',
      );
    },
  );

  test(
    'known notifications localize while unknown notifications keep fallback',
    () async {
      final es = await AppLocalizations.delegate.load(const Locale('es', 'MX'));
      final known = app.AppNotification(
        id: 'n',
        type: app.AppNotificationType.friendRequest,
        recipientUid: 'recipient',
        matchId: '',
        title: 'New friend request',
        message: 'Alex sent you a friend request.',
        read: false,
        createdAt: null,
        eventId: 'event',
        actorDisplayName: 'Alex',
      );
      expect(
        app.localizedNotificationTitle(known, es),
        'Nueva solicitud de amistad',
      );
      expect(app.localizedNotificationMessage(known, es), contains('Alex'));

      final unknown = app.AppNotification(
        id: 'legacy',
        type: app.AppNotificationType.unknown,
        recipientUid: 'recipient',
        matchId: '',
        title: 'Legacy title',
        message: 'Legacy message',
        read: true,
        createdAt: null,
        eventId: '',
      );
      expect(app.localizedNotificationTitle(unknown, es), 'Legacy title');
      expect(app.localizedNotificationMessage(unknown, es), 'Legacy message');
    },
  );

  test(
    'es-MX dates and report labels are localized without changing values',
    () async {
      final es = await AppLocalizations.delegate.load(const Locale('es', 'MX'));
      final date = DateTime(2030, 9, 18, 17, 30);
      expect(
        messagingDateSeparator(
          date,
          now: DateTime(2030, 9, 20),
          locale: const Locale('es', 'MX'),
          todayLabel: es.today,
          yesterdayLabel: es.yesterday,
        ),
        contains('sep'),
      );
      expect(es.harassmentBullying, 'Acoso o intimidación');
      expect(ReportReason.harassmentBullying.value, 'harassment_bullying');
    },
  );

  testWidgets('Spanish locale routes legal links to parallel es-MX pages', (
    tester,
  ) async {
    final controller = PadelXLocaleController(
      store: _MemoryLocaleStore('es-MX'),
      systemLocales: const [Locale('en')],
    );
    await controller.load();
    Uri? opened;
    await tester.pumpWidget(
      _localizedApp(
        controller,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openLegalLink(
              context,
              '/privacy',
              configuration: const PadelXLegalConfiguration(
                productName: 'PadelX',
                operatorName: 'Paul Desautels',
                contactEmail: 'support.padelx@gmail.com',
                termsVersion: 'terms-beta-v1',
                privacyVersion: 'privacy-beta-v1',
                communityVersion: 'community-beta-v1',
                baseUrl: 'https://example.test',
              ),
              launcher: (uri) async {
                opened = uri;
                return true;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(opened?.path, '/es-MX/privacy');
  });

  test(
    'platform and legal locale artifacts advertise only supported locales',
    () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<string>es-MX</string>'));
      expect(
        File('ios/Runner/en.lproj/InfoPlist.strings').existsSync(),
        isTrue,
      );
      expect(
        File('ios/Runner/es-MX.lproj/InfoPlist.strings').existsSync(),
        isTrue,
      );
      expect(
        File('android/app/src/main/res/values-es-rMX/strings.xml').existsSync(),
        isTrue,
      );
      for (final page in const [
        'privacy',
        'terms',
        'community-guidelines',
        'account-deletion',
      ]) {
        final spanish = File('web/es-MX/$page/index.html').readAsStringSync();
        expect(spanish, contains('lang="es-MX"'));
        expect(spanish, contains('Paul Desautels'));
        expect(spanish, contains('support.padelx@gmail.com'));
        expect(spanish, contains('href="/$page">English</a>'));
      }
    },
  );
}
