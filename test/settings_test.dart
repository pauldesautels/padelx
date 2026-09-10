import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/friends.dart';
import 'package:padelx/friends_repository.dart';
import 'package:padelx/main.dart';
import 'package:padelx/account_deletion.dart';
import 'package:padelx/settings_screen.dart';
import 'package:padelx/social_profile.dart';

class _SettingsFriends implements FriendsRepository {
  @override
  Future<BlockedPlayersPage> loadBlockedPlayers({
    Object? cursor,
    int pageSize = 20,
  }) async => const BlockedPlayersPage();
  @override
  Future<void> block(String uid) async {}
  @override
  Future<void> cancel(String uid) async {}
  @override
  Future<FriendsPage> loadPage(
    String viewerUid, {
    required String status,
    FriendDirection? direction,
    Object? cursor,
    int pageSize = 20,
  }) async => const FriendsPage();
  @override
  Future<RelationshipPolicy> policy(String targetUid) async =>
      const RelationshipPolicy();
  @override
  Future<void> remove(String uid) async {}
  @override
  Future<void> requestFriend(String targetUid) async {}
  @override
  Future<void> respond(String requesterUid, bool accept) async {}
  @override
  Future<void> unblock(String uid) async {}
  @override
  Stream<void> watchFriendViews(String viewerUid) => const Stream.empty();
}

void main() {
  testWidgets('Profile exposes Settings without a Delete Account action', (
    tester,
  ) async {
    var opened = false;
    const profile = UserProfile(
      uid: 'viewer',
      displayName: 'Viewer',
      level: '3',
      email: 'viewer@example.com',
      socialProfile: SocialProfileData(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileTab(
          profile: profile,
          uid: 'viewer',
          loader: (_) async => const PublicPlayerProfile(
            uid: 'viewer',
            displayName: 'Viewer',
            level: '3',
            matches: [],
          ),
          onSettings: () => opened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete Account'), findsNothing);
    await tester.tap(find.byKey(const Key('open-settings')));
    expect(opened, true);
  });

  testWidgets('Settings navigates to Account and Delete Account callback', (
    tester,
  ) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          friendsRepository: _SettingsFriends(),
          onDeleteAccount: () => deleted = true,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-account')));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsWidgets);
    await tester.tap(find.byKey(const Key('account-delete-account')));
    expect(deleted, true);
  });

  testWidgets('Settings deletion Back returns to Account without submitting', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: SettingsScreen(
          friendsRepository: _SettingsFriends(),
          onDeleteAccount: () {
            navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (context) => DeleteAccountScreen(
                  onFinished: (_) async {},
                  onCancel: () => Navigator.pop(context),
                  submitDeletion: (_) async => submissions++,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-delete-account')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-submitted');
    await tester.tap(find.byKey(const Key('cancel-account-deletion')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-delete-account')), findsOneWidget);
    expect(submissions, 0);
  });

  testWidgets('Settings Privacy opens Blocked Players', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          friendsRepository: _SettingsFriends(),
          onDeleteAccount: () {},
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-blocked-players')));
    await tester.pumpAndSettle();
    expect(find.text('Blocked Players'), findsOneWidget);
    expect(find.text('You have not blocked any players.'), findsOneWidget);
  });

  testWidgets('Verify Email retains low-prominence account deletion access', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'viewer@example.com',
          resendCooldown: Duration.zero,
          onContinue: () async => false,
          onResend: () async {},
          onSignOut: () async {},
          onDeleteAccount: () => opened = true,
        ),
      ),
    );
    expect(find.text('Delete account'), findsOneWidget);
    await tester.tap(find.byKey(const Key('verification-delete-account')));
    expect(opened, true);
  });

  testWidgets('Verify Email deletion Back returns without submitting', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: EmailVerificationScreen(
          email: 'viewer@example.com',
          resendCooldown: Duration.zero,
          onContinue: () async => false,
          onResend: () async {},
          onSignOut: () async {},
          onDeleteAccount: () {
            navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (context) => DeleteAccountScreen(
                  onFinished: (_) async {},
                  onCancel: () => Navigator.pop(context),
                  submitDeletion: (_) async => submissions++,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('verification-delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-account-deletion')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('verification-delete-account')),
      findsOneWidget,
    );
    expect(submissions, 0);
  });
}
