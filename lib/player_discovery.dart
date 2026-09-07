enum PlayerRelationshipFilter { all, friends, playedWith }

class PlayerDiscoveryFilters {
  final String area;
  final String level;
  final String preferredSide;
  final PlayerRelationshipFilter relationship;
  const PlayerDiscoveryFilters({
    this.area = '',
    this.level = '',
    this.preferredSide = 'any',
    this.relationship = PlayerRelationshipFilter.all,
  });

  Map<String, Object> toMap({Object? cursor}) => {
    if (area.trim().isNotEmpty) 'area': area.trim(),
    if (level.trim().isNotEmpty) 'level': level.trim(),
    'preferredSide': preferredSide,
    'relationship': relationship.name,
    if (cursor case final Object value) 'cursor': value,
    'limit': 20,
  };
}

class DiscoveredPlayer {
  final String uid, displayName, level, preferredSide, countryCode, city, area;
  final int ratingCount, completedMatchCount, playedTogetherCount;
  final int avatarVersion;
  final double ratingAverage;
  final bool isFriend, canPlayAgain;
  final String friendStatus, friendDirection;
  const DiscoveredPlayer({
    required this.uid,
    required this.displayName,
    required this.level,
    required this.preferredSide,
    required this.countryCode,
    required this.city,
    required this.area,
    required this.ratingCount,
    required this.ratingAverage,
    required this.completedMatchCount,
    required this.playedTogetherCount,
    required this.isFriend,
    required this.canPlayAgain,
    required this.friendStatus,
    required this.friendDirection,
    this.avatarVersion = 0,
  });

  factory DiscoveredPlayer.fromMap(
    Map<dynamic, dynamic> data,
  ) => DiscoveredPlayer(
    uid: data['uid']?.toString() ?? '',
    displayName: data['displayName']?.toString() ?? '',
    level: data['level']?.toString() ?? '',
    preferredSide: data['preferredSide']?.toString() ?? 'either',
    countryCode: data['countryCode']?.toString() ?? '',
    city: data['city']?.toString() ?? '',
    area: data['area']?.toString() ?? '',
    ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
    ratingAverage: (data['ratingAverage'] as num?)?.toDouble() ?? 0,
    completedMatchCount: (data['completedMatchCount'] as num?)?.toInt() ?? 0,
    playedTogetherCount: (data['playedTogetherCount'] as num?)?.toInt() ?? 0,
    isFriend: data['isFriend'] == true,
    canPlayAgain: data['canPlayAgain'] == true,
    friendStatus: data['friendStatus']?.toString() ?? 'none',
    friendDirection: data['friendDirection']?.toString() ?? 'none',
    avatarVersion: data['avatarVersion'] is num
        ? (data['avatarVersion'] as num).toInt()
        : 0,
  );

  String get locationLabel =>
      [area, city].where((value) => value.isNotEmpty).join(', ');
}

class PlayerDiscoveryPage {
  final List<DiscoveredPlayer> players;
  final Object? cursor;
  final bool hasMore, noLocation;
  const PlayerDiscoveryPage({
    this.players = const [],
    this.cursor,
    this.hasMore = false,
    this.noLocation = false,
  });
}
