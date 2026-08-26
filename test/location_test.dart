import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/location.dart';
import 'package:padelx/main.dart';

void main() {
  group('global match location', () {
    test('serializes Mexico and optional area', () {
      const location = MatchLocation(
        clubName: 'Padel Co Polanco',
        countryCode: 'mx',
        country: 'Mexico',
        region: 'Mexico City',
        city: 'Mexico City',
        area: 'Polanco',
      );
      expect(location.isValid, isTrue);
      expect(location.toMap()['countryCode'], 'MX');
      expect(location.localityLabel, 'Polanco, Mexico City, Mexico');
    });

    test('supports US state and coordinates', () {
      const location = MatchLocation(
        clubName: 'Reserve Padel',
        countryCode: 'US',
        country: 'USA',
        region: 'Florida',
        city: 'Miami',
        latitude: 25.7617,
        longitude: -80.1918,
      );
      expect(location.toMap()['region'], 'Florida');
      expect(location.toMap()['latitude'], 25.7617);
      expect(location.localityLabel, 'Miami, Florida, USA');
    });

    test('supports countries without a meaningful region', () {
      const location = MatchLocation(
        clubName: 'Padel Nuestro',
        countryCode: 'ES',
        country: 'Spain',
        region: '',
        city: 'Madrid',
      );
      expect(location.isValid, isTrue);
      expect(location.localityLabel, 'Madrid, Spain');
    });

    test('requires club, country, ISO code, and city', () {
      const location = MatchLocation(
        clubName: 'Club',
        countryCode: '',
        country: 'UAE',
        region: '',
        city: 'Dubai',
      );
      expect(location.isValid, isFalse);
    });

    test('legacy match falls back to old club and location string', () {
      final location = MatchLocation.fromMap(
        {'club': 'Legacy Club', 'location': 'Old Town'},
        legacyClub: 'Legacy Club',
        legacyLocation: 'Old Town',
      );
      expect(location.clubName, 'Legacy Club');
      expect(location.localityLabel, 'Old Town');
    });
  });

  test('preferred discovery location round trips and can change', () {
    const madrid = DiscoveryLocation(
      country: 'Spain',
      countryCode: 'ES',
      city: 'Madrid',
    );
    final restored = DiscoveryLocation.fromMap(madrid.toMap());
    expect(restored.city, 'Madrid');
    const miami = DiscoveryLocation(
      country: 'USA',
      countryCode: 'US',
      city: 'Miami',
    );
    expect(miami.city, isNot(restored.city));
  });

  test('participation states remain authoritative', () {
    expect(
      resolveMatchParticipationState(
        isOrganizer: true,
        isConfirmedPlayer: false,
      ),
      MatchParticipationState.organizer,
    );
    expect(
      resolveMatchParticipationState(
        isOrganizer: false,
        isConfirmedPlayer: true,
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
      ),
      MatchParticipationState.available,
    );
    expect(
      matchParticipationButtonLabel(
        MatchParticipationState.available,
        spotsLeft: 0,
      ),
      'Match Full',
    );
  });

  test(
    'discovery combines location, date, level, availability, and search',
    () {
      final now = DateTime(2026, 8, 26, 10);
      Match match(
        String id,
        String city, {
        String area = '',
        String level = '3',
        int spots = 1,
        int hours = 2,
        String club = 'Global Padel',
      }) => Match(
        id: id,
        title: id,
        club: club,
        level: level,
        spotsLeft: spots,
        creatorUid: 'owner',
        creatorEmail: '',
        players: const [],
        scheduledAt: now.add(Duration(hours: hours)),
        location: MatchLocation(
          clubName: club,
          countryCode: city == 'Madrid' ? 'ES' : 'US',
          country: city == 'Madrid' ? 'Spain' : 'USA',
          region: '',
          city: city,
          area: area,
        ),
      );
      final matches = [
        match('target', 'Madrid', area: 'Centro'),
        match('wrong-city', 'Miami', area: 'Centro'),
        match('wrong-level', 'Madrid', area: 'Centro', level: '4'),
        match('full', 'Madrid', area: 'Centro', spots: 0),
        match('later', 'Madrid', area: 'Centro', hours: 5, club: 'Other Club'),
      ];
      final result = filterDiscoveredMatches(
        matches,
        now: now,
        country: 'Spain',
        city: 'Madrid',
        area: 'Centro',
        date: MatchDateFilter.today,
        level: '3',
        availableOnly: true,
        search: 'Global',
      );
      expect(result.map((match) => match.id), ['target']);
      expect(
        filterDiscoveredMatches(
          matches,
          now: now,
          city: 'Madrid',
        ).map((match) => match.id),
        ['target', 'wrong-level', 'full', 'later'],
      );
    },
  );
}
