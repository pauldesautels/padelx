import 'dart:async';

import 'package:flutter/material.dart';
import 'conversation_screen.dart';
import 'messaging.dart';
import 'messaging_repository.dart';
import 'profile_avatar.dart';

class MessagesScreen extends StatefulWidget {
  final String currentUid;
  final MessagingRepository repository;
  final ConversationNotificationStream? conversationNotificationStream;
  const MessagesScreen({
    super.key,
    required this.currentUid,
    required this.repository,
    this.conversationNotificationStream,
  });
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<ConversationSummary> _items = [];
  final Map<String, String> _direct = {}, _matches = {};
  final Map<String, int> _avatars = {};
  String? _cursor;
  StreamSubscription<String>? _invalidationSubscription;
  String? _invalidationBaseline;
  int _listenerGeneration = 0;
  bool _loading = true,
      _loadingOlder = false,
      _more = false,
      _refreshing = false,
      _refreshPending = false;
  @override
  void initState() {
    super.initState();
    _startInvalidationListener();
    unawaited(_refresh(source: 'initial'));
  }

  void _startInvalidationListener() {
    _invalidationBaseline = null;
    _invalidationSubscription = widget.repository
        .watchInboxInvalidations(widget.currentUid)
        .listen(
          (version) {
            if (_invalidationBaseline == null) {
              _invalidationBaseline = version;
              return;
            }
            if (_invalidationBaseline == version) return;
            _invalidationBaseline = version;
            unawaited(_refresh(source: 'notification'));
          },
          onError: (Object _) {
            debugPrint('Messages inbox notification listener failed.');
          },
        );
  }

  Future<void> _restartInvalidationListener(int generation) async {
    final previous = _invalidationSubscription;
    _invalidationSubscription = null;
    await previous?.cancel();
    if (!mounted || generation != _listenerGeneration) return;
    _startInvalidationListener();
    await _refresh(source: 'identity-change');
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUid != widget.currentUid ||
        oldWidget.repository != widget.repository) {
      _listenerGeneration++;
      unawaited(_restartInvalidationListener(_listenerGeneration));
    }
  }

  @override
  void dispose() {
    _listenerGeneration++;
    unawaited(_invalidationSubscription?.cancel());
    super.dispose();
  }

  Future<void> _refresh({required String source}) async {
    if (_refreshing || _loadingOlder) {
      _refreshPending = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshPending = false;
        await _loadPage(source: source);
      } while (mounted && _refreshPending);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _refreshing || !_more) return;
    setState(() => _loadingOlder = true);
    try {
      await _loadPage(append: true, source: 'pagination');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
      if (_refreshPending) unawaited(_refresh(source: 'queued'));
    }
  }

  Future<void> _loadPage({bool append = false, required String source}) async {
    try {
      final page = await widget.repository.conversations(
        before: append ? _cursor : null,
      );
      final direct = await widget.repository.directNames(
        page.conversations.map((c) => c.otherUid ?? ''),
      );
      final matches = await widget.repository.matchNames(
        page.conversations.map((c) => c.matchId ?? ''),
      );
      final avatars = widget.repository is FirebaseMessagingRepository
          ? await (widget.repository as FirebaseMessagingRepository)
                .directAvatarVersions(
                  page.conversations.map((c) => c.otherUid ?? ''),
                )
          : const <String, int>{};
      if (!mounted) return;
      setState(() {
        if (!append) {
          _items.clear();
          _direct.clear();
          _matches.clear();
          _avatars.clear();
        }
        _items.addAll(page.conversations);
        _direct.addAll(direct);
        _matches.addAll(matches);
        _avatars.addAll(avatars);
        _cursor = page.cursor;
        _more = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      debugPrint('Messages inbox $source load failed.');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _title(ConversationSummary c) => c.type == 'direct'
      ? (_direct[c.otherUid] ?? 'Player')
      : (_matches[c.matchId] ?? 'Match chat');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Messages')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
        ? const Center(
            key: Key('conversation-list-empty'),
            child: Text('No conversations yet.'),
          )
        : ListView(
            children: [
              ..._items.map(
                (c) => ListTile(
                  key: Key('conversation-${c.id}'),
                  leading: c.type == 'direct'
                      ? ProfileAvatar(
                          uid: c.otherUid ?? '',
                          displayName: _title(c),
                          avatarVersion: _avatars[c.otherUid] ?? 0,
                        )
                      : const CircleAvatar(child: Icon(Icons.sports_tennis)),
                  title: Text(_title(c)),
                  subtitle: Text(
                    c.preview.isEmpty ? 'No messages yet' : c.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: c.unreadCount > 0
                      ? Badge(label: Text('${c.unreadCount}'))
                      : Text(messagingTime(c.lastMessageAt)),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConversationScreen(
                          conversationId: c.id,
                          currentUid: widget.currentUid,
                          title: _title(c),
                          repository: widget.repository,
                          otherUid: c.type == 'direct' ? c.otherUid : null,
                          avatarVersion: _avatars[c.otherUid] ?? 0,
                          notificationStream:
                              widget.conversationNotificationStream,
                        ),
                      ),
                    );
                    if (mounted) {
                      unawaited(_refresh(source: 'conversation-return'));
                    }
                  },
                ),
              ),
              if (_more)
                TextButton(
                  key: const Key('load-older-conversations'),
                  onPressed: _loadingOlder ? null : _loadOlder,
                  child: Text(_loadingOlder ? 'Loading…' : 'Load older'),
                ),
            ],
          ),
  );
}
