import 'package:cloud_firestore/cloud_firestore.dart';

import 'played_with.dart';

abstract class PlayedWithRepository {
  Future<PlayedWithPage> loadPage(
    String viewerUid, {
    Object? cursor,
    int pageSize = 20,
  });

  Future<PlayedWithRelationship?> relationship(
    String viewerUid,
    String otherUid,
  );
}

class FirestorePlayedWithRepository implements PlayedWithRepository {
  final FirebaseFirestore firestore;
  final PlayedWithFilter? filter;
  final int profileBatchSize;

  FirestorePlayedWithRepository({
    FirebaseFirestore? firestore,
    this.filter,
    this.profileBatchSize = 30,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<PlayedWithPage> loadPage(
    String viewerUid, {
    Object? cursor,
    int pageSize = 20,
  }) async {
    if (viewerUid.isEmpty || pageSize <= 0) return const PlayedWithPage();
    Query<Map<String, dynamic>> query = firestore
        .collection('users')
        .doc(viewerUid)
        .collection('playedWith')
        .orderBy('lastPlayedAt', descending: true)
        .limit(pageSize + 1);
    if (cursor is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(cursor);
    }
    final snapshot = await query.get();
    final relationshipDocs = snapshot.docs.take(pageSize).toList();
    final relationships = relationshipDocs
        .map(
          (doc) =>
              PlayedWithRelationship.fromMap(doc.data(), documentId: doc.id),
        )
        .where((item) => item.otherUid.isNotEmpty)
        .toList();
    final profiles = await _loadProfiles(
      relationships.map((item) => item.otherUid).toSet().toList(),
    );
    var players = relationships
        .where((item) => profiles.containsKey(item.otherUid))
        .map(
          (item) => PlayedWithPlayer(
            relationship: item,
            profile: profiles[item.otherUid]!,
          ),
        )
        .toList();
    players = sortPlayedWithPlayers(players);
    if (filter != null) players = await filter!(players);
    return PlayedWithPage(
      players: players,
      cursor: relationshipDocs.isEmpty ? cursor : relationshipDocs.last,
      hasMore: snapshot.docs.length > pageSize,
    );
  }

  Future<Map<String, PlayedWithPublicProfile>> _loadProfiles(
    List<String> ids,
  ) async {
    final result = <String, PlayedWithPublicProfile>{};
    final safeChunkSize = profileBatchSize.clamp(1, 30);
    for (var offset = 0; offset < ids.length; offset += safeChunkSize) {
      final end = (offset + safeChunkSize).clamp(0, ids.length);
      final chunk = ids.sublist(offset, end);
      final snapshot = await firestore
          .collection('publicProfiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final document in snapshot.docs) {
        final data = document.data();
        if (data['deleted'] == true) continue;
        final profile = PlayedWithPublicProfile.fromMap(document.id, data);
        if (profile.displayName.isNotEmpty) result[document.id] = profile;
      }
    }
    return result;
  }

  @override
  Future<PlayedWithRelationship?> relationship(
    String viewerUid,
    String otherUid,
  ) async {
    if (viewerUid.isEmpty || otherUid.isEmpty || viewerUid == otherUid) {
      return null;
    }
    final document = await firestore
        .collection('users')
        .doc(viewerUid)
        .collection('playedWith')
        .doc(otherUid)
        .get();
    return document.exists
        ? PlayedWithRelationship.fromMap(
            document.data() ?? const {},
            documentId: document.id,
          )
        : null;
  }
}
