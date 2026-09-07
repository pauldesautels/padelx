import 'location.dart';

class PlayAgainTarget {
  final String uid;
  final String displayName;
  final String? sourceMatchId;
  final MatchLocation? location;
  final String? level;

  const PlayAgainTarget({
    required this.uid,
    required this.displayName,
    this.sourceMatchId,
    this.location,
    this.level,
  });

  MatchLocation? get safeLocation =>
      location?.isValid == true ? location : null;
  String? get safeLevel =>
      RegExp(r'^Level ([1-6](\.5)?|7)$').hasMatch(level ?? '') ? level : null;
}
