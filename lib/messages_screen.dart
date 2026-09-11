import 'dart:async';

import 'package:flutter/material.dart';
import 'conversation_screen.dart';
import 'firebase_diagnostics.dart';
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
  final Map<String, MessagingIdentity> _players = {};
  final Map<String, String> _matches = {};
  String? _cursor;
  StreamSubscription<String>? _invalidationSubscription;
  String? _invalidationBaseline;
  int _listenerGeneration = 0;
  bool _loading = true,
      _loadingOlder = false,
      _more = false,
      _refreshing = false,
      _refreshPending = false;
  bool _initialLoadFailed = false;
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
          onError: (Object error) {
            debugPrint(
              'Messages inbox notification listener failed '
              '${safeFirebaseFailure(error)}.',
            );
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
      final players = await widget.repository.playerIdentities(
        page.conversations.map((c) => c.otherUid ?? ''),
      );
      final matches = await widget.repository.matchNames(
        page.conversations.map((c) => c.matchId ?? ''),
      );
      if (!mounted) return;
      setState(() {
        if (!append) {
          _items.clear();
          _players.clear();
          _matches.clear();
        }
        _items.addAll(page.conversations);
        _players.addAll(players);
        _matches.addAll(matches);
        _cursor = page.cursor;
        _more = page.hasMore;
        _loading = false;
        _initialLoadFailed = false;
      });
    } catch (_) {
      debugPrint('Messages inbox $source load failed.');
      if (mounted) {
        setState(() {
          _loading = false;
          if (_items.isEmpty) _initialLoadFailed = true;
        });
      }
    }
  }

  String _title(ConversationSummary c) => c.type == 'direct'
      ? (_players[c.otherUid]?.displayName ?? 'Player')
      : (_matches[c.matchId] ?? 'Match chat');
  void _retry() {
    setState(() {
      _loading = true;
      _initialLoadFailed = false;
    });
    unawaited(_refresh(source: 'retry'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Messages')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _initialLoadFailed
        ? Center(
            key: const Key('conversation-list-error'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Messages are unavailable right now.'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _retry, child: const Text('Try Again')),
              ],
            ),
          )
        : _items.isEmpty
        ? const Center(
            key: Key('conversation-list-empty'),
            child: Text('No conversations yet.'),
          )
        : ListView(
            children: [
              ..._items.map((c) {
                final title = _title(c);
                final unread = c.unreadCount > 0;
                final identity = _players[c.otherUid];
                final timestamp = messagingInboxTime(c.lastMessageAt);
                return Semantics(
                  label: [
                    c.type == 'match' ? '$title, Match Chat' : title,
                    c.preview.isEmpty ? 'No messages yet' : c.preview,
                    if (timestamp.isNotEmpty) timestamp,
                    if (unread) '${c.unreadCount} unread messages',
                  ].join(', '),
                  button: true,
                  excludeSemantics: true,
                  child: ListTile(
                    key: Key('conversation-${c.id}'),
                    leading: c.type == 'direct'
                        ? ProfileAvatar(
                            uid: c.otherUid ?? '',
                            displayName: title,
                            avatarVersion: identity?.avatarVersion ?? 0,
                          )
                        : const CircleAvatar(
                            backgroundColor: Color(0xFF16382E),
                            child: Icon(Icons.sports_tennis),
                          ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (timestamp.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timestamp,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.type == 'match')
                          const Text(
                            'Match Chat',
                            style: TextStyle(
                              color: Color(0xFF72F58B),
                              fontSize: 12,
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.preview.isEmpty
                                    ? 'No messages yet'
                                    : c.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (unread) ...[
                              const SizedBox(width: 8),
                              Badge(label: Text('${c.unreadCount}')),
                            ],
                          ],
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ConversationScreen(
                            conversationId: c.id,
                            currentUid: widget.currentUid,
                            title: title,
                            repository: widget.repository,
                            otherUid: c.type == 'direct' ? c.otherUid : null,
                            avatarVersion: identity?.avatarVersion ?? 0,
                            conversationType: c.type,
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
                );
              }),
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
