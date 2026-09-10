import 'location.dart';
import 'level.dart';

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
  String? get safeLevel {
    final normalized = normalizePadelLevel(level);
    return normalized == null ? null : matchLevelStorageValue(normalized);
  }
}
