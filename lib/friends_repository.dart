import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'friends.dart';
import 'played_with.dart';

class FriendsPage {
  final List<FriendView> views;
  final Map<String, PlayedWithPublicProfile> profiles;
  final Object? cursor;
  final bool hasMore;
  const FriendsPage({
    this.views = const [],
    this.profiles = const {},
    this.cursor,
    this.hasMore = false,
  });
}

abstract class FriendsRepository {
  Future<FriendsPage> loadPage(
    String viewerUid, {
    required String status,
    FriendDirection? direction,
    Object? cursor,
    int pageSize = 20,
  });
  Future<RelationshipPolicy> policy(String targetUid);
  Future<void> requestFriend(String targetUid);
  Future<void> respond(String requesterUid, bool accept);
  Future<void> cancel(String targetUid);
  Future<void> remove(String targetUid);
  Future<void> block(String targetUid);
  Future<void> unblock(String targetUid);
}

class FirebaseFriendsRepository implements FriendsRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  FirebaseFriendsRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       functions = functions ?? FirebaseFunctions.instance;

  Future<void> _call(String name, Map<String, Object> data) async {
    await functions.httpsCallable(name).call(data);
  }

  @override
  Future<FriendsPage> loadPage(
    String viewerUid, {
    required String status,
    FriendDirection? direction,
    Object? cursor,
    int pageSize = 20,
  }) async {
    Query<Map<String, dynamic>> query = firestore
        .collection('users')
        .doc(viewerUid)
        .collection('friendViews')
        .where('status', isEqualTo: status);
    if (direction != null) {
      query = query.where('direction', isEqualTo: direction.name);
    }
    query = query
        .orderBy(
          status == 'accepted' ? 'acceptedAt' : 'createdAt',
          descending: true,
        )
        .limit(pageSize + 1);
    if (cursor is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(cursor);
    }
    final snapshot = await query.get();
    final docs = snapshot.docs.take(pageSize).toList();
    final views = docs
        .map((doc) => FriendView.fromMap(doc.data(), doc.id))
        .toList();
    final profiles = <String, PlayedWithPublicProfile>{};
    final ids = views.map((view) => view.otherUid).toList();
    for (var offset = 0; offset < ids.length; offset += 30) {
      final chunk = ids.sublist(offset, (offset + 30).clamp(0, ids.length));
      final result = await firestore
          .collection('publicProfiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in result.docs) {
        if (doc.data()['deleted'] != true) {
          profiles[doc.id] = PlayedWithPublicProfile.fromMap(
            doc.id,
            doc.data(),
          );
        }
      }
    }
    return FriendsPage(
      views: views,
      profiles: profiles,
      cursor: docs.isEmpty ? cursor : docs.last,
      hasMore: snapshot.docs.length > pageSize,
    );
  }

  @override
  Future<RelationshipPolicy> policy(String targetUid) async {
    final response = await functions
        .httpsCallable('getRelationshipPolicies')
        .call({
          'targetUids': [targetUid],
        });
    final root = Map<dynamic, dynamic>.from(response.data as Map);
    final policies = Map<dynamic, dynamic>.from(
      root['policies'] as Map? ?? const {},
    );
    return RelationshipPolicy.fromMap(
      Map<dynamic, dynamic>.from(policies[targetUid] as Map? ?? const {}),
    );
  }

  @override
  Future<void> requestFriend(String uid) =>
      _call('requestFriend', {'targetUid': uid});
  @override
  Future<void> respond(String uid, bool accept) => _call(
    'respondToFriendRequest',
    {'targetUid': uid, 'action': accept ? 'accept' : 'decline'},
  );
  @override
  Future<void> cancel(String uid) =>
      _call('cancelFriendRequest', {'targetUid': uid});
  @override
  Future<void> remove(String uid) => _call('removeFriend', {'targetUid': uid});
  @override
  Future<void> block(String uid) => _call('blockPlayer', {'targetUid': uid});
  @override
  Future<void> unblock(String uid) =>
      _call('unblockPlayer', {'targetUid': uid});
}
