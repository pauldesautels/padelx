import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

String avatarStoragePath(String uid, int version) =>
    'profileAvatars/$uid/avatar.jpg';

String avatarInitials(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '';
  return [
    parts.first,
    if (parts.length > 1) parts.last,
  ].map((part) => part.characters.first.toUpperCase()).join();
}

class ProfileAvatar extends StatelessWidget {
  final String uid;
  final String displayName;
  final int avatarVersion;
  final double radius;
  final bool deleted;

  const ProfileAvatar({
    super.key,
    required this.uid,
    required this.displayName,
    this.avatarVersion = 0,
    this.radius = 20,
    this.deleted = false,
  });

  Widget _fallback() => CircleAvatar(
    radius: radius,
    child: deleted || avatarInitials(displayName).isEmpty
        ? const Icon(Icons.person_outline)
        : Text(avatarInitials(displayName)),
  );

  @override
  Widget build(BuildContext context) {
    if (deleted || uid.isEmpty || avatarVersion <= 0) return _fallback();
    final reference = FirebaseStorage.instance.ref(
      avatarStoragePath(uid, avatarVersion),
    );
    return FutureBuilder<String>(
      future: reference.getDownloadURL(),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return _fallback();
        return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage('$url&v=$avatarVersion'),
          onBackgroundImageError: (_, _) {},
        );
      },
    );
  }
}
