import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/legal.dart';
import 'package:padelx/legal_acceptance.dart';

class FakeLegalRepository implements LegalAcceptanceRepository {
  bool accepted;
  int writes = 0;
  final List<String> ids = [];
  FakeLegalRepository({this.accepted = false});
  @override
  Future<bool> getAcceptance() async => accepted;
  @override
  Future<void> recordAcceptance({required String requestId}) async {
    writes++;
    ids.add(requestId);
    accepted = true;
  }
}

void main() {
  test(
    'legal configuration centralizes beta identity versions and safe URLs',
    () {
      const value = PadelXLegalConfiguration(
        productName: 'PadelX',
        operatorName: 'Paul Desautels',
        contactEmail: 'support.padelx@gmail.com',
        termsVersion: 'terms-beta-v2',
        privacyVersion: 'privacy-beta-v2',
        communityVersion: 'community-beta-v2',
        baseUrl: 'https://example.test/base/',
      );
      expect(value.uri('/privacy').toString(), 'https://example.test/privacy');
      expect(
        PadelXLegalConfiguration.beta.contactEmail,
        'support.padelx@gmail.com',
      );
      expect(PadelXLegalConfiguration.beta.termsVersion, 'terms-beta-v2');
      expect(PadelXLegalConfiguration.beta.privacyVersion, 'privacy-beta-v2');
      expect(
        PadelXLegalConfiguration.beta.communityVersion,
        'community-beta-v2',
      );
      expect(
        const PadelXLegalConfiguration(
          productName: 'PadelX',
          operatorName: 'Paul Desautels',
          contactEmail: 'support.padelx@gmail.com',
          termsVersion: 'terms-beta-v2',
          privacyVersion: 'privacy-beta-v2',
          communityVersion: 'community-beta-v2',
          baseUrl: '',
        ).uri('/terms'),
        isNull,
      );
    },
  );

  test('legal base URL is environment-bound and fails closed', () {
    expect(
      legalBaseUrlForEnvironment(
        configuredBaseUrl: '',
        firebaseEnvironment: 'staging',
        firebaseProjectId: 'padelx-staging',
      ),
      stagingLegalBaseUrl,
    );
    expect(
      legalBaseUrlForEnvironment(
        configuredBaseUrl: 'https://padelx-staging.web.app',
        firebaseEnvironment: 'staging',
        firebaseProjectId: 'padelx-staging',
      ),
      stagingLegalBaseUrl,
    );
    for (final unsafe in [
      ('', 'production', 'padelx-f168f'),
      ('https://padelx-staging.web.app', 'production', 'padelx-f168f'),
      ('https://example.test', 'staging', 'padelx-staging'),
      ('', 'staging', 'padelx-f168f'),
    ]) {
      expect(
        legalBaseUrlForEnvironment(
          configuredBaseUrl: unsafe.$1,
          firebaseEnvironment: unsafe.$2,
          firebaseProjectId: unsafe.$3,
        ),
        isEmpty,
      );
    }
    expect(
      legalBaseUrlForEnvironment(
        configuredBaseUrl: 'https://legal.padelx.example',
        firebaseEnvironment: 'production',
        firebaseProjectId: 'padelx-f168f',
      ),
      'https://legal.padelx.example',
    );
  });

  test('all English policy URIs resolve from one configured origin', () {
    const configuration = PadelXLegalConfiguration(
      productName: 'PadelX',
      operatorName: 'Paul Desautels',
      contactEmail: 'support.padelx@gmail.com',
      termsVersion: 'terms-beta-v2',
      privacyVersion: 'privacy-beta-v2',
      communityVersion: 'community-beta-v2',
      baseUrl: 'https://example.test',
    );
    for (final path in [
      '/terms',
      '/privacy',
      '/community-guidelines',
      '/account-deletion',
    ]) {
      expect(configuration.uri(path), Uri.parse('https://example.test$path'));
    }
  });

  testWidgets(
    'acceptance gate exposes every policy represented by the receipt',
    (tester) async {
      final opened = <String>[];
      const configuration = PadelXLegalConfiguration(
        productName: 'PadelX',
        operatorName: 'Paul Desautels',
        contactEmail: 'support.padelx@gmail.com',
        termsVersion: 'terms-beta-v2',
        privacyVersion: 'privacy-beta-v2',
        communityVersion: 'community-beta-v2',
        baseUrl: 'https://example.test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LegalAcceptanceScreen(
            repository: FakeLegalRepository(),
            onAccepted: () async {},
            legalConfiguration: configuration,
            legalLauncher: (uri) async {
              opened.add(uri.path);
              return true;
            },
          ),
        ),
      );

      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Community Guidelines'), findsOneWidget);
      expect(
        find.textContaining('agree to follow the Community Guidelines'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('legal-acceptance-continue')),
            )
            .onPressed,
        isNull,
      );

      for (final label in [
        'Terms of Use',
        'Privacy Policy',
        'Community Guidelines',
      ]) {
        await tester.tap(find.widgetWithText(TextButton, label));
        await tester.pump();
      }
      expect(opened, ['/terms', '/privacy', '/community-guidelines']);
    },
  );

  testWidgets(
    'missing acceptance fails closed and records once after acknowledgement',
    (tester) async {
      final repository = FakeLegalRepository();
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: LegalAcceptanceScreen(
            repository: repository,
            onAccepted: () async => continued = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('legal-acceptance-continue')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('legal-acceptance-checkbox')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('legal-acceptance-continue')));
      await tester.pumpAndSettle();
      expect(repository.writes, 1);
      expect(continued, true);
    },
  );

  testWidgets(
    'existing account records current acceptance and exits after authoritative recheck',
    (tester) async {
      final repository = FakeLegalRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: LegalAcceptanceGate(
            repository: repository,
            acceptedBuilder: (_) => const Scaffold(body: Text('HOME')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Legal acknowledgement'), findsOneWidget);

      await tester.tap(find.byKey(const Key('legal-acceptance-checkbox')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('legal-acceptance-continue')));
      await tester.pumpAndSettle();

      expect(repository.writes, 1);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('Legal acknowledgement'), findsNothing);
    },
  );

  testWidgets('authoritative accepted user passes the legal gate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalAcceptanceGate(
          repository: FakeLegalRepository(accepted: true),
          acceptedBuilder: (_) => const Scaffold(body: Text('HOME')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}
