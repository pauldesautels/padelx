import 'package:flutter/material.dart';
import 'messaging.dart';
import 'messaging_repository.dart';
import 'profile_avatar.dart';

class ConversationScreen extends StatefulWidget {
  final String conversationId;
  final String currentUid;
  final String title;
  final MessagingRepository repository;
  final String? otherUid;
  final int avatarVersion;
  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.currentUid,
    required this.title,
    required this.repository,
    this.otherUid,
    this.avatarVersion = 0,
  });
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  String? _cursor;
  bool _loading = true,
      _loadingOlder = false,
      _sending = false,
      _hasMore = false,
      _canSend = true;
  String? _disabledReason;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final page = await widget.repository.messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _canSend = page.canSend;
        _disabledReason = page.disabledReason;
        _loading = false;
      });
      await widget.repository.markRead(widget.conversationId);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _older() async {
    if (_loadingOlder || !_hasMore) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await widget.repository.messages(
        widget.conversationId,
        before: _cursor,
      );
      if (mounted) {
        setState(() {
          _messages.addAll(page.messages);
          _cursor = page.cursor;
          _hasMore = page.hasMore;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
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
      await _load();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          if (widget.otherUid != null) ...[
            ProfileAvatar(
              uid: widget.otherUid!,
              displayName: widget.title,
              avatarVersion: widget.avatarVersion,
              radius: 16,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(widget.title)),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('refresh-conversation'),
          tooltip: 'Refresh messages',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? const Center(
                  key: Key('messages-empty-state'),
                  child: Text('No messages yet. Say hello!'),
                )
              : ListView.builder(
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
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        color: mine ? Colors.green.shade800 : null,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(message.text),
                              const SizedBox(height: 3),
                              Text(
                                messagingTime(message.createdAt),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('message-composer'),
                      controller: _controller,
                      maxLength: 1000,
                      maxLines: 4,
                      minLines: 1,
                      decoration: const InputDecoration(hintText: 'Message'),
                    ),
                  ),
                  IconButton(
                    key: const Key('send-message'),
                    onPressed: _sending ? null : _send,
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
