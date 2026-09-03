import 'dart:async';

import 'geohash.dart';
import 'location.dart';

class MatchMutationResult {
  final String matchId;
  final MatchLocation location;

  const MatchMutationResult(this.matchId, this.location);
}

/// Waits only for this mutation's geographic projection. An edit may retain
/// old hashes temporarily, so presence alone is not sufficient.
Future<bool> waitForMatchGeoIndex(
  MatchMutationResult result, {
  required Future<Map<String, dynamic>?> Function(String) loadDocument,
  Duration delay = const Duration(milliseconds: 400),
  int maxAttempts = 10,
  Duration timeout = const Duration(seconds: 5),
  bool Function()? isActive,
}) async {
  final location = result.location;
  if (!hasUsableCoordinates(location.latitude, location.longitude)) {
    return false;
  }
  final hash3 = encodeGeohash(
    location.latitude!,
    location.longitude!,
    precision: 3,
  );
  final hash4 = encodeGeohash(
    location.latitude!,
    location.longitude!,
    precision: 4,
  );
  final elapsed = Stopwatch()..start();
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (isActive?.call() == false || elapsed.elapsed >= timeout) return false;
    try {
      final data = await loadDocument(
        result.matchId,
      ).timeout(timeout - elapsed.elapsed);
      if (data?['geoHash3'] == hash3 && data?['geoHash4'] == hash4) return true;
    } on TimeoutException {
      return false;
    } catch (_) {
      // Creation/edit already succeeded. A read failure must not undo that.
    }
    if (attempt + 1 < maxAttempts) {
      final remaining = timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) return false;
      await Future<void>.delayed(delay < remaining ? delay : remaining);
    }
  }
  return false;
}
