import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? friendDate(Object? value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
    ? value
    : null;

enum FriendDirection { none, incoming, outgoing, mutual }

class RelationshipPolicy {
  final String status;
  final FriendDirection direction;
  final bool interactionAllowed;
  final bool blockedByViewer;

  const RelationshipPolicy({
    this.status = 'none',
    this.direction = FriendDirection.none,
    this.interactionAllowed = true,
    this.blockedByViewer = false,
  });

  factory RelationshipPolicy.fromMap(Map<dynamic, dynamic> data) =>
      RelationshipPolicy(
        status: data['status']?.toString() ?? 'none',
        direction: FriendDirection.values.firstWhere(
          (value) => value.name == data['direction'],
          orElse: () => FriendDirection.none,
        ),
        interactionAllowed: data['interactionAllowed'] == true,
        blockedByViewer: data['blockedByViewer'] == true,
      );
}

class FriendView {
  final String otherUid;
  final String friendshipId;
  final String status;
  final FriendDirection direction;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;

  const FriendView({
    required this.otherUid,
    required this.friendshipId,
    required this.status,
    required this.direction,
    this.createdAt,
    this.updatedAt,
    this.acceptedAt,
  });

  factory FriendView.fromMap(Map<String, dynamic> data, String id) =>
      FriendView(
        otherUid: data['otherUid']?.toString() ?? id,
        friendshipId: data['friendshipId']?.toString() ?? '',
        status: data['status']?.toString() ?? '',
        direction: FriendDirection.values.firstWhere(
          (value) => value.name == data['direction'],
          orElse: () => FriendDirection.none,
        ),
        createdAt: friendDate(data['createdAt']),
        updatedAt: friendDate(data['updatedAt']),
        acceptedAt: friendDate(data['acceptedAt']),
      );
}
