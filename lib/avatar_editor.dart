import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'avatar_repository.dart';
import 'profile_avatar.dart';
import 'l10n/l10n.dart';

class AvatarEditor extends StatefulWidget {
  final String uid;
  final String displayName;
  final int avatarVersion;
  final ValueChanged<int> onChanged;
  final AvatarRepository? repository;

  const AvatarEditor({
    super.key,
    required this.uid,
    required this.displayName,
    required this.avatarVersion,
    required this.onChanged,
    this.repository,
  });

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  Uint8List? _preview;
  bool _busy = false;

  Future<void> _choose() async {
    final selected = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final mime = selected.mimeType ?? _mimeFromName(selected.name);
      final normalized = normalizeAvatar(
        await selected.readAsBytes(),
        mimeType: mime,
      );
      if (!mounted) return;
      setState(() => _preview = normalized);
    } on AvatarValidationException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Could not read that image.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final bytes = _preview;
    if (bytes == null || _busy) return;
    setState(() => _busy = true);
    try {
      final version = await (widget.repository ?? AvatarRepository()).replace(
        uid: widget.uid,
        currentVersion: widget.avatarVersion,
        jpegBytes: bytes,
      );
      if (!mounted) return;
      setState(() => _preview = null);
      widget.onChanged(version);
      _message('Profile photo updated.');
    } catch (_) {
      _message('Could not update your profile photo. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    if (_busy || widget.avatarVersion <= 0) return;
    setState(() => _busy = true);
    try {
      await (widget.repository ?? AvatarRepository()).remove(
        uid: widget.uid,
        currentVersion: widget.avatarVersion,
      );
      widget.onChanged(0);
      _message('Profile photo removed.');
    } catch (_) {
      _message('Could not remove your profile photo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg')
        ? 'image/jpeg'
        : '';
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_preview != null)
        CircleAvatar(radius: 54, backgroundImage: MemoryImage(_preview!))
      else
        ProfileAvatar(
          uid: widget.uid,
          displayName: widget.displayName,
          avatarVersion: widget.avatarVersion,
          radius: 54,
        ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          OutlinedButton.icon(
            key: const Key('choose-avatar'),
            onPressed: _busy ? null : _choose,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              _preview == null
                  ? context.l10n.choosePhoto
                  : context.l10n.chooseAnotherPhoto,
            ),
          ),
          if (_preview != null)
            FilledButton(
              key: const Key('upload-avatar'),
              onPressed: _busy ? null : _upload,
              child: Text(context.l10n.usePhoto),
            ),
          if (_preview == null && widget.avatarVersion > 0)
            TextButton(
              key: const Key('remove-avatar'),
              onPressed: _busy ? null : _remove,
              child: Text(context.l10n.remove),
            ),
        ],
      ),
      Text(
        context.l10n.photoCropHelp,
        style: TextStyle(color: Colors.white60, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ],
  );
}
