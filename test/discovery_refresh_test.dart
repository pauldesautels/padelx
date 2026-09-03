import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/discovery_refresh.dart';
import 'package:padelx/location.dart';
import 'package:padelx/main.dart';
import 'package:padelx/places_autocomplete.dart';

const location = MatchLocation(
  clubName: 'Club',
  countryCode: 'MX',
  country: 'Mexico',
  region: '',
  city: 'Ciudad de México',
  latitude: 19.4326,
  longitude: -99.1332,
);
const result = MatchMutationResult('new-match', location);
const indexed = {'geoHash3': '9g3', 'geoHash4': '9g3w'};

void main() {
  testWidgets(
    'Home and Matches share completed discovery across tab switches and refresh',
    (tester) async {
      final now = DateTime.now();
      Match nearby(String id, int hours) => Match(
        id: id,
        title: 'Game $id',
        club: 'Nearby club $id',
        level: 'Level 2',
        spotsLeft: 2,
        creatorUid: 'owner',
        creatorEmail: '',
        players: const [],
        location: location,
        scheduledAt: now.add(Duration(hours: hours)),
      );
      final pending = <Completer<List<Match>>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            discoveryLoader: () {
              final request = Completer<List<Match>>();
              pending.add(request);
              return request.future;
            },
          ),
        ),
      );
      pending.single.complete([]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-empty-state')), findsOneWidget);

      await tester.tap(find.text('Matches').last);
      await tester.pumpAndSettle();
      // Exercise the actual discovery callback used by location selection.
      tester
          .widget<MatchesTab>(find.byType(MatchesTab))
          .onDiscoveryQueryChanged!(location, 25);
      await tester.pump();
      expect(pending.length, 2);
      pending.last.complete([
        nearby('4', 4),
        nearby('2', 2),
        nearby('1', 1),
        nearby('3', 3),
      ]);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MatchesTab>(find.byType(MatchesTab))
            .matches
            .map((match) => match.id),
        ['1', '2', '3', '4'],
      );
      await tester.scrollUntilVisible(
        find.text('Nearby club 1'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nearby club 1'), findsOneWidget);

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(pending.length, 2); // Tab changes reuse the completed discovery.
      expect(
        tester
            .widget<HomeTab>(find.byType(HomeTab))
            .matches
            .map((match) => match.id),
        ['1', '2', '3', '4'],
      );
      expect(find.byKey(const Key('home-empty-state')), findsNothing);
      final homeList = tester.widget<ListView>(
        find.byKey(const Key('home-scroll-view')),
      );
      final children =
          (homeList.childrenDelegate as SliverChildListDelegate).children;
      expect(children.whereType<MatchCard>().map((card) => card.match.id), [
        '1',
        '2',
        '3',
      ]);
      await tester.scrollUntilVisible(
        find.text('Nearby club 1'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nearby club 1'), findsOneWidget);

      await tester.tap(find.byTooltip('Refresh matches'));
      await tester.pump();
      expect(pending.length, 3);
      pending.last.complete([nearby('refreshed', 5)]);
      await tester.pumpAndSettle();
      expect(
        tester.widget<HomeTab>(find.byType(HomeTab)).matches.single.id,
        'refreshed',
      );
      expect(find.text('Nearby club refreshed'), findsOneWidget);
      expect(find.text('Nearby club 1'), findsNothing);

      await tester.tap(find.text('Matches').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MatchesTab>(find.byType(MatchesTab)).matches.single.id,
        'refreshed',
      );
      await tester.scrollUntilVisible(
        find.text('Nearby club refreshed'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nearby club refreshed'), findsOneWidget);
      // Refresh while Matches is visible; completion must also update Home.
      await tester.tap(find.byTooltip('Refresh matches'));
      await tester.pump();
      await tester.tap(find.text('Home').last);
      await tester.pump();
      pending.last.complete([nearby('last', 6)]);
      await tester.pumpAndSettle();
      expect(
        tester.widget<HomeTab>(find.byType(HomeTab)).matches.single.id,
        'last',
      );
      expect(find.byKey(const Key('home-empty-state')), findsNothing);
    },
  );

  test(
    'waits for updated hashes, targeting only the changed document',
    () async {
      final ids = <String>[];
      final ready = await waitForMatchGeoIndex(
        result,
        delay: Duration.zero,
        loadDocument: (id) async {
          ids.add(id);
          return ids.length < 3
              ? {'geoHash3': '9g3', 'geoHash4': '9g3q'}
              : indexed;
        },
      );
      expect(ready, isTrue);
      expect(ids, ['new-match', 'new-match', 'new-match']);
    },
  );

  test('missing hashes and failed reads are bounded', () async {
    var reads = 0;
    expect(
      await waitForMatchGeoIndex(
        result,
        delay: Duration.zero,
        loadDocument: (_) async {
          reads++;
          if (reads.isOdd) throw StateError('offline');
          return null;
        },
      ),
      isFalse,
    );
    expect(reads, 10);
  });

  test('a stalled read times out without further reads', () async {
    var reads = 0;
    expect(
      await waitForMatchGeoIndex(
        result,
        timeout: const Duration(milliseconds: 10),
        loadDocument: (_) {
          reads++;
          return Completer<Map<String, dynamic>?>().future;
        },
      ),
      isFalse,
    );
    expect(reads, 1);
  });

  test('disposal stops further polling', () async {
    var active = true;
    var reads = 0;
    await waitForMatchGeoIndex(
      result,
      delay: Duration.zero,
      isActive: () => active,
      loadDocument: (_) async {
        reads++;
        active = false;
        return null;
      },
    );
    expect(reads, 1);
  });

  testWidgets('creation returns ID and preserves success message', (
    tester,
  ) async {
    MatchMutationResult? returned;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                returned = await Navigator.push<MatchMutationResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateMatchScreen(
                      initialLocation: location,
                      initialScheduledAt: DateTime.now().add(
                        const Duration(days: 1),
                      ),
                      initialLevel: 'Level 2',
                      creator: (_) async => 'new-match',
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('create-match-submit')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('create-match-submit')));
    await tester.pumpAndSettle();
    expect(returned?.matchId, 'new-match');
    expect(returned?.location.latitude, location.latitude);
    expect(find.text('Match created successfully.'), findsOneWidget);
  });

  for (final ready in [true, false]) {
    testWidgets('parent refreshes after bounded indexing wait: ready=$ready', (
      tester,
    ) async {
      var loads = 0;
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            discoveryLoader: () async {
              loads++;
              return [];
            },
            indexRetryAttempts: 3,
            indexRetryDelay: const Duration(milliseconds: 400),
            matchDocumentLoader: (id) async {
              expect(id, 'new-match');
              reads++;
              return ready && reads == 3 ? indexed : null;
            },
            createMatchScreenBuilder: () => Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.pop(context, result),
                  child: const Text('Complete'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 1);
      await tester.tap(find.byKey(const Key('home-create-match')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete'));
      await tester.pump();
      expect(reads, 1);
      expect(loads, 1);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(loads, 2);
      await tester.tap(find.byTooltip('Refresh matches'));
      await tester.pumpAndSettle();
      expect(loads, 3);
    });
  }

  testWidgets('cancelled create does not read or refresh', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          discoveryLoader: () async {
            loads++;
            return [];
          },
          matchDocumentLoader: (_) async => throw StateError('must not read'),
          createMatchScreenBuilder: () => Scaffold(appBar: AppBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-create-match')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(loads, 1);
  });

  testWidgets('location edit returns updated coordinates for indexing wait', (
    tester,
  ) async {
    const moved = MatchLocation(
      clubName: 'Polanco Club',
      countryCode: 'MX',
      country: 'Mexico',
      region: '',
      city: 'Ciudad de México',
      latitude: 19.433,
      longitude: -99.2,
    );
    final match = Match(
      id: 'existing-match',
      title: 'Game',
      club: 'Club',
      level: 'Level 2',
      spotsLeft: 3,
      creatorUid: 'owner',
      creatorEmail: '',
      players: const [],
      location: location,
      scheduledAt: DateTime.now().add(const Duration(days: 1)),
    );
    MatchMutationResult? returned;
    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                returned = await Navigator.push<MatchMutationResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditMatchScreen(
                      match: match,
                      saver: (update) async {
                        saved = update;
                      },
                    ),
                  ),
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    tester
        .widget<PlacesAutocompleteField>(find.byType(PlacesAutocompleteField))
        .onSelected(moved);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('edit-match-submit')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('edit-match-submit')));
    await tester.pumpAndSettle();
    expect(returned?.matchId, 'existing-match');
    expect(returned?.location.longitude, moved.longitude);
    expect((saved?['location'] as Map)['longitude'], moved.longitude);
    var reads = 0;
    expect(
      await tester.runAsync(
        () => waitForMatchGeoIndex(
          returned!,
          delay: Duration.zero,
          loadDocument: (id) async {
            expect(id, 'existing-match');
            reads++;
            return reads == 1
                ? indexed
                : {'geoHash3': '9g3', 'geoHash4': '9g3q'};
          },
        ),
      ),
      isTrue,
    );
    expect(reads, 2);
  });
}
