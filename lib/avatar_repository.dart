import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

import 'profile_avatar.dart';

const int avatarMaxInputBytes = 5 * 1024 * 1024;
const int avatarOutputDimension = 512;
const int avatarJpegQuality = 85;
const Set<String> avatarInputMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
};

class AvatarValidationException implements Exception {
  final String message;
  const AvatarValidationException(this.message);
  @override
  String toString() => message;
}

Uint8List normalizeAvatar(Uint8List bytes, {required String mimeType}) {
  if (!avatarInputMimeTypes.contains(mimeType.toLowerCase())) {
    throw const AvatarValidationException('Choose a JPEG, PNG, or WebP image.');
  }
  if (bytes.isEmpty || bytes.length > avatarMaxInputBytes) {
    throw const AvatarValidationException(
      'The image must be smaller than 5 MB.',
    );
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const AvatarValidationException(
      'The selected file is not a valid image.',
    );
  }
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final square = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final resized = img.copyResize(
    square,
    width: avatarOutputDimension,
    height: avatarOutputDimension,
    interpolation: img.Interpolation.cubic,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: avatarJpegQuality));
}

class AvatarRepository {
  final FirebaseStorage storage;
  final FirebaseFirestore firestore;

  AvatarRepository({FirebaseStorage? storage, FirebaseFirestore? firestore})
    : storage = storage ?? FirebaseStorage.instance,
      firestore = firestore ?? FirebaseFirestore.instance;

  Future<int> replace({
    required String uid,
    required int currentVersion,
    required Uint8List jpegBytes,
  }) async {
    final nextVersion = DateTime.now().microsecondsSinceEpoch;
    final avatar = storage.ref(avatarStoragePath(uid, nextVersion));
    await avatar.putData(
      jpegBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=31536000,immutable',
      ),
    );
    // The deterministic object is already valid if the profile batch fails.
    // Retrying the batch recovers without a missing reference or an orphan.
    await _updateVersion(uid, nextVersion);
    return nextVersion;
  }

  Future<void> remove({
    required String uid,
    required int currentVersion,
  }) async {
    await _updateVersion(uid, 0);
    if (currentVersion > 0) {
      await storage.ref(avatarStoragePath(uid, currentVersion)).delete();
    }
  }

  Future<void> _updateVersion(String uid, int version) async {
    final batch = firestore.batch();
    batch.update(firestore.collection('users').doc(uid), {
      'avatarVersion': version,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(firestore.collection('publicProfiles').doc(uid), {
      'avatarVersion': version,
    });
    await batch.commit();
  }
}
