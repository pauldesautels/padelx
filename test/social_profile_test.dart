import 'package:flutter_test/flutter_test.dart';
import 'package:padelx/social_profile.dart';

void main() {
  test('preferred side uses stable values and safe parsing defaults', () {
    expect(PreferredSide.values.map((value) => value.value), [
      'left',
      'right',
      'either',
    ]);
    expect(parsePreferredSide('left'), PreferredSide.left);
    expect(parsePreferredSide('unknown'), PreferredSide.either);
    expect(parsePreferredSide(null), PreferredSide.either);
  });

  test('play frequency uses stable values and safe parsing defaults', () {
    expect(PlayFrequency.values.map((value) => value.value), [
      'occasional',
      'weekly',
      'several_per_week',
    ]);
    expect(
      parsePlayFrequency('several_per_week'),
      PlayFrequency.severalPerWeek,
    );
    expect(parsePlayFrequency(null), PlayFrequency.occasional);
  });

  test('legacy social profile fields get explicit privacy-safe defaults', () {
    final profile = SocialProfileData.fromMap(const {});
    expect(profile.preferredSide, PreferredSide.either);
    expect(profile.playFrequency, PlayFrequency.occasional);
    expect(profile.bio, '');
    expect(profile.discoverable, isFalse);
  });

  test('social profile serializes machine values and trims bio', () {
    const profile = SocialProfileData(
      preferredSide: PreferredSide.right,
      playFrequency: PlayFrequency.severalPerWeek,
      bio: '  Friendly games  ',
      discoverable: true,
    );
    expect(profile.toMap(), {
      'preferredSide': 'right',
      'playFrequency': 'several_per_week',
      'bio': 'Friendly games',
      'discoverable': true,
    });
  });

  test('coarse location omits every precise/private field', () {
    final location = coarsePublicLocation({
      'countryCode': 'mx',
      'city': 'Mexico City',
      'cityId': 'city-place-id',
      'area': 'Roma Norte',
      'areaId': 'area-place-id',
      'latitude': 19.4,
      'longitude': -99.1,
      'placeId': 'match-place-id',
      'email': 'secret@example.com',
    });
    expect(location, {
      'countryCode': 'MX',
      'city': 'Mexico City',
      'cityId': 'city-place-id',
      'area': 'Roma Norte',
      'areaId': 'area-place-id',
    });
  });
}
