import 'package:cloud_functions/cloud_functions.dart';
import 'player_discovery.dart';

abstract class PlayerDiscoveryRepository {
  Future<PlayerDiscoveryPage> discover(
    PlayerDiscoveryFilters filters, {
    Object? cursor,
  });
}

class FirebasePlayerDiscoveryRepository implements PlayerDiscoveryRepository {
  final FirebaseFunctions functions;
  FirebasePlayerDiscoveryRepository({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;
  @override
  Future<PlayerDiscoveryPage> discover(
    PlayerDiscoveryFilters filters, {
    Object? cursor,
  }) async {
    final response = await functions
        .httpsCallable('discoverPlayers')
        .call(filters.toMap(cursor: cursor));
    final data = Map<dynamic, dynamic>.from(response.data as Map);
    return PlayerDiscoveryPage(
      players: (data['players'] as List? ?? const [])
          .map(
            (item) => DiscoveredPlayer.fromMap(
              Map<dynamic, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      cursor: data['cursor'],
      hasMore: data['hasMore'] == true,
      noLocation: data['noLocation'] == true,
    );
  }
}
