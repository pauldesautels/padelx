import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:padelx/avatar_repository.dart';
import 'package:padelx/profile_avatar.dart';

void main() {
  test('avatar path is deterministic and versioned', () {
    expect(avatarStoragePath('alice', 42), 'profileAvatars/alice/avatar.jpg');
  });

  test('initials support fallback and legacy profiles', () {
    expect(avatarInitials('Ada Lovelace'), 'AL');
    expect(avatarInitials('Pelé'), 'P');
    expect(avatarInitials(''), '');
  });

  test('normalization center-crops to static 512 JPEG', () {
    final source = img.Image(width: 900, height: 600);
    final bytes = Uint8List.fromList(img.encodePng(source));
    final output = normalizeAvatar(bytes, mimeType: 'image/png');
    final decoded = img.decodeJpg(output)!;
    expect(decoded.width, avatarOutputDimension);
    expect(decoded.height, avatarOutputDimension);
    expect(output.length, lessThan(avatarMaxInputBytes));
  });

  test('wrong file type is rejected', () {
    expect(
      () => normalizeAvatar(Uint8List.fromList([1]), mimeType: 'image/gif'),
      throwsA(isA<AvatarValidationException>()),
    );
  });

  test('oversized input is rejected before decoding', () {
    expect(
      () => normalizeAvatar(
        Uint8List(avatarMaxInputBytes + 1),
        mimeType: 'image/jpeg',
      ),
      throwsA(isA<AvatarValidationException>()),
    );
  });
}
