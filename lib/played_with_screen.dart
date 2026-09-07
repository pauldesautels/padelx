import 'package:flutter/material.dart';

import 'played_with.dart';
import 'profile_avatar.dart';
import 'played_with_repository.dart';
import 'social_profile.dart';
import 'play_again.dart';

typedef PlayedWithProfileTap =
    void Function(BuildContext context, PlayedWithPlayer player);

String playedWithShortDate(DateTime? date) {
  if (date == null) return 'Date unavailable';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

class PlayedWithScreen extends StatefulWidget {
  final String viewerUid;
  final PlayedWithRepository repository;
  final PlayedWithProfileTap onProfileTap;
  final ValueChanged<PlayAgainTarget>? onPlayAgain;

  const PlayedWithScreen({
    super.key,
    required this.viewerUid,
    required this.repository,
    required this.onProfileTap,
    this.onPlayAgain,
  });

  @override
  State<PlayedWithScreen> createState() => _PlayedWithScreenState();
}

class _PlayedWithScreenState extends State<PlayedWithScreen> {
  final List<PlayedWithPlayer> _players = [];
  Object? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.loadPage(
        widget.viewerUid,
        cursor: _cursor,
      );
      if (!mounted) return;
      setState(() {
        final known = _players.map((item) => item.profile.uid).toSet();
        _players.addAll(
          page.players.where((item) => known.add(item.profile.uid)),
        );
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("People you've played with")),
    body: _players.isEmpty && _loading
        ? const Center(child: CircularProgressIndicator())
        : _players.isEmpty && _error != null
        ? _PlayedWithMessage(
            title: 'Could not load players.',
            actionLabel: 'Try Again',
            onAction: _loadMore,
          )
        : _players.isEmpty
        ? const _PlayedWithMessage(
            title:
                'People you play with will appear here after completed matches.',
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: _players.length + (_hasMore || _error != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _players.length) {
                final player = _players[index];
                return PlayedWithTile(
                  player: player,
                  onTap: () => widget.onProfileTap(context, player),
                  onPlayAgain: widget.onPlayAgain == null
                      ? null
                      : () => widget.onPlayAgain!(
                          PlayAgainTarget(
                            uid: player.profile.uid,
                            displayName: player.profile.displayName,
                            sourceMatchId: player.relationship.lastMatchId,
                          ),
                        ),
                );
              }
              if (_error != null) {
                return TextButton(
                  onPressed: _loadMore,
                  child: const Text('Try loading more again'),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          key: const Key('played-with-load-more'),
                          onPressed: _loadMore,
                          child: const Text('Load more'),
                        ),
                ),
              );
            },
          ),
  );
}

class PlayedWithTile extends StatelessWidget {
  final PlayedWithPlayer player;
  final VoidCallback? onTap;
  final VoidCallback? onPlayAgain;

  const PlayedWithTile({
    super.key,
    required this.player,
    this.onTap,
    this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final profile = player.profile;
    final relationship = player.relationship;
    final rating = profile.ratingCount == 0
        ? 'Not rated'
        : '${profile.ratingAverage.toStringAsFixed(1)} ★ (${profile.ratingCount})';
    final matches = relationship.completedMatchCount;
    return Card(
      child: ListTile(
        key: Key('played-with-${profile.uid}'),
        onTap: onTap,
        isThreeLine: true,
        leading: ProfileAvatar(
          uid: profile.uid,
          displayName: profile.displayName,
          avatarVersion: profile.avatarVersion,
        ),
        title: Text(profile.displayName),
        subtitle: Text(
          [
            [
              profile.level.isEmpty
                  ? 'Level not set'
                  : 'Level ${profile.level}',
              '${profile.socialProfile.preferredSide.label} side',
              rating,
            ].join(' · '),
            [
              'Last played ${playedWithShortDate(relationship.lastPlayedAt)}',
              '$matches ${matches == 1 ? 'match' : 'matches'} together',
              if (profile.locationLabel.isNotEmpty) profile.locationLabel,
            ].join(' · '),
          ].join('\n'),
        ),
        trailing: onPlayAgain == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                key: Key('play-again-${profile.uid}'),
                tooltip: 'Play Again',
                onPressed: onPlayAgain,
                icon: const Icon(Icons.replay),
              ),
      ),
    );
  }
}

class PlayedWithPreview extends StatefulWidget {
  final String viewerUid;
  final PlayedWithRepository repository;
  final PlayedWithProfileTap onProfileTap;
  final VoidCallback onViewAll;
  final int limit;
  final ValueChanged<PlayAgainTarget>? onPlayAgain;

  const PlayedWithPreview({
    super.key,
    required this.viewerUid,
    required this.repository,
    required this.onProfileTap,
    required this.onViewAll,
    this.limit = 3,
    this.onPlayAgain,
  });

  @override
  State<PlayedWithPreview> createState() => _PlayedWithPreviewState();
}

class _PlayedWithPreviewState extends State<PlayedWithPreview> {
  late Future<PlayedWithPage> _page;

  @override
  void initState() {
    super.initState();
    _page = widget.repository.loadPage(
      widget.viewerUid,
      pageSize: widget.limit,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PlayedWithPage>(
    future: _page,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (snapshot.hasError) return const SizedBox.shrink();
      final players = (snapshot.data?.players ?? const <PlayedWithPlayer>[])
          .take(widget.limit)
          .toList();
      if (players.isEmpty) return const SizedBox.shrink();
      return Column(
        key: const Key('home-played-with-preview'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "People you've played with",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                key: const Key('played-with-view-all'),
                onPressed: widget.onViewAll,
                child: const Text('View All'),
              ),
            ],
          ),
          ...players.map(
            (player) => PlayedWithTile(
              player: player,
              onTap: () => widget.onProfileTap(context, player),
              onPlayAgain: widget.onPlayAgain == null
                  ? null
                  : () => widget.onPlayAgain!(
                      PlayAgainTarget(
                        uid: player.profile.uid,
                        displayName: player.profile.displayName,
                        sourceMatchId: player.relationship.lastMatchId,
                      ),
                    ),
            ),
          ),
        ],
      );
    },
  );
}

class _PlayedWithMessage extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _PlayedWithMessage({
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, size: 44, color: Colors.white54),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    ),
  );
}
