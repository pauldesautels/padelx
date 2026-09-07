import 'package:cloud_firestore/cloud_firestore.dart';

import 'social_profile.dart';

DateTime? playedWithDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int playedWithInt(Object? value) => value is num ? value.toInt() : 0;

class PlayedWithRelationship {
  final String otherUid;
  final DateTime? firstPlayedAt;
  final DateTime? lastPlayedAt;
  final String lastMatchId;
  final int completedMatchCount;

  const PlayedWithRelationship({
    required this.otherUid,
    this.firstPlayedAt,
    this.lastPlayedAt,
    this.lastMatchId = '',
    this.completedMatchCount = 0,
  });

  factory PlayedWithRelationship.fromMap(
    Map<String, dynamic> data, {
    String documentId = '',
  }) => PlayedWithRelationship(
    otherUid: data['otherUid']?.toString() ?? documentId,
    firstPlayedAt: playedWithDate(data['firstPlayedAt']),
    lastPlayedAt: playedWithDate(data['lastPlayedAt']),
    lastMatchId: data['lastMatchId']?.toString() ?? '',
    completedMatchCount: playedWithInt(data['completedMatchCount']),
  );
}

class PlayedWithPublicProfile {
  final String uid;
  final String displayName;
  final String level;
  final int ratingCount;
  final double ratingAverage;
  final int completedMatchCount;
  final int repeatPlayerCount;
  final int avatarVersion;
  final String countryCode;
  final String city;
  final String area;
  final SocialProfileData socialProfile;

  const PlayedWithPublicProfile({
    required this.uid,
    required this.displayName,
    required this.level,
    this.ratingCount = 0,
    this.ratingAverage = 0,
    this.completedMatchCount = 0,
    this.repeatPlayerCount = 0,
    this.avatarVersion = 0,
    this.countryCode = '',
    this.city = '',
    this.area = '',
    this.socialProfile = const SocialProfileData(),
  });

  factory PlayedWithPublicProfile.fromMap(
    String uid,
    Map<String, dynamic> data,
  ) => PlayedWithPublicProfile(
    uid: uid,
    displayName: data['displayName']?.toString().trim() ?? '',
    level: data['level']?.toString().trim() ?? '',
    ratingCount: playedWithInt(data['ratingCount']),
    ratingAverage: data['ratingAverage'] is num
        ? (data['ratingAverage'] as num).toDouble()
        : 0,
    completedMatchCount: playedWithInt(data['completedMatchCount']),
    repeatPlayerCount: playedWithInt(data['repeatPlayerCount']),
    avatarVersion: avatarVersionFromMap(data),
    countryCode: data['countryCode']?.toString().trim() ?? '',
    city: data['city']?.toString().trim() ?? '',
    area: data['area']?.toString().trim() ?? '',
    socialProfile: SocialProfileData.fromMap(data),
  );

  String get locationLabel =>
      [area, city, countryCode].where((value) => value.isNotEmpty).join(', ');
}

class PlayedWithPlayer {
  final PlayedWithRelationship relationship;
  final PlayedWithPublicProfile profile;

  const PlayedWithPlayer({required this.relationship, required this.profile});
}

class PlayedWithPage {
  final List<PlayedWithPlayer> players;
  final Object? cursor;
  final bool hasMore;

  const PlayedWithPage({
    this.players = const [],
    this.cursor,
    this.hasMore = false,
  });
}

typedef PlayedWithFilter =
    Future<List<PlayedWithPlayer>> Function(List<PlayedWithPlayer> players);

List<PlayedWithPlayer> sortPlayedWithPlayers(
  Iterable<PlayedWithPlayer> players,
) {
  final result = players.toList();
  result.sort((a, b) {
    final left = a.relationship.lastPlayedAt;
    final right = b.relationship.lastPlayedAt;
    if (left == null && right == null) {
      return a.profile.uid.compareTo(b.profile.uid);
    }
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  });
  return result;
}
