import 'package:flutter/material.dart';
import 'profile_avatar.dart';
import 'friends_repository.dart';
import 'friends_screen.dart';
import 'player_discovery.dart';
import 'player_discovery_repository.dart';

typedef PlayerTap =
    void Function(BuildContext context, DiscoveredPlayer player);
typedef PlayerPlayAgain = void Function(DiscoveredPlayer player);

class PlayersScreen extends StatefulWidget {
  final PlayerDiscoveryRepository repository;
  final FriendsRepository friendsRepository;
  final PlayerTap onProfileTap;
  final PlayerPlayAgain? onPlayAgain;
  const PlayersScreen({
    super.key,
    required this.repository,
    required this.friendsRepository,
    required this.onProfileTap,
    this.onPlayAgain,
  });
  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final players = <DiscoveredPlayer>[];
  var filters = const PlayerDiscoveryFilters();
  Object? cursor, error;
  bool loading = false, hasMore = true, noLocation = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (loading || (!hasMore && !reset)) return;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        players.clear();
        cursor = null;
        hasMore = true;
      }
    });
    try {
      final page = await widget.repository.discover(filters, cursor: cursor);
      if (!mounted) return;
      setState(() {
        players.addAll(page.players);
        cursor = page.cursor;
        hasMore = page.hasMore;
        noLocation = page.noLocation;
      });
    } catch (value) {
      if (mounted) setState(() => error = value);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _setFilters(PlayerDiscoveryFilters value) {
    filters = value;
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('players-scroll-view'),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
    children: [
      const Text(
        'Players',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text(
        'Find padel players you may want to play with.',
        style: TextStyle(color: Colors.white70),
      ),
      const SizedBox(height: 16),
      _Filters(filters: filters, onChanged: _setFilters),
      const SizedBox(height: 12),
      if (noLocation)
        const _State(
          key: Key('players-no-location'),
          icon: Icons.location_off_outlined,
          title: 'Set your city to find players',
          message:
              'Add a coarse city in your profile. Your precise location is never shared.',
        )
      else if (players.isEmpty && loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        )
      else if (players.isEmpty && error != null)
        _State(
          key: const Key('players-error'),
          icon: Icons.cloud_off_outlined,
          title: 'Players are unavailable right now',
          action: () => _load(reset: true),
        )
      else if (players.isEmpty)
        const _State(
          key: Key('players-empty'),
          icon: Icons.group_outlined,
          title: 'No players match these filters',
          message: 'Try a broader area, level, side, or relationship filter.',
        )
      else
        ...players.map(
          (player) => PlayerDiscoveryCard(
            player: player,
            friendsRepository: widget.friendsRepository,
            onTap: () => widget.onProfileTap(context, player),
            onPlayAgain: player.canPlayAgain && widget.onPlayAgain != null
                ? () => widget.onPlayAgain!(player)
                : null,
            onChanged: () => _load(reset: true),
          ),
        ),
      if (hasMore && players.isNotEmpty)
        TextButton(
          onPressed: loading ? null : _load,
          child: Text(loading ? 'Loading…' : 'Load more'),
        ),
    ],
  );
}

class _Filters extends StatelessWidget {
  final PlayerDiscoveryFilters filters;
  final ValueChanged<PlayerDiscoveryFilters> onChanged;
  const _Filters({required this.filters, required this.onChanged});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      SizedBox(
        width: 130,
        child: TextField(
          key: const Key('players-area-filter'),
          decoration: const InputDecoration(labelText: 'Area', isDense: true),
          onSubmitted: (value) => onChanged(
            PlayerDiscoveryFilters(
              area: value,
              level: filters.level,
              preferredSide: filters.preferredSide,
              relationship: filters.relationship,
            ),
          ),
        ),
      ),
      DropdownButton<String>(
        value: filters.level.isEmpty ? 'any' : filters.level,
        items:
            const [
                  'any',
                  '1',
                  '1.5',
                  '2',
                  '2.5',
                  '3',
                  '3.5',
                  '4',
                  '4.5',
                  '5',
                  '5.5',
                  '6',
                  '6.5',
                  '7',
                  'Beginner',
                  'Intermediate',
                  'Advanced',
                ]
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      v == 'any'
                          ? 'Any level'
                          : (RegExp(r'^[0-9]').hasMatch(v) ? 'Level $v' : v),
                    ),
                  ),
                )
                .toList(),
        onChanged: (v) => onChanged(
          PlayerDiscoveryFilters(
            area: filters.area,
            level: v == 'any' ? '' : v!,
            preferredSide: filters.preferredSide,
            relationship: filters.relationship,
          ),
        ),
      ),
      DropdownButton<String>(
        value: filters.preferredSide,
        items:
            const {
                  'any': 'Any side',
                  'left': 'Left',
                  'right': 'Right',
                  'either': 'Either only',
                }.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
        onChanged: (v) => onChanged(
          PlayerDiscoveryFilters(
            area: filters.area,
            level: filters.level,
            preferredSide: v!,
            relationship: filters.relationship,
          ),
        ),
      ),
      DropdownButton<PlayerRelationshipFilter>(
        value: filters.relationship,
        items:
            const {
                  PlayerRelationshipFilter.all: 'Everyone',
                  PlayerRelationshipFilter.friends: 'Friends',
                  PlayerRelationshipFilter.playedWith: 'Played With',
                }.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
        onChanged: (v) => onChanged(
          PlayerDiscoveryFilters(
            area: filters.area,
            level: filters.level,
            preferredSide: filters.preferredSide,
            relationship: v!,
          ),
        ),
      ),
    ],
  );
}

class PlayerDiscoveryCard extends StatelessWidget {
  final DiscoveredPlayer player;
  final FriendsRepository friendsRepository;
  final VoidCallback onTap, onChanged;
  final VoidCallback? onPlayAgain;
  const PlayerDiscoveryCard({
    super.key,
    required this.player,
    required this.friendsRepository,
    required this.onTap,
    required this.onChanged,
    this.onPlayAgain,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  uid: player.uid,
                  displayName: player.displayName,
                  avatarVersion: player.avatarVersion,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    player.displayName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (player.isFriend) const Chip(label: Text('Friend')),
              ],
            ),
            Text(
              'Level ${player.level} · ${player.preferredSide[0].toUpperCase()}${player.preferredSide.substring(1)} side',
            ),
            if (player.locationLabel.isNotEmpty)
              Text(
                player.locationLabel,
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 8),
            Text(
              player.ratingCount == 0
                  ? 'No ratings yet · ${player.completedMatchCount} completed matches'
                  : '${player.ratingAverage.toStringAsFixed(1)} ★ (${player.ratingCount}) · ${player.completedMatchCount} completed matches',
            ),
            if (player.playedTogetherCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Played together ${player.playedTogetherCount} ${player.playedTogetherCount == 1 ? 'time' : 'times'}',
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (!player.isFriend)
                  FriendAction(
                    targetUid: player.uid,
                    repository: friendsRepository,
                    onChanged: onChanged,
                  ),
                if (onPlayAgain != null)
                  OutlinedButton.icon(
                    onPressed: onPlayAgain,
                    icon: const Icon(Icons.replay),
                    label: const Text('Play Again'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _State extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? action;
  const _State({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Icon(icon, size: 44),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (message != null) Text(message!, textAlign: TextAlign.center),
        if (action != null)
          TextButton(onPressed: action, child: const Text('Try Again')),
      ],
    ),
  );
}
