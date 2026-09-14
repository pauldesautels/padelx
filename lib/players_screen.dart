import 'dart:async';

import 'package:flutter/material.dart';
import 'area_selector.dart';
import 'level.dart';
import 'location.dart';
import 'places.dart';
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
  final DiscoveryLocation discoveryLocation;
  final VoidCallback? onEditProfileLocation;
  final GooglePlacesClient? placesClient;
  const PlayersScreen({
    super.key,
    required this.repository,
    required this.friendsRepository,
    required this.onProfileTap,
    this.onPlayAgain,
    this.discoveryLocation = const DiscoveryLocation(
      country: '',
      countryCode: '',
      city: '',
    ),
    this.onEditProfileLocation,
    this.placesClient,
  });
  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final players = <DiscoveredPlayer>[];
  var filters = const PlayerDiscoveryFilters();
  Object? cursor, error;
  bool loading = false, hasMore = true, noLocation = false;
  Timer? _filterTimer;
  int _filterGeneration = 0;
  bool _queuedFilterLoad = false;
  DateTime? _lastRequestStarted;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlayersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameDiscoveryScope(oldWidget.discoveryLocation, widget.discoveryLocation)) return;
    filters = PlayerDiscoveryFilters(
      level: filters.level,
      preferredSide: filters.preferredSide,
      relationship: filters.relationship,
    );
    _filterGeneration += 1;
    _queuedFilterLoad = true;
    _scheduleFilterLoad();
  }

  bool _sameDiscoveryScope(DiscoveryLocation left, DiscoveryLocation right) {
    if (left.countryCode.trim().toUpperCase() != right.countryCode.trim().toUpperCase()) return false;
    final leftId = left.cityId.trim();
    final rightId = right.cityId.trim();
    if (leftId.isNotEmpty || rightId.isNotEmpty) return leftId == rightId;
    return left.city.trim() == right.city.trim();
  }

  @override
  void dispose() {
    _filterTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (loading) {
      if (reset) _queuedFilterLoad = true;
      return;
    }
    if (!hasMore && !reset) return;
    final requestedFilters = filters;
    final requestedGeneration = _filterGeneration;
    _lastRequestStarted = DateTime.now();
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
      if (requestedGeneration != _filterGeneration ||
          requestedFilters != filters) {
        _queuedFilterLoad = true;
        return;
      }
      setState(() {
        players.addAll(page.players);
        cursor = page.cursor;
        hasMore = page.hasMore;
        noLocation = page.noLocation;
      });
    } catch (value) {
      if (mounted && requestedGeneration == _filterGeneration) {
        setState(() => error = value);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
        if (_queuedFilterLoad) {
          _queuedFilterLoad = false;
          _scheduleFilterLoad();
        }
      }
    }
  }

  void _setFilters(PlayerDiscoveryFilters value) {
    if (value == filters) return;
    setState(() => filters = value);
    _filterGeneration += 1;
    _queuedFilterLoad = true;
    _scheduleFilterLoad();
  }

  Future<void> _refresh() async {
    _filterGeneration += 1;
    _queuedFilterLoad = loading;
    await _load(reset: true);
  }

  void _scheduleFilterLoad() {
    _filterTimer?.cancel();
    if (loading) return;
    final elapsed = _lastRequestStarted == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_lastRequestStarted!);
    final delay = elapsed >= const Duration(milliseconds: 800)
        ? Duration.zero
        : const Duration(milliseconds: 800) - elapsed;
    _filterTimer = Timer(delay, () {
      _queuedFilterLoad = false;
      _load(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      key: const Key('players-scroll-view'),
      physics: const AlwaysScrollableScrollPhysics(),
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
      if (widget.discoveryLocation.isConfigured) ...[
        Semantics(
          header: true,
          child: Text(
            'Players in\n${widget.discoveryLocation.city}',
            key: const Key('players-active-city'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        if (widget.onEditProfileLocation != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('players-edit-location'),
              onPressed: widget.onEditProfileLocation,
              child: const Text('Edit profile location'),
            ),
          ),
        const SizedBox(height: 8),
      ],
      _Filters(
        filters: filters,
        location: widget.discoveryLocation,
        placesClient: widget.placesClient,
        onChanged: _setFilters,
      ),
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
        _State(
          key: Key(hasMore ? 'players-more-available' : 'players-empty'),
          icon: Icons.group_outlined,
          title: hasMore
              ? 'More players may match'
              : 'No players match these filters',
          message: hasMore
              ? 'Continue searching the remaining players.'
              : 'Try a broader area, level, side, or relationship filter.',
          action: hasMore ? _load : null,
          actionLabel: 'Load more',
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
    ),
  );
}

class _Filters extends StatelessWidget {
  final PlayerDiscoveryFilters filters;
  final DiscoveryLocation location;
  final GooglePlacesClient? placesClient;
  final ValueChanged<PlayerDiscoveryFilters> onChanged;
  const _Filters({
    required this.filters,
    required this.location,
    required this.onChanged,
    this.placesClient,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AreaSelectorField(
        key: const Key('players-area-filter'),
        value: filters.area,
        location: location,
        placesClient: placesClient,
        onChanged: (value) => onChanged(
          PlayerDiscoveryFilters(
            area: value.label,
            areaId: value.id,
            level: filters.level,
            preferredSide: filters.preferredSide,
            relationship: filters.relationship,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          DropdownButton<String>(
            key: const Key('players-level-filter'),
            value: filters.level.isEmpty ? 'any' : filters.level,
            items: ['any', ...padelLevelValues]
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
                areaId: filters.areaId,
                level: v == 'any' ? '' : v!,
                preferredSide: filters.preferredSide,
                relationship: filters.relationship,
              ),
            ),
          ),
          DropdownButton<String>(
            key: const Key('players-side-filter'),
            value: filters.preferredSide,
            items:
                const {
                      'any': 'Any side',
                      'left': 'Left',
                      'right': 'Right',
                      'either': 'Either only',
                    }.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
            onChanged: (v) => onChanged(
              PlayerDiscoveryFilters(
                area: filters.area,
                areaId: filters.areaId,
                level: filters.level,
                preferredSide: v!,
                relationship: filters.relationship,
              ),
            ),
          ),
          DropdownButton<PlayerRelationshipFilter>(
            key: const Key('players-relationship-filter'),
            value: filters.relationship,
            items:
                const {
                      PlayerRelationshipFilter.all: 'Everyone',
                      PlayerRelationshipFilter.friends: 'Friends',
                      PlayerRelationshipFilter.playedWith: 'Played With',
                    }.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
            onChanged: (v) => onChanged(
              PlayerDiscoveryFilters(
                area: filters.area,
                areaId: filters.areaId,
                level: filters.level,
                preferredSide: filters.preferredSide,
                relationship: v!,
              ),
            ),
          ),
        ],
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
  final String actionLabel;
  const _State({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.actionLabel = 'Try Again',
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
          TextButton(onPressed: action, child: Text(actionLabel)),
      ],
    ),
  );
}
