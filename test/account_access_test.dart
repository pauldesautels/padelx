import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:padelx/account_access.dart';

class FakeAccessRepository implements AccountAccessRepository {
  FakeAccessRepository(this.states);
  final List<Object> states;
  int calls = 0;

  @override
  Future<AccountAccessState> load() async {
    final value = states[calls.clamp(0, states.length - 1)];
    calls++;
    if (value is Exception) throw value;
    return value as AccountAccessState;
  }
}

Widget app({
  required FakeAccessRepository repository,
  String uid = 'account-a',
  VoidCallback? onDelete,
  Future<void> Function()? onSignOut,
}) => MaterialApp(
  home: AccountAccessGate(
    uid: uid,
    repository: repository,
    allowedBuilder: (_) => const Scaffold(body: Text('NORMAL APP')),
    onDeleteAccount: onDelete ?? () {},
    onSignOut: onSignOut ?? () async {},
    supportLauncher: (_) async => true,
  ),
);

void main() {
  testWidgets('normal user passes through account access gate', (tester) async {
    final repository = FakeAccessRepository([
      const AccountAccessState(restricted: false),
    ]);
    await tester.pumpWidget(app(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('NORMAL APP'), findsOneWidget);
  });

  testWidgets('suspended shell is sanitized and retains safe actions', (
    tester,
  ) async {
    var deleted = false;
    var signedOut = false;
    final repository = FakeAccessRepository([
      AccountAccessState(
        restricted: true,
        status: 'suspended',
        reasonCategory: 'harassment_abuse',
        expiresAt: DateTime(2099, 1, 2),
      ),
    ]);
    await tester.pumpWidget(
      app(
        repository: repository,
        onDelete: () => deleted = true,
        onSignOut: () async => signedOut = true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account temporarily suspended'), findsOneWidget);
    expect(find.text('Harassment or abusive conduct'), findsOneWidget);
    expect(find.text('Restriction ends'), findsOneWidget);
    expect(find.textContaining('reporter'), findsNothing);
    await tester.tap(find.text('Delete Account'));
    expect(deleted, true);
    await tester.tap(find.text('Sign Out'));
    expect(signedOut, true);
  });

  testWidgets('banned shell omits expiry and can contact support', (
    tester,
  ) async {
    final repository = FakeAccessRepository([
      const AccountAccessState(
        restricted: true,
        status: 'banned',
        reasonCategory: 'privacy_violation',
      ),
    ]);
    await tester.pumpWidget(app(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Account restricted'), findsOneWidget);
    expect(find.text('Privacy violation'), findsOneWidget);
    expect(find.text('Restriction ends'), findsNothing);
    await tester.tap(find.text('Contact PadelX Support'));
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('retry leaves expired restriction without logout', (
    tester,
  ) async {
    final repository = FakeAccessRepository([
      AccountAccessState(
        restricted: true,
        status: 'suspended',
        reasonCategory: 'other_policy_violation',
        expiresAt: DateTime(2099),
      ),
      const AccountAccessState(restricted: false),
    ]);
    await tester.pumpWidget(app(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check access again'));
    await tester.pumpAndSettle();
    expect(find.text('NORMAL APP'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('canonical callable denial refreshes mounted access gate', (
    tester,
  ) async {
    final repository = FakeAccessRepository([
      const AccountAccessState(restricted: false),
      const AccountAccessState(restricted: true, status: 'banned'),
    ]);
    await tester.pumpWidget(app(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('NORMAL APP'), findsOneWidget);
    signalAccountAccessRestriction(
      FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Account access is restricted.',
        details: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account restricted'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('access lookup fails closed and remains retryable', (
    tester,
  ) async {
    final repository = FakeAccessRepository([
      StateError('private failure'),
      const AccountAccessState(restricted: false),
    ]);
    await tester.pumpWidget(app(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Could not verify account access.'), findsOneWidget);
    expect(find.textContaining('private failure'), findsNothing);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('NORMAL APP'), findsOneWidget);
  });

  testWidgets('UID change discards prior account state', (tester) async {
    final restricted = FakeAccessRepository([
      const AccountAccessState(restricted: true, status: 'banned'),
    ]);
    await tester.pumpWidget(app(repository: restricted));
    await tester.pumpAndSettle();
    expect(find.text('Account restricted'), findsOneWidget);
    final allowed = FakeAccessRepository([
      const AccountAccessState(restricted: false),
    ]);
    await tester.pumpWidget(app(repository: allowed, uid: 'account-b'));
    await tester.pumpAndSettle();
    expect(find.text('NORMAL APP'), findsOneWidget);
  });

  testWidgets('restricted shell remains usable at narrow large text size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeAccessRepository([
      AccountAccessState(
        restricted: true,
        status: 'suspended',
        expiresAt: DateTime(2099),
      ),
    ]);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: app(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Contact PadelX Support'), findsOneWidget);
  });
}
