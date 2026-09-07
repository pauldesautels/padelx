import 'package:flutter/material.dart';
import 'conversation_screen.dart';
import 'messaging.dart';
import 'messaging_repository.dart';
import 'profile_avatar.dart';

class MessagesScreen extends StatefulWidget {
  final String currentUid;
  final MessagingRepository repository;
  const MessagesScreen({
    super.key,
    required this.currentUid,
    required this.repository,
  });
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<ConversationSummary> _items = [];
  final Map<String, String> _direct = {}, _matches = {};
  final Map<String, int> _avatars = {};
  String? _cursor;
  bool _loading = true, _more = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
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
      if (!append) _items.clear();
      _items.addAll(page.conversations);
      _direct.addAll(direct);
      _matches.addAll(matches);
      _avatars.addAll(avatars);
      _cursor = page.cursor;
      _more = page.hasMore;
      _loading = false;
    });
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
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
              ),
              if (_more)
                TextButton(
                  key: const Key('load-older-conversations'),
                  onPressed: () => _load(append: true),
                  child: const Text('Load older'),
                ),
            ],
          ),
  );
}
