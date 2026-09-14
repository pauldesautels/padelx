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
        termsVersion: 'terms-beta-v1',
        privacyVersion: 'privacy-beta-v1',
        communityVersion: 'community-beta-v1',
        baseUrl: 'https://example.test/base/',
      );
      expect(value.uri('/privacy').toString(), 'https://example.test/privacy');
      expect(
        PadelXLegalConfiguration.beta.contactEmail,
        'support.padelx@gmail.com',
      );
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
