import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/friends.dart';
import 'package:padelx/friends_repository.dart';
import 'package:padelx/l10n/app_localizations.dart';
import 'package:padelx/location.dart';
import 'package:padelx/main.dart' show MatchAutoFillCard;
import 'package:padelx/matchmaking_repository.dart';
import 'package:padelx/matchmaking_screen.dart';
import 'package:padelx/places.dart';
import 'package:padelx/push_notifications.dart';

class _PushSettings implements PushSettingsService {
  _PushSettings(this.enabled);
  final bool enabled;
  @override
  Future<void> disable(String uid) async {}
  @override
  Future<PushPermissionState> enable(String uid) async =>
      PushPermissionState.allowed;
  @override
  Future<bool> isDeliveryEnabled(String uid) async => enabled;
  @override
  Future<PushPermissionState> permissionState() async =>
      enabled ? PushPermissionState.allowed : PushPermissionState.denied;
}

class _MatchmakingRepository implements MatchmakingRepository {
  MatchmakingState current;
  final invalidations = StreamController<void>.broadcast();
  final actions = <String>[];
  MatchmakingVenueInput? resolvedVenue;
  _MatchmakingRepository(this.current);
  @override
  Future<Map<String, dynamic>> create(MatchmakingRequestInput input) async {
    actions.add('create:${input.mode.storageValue}');
    return const {};
  }

  @override
  Future<void> cancel(String requestId) async => actions.add('cancel');
  @override
  Future<void> respondToPartner(
    String requestId, {
    required bool accept,
  }) async => actions.add('partner:$accept');
  @override
  Future<void> respondToProposal(
    String proposalId, {
    required bool accept,
    required String requestId,
  }) async => actions.add('proposal:$accept');
  @override
  Future<MatchmakingState> state() async => current;
  @override
  Future<String> resolveVenue(
    String proposalId,
    String requestId,
    MatchmakingVenueInput venue,
  ) async {
    resolvedVenue = venue;
    return 'match-id';
  }

  @override
  Stream<void> watchStateInvalidations(String uid) => invalidations.stream;
}

class _FriendsRepository implements FriendsRepository {
  @override
  Future<FriendsPage> loadPage(
    String viewerUid, {
    required String status,
    FriendDirection? direction,
    Object? cursor,
    int pageSize = 20,
  }) async => const FriendsPage();
  @override
  Stream<void> watchFriendViews(String viewerUid) => const Stream.empty();
  @override
  Future<BlockedPlayersPage> loadBlockedPlayers({
    Object? cursor,
    int pageSize = 20,
  }) => throw UnimplementedError();
  @override
  Future<RelationshipPolicy> policy(String targetUid) =>
      throw UnimplementedError();
  @override
  Future<void> requestFriend(String targetUid) => throw UnimplementedError();
  @override
  Future<void> respond(String requesterUid, bool accept) =>
      throw UnimplementedError();
  @override
  Future<void> cancel(String targetUid) => throw UnimplementedError();
  @override
  Future<void> remove(String targetUid) => throw UnimplementedError();
  @override
  Future<void> block(String targetUid) => throw UnimplementedError();
  @override
  Future<void> unblock(String targetUid) => throw UnimplementedError();
}

class _VenuePlacesClient extends GooglePlacesClient {
  int padelSearches = 0;
  int genericSearches = 0;
  final double latitude;
  final double longitude;
  _VenuePlacesClient({this.latitude = 19.4328, this.longitude = -99.133})
    : super(apiKey: 'test-key');

  @override
  Future<List<PlacePrediction>> searchPadelVenues(
    String query, {
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
  }) async {
    padelSearches++;
    return const [
      PlacePrediction(placeId: 'padel-place', label: 'Central Padel Club'),
    ];
  }

  @override
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    required String sessionToken,
    bool citiesOnly = false,
    bool areasOnly = false,
    String countryCode = '',
    double? biasLatitude,
    double? biasLongitude,
  }) async {
    genericSearches++;
    return const [];
  }

  @override
  Future<MatchLocation> placeDetails(
    String placeId, {
    required String sessionToken,
  }) async => MatchLocation(
    clubName: 'Central Padel Club',
    countryCode: 'MX',
    country: 'Mexico',
    region: 'CDMX',
    city: 'Mexico City',
    area: 'Centro',
    placeId: 'padel-place',
    formattedAddress: 'Central Padel Club, Mexico City',
    latitude: latitude,
    longitude: longitude,
  );
}

Widget _app(
  _MatchmakingRepository repository, {
  Locale locale = const Locale('en'),
  GooglePlacesClient? placesClient,
  PushSettingsService? pushSettingsService,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: MatchmakingScreen(
    currentUid: 'viewer',
    repository: repository,
    placesClient: placesClient,
    pushSettingsService: pushSettingsService,
    friendsRepository: _FriendsRepository(),
    level: '3.5',
    preferredSide: 'left',
    discoveryLocation: const DiscoveryLocation(
      country: 'Mexico',
      countryCode: 'MX',
      city: 'Mexico City',
      cityId: 'city-id',
      area: 'Polanco',
      latitude: 19.43,
      longitude: -99.13,
    ),
    onOpenMatch: (_) {},
    now: () => DateTime.utc(2030, 1, 1, 12),
  ),
);

void main() {
  testWidgets('Quick Match warns without push but remains available', (
    tester,
  ) async {
    final repository = _MatchmakingRepository(
      const MatchmakingState(requests: [], proposals: []),
    );
    await tester.pumpWidget(
      _app(
        repository,
        locale: const Locale('es', 'MX'),
        pushSettingsService: _PushSettings(false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Activa las notificaciones'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-matchmaking')),
      300,
    );
    expect(find.byKey(const Key('start-matchmaking')), findsOneWidget);
  });

  testWidgets(
    'empty authoritative state shows localized Solo and Partner request UI',
    (tester) async {
      final repository = _MatchmakingRepository(
        const MatchmakingState(requests: [], proposals: []),
      );
      await tester.pumpWidget(
        _app(repository, locale: const Locale('es', 'MX')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quick Match'), findsOneWidget);
      expect(find.text('Solo'), findsOneWidget);
      expect(find.text('Con un compañero'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('start-matchmaking')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('start-matchmaking')), findsOneWidget);
    },
  );

  testWidgets(
    'coordinator uses bounded padel search and retains canonical venue details',
    (tester) async {
      final repository = _MatchmakingRepository(
        const MatchmakingState(
          requests: [],
          proposals: [
            {
              'proposalId': 'proposal-venue',
              'status': 'venue_needed',
              'confirmation': 'accepted',
              'coordinator': true,
              'memberCount': 4,
              'scheduledAt': '2030-01-02T18:00:00Z',
              'expiresAt': '2030-01-02T19:00:00Z',
              'city': 'Mexico City',
              'cityId': 'city-id',
              'area': '',
              'participants': [],
              'venueSearch': {
                'countryCode': 'MX',
                'cityId': 'city-id',
                'city': 'Mexico City',
                'latitude': 19.4326,
                'longitude': -99.1332,
                'radiusKm': 10.0,
              },
            },
          ],
        ),
      );
      final places = _VenuePlacesClient();
      await tester.pumpWidget(_app(repository, placesClient: places));
      await tester.pumpAndSettle();
      expect(find.text('Players Ready'), findsOneWidget);
      expect(find.text('Match Found'), findsNothing);
      expect(find.textContaining('Wednesday, Jan 2 ·'), findsOneWidget);
      expect(find.text('Court not selected yet'), findsOneWidget);
      expect(find.text('Choose Venue'), findsOneWidget);
      await tester.tap(find.text('Choose Venue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('agreed 10.0 km'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('places-autocomplete-field')),
        'Central',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(places.padelSearches, 1);
      expect(places.genericSearches, 0);
      await tester.tap(find.text('Central Padel Club'));
      await tester.pumpAndSettle();
      final selectedField = tester.widget<TextField>(
        find.byKey(const Key('places-autocomplete-field')),
      );
      expect(selectedField.controller?.text, 'Central Padel Club');
      expect(find.text('Central Padel Club, Mexico City'), findsOneWidget);
      expect(
        find.text('No padel courts found within your search area.'),
        findsNothing,
      );
      await tester.tap(find.text('Confirm Venue'));
      await tester.pumpAndSettle();
      expect(repository.resolvedVenue?.placeId, 'padel-place');
      expect(repository.resolvedVenue?.label, 'Central Padel Club');
      expect(
        repository.resolvedVenue?.address,
        'Central Padel Club, Mexico City',
      );
      expect(repository.resolvedVenue?.latitude, 19.4328);
    },
  );

  testWidgets('non-coordinator sees a passive players-ready venue state', (
    tester,
  ) async {
    final repository = _MatchmakingRepository(
      const MatchmakingState(
        requests: [],
        proposals: [
          {
            'proposalId': 'proposal-waiting-venue',
            'status': 'venue_needed',
            'confirmation': 'accepted',
            'coordinator': false,
            'memberCount': 4,
            'scheduledAt': '2030-01-02T18:00:00Z',
            'expiresAt': '2030-01-02T19:00:00Z',
            'city': 'Mexico City',
            'area': '',
            'participants': [],
          },
        ],
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Players Ready'), findsOneWidget);
    expect(find.text('Your spot is confirmed'), findsNothing);
    expect(
      find.text(
        'Everyone accepted. Waiting for the coordinator to choose the court.',
      ),
      findsOneWidget,
    );
    expect(find.text('Choose Venue'), findsNothing);
    expect(find.text('Open Match Details'), findsNothing);
  });

  testWidgets('es-MX venue search explains bounded padel results', (
    tester,
  ) async {
    final repository = _MatchmakingRepository(
      const MatchmakingState(
        requests: [],
        proposals: [
          {
            'proposalId': 'proposal-es',
            'status': 'venue_needed',
            'confirmation': 'accepted',
            'coordinator': true,
            'memberCount': 4,
            'scheduledAt': '2030-01-02T18:00:00Z',
            'expiresAt': '2030-01-02T19:00:00Z',
            'city': 'Ciudad de México',
            'cityId': 'city-id',
            'area': '',
            'participants': [],
            'venueSearch': {
              'countryCode': 'MX',
              'cityId': 'city-id',
              'city': 'Ciudad de México',
              'latitude': 19.4326,
              'longitude': -99.1332,
              'radiusKm': 10.0,
            },
          },
        ],
      ),
    );
    await tester.pumpWidget(
      _app(
        repository,
        locale: const Locale('es', 'MX'),
        placesClient: _VenuePlacesClient(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir cancha'));
    await tester.pumpAndSettle();
    expect(find.text('Club o cancha de pádel'), findsOneWidget);
    expect(find.textContaining('área acordada de 10.0 km'), findsOneWidget);
  });

  testWidgets(
    'venue outside authoritative radius is rejected before submission',
    (tester) async {
      final repository = _MatchmakingRepository(
        const MatchmakingState(
          requests: [],
          proposals: [
            {
              'proposalId': 'proposal-far',
              'status': 'venue_needed',
              'confirmation': 'accepted',
              'coordinator': true,
              'memberCount': 4,
              'scheduledAt': '2030-01-02T18:00:00Z',
              'expiresAt': '2030-01-02T19:00:00Z',
              'city': 'Mexico City',
              'cityId': 'city-id',
              'area': '',
              'participants': [],
              'venueSearch': {
                'countryCode': 'MX',
                'cityId': 'city-id',
                'city': 'Mexico City',
                'latitude': 19.4326,
                'longitude': -99.1332,
                'radiusKm': 10.0,
              },
            },
          ],
        ),
      );
      await tester.pumpWidget(
        _app(
          repository,
          placesClient: _VenuePlacesClient(latitude: 20.7, longitude: -103.3),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose Venue'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('places-autocomplete-field')),
        'Far club',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.tap(find.text('Central Padel Club'));
      await tester.pumpAndSettle();
      expect(
        find.text('That venue is outside the agreed search area.'),
        findsOneWidget,
      );
      expect(repository.resolvedVenue, isNull);
      expect(find.text('Confirm Venue'), findsOneWidget);
    },
  );

  testWidgets('private court keeps the separate generic location path', (
    tester,
  ) async {
    final repository = _MatchmakingRepository(
      const MatchmakingState(
        requests: [],
        proposals: [
          {
            'proposalId': 'proposal-private-path',
            'status': 'venue_needed',
            'confirmation': 'accepted',
            'coordinator': true,
            'memberCount': 4,
            'scheduledAt': '2030-01-02T18:00:00Z',
            'expiresAt': '2030-01-02T19:00:00Z',
            'city': 'Mexico City',
            'cityId': 'city-id',
            'area': '',
            'participants': [],
            'venueSearch': {
              'countryCode': 'MX',
              'cityId': 'city-id',
              'city': 'Mexico City',
              'latitude': 19.4326,
              'longitude': -99.1332,
              'radiusKm': 10.0,
            },
          },
        ],
      ),
    );
    final places = _VenuePlacesClient();
    await tester.pumpWidget(_app(repository, placesClient: places));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Venue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private court'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('places-autocomplete-field')),
      'Private',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(places.genericSearches, 1);
    expect(places.padelSearches, 0);
  });

  testWidgets('partner invitation is restored and accepts exactly once', (
    tester,
  ) async {
    final repository = _MatchmakingRepository(
      const MatchmakingState(
        requests: [
          {
            'requestId': 'request-id',
            'status': 'awaiting_partner',
            'role': 'partner',
            'inviterDisplayName': 'Player One',
            'city': 'Mexico City',
            'area': '',
            'availability': [],
          },
        ],
        proposals: [],
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('Partner invitation'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(repository.actions, ['partner:true']);
  });

  testWidgets('active request survives refresh and can be cancelled', (
    tester,
  ) async {
    final repository = _MatchmakingRepository(
      const MatchmakingState(
        requests: [
          {
            'requestId': 'request-id',
            'status': 'active',
            'role': 'owner',
            'city': 'Mexico City',
            'area': 'Polanco',
            'availability': [],
          },
        ],
        proposals: [],
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('Finding your match…'), findsOneWidget);
    repository.invalidations.add(null);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Search'));
    await tester.pumpAndSettle();
    expect(repository.actions, ['cancel']);
  });

  testWidgets(
    'match proposal displays safe summaries and serializes acceptance',
    (tester) async {
      final repository = _MatchmakingRepository(
        MatchmakingState(
          requests: const [],
          proposals: [
            {
              'proposalId': 'proposal-id',
              'status': 'confirming',
              'confirmation': 'offered',
              'scheduledAt': DateTime.utc(2030, 1, 2, 18),
              'expiresAt': DateTime.utc(2030, 1, 2, 19),
              'city': 'Mexico City',
              'area': 'Polanco',
              'participants': const [
                {
                  'displayName': 'Player One',
                  'level': '3.5',
                  'confirmation': 'accepted',
                },
                {
                  'displayName': 'Player Two',
                  'level': '3',
                  'confirmation': 'offered',
                },
              ],
            },
          ],
        ),
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(find.text('Match Found'), findsOneWidget);
      expect(find.text('Player One'), findsOneWidget);
      await tester.tap(find.byKey(const Key('accept-match')));
      await tester.pumpAndSettle();
      expect(repository.actions, ['proposal:true']);
    },
  );

  testWidgets(
    'legacy promoted projection without a selected venue remains Players Ready',
    (tester) async {
      final repository = _MatchmakingRepository(
        MatchmakingState(
          requests: const [],
          proposals: [
            {
              'proposalId': 'legacy-pre-venue',
              'status': 'promoted',
              'matchId': 'legacy-projected-match',
              'venueStatus': 'needed',
              'confirmation': 'accepted',
              'coordinator': true,
              'memberCount': 4,
              'scheduledAt': DateTime.utc(2030, 1, 2, 18),
              'expiresAt': DateTime.utc(2030, 1, 2, 19),
              'city': 'Mexico City',
              'area': '',
              'participants': const [
                {'displayName': 'One', 'confirmation': 'accepted'},
                {'displayName': 'Two', 'confirmation': 'accepted'},
                {'displayName': 'Three', 'confirmation': 'accepted'},
                {'displayName': 'Four', 'confirmation': 'accepted'},
              ],
            },
          ],
        ),
      );

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('Players Ready'), findsOneWidget);
      expect(find.text('4 of 4 confirmed'), findsOneWidget);
      expect(find.text('Court not selected yet'), findsOneWidget);
      expect(find.text('Choose Venue'), findsOneWidget);
      expect(find.text('Match Found'), findsNothing);
      expect(find.text('Open Match Details'), findsNothing);
    },
  );

  testWidgets(
    'completed promotion routes to its canonical match without pre-venue copy',
    (tester) async {
      final repository = _MatchmakingRepository(
        MatchmakingState(
          requests: const [],
          proposals: [
            {
              'proposalId': 'completed-promotion',
              'status': 'promoted',
              'matchId': 'canonical-match',
              'venueStatus': 'selected',
              'confirmation': 'accepted',
              'coordinator': true,
              'memberCount': 4,
              'scheduledAt': DateTime.utc(2030, 1, 2, 18),
              'expiresAt': DateTime.utc(2030, 1, 2, 19),
              'city': 'Mexico City',
              'area': '',
              'participants': const [
                {'displayName': 'One', 'confirmation': 'accepted'},
                {'displayName': 'Two', 'confirmation': 'accepted'},
                {'displayName': 'Three', 'confirmation': 'accepted'},
                {'displayName': 'Four', 'confirmation': 'accepted'},
              ],
            },
          ],
        ),
      );

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('Match confirmed'), findsOneWidget);
      expect(find.text('Open Match Details'), findsOneWidget);
      expect(find.text('Match Found'), findsNothing);
      expect(find.text('Court not selected yet'), findsNothing);
      expect(find.text('Players Ready'), findsNothing);
      expect(find.text('Choose Venue'), findsNothing);
    },
  );

  testWidgets(
    'matchmaking proposal fits narrow mobile layout at enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _MatchmakingRepository(
        MatchmakingState(
          requests: const [],
          proposals: [
            {
              'proposalId': 'proposal-narrow',
              'status': 'confirming',
              'confirmation': 'offered',
              'scheduledAt': DateTime.utc(2030, 1, 2, 18),
              'expiresAt': DateTime.utc(2030, 1, 2, 19),
              'city': 'Ciudad de México',
              'area': 'San Pedro de los Pinos',
              'participants': const [
                {
                  'displayName': 'Nombre de jugador largo',
                  'level': '3.5',
                  'confirmation': 'accepted',
                  'team': 1,
                },
              ],
            },
          ],
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: _app(repository, locale: const Locale('es', 'MX')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Nombre de jugador largo'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Equipo 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('accepted lobby member sees locked spot and truthful progress', (
    tester,
  ) async {
    final repository = _MatchmakingRepository(
      MatchmakingState(
        requests: const [],
        proposals: [
          {
            'proposalId': 'lobby-progress',
            'status': 'confirming',
            'confirmation': 'accepted',
            'memberCount': 3,
            'scheduledAt': DateTime.utc(2030, 1, 2, 18),
            'expiresAt': DateTime.utc(2030, 1, 2, 19),
            'city': 'Mexico City',
            'area': '',
            'participants': const [
              {'displayName': 'One', 'confirmation': 'accepted'},
              {'displayName': 'Two', 'confirmation': 'accepted'},
              {'displayName': 'Three', 'confirmation': 'offered'},
            ],
          },
        ],
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('2 of 4 confirmed'), findsOneWidget);
    expect(find.text('Your spot is confirmed'), findsOneWidget);
    expect(find.text('We’re finding the remaining players.'), findsOneWidget);
    expect(find.byKey(const Key('accept-match')), findsNothing);
  });

  testWidgets(
    'Match Details AutoFill card is responsive and invokes one action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es', 'MX'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: MatchAutoFillCard(
                  enabled: true,
                  busy: false,
                  onToggle: () => toggles++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Buscando otro jugador'), findsOneWidget);
      await tester.tap(find.byKey(const Key('match-autofill-action')));
      expect(toggles, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy Match Details AutoFill card blocks duplicate actions', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MatchAutoFillCard(
            enabled: false,
            busy: true,
            onToggle: () => toggles++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('match-autofill-action')));
    expect(toggles, 0);
  });
}
