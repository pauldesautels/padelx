import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/matchmaking_repository.dart';

void main() {
  test('request payload uses canonical codes and UTC availability', () {
    final input = MatchmakingRequestInput(
      requestId: 'request_1234567890',
      mode: MatchmakingMode.partner,
      partnerUid: 'partner-uid',
      availability: [
        MatchmakingAvailability(
          earliestStart: DateTime.parse('2030-01-02T18:00:00-06:00'),
          latestStart: DateTime.parse('2030-01-02T22:00:00-06:00'),
        ),
      ],
      timezone: 'America/Mexico_City',
      travelRadiusKm: 20,
      preferredSide: 'left',
    );

    expect(input.toPayload(), {
      'requestId': 'request_1234567890',
      'mode': 'partner',
      'partnerUid': 'partner-uid',
      'availability': [
        {
          'earliestStart': '2030-01-03T00:00:00.000Z',
          'latestStart': '2030-01-03T04:00:00.000Z',
        },
      ],
      'timezone': 'America/Mexico_City',
      'travelRadiusKm': 20,
      'preferredSide': 'left',
    });
  });

  test('autofill payload stays payment-free and match-scoped', () {
    final input = MatchmakingRequestInput(
      requestId: 'request_1234567890',
      mode: MatchmakingMode.autofill,
      sourceMatchId: 'match-id',
      autoFillAfterCancellation: true,
      availability: [
        MatchmakingAvailability(
          earliestStart: DateTime.utc(2030, 1, 2, 18),
          latestStart: DateTime.utc(2030, 1, 2, 22),
        ),
      ],
      timezone: 'America/Mexico_City',
      travelRadiusKm: 10,
      preferredSide: 'either',
    );
    final payload = input.toPayload();
    expect(payload['mode'], 'autofill');
    expect(payload['sourceMatchId'], 'match-id');
    expect(payload['autoFillAfterCancellation'], true);
    expect(payload, isNot(contains('payment')));
  });

  test('venue payload uses canonical type and keeps private detail task-scoped', () {
    const venue = MatchmakingVenueInput(
      type: MatchmakingVenueType.privateFree,
      label: 'Private court',
      address: 'Synthetic exact address',
      latitude: 19.43,
      longitude: -99.13,
      countryCode: 'MX',
      country: 'Mexico',
      cityId: 'places-cdmx',
      city: 'Mexico City',
      areaId: 'places-polanco',
      area: 'Polanco',
    );
    final payload = venue.toPayload();
    expect(payload['type'], 'private_free');
    expect(payload['address'], 'Synthetic exact address');
    expect(payload, isNot(contains('uid')));
    expect(payload, isNot(contains('payment')));
  });
}
