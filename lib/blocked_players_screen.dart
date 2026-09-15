import 'package:flutter/material.dart';

import 'friends.dart';
import 'friends_repository.dart';
import 'level.dart';
import 'profile_avatar.dart';
import 'l10n/l10n.dart';

class BlockedPlayersScreen extends StatefulWidget {
  final FriendsRepository repository;

  const BlockedPlayersScreen({super.key, required this.repository});

  @override
  State<BlockedPlayersScreen> createState() => _BlockedPlayersScreenState();
}

class _BlockedPlayersScreenState extends State<BlockedPlayersScreen> {
  final List<BlockedPlayer> _players = [];
  final Set<String> _unblocking = {};
  Object? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      final page = await widget.repository.loadBlockedPlayers(
        cursor: reset ? null : _cursor,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _players.clear();
        final known = _players.map((player) => player.uid).toSet();
        _players.addAll(page.players.where((player) => known.add(player.uid)));
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(BlockedPlayer player) async {
    if (_unblocking.contains(player.uid)) return;
    setState(() => _unblocking.add(player.uid));
    try {
      await widget.repository.unblock(player.uid);
      if (!mounted) return;
      setState(() => _players.removeWhere((item) => item.uid == player.uid));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.unblockedNotice)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.socialUnavailable)));
      }
    } finally {
      if (mounted) setState(() => _unblocking.remove(player.uid));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.blockedPlayers)),
    body: _players.isEmpty && _loading
        ? const Center(child: CircularProgressIndicator())
        : _players.isEmpty && _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.blockedPlayersUnavailable),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _load(reset: true),
                    child: Text(context.l10n.tryAgain),
                  ),
                ],
              ),
            ),
          )
        : _players.isEmpty
        ? Center(child: Text(context.l10n.noBlockedPlayers))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _players.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _players.length) {
                return Center(
                  child: TextButton(
                    key: const Key('blocked-players-load-more'),
                    onPressed: _loading ? null : _load,
                    child: Text(
                      _loading
                          ? context.l10n.loadingEllipsis
                          : context.l10n.loadMore,
                    ),
                  ),
                );
              }
              final player = _players[index];
              final busy = _unblocking.contains(player.uid);
              return ListTile(
                key: ValueKey('blocked-player-${player.uid}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                leading: player.unavailable
                    ? const CircleAvatar(child: Icon(Icons.person_off_outlined))
                    : ProfileAvatar(
                        uid: player.uid,
                        displayName: player.displayName,
                        avatarVersion: player.avatarVersion,
                      ),
                title: Text(player.displayName),
                subtitle: Text(
                  player.unavailable
                      ? context.l10n.profileUnavailable
                      : player.level.isEmpty
                      ? context.l10n.levelNotSet
                      : padelLevelLabel(player.level),
                ),
                trailing: OutlinedButton(
                  key: ValueKey('unblock-${player.uid}'),
                  onPressed: busy ? null : () => _unblock(player),
                  child: Text(
                    busy
                        ? context.l10n.unblockingEllipsis
                        : context.l10n.unblock,
                  ),
                ),
              );
            },
          ),
  );
}
