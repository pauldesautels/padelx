import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'firebase_diagnostics.dart';
import 'messaging.dart';
import 'messaging_repository.dart';
import 'profile_avatar.dart';

typedef ConversationNotificationStream =
    Stream<Map<String, dynamic>?> Function(
      String conversationId,
      String currentUid,
    );

class ConversationScreen extends StatefulWidget {
  final String conversationId;
  final String currentUid;
  final String title;
  final MessagingRepository repository;
  final String? otherUid;
  final int avatarVersion;
  final String? conversationType;
  final ConversationNotificationStream? notificationStream;
  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.currentUid,
    required this.title,
    required this.repository,
    this.otherUid,
    this.avatarVersion = 0,
    this.conversationType,
    this.notificationStream,
  });
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Map<String, MessagingIdentity> _identities = {};
  String? _cursor;
  bool _loading = true,
      _loadingOlder = false,
      _sending = false,
      _hasMore = false,
      _canSend = true,
      _refreshing = false,
      _refreshPending = false,
      _initialLoadFailed = false,
      _conversationUnavailable = false,
      _hasLoadedOlder = false;
  String? _disabledReason;
  StreamSubscription<Map<String, dynamic>?>? _notificationSubscription;
  String? _lastHandledNotification;

  @override
  void initState() {
    super.initState();
    _startNotificationListener();
    _controller.addListener(_composerChanged);
    unawaited(_load(source: 'initial'));
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _controller.removeListener(_composerChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startNotificationListener() {
    if (_notificationSubscription != null) return;
    final stream =
        widget.notificationStream?.call(
          widget.conversationId,
          widget.currentUid,
        ) ??
        FirebaseFirestore.instance
            .doc(
              'notifications/message_${widget.conversationId}_${widget.currentUid}',
            )
            .snapshots()
            .map((snapshot) => snapshot.data());
    _notificationSubscription = stream.listen(
      _handleNotification,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'Conversation notification listener failed '
          '${safeFirebaseFailure(error)}.',
        );
      },
    );
  }

  void _handleNotification(Map<String, dynamic>? notification) {
    if (notification == null || notification['isRead'] != false) return;
    if (notification['recipientUid'] != widget.currentUid ||
        notification['conversationId'] != widget.conversationId) {
      return;
    }
    final actorUid = notification['actorUid']?.toString();
    if (actorUid == null || actorUid.isEmpty || actorUid == widget.currentUid) {
      return;
    }
    final createdAt = notification['createdAt'];
    final createdKey = switch (createdAt) {
      Timestamp value => '${value.seconds}:${value.nanoseconds}',
      DateTime value => value.microsecondsSinceEpoch.toString(),
      _ => createdAt?.toString(),
    };
    if (createdKey == null) return;
    final notificationKey = '$actorUid:$createdKey';
    if (_lastHandledNotification == notificationKey) return;
    _lastHandledNotification = notificationKey;
    unawaited(_load(source: 'notification'));
  }

  Future<void> _load({String source = 'refresh'}) async {
    if (_refreshing || _loadingOlder) {
      _refreshPending = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshPending = false;
        await _loadLatest(source);
      } while (mounted && _refreshPending);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadLatest(String source) async {
    final preserveScroll =
        _scrollController.hasClients && _scrollController.offset > 80;
    final oldOffset = preserveScroll ? _scrollController.offset : 0.0;
    final oldExtent = preserveScroll
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    try {
      final page = await widget.repository.messages(widget.conversationId);
      final missingSenders = page.messages
          .map((message) => message.senderUid)
          .where(
            (uid) =>
                uid.isNotEmpty &&
                uid != widget.currentUid &&
                !_identities.containsKey(uid),
          );
      Map<String, MessagingIdentity> identities = const {};
      try {
        identities = await widget.repository.playerIdentities(missingSenders);
      } catch (error) {
        debugPrint(
          'Conversation sender identity load failed: ${error.runtimeType}.',
        );
      }
      if (!mounted) return;
      setState(() {
        if (_hasLoadedOlder) {
          final freshIds = page.messages.map((message) => message.id).toSet();
          final retainedOlder = _messages
              .where((message) => !freshIds.contains(message.id))
              .toList();
          _messages
            ..clear()
            ..addAll(page.messages)
            ..addAll(retainedOlder);
        } else {
          _messages
            ..clear()
            ..addAll(page.messages);
          _cursor = page.cursor;
          _hasMore = page.hasMore;
        }
        _identities.addAll(identities);
        _canSend = page.canSend;
        _disabledReason = page.disabledReason;
        _loading = false;
        _initialLoadFailed = false;
        _conversationUnavailable = false;
      });
      _restoreScroll(preserveScroll, oldOffset, oldExtent);
      try {
        await widget.repository.markRead(widget.conversationId);
      } catch (error) {
        debugPrint('Conversation mark-read failed: ${error.runtimeType}.');
      }
    } catch (error) {
      debugPrint(
        'Conversation $source message load failed: ${error.runtimeType}.',
      );
      if (mounted) {
        setState(() {
          _loading = false;
          if (_messages.isEmpty) {
            _initialLoadFailed = true;
            _conversationUnavailable = _isUnavailableError(error);
          }
        });
      }
    }
  }

  bool _isUnavailableError(Object error) =>
      error is FirebaseFunctionsException &&
      const {
        'permission-denied',
        'not-found',
        'failed-precondition',
      }.contains(error.code);

  void _restoreScroll(bool preserve, double offset, double extent) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (!preserve) {
        _scrollController.jumpTo(0);
        return;
      }
      final newExtent = _scrollController.position.maxScrollExtent;
      final target = (offset + newExtent - extent).clamp(0.0, newExtent);
      _scrollController.jumpTo(target);
    });
  }

  Future<void> _older() async {
    if (_loadingOlder || _refreshing || !_hasMore) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await widget.repository.messages(
        widget.conversationId,
        before: _cursor,
      );
      final missingSenders = page.messages
          .map((message) => message.senderUid)
          .where(
            (uid) =>
                uid.isNotEmpty &&
                uid != widget.currentUid &&
                !_identities.containsKey(uid),
          );
      Map<String, MessagingIdentity> identities = const {};
      try {
        identities = await widget.repository.playerIdentities(missingSenders);
      } catch (error) {
        debugPrint(
          'Conversation sender identity load failed: ${error.runtimeType}.',
        );
      }
      if (mounted) {
        setState(() {
          _messages.addAll(page.messages);
          _identities.addAll(identities);
          _cursor = page.cursor;
          _hasMore = page.hasMore;
          _hasLoadedOlder = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
      if (_refreshPending) unawaited(_load(source: 'queued'));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || text.runes.length > 1000 || _sending) return;
    setState(() => _sending = true);
    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}_${widget.currentUid.hashCode.abs()}';
    try {
      await widget.repository.send(widget.conversationId, text, requestId);
      _controller.clear();
      await _load(source: 'send');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send this message.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _composerChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit {
    final text = _controller.text.trim();
    return !_sending && text.isNotEmpty && text.runes.length <= 1000;
  }

  bool get _isMatch =>
      widget.conversationType == 'match' ||
      (widget.conversationType == null && widget.otherUid == null);

  void _retry() {
    setState(() {
      _loading = true;
      _initialLoadFailed = false;
      _conversationUnavailable = false;
    });
    unawaited(_load(source: 'retry'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          if (_isMatch) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF16382E),
              child: Icon(Icons.sports_tennis, size: 18),
            ),
            const SizedBox(width: 10),
          ] else if (widget.otherUid != null) ...[
            ProfileAvatar(
              uid: widget.otherUid!,
              displayName: widget.title,
              avatarVersion: widget.avatarVersion,
              radius: 16,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _isMatch
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Match Chat',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  )
                : Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('refresh-conversation'),
          tooltip: 'Refresh messages',
          onPressed: () => _load(source: 'manual'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _initialLoadFailed
              ? Center(
                  key: const Key('messages-error-state'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _conversationUnavailable
                            ? 'Conversation unavailable'
                            : 'Messages are unavailable right now.',
                      ),
                      if (!_conversationUnavailable) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ],
                  ),
                )
              : _messages.isEmpty
              ? const Center(
                  key: Key('messages-empty-state'),
                  child: Text('No messages yet. Say hello!'),
                )
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return TextButton(
                        key: const Key('load-older-messages'),
                        onPressed: _older,
                        child: Text(
                          _loadingOlder ? 'Loading…' : 'Load older messages',
                        ),
                      );
                    }
                    final message = _messages[index];
                    final mine = message.senderUid == widget.currentUid;
                    final older = index + 1 < _messages.length
                        ? _messages[index + 1]
                        : null;
                    final newer = index > 0 ? _messages[index - 1] : null;
                    final startsGroup =
                        older == null ||
                        older.senderUid != message.senderUid ||
                        !messagingSameLocalDay(
                          older.createdAt,
                          message.createdAt,
                        );
                    final endsGroup =
                        newer == null ||
                        newer.senderUid != message.senderUid ||
                        !messagingSameLocalDay(
                          newer.createdAt,
                          message.createdAt,
                        );
                    final startsDay =
                        older == null ||
                        !messagingSameLocalDay(
                          older.createdAt,
                          message.createdAt,
                        );
                    final identity =
                        _identities[message.senderUid] ??
                        MessagingIdentity(
                          uid: message.senderUid,
                          displayName: 'Player',
                        );
                    return Column(
                      children: [
                        if (startsDay && message.createdAt != null)
                          _MessageDateSeparator(
                            label: messagingDateSeparator(message.createdAt),
                          ),
                        MessageBubble(
                          key: Key('message-${message.id}'),
                          message: message,
                          mine: mine,
                          identity: identity,
                          showIdentity: !mine && startsGroup,
                          showSenderName: !mine && startsGroup && _isMatch,
                          showTimestamp: endsGroup,
                          grouped: !startsGroup,
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (!_canSend)
          Padding(
            key: const Key('message-composer-disabled'),
            padding: const EdgeInsets.all(12),
            child: Text(
              _disabledReason ?? 'This conversation is read-only.',
              style: const TextStyle(color: Colors.white60),
            ),
          ),
        if (_canSend)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF17231F),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        key: const Key('message-composer'),
                        controller: _controller,
                        maxLength: 1000,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    key: const Key('send-message'),
                    tooltip: 'Send message',
                    onPressed: _canSubmit ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _MessageDateSeparator extends StatelessWidget {
  final String label;

  const _MessageDateSeparator({required this.label});

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final MessagingIdentity identity;
  final bool showIdentity;
  final bool showSenderName;
  final bool showTimestamp;
  final bool grouped;

  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.identity,
    required this.showIdentity,
    required this.showSenderName,
    required this.showTimestamp,
    required this.grouped,
  });

  @override
  Widget build(BuildContext context) {
    final time = messagingTime(message.createdAt);
    final sender = mine ? 'You' : identity.displayName;
    return Semantics(
      label: [sender, message.text, if (time.isNotEmpty) time].join(', '),
      container: true,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(top: grouped ? 3 : 10),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) ...[
              SizedBox(
                width: 36,
                child: showIdentity
                    ? ProfileAvatar(
                        uid: identity.uid,
                        displayName: identity.displayName,
                        avatarVersion: identity.avatarVersion,
                        radius: 15,
                      )
                    : null,
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: FractionallySizedBox(
                key: Key('message-content-${message.id}'),
                widthFactor: 0.78,
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (showSenderName) ...[
                      Text(
                        identity.displayName,
                        key: Key('message-sender-${message.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9FE7B1),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: mine
                            ? const Color(0xFF164B3B)
                            : const Color(0xFF1A2420),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(message.text),
                    ),
                    if (showTimestamp && time.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        time,
                        key: Key('message-time-${message.id}'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
