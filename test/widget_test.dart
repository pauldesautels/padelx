import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:padelx/current_location.dart';
import 'package:padelx/location.dart';
import 'package:padelx/main.dart';

void main() {
  testWidgets('password reset sends email and shows confirmation', (
    WidgetTester tester,
  ) async {
    String? requestedEmail;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          passwordResetSender: (email) async {
            requestedEmail = email;
          },
        ),
      ),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'player@example.com',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pumpAndSettle();

    expect(requestedEmail, 'player@example.com');
    expect(
      find.text('Password reset email sent. Check your inbox.'),
      findsOneWidget,
    );
  });

  testWidgets('password reset requires an email address', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(passwordResetSender: (_) async {})),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send reset email'));
    await tester.pump();

    expect(find.text('Please enter your email address.'), findsOneWidget);
  });

  testWidgets('password reset shows a clean Firebase error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          passwordResetSender: (_) async {
            throw FirebaseAuthException(code: 'invalid-email');
          },
        ),
      ),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'not-an-email',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pump();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
  });

  testWidgets('create match form requires all fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateMatchScreen()));

    expect(find.text('Set up a new game'), findsOneWidget);
    expect(find.text('Create Match'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create-match-submit')).first);
    await tester.pump();

    expect(find.text('Please fill in all fields'), findsOneWidget);
  });

  testWidgets('my matches distinguishes organizing and joined matches', (
    WidgetTester tester,
  ) async {
    final organizingMatch = Match(
      id: 'organizing',
      title: 'Friday · 6:00 PM',
      club: 'Padel Club',
      level: 'Level 3–4',
      spotsLeft: 2,
      creatorUid: 'current-user',
      creatorEmail: 'organizer@example.com',
      players: [],
      scheduledAt: DateTime.now().add(const Duration(days: 1)),
    );
    final joinedMatch = Match(
      id: 'joined',
      title: 'Saturday · 10:00 AM',
      club: 'Central Padel',
      level: 'Level 2–3',
      spotsLeft: 1,
      creatorUid: 'another-user',
      creatorEmail: 'other@example.com',
      players: [MatchPlayer(uid: 'current-user', email: 'player@example.com')],
      scheduledAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [organizingMatch, joinedMatch],
            currentUid: 'current-user',
            isLoading: false,
            error: false,
          ),
        ),
      ),
    );

    expect(find.text('Organizing'), findsOneWidget);
    expect(find.text('Joined'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Friday · 6:00 PM'), findsOneWidget);
    expect(find.text('Central Padel'), findsOneWidget);
    expect(find.text('1 spot left'), findsOneWidget);
  });

  testWidgets('open matches hides past matches and orders future matches', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final matches = [
      Match(
        id: 'later',
        title: 'Later',
        club: 'Club',
        level: 'Level 3',
        spotsLeft: 2,
        creatorUid: 'one',
        creatorEmail: 'one@example.com',
        players: const [],
        scheduledAt: now.add(const Duration(days: 2)),
      ),
      Match(
        id: 'past',
        title: 'Past match',
        club: 'Club',
        level: 'Level 3',
        spotsLeft: 2,
        creatorUid: 'one',
        creatorEmail: 'one@example.com',
        players: const [],
        scheduledAt: now.subtract(const Duration(days: 1)),
      ),
      Match(
        id: 'sooner',
        title: 'Sooner',
        club: 'Club',
        level: 'Level 3',
        spotsLeft: 2,
        creatorUid: 'one',
        creatorEmail: 'one@example.com',
        players: const [],
        scheduledAt: now.add(const Duration(days: 1)),
      ),
    ];
    final openMatches = sortedMatches(
      matches.where((match) => !isPastMatch(match, now)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesTab(
            matches: openMatches,
            isLoading: false,
            error: false,
          ),
        ),
      ),
    );

    expect(find.text('Past match'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Sooner')).dy,
      lessThan(tester.getTopLeft(find.text('Later')).dy),
    );
  });

  testWidgets('open matches search filters by club or location immediately', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [
      _match(id: 'one', club: 'Roma Padel Center'),
      _match(id: 'two', club: 'Polanco Courts'),
    ]);

    await tester.enterText(find.byKey(const Key('match-search-field')), 'roma');
    await tester.pump();

    expect(find.text('Roma Padel Center'), findsOneWidget);
    expect(find.text('Polanco Courts'), findsNothing);
  });

  testWidgets('open matches date filters handle today tomorrow and this week', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final today = now.add(const Duration(minutes: 1));
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 12);
    final nextWeek = DateTime(
      now.year,
      now.month,
      now.day + (8 - now.weekday),
      12,
    );
    await _pumpMatches(tester, [
      _match(id: 'today', club: 'Today Club', scheduledAt: today),
      _match(id: 'tomorrow', club: 'Tomorrow Club', scheduledAt: tomorrow),
      _match(id: 'next-week', club: 'Next Week Club', scheduledAt: nextWeek),
    ]);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Today'));
    await tester.pump();
    expect(find.text('Today Club'), findsOneWidget);
    expect(find.text('Tomorrow Club'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow'));
    await tester.pump();
    expect(find.text('Tomorrow Club'), findsOneWidget);
    expect(find.text('Today Club'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'This Week'));
    await tester.pump();
    expect(find.text('Today Club'), findsOneWidget);
    expect(find.text('Next Week Club'), findsNothing);
  });

  testWidgets('open matches filters by player level', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [
      _match(id: 'beginner', club: 'Beginner Club', level: 'Level 1'),
      _match(id: 'advanced', club: 'Advanced Club', level: 'Level 4'),
    ]);

    await tester.tap(find.byKey(const Key('level-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 4').last);
    await tester.pumpAndSettle();

    expect(find.text('Advanced Club'), findsOneWidget);
    expect(find.text('Beginner Club'), findsNothing);
  });

  testWidgets('open matches can show only matches with available spots', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [
      _match(id: 'open', club: 'Open Club', spotsLeft: 1),
      _match(id: 'full', club: 'Full Club', spotsLeft: 0),
    ]);

    await tester.tap(find.byKey(const Key('available-spots-filter')));
    await tester.pump();

    expect(find.text('Open Club'), findsOneWidget);
    expect(find.text('Full Club'), findsNothing);
  });

  testWidgets('open matches combines filters and clear restores all matches', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [
      _match(id: 'target', club: 'Roma Padel', level: 'Level 3', spotsLeft: 2),
      _match(
        id: 'wrong-level',
        club: 'Roma Courts',
        level: 'Level 2',
        spotsLeft: 2,
      ),
      _match(id: 'full', club: 'Roma Arena', level: 'Level 3', spotsLeft: 0),
    ]);

    await tester.enterText(find.byKey(const Key('match-search-field')), 'roma');
    await tester.tap(find.byKey(const Key('level-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('available-spots-filter')));
    await tester.pump();

    expect(find.text('Roma Padel'), findsOneWidget);
    expect(find.text('Roma Courts'), findsNothing);
    expect(find.text('Roma Arena'), findsNothing);

    await tester.tap(find.byKey(const Key('clear-match-filters')));
    await tester.pump();
    expect(find.text('Roma Padel'), findsOneWidget);
    expect(find.text('Roma Courts'), findsOneWidget);
    expect(find.text('Roma Arena'), findsOneWidget);
  });

  testWidgets('open matches shows empty results with a reset option', (
    WidgetTester tester,
  ) async {
    await _pumpMatches(tester, [_match(id: 'one', club: 'Roma Padel')]);

    await tester.enterText(
      find.byKey(const Key('match-search-field')),
      'missing',
    );
    await tester.pump();
    expect(find.text('No matches found'), findsOneWidget);
    expect(find.text('Reset filters'), findsOneWidget);

    await tester.tap(find.text('Reset filters'));
    await tester.pump();
    expect(find.text('Roma Padel'), findsOneWidget);
    expect(find.text('No matches found'), findsNothing);
  });

  testWidgets('current location applies the default 25 km radius', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now().add(const Duration(days: 1));
    Match locatedMatch(String id, double longitude) => Match(
      id: id,
      title: id,
      club: '$id club',
      level: 'Level 3',
      spotsLeft: 2,
      creatorUid: 'creator',
      creatorEmail: 'creator@example.com',
      players: const [],
      scheduledAt: now,
      location: MatchLocation(
        clubName: '$id club',
        countryCode: 'MX',
        country: 'Mexico',
        region: '',
        city: 'Test City',
        latitude: 0,
        longitude: longitude,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesTab(
            matches: [locatedMatch('near', 0.1), locatedMatch('far', 0.3)],
            isLoading: false,
            error: false,
            currentLocationProvider: const _FakeCurrentLocationProvider(
              coordinates: CurrentCoordinates(latitude: 0, longitude: 0),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('use-current-location')));
    await tester.pumpAndSettle();

    expect(find.text('Current location · 25 km radius'), findsOneWidget);
    expect(find.text('near club'), findsOneWidget);
    expect(find.text('far club'), findsNothing);
    expect(find.textContaining('km away'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '25 km'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '50 km'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '100 km'), findsOneWidget);
  });

  testWidgets('location denial keeps matches and manual discovery available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesTab(
            matches: [_match(id: 'one', club: 'Manual Search Club')],
            isLoading: false,
            error: false,
            currentLocationProvider: const _FakeCurrentLocationProvider(
              error: CurrentLocationError.permissionDenied,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('use-current-location')));
    await tester.pumpAndSettle();

    expect(find.text('Manual Search Club'), findsOneWidget);
    expect(find.byKey(const Key('use-current-location')), findsOneWidget);
    expect(find.byKey(const Key('current-location-error')), findsOneWidget);
    expect(find.textContaining('search for a location manually'), findsWidgets);
  });

  test('legacy matches without a timestamp remain upcoming', () {
    const legacyMatch = Match(
      id: 'legacy',
      title: 'Friday · 6:00 PM',
      club: 'Club',
      level: 'Level 3',
      spotsLeft: 2,
      creatorUid: 'one',
      creatorEmail: 'one@example.com',
      players: [],
    );

    expect(isPastMatch(legacyMatch, DateTime.now()), isFalse);
  });

  testWidgets('my matches shows empty and error states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [],
            currentUid: 'current-user',
            isLoading: false,
            error: false,
          ),
        ),
      ),
    );
    expect(find.text('You have no matches yet'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: [],
            currentUid: 'current-user',
            isLoading: false,
            error: true,
          ),
        ),
      ),
    );
    expect(find.text('Could not load your matches.'), findsOneWidget);
  });

  test(
    'requesting to join creates a pending request without adding a player',
    () {
      const request = JoinRequest(
        userId: 'player',
        displayName: 'Ana',
        level: 'Level 3',
        email: 'ana@example.com',
        status: 'pending',
      );
      validateJoinRequest({'players': <Map<String, dynamic>>[]}, null, request);

      final document = request.toMap();
      expect(document['userId'], 'player');
      expect(document['status'], 'pending');
    },
  );

  test('a duplicate pending join request is rejected', () {
    expect(
      () => validateJoinRequest(
        {'players': <Map<String, dynamic>>[]},
        {'userId': 'player', 'status': 'pending'},
        const JoinRequest(
          userId: 'player',
          displayName: 'Ana',
          level: 'Level 3',
          email: 'ana@example.com',
          status: 'pending',
        ),
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  test('an approved requester cannot submit another request', () {
    expect(
      () => validateJoinRequest(
        {'players': <Map<String, dynamic>>[]},
        {'userId': 'player', 'status': 'approved'},
        const JoinRequest(
          userId: 'player',
          displayName: 'Ana',
          level: 'Level 3',
          email: 'ana@example.com',
          status: 'pending',
        ),
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  test('legacy player maps using userId are recognized as confirmed', () {
    final player = MatchPlayer.fromMap({
      'userId': 'legacy-player',
      'email': 'legacy@example.com',
    });

    expect(player.uid, 'legacy-player');
    expect(
      () => validateJoinRequest(
        {
          'players': [
            {'userId': 'legacy-player', 'email': 'legacy@example.com'},
          ],
        },
        null,
        const JoinRequest(
          userId: 'legacy-player',
          displayName: 'Legacy Player',
          level: 'Level 2',
          email: 'legacy@example.com',
          status: 'pending',
        ),
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  test('legacy createdBy fields resolve to the organizer identity', () {
    final data = {
      'createdBy': 'rwW6TOBywxYII1Zeee7Bc1cTzzC3',
      'createdByEmail': 'pauldesautels@hotmail.com',
    };

    expect(matchCreatorUid(data), 'rwW6TOBywxYII1Zeee7Bc1cTzzC3');
    expect(matchCreatorEmail(data), 'pauldesautels@hotmail.com');
    expect(
      isOrganizerIdentity(
        data,
        'rwW6TOBywxYII1Zeee7Bc1cTzzC3',
        'pauldesautels@hotmail.com',
      ),
      isTrue,
    );
    expect(
      isOrganizerIdentity(data, 'different-user', 'other@example.com'),
      isFalse,
    );
  });

  test('join request creates one deterministic organizer notification', () {
    final data = buildJoinRequestNotification(
      recipientUid: 'organizer',
      matchId: 'match-1',
      eventId: 'event-1',
      actorUid: 'player',
      actorDisplayName: 'Ana',
    );

    expect(data['recipientUid'], 'organizer');
    expect(data['message'], 'Ana requested to join your match.');
    expect(data['read'], isFalse);
    expect(data['createdAt'], isA<FieldValue>());
    expect(
      notificationDocumentId(
        AppNotificationType.joinRequest,
        'match-1',
        'event-1',
      ),
      notificationDocumentId(
        AppNotificationType.joinRequest,
        'match-1',
        'event-1',
      ),
    );
  });

  test('approval and decline notifications contain the match club', () {
    final approved = buildReviewNotification(
      approve: true,
      recipientUid: 'player',
      matchId: 'match-1',
      club: 'Roma Padel',
      eventId: 'event-1',
      actorUid: 'organizer',
    );
    final declined = buildReviewNotification(
      approve: false,
      recipientUid: 'player',
      matchId: 'match-1',
      club: 'Roma Padel',
      eventId: 'event-1',
      actorUid: 'organizer',
    );

    expect(
      approved['message'],
      'Your request to join the match at Roma Padel was approved.',
    );
    expect(
      declined['message'],
      'Your request to join the match at Roma Padel was declined.',
    );
  });

  test('notification ownership denies another user', () {
    expect(canReadNotification('recipient', 'recipient'), isTrue);
    expect(canReadNotification('another-user', 'recipient'), isFalse);
    expect(canReadNotification('', 'recipient'), isFalse);
  });

  test('unread notification count ignores read items', () {
    expect(
      unreadNotificationCount([
        _notification(id: 'one'),
        _notification(id: 'two', read: true),
        _notification(id: 'three'),
      ]),
      2,
    );
  });

  testWidgets('notifications show empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: const [],
            isLoading: false,
            error: false,
            onMarkRead: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('unread notification can be marked read', (
    WidgetTester tester,
  ) async {
    AppNotification? markedRead;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(
            notifications: [_notification(id: 'one')],
            isLoading: false,
            error: false,
            onMarkRead: (notification) => markedRead = notification,
            onOpen: (_) {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Mark as read'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as read'));
    expect(markedRead?.id, 'one');
  });

  testWidgets('notification badge displays unread count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NotificationBadge(count: 3))),
    );

    expect(find.text('3'), findsOneWidget);
  });

  test('a declined player can submit a new pending request', () {
    expect(
      () => validateJoinRequest(
        {'players': <Map<String, dynamic>>[]},
        {'userId': 'player', 'status': 'declined'},
        const JoinRequest(
          userId: 'player',
          displayName: 'Ana',
          level: 'Level 3',
          email: 'ana@example.com',
          status: 'pending',
        ),
      ),
      returnsNormally,
    );
  });

  test('match participation state restores persisted request status', () {
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: true,
        requestStatus: 'pending',
      ),
      MatchParticipationState.confirmed,
    );
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
        requestStatus: 'pending',
      ),
      MatchParticipationState.pending,
    );
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
        requestStatus: 'declined',
      ),
      MatchParticipationState.available,
    );
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
      ),
      MatchParticipationState.available,
    );
    expect(
      resolveMatchParticipationState(
        isOrganizer: true,
        isConfirmedPlayer: false,
        requestStatus: 'pending',
      ),
      MatchParticipationState.organizer,
    );
  });

  test(
    'leave refresh makes live membership authoritative for button state',
    () {
      final beforeLeave = resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: true,
        requestStatus: 'approved',
      );
      final afterLeave = resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
        requestStatus: 'declined',
      );

      expect(
        matchParticipationButtonLabel(beforeLeave, spotsLeft: 1),
        'Leave Match',
      );
      expect(
        matchParticipationButtonLabel(afterLeave, spotsLeft: 2),
        'Request to Join',
      );
    },
  );

  test('approved request alone does not create stale confirmed membership', () {
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: false,
        requestStatus: 'approved',
      ),
      MatchParticipationState.available,
    );
  });

  test('pending request and organizer button behavior remain unchanged', () {
    expect(
      matchParticipationButtonLabel(
        resolveMatchParticipationState(
          isOrganizer: false,
          isConfirmedPlayer: false,
          requestStatus: 'pending',
        ),
        spotsLeft: 2,
      ),
      'Request Pending',
    );
    expect(
      matchParticipationButtonLabel(
        resolveMatchParticipationState(
          isOrganizer: true,
          isConfirmedPlayer: false,
          requestStatus: 'pending',
        ),
        spotsLeft: 2,
      ),
      'Cancel Match',
    );
  });

  testWidgets('organizer sees pending requests and can approve or decline', (
    WidgetTester tester,
  ) async {
    const request = JoinRequest(
      userId: 'player',
      displayName: 'Ana Player',
      level: 'Level 3',
      email: 'ana@example.com',
      status: 'pending',
    );
    bool approved = false;
    bool declined = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JoinRequestsSection(
            requests: const [request],
            onApprove: (_) => approved = true,
            onDecline: (_) => declined = true,
          ),
        ),
      ),
    );

    expect(find.text('Join Requests'), findsOneWidget);
    expect(find.text('Ana Player'), findsOneWidget);
    expect(find.text('Level 3'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    expect(approved, isTrue);
    await tester.tap(find.text('Decline'));
    expect(declined, isTrue);
  });

  testWidgets(
    'organizer request section shows loading empty and error states',
    (WidgetTester tester) async {
      Widget section({bool loading = false, String? errorMessage}) {
        return MaterialApp(
          home: Scaffold(
            body: JoinRequestsSection(
              requests: const [],
              loading: loading,
              errorMessage: errorMessage,
              onApprove: (_) {},
              onDecline: (_) {},
            ),
          ),
        );
      }

      await tester.pumpWidget(section(loading: true));
      expect(find.text('Loading join requests...'), findsOneWidget);
      expect(find.text('No pending requests.'), findsNothing);

      await tester.pumpWidget(section());
      expect(find.text('No pending requests.'), findsOneWidget);

      await tester.pumpWidget(
        section(errorMessage: 'Permission denied while loading join requests.'),
      );
      expect(
        find.text('Permission denied while loading join requests.'),
        findsOneWidget,
      );
      expect(find.text('No pending requests.'), findsNothing);
    },
  );

  test('approving adds one confirmed player and updates capacity', () {
    final update = buildReviewRequestUpdate(
      {'spotsLeft': 2, 'players': <Map<String, dynamic>>[]},
      {
        'userId': 'player',
        'displayName': 'Ana',
        'level': 'Level 3',
        'email': 'ana@example.com',
        'status': 'pending',
      },
    );

    expect((update['players'] as List), hasLength(1));
    expect(update['spotsLeft'], 1);
    expect(buildRequestStatusUpdate({'status': 'pending'}, approve: true), {
      'status': 'approved',
    });
  });

  test(
    'approval normalizes a legacy match without players and string spots',
    () {
      final update = buildReviewRequestUpdate(
        {'spotsLeft': '2 spots left'},
        {
          'userId': 'player',
          'displayName': 'Ana',
          'level': 'Level 3',
          'email': 'ana@example.com',
          'status': 'pending',
        },
      );

      expect(update['spotsLeft'], 1);
      expect((update['players'] as List).single['uid'], 'player');
    },
  );

  test(
    'approval preserves legacy organizer fields and appends a clean player',
    () {
      final joinedAt = Timestamp.fromDate(DateTime.utc(2026, 5, 8));
      final update = buildReviewRequestUpdate(
        {
          'spotsLeft': 2,
          'players': [
            {
              'uid': 'organizer',
              'email': 'organizer@example.com',
              'role': 'Player',
              'joinedAt': joinedAt,
              'legacyMetadata': {
                'clubs': ['Polanco'],
              },
            },
          ],
        },
        {
          'userId': 'requester',
          'displayName': 'Paul2',
          'level': '2',
          'email': 'requester@example.com',
          'status': 'pending',
        },
      );

      final players = update['players'] as List;
      expect(players.first['role'], 'Player');
      expect(players.first['joinedAt'], same(joinedAt));
      expect(players.first['legacyMetadata'], {
        'clubs': ['Polanco'],
      });
      expect(players.first, isA<Map<String, dynamic>>());
      expect(players.first['legacyMetadata'], isA<Map<String, dynamic>>());
      expect(
        (players.first['legacyMetadata'] as Map)['clubs'],
        isA<List<dynamic>>(),
      );
      expect((players.last as Map).keys, {
        'uid',
        'email',
        'displayName',
        'level',
      });
      expect(update['spotsLeft'], 1);
    },
  );

  test('legacy player normalization rejects non-Firestore values', () {
    expect(
      () => normalizeLegacyPlayers([
        {'uid': 'organizer', 'unsupported': Object()},
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('declining changes status without adding a confirmed player', () {
    final update = buildRequestStatusUpdate({
      'userId': 'player',
      'status': 'pending',
    }, approve: false);

    expect(update, {'status': 'declined'});
  });

  test('approval is rejected when the four-person match is full', () {
    expect(
      () => buildReviewRequestUpdate(
        {
          'spotsLeft': 1,
          'players': [
            {'uid': 'one'},
            {'uid': 'two'},
            {'uid': 'three'},
          ],
        },
        {'userId': 'four', 'status': 'pending'},
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  test('approval cannot create duplicate participation', () {
    expect(
      () => buildReviewRequestUpdate(
        {
          'spotsLeft': 2,
          'players': [
            {'uid': 'player'},
          ],
        },
        {'userId': 'player', 'status': 'pending'},
      ),
      throwsA(isA<MatchActionException>()),
    );
  });

  testWidgets('pending requests are separate from joined matches', (
    WidgetTester tester,
  ) async {
    final pending = _match(id: 'pending', club: 'Pending Club');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyMatchesTab(
            matches: const [],
            pendingMatches: [pending],
            currentUid: 'player',
            isLoading: false,
            error: false,
          ),
        ),
      ),
    );

    expect(find.text('Pending Requests'), findsOneWidget);
    expect(find.text('Request Pending'), findsOneWidget);
    expect(find.text('Joined'), findsNothing);
  });
}

Match _match({
  required String id,
  required String club,
  String level = 'Level 3',
  int spotsLeft = 2,
  DateTime? scheduledAt,
}) {
  return Match(
    id: id,
    title: 'Match $id',
    club: club,
    level: level,
    spotsLeft: spotsLeft,
    creatorUid: 'creator',
    creatorEmail: 'creator@example.com',
    players: const [],
    scheduledAt: scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
  );
}

Future<void> _pumpMatches(WidgetTester tester, List<Match> matches) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MatchesTab(matches: matches, isLoading: false, error: false),
      ),
    ),
  );
}

AppNotification _notification({required String id, bool read = false}) {
  return AppNotification(
    id: id,
    type: AppNotificationType.joinRequest,
    recipientUid: 'recipient',
    matchId: 'match-1',
    title: 'New join request',
    message: 'Ana requested to join your match.',
    read: read,
    createdAt: DateTime.utc(2026, 8, 26),
    eventId: 'event-$id',
    actorUid: 'player',
    actorDisplayName: 'Ana',
  );
}

class _FakeCurrentLocationProvider implements CurrentLocationProvider {
  final CurrentCoordinates? coordinates;
  final CurrentLocationError? error;

  const _FakeCurrentLocationProvider({this.coordinates, this.error});

  @override
  Future<CurrentCoordinates> getCurrentLocation() async {
    if (error != null) throw CurrentLocationException(error!);
    return coordinates!;
  }
}
