enum PreferredSide { left, right, either }

enum PlayFrequency { occasional, weekly, severalPerWeek }

const int socialProfileBioMaxLength = 160;

int avatarVersionFromMap(Map<dynamic, dynamic> data) =>
    data['avatarVersion'] is num && (data['avatarVersion'] as num) > 0
    ? (data['avatarVersion'] as num).toInt()
    : 0;

extension PreferredSideValue on PreferredSide {
  String get value => name;
  String get label => switch (this) {
    PreferredSide.left => 'Left',
    PreferredSide.right => 'Right',
    PreferredSide.either => 'Either',
  };
}

extension PlayFrequencyValue on PlayFrequency {
  String get value => switch (this) {
    PlayFrequency.occasional => 'occasional',
    PlayFrequency.weekly => 'weekly',
    PlayFrequency.severalPerWeek => 'several_per_week',
  };
  String get label => switch (this) {
    PlayFrequency.occasional => 'Occasionally',
    PlayFrequency.weekly => 'Weekly',
    PlayFrequency.severalPerWeek => 'Several times a week',
  };
}

PreferredSide parsePreferredSide(Object? value) => switch (value) {
  'left' => PreferredSide.left,
  'right' => PreferredSide.right,
  _ => PreferredSide.either,
};

PlayFrequency parsePlayFrequency(Object? value) => switch (value) {
  'weekly' => PlayFrequency.weekly,
  'several_per_week' => PlayFrequency.severalPerWeek,
  _ => PlayFrequency.occasional,
};

class SocialProfileData {
  final PreferredSide preferredSide;
  final PlayFrequency playFrequency;
  final String bio;
  final bool discoverable;

  const SocialProfileData({
    this.preferredSide = PreferredSide.either,
    this.playFrequency = PlayFrequency.occasional,
    this.bio = '',
    this.discoverable = false,
  });

  factory SocialProfileData.fromMap(Map<dynamic, dynamic> data) =>
      SocialProfileData(
        preferredSide: parsePreferredSide(data['preferredSide']),
        playFrequency: parsePlayFrequency(data['playFrequency']),
        bio: data['bio'] is String ? (data['bio'] as String).trim() : '',
        discoverable: data['discoverable'] is bool
            ? data['discoverable'] as bool
            : false,
      );

  Map<String, Object> toMap() => {
    'preferredSide': preferredSide.value,
    'playFrequency': playFrequency.value,
    'bio': bio.trim(),
    'discoverable': discoverable,
  };
}

Map<String, String> coarsePublicLocation(Map<dynamic, dynamic> location) => {
  'countryCode': location['countryCode']?.toString().trim().toUpperCase() ?? '',
  'city': location['city']?.toString().trim() ?? '',
  'area': location['area']?.toString().trim() ?? '',
};
