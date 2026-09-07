import 'package:cloud_functions/cloud_functions.dart';

import 'friends.dart';
import 'played_with.dart';

abstract class RelationshipPolicyService {
  Future<Map<String, RelationshipPolicy>> policies(List<String> targetUids);

  Future<List<PlayedWithPlayer>> filterPlayedWith(
    List<PlayedWithPlayer> players,
  ) async {
    if (players.isEmpty) return players;
    final result = await policies(
      players.map((item) => item.profile.uid).toList(),
    );
    return players
        .where((item) => result[item.profile.uid]?.interactionAllowed != false)
        .toList();
  }
}

class FirebaseRelationshipPolicyService extends RelationshipPolicyService {
  final FirebaseFunctions functions;
  FirebaseRelationshipPolicyService({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<Map<String, RelationshipPolicy>> policies(
    List<String> targetUids,
  ) async {
    if (targetUids.isEmpty) return const {};
    final response = await functions
        .httpsCallable('getRelationshipPolicies')
        .call({'targetUids': targetUids});
    final payload = Map<dynamic, dynamic>.from(response.data as Map);
    final values = Map<dynamic, dynamic>.from(
      payload['policies'] as Map? ?? const {},
    );
    return {
      for (final entry in values.entries)
        entry.key.toString(): RelationshipPolicy.fromMap(
          Map<dynamic, dynamic>.from(entry.value as Map),
        ),
    };
  }
}
