import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'friends.dart';
import 'friends_repository.dart';
import 'played_with.dart';
import 'profile_avatar.dart';

class FriendAction extends StatefulWidget {
  final String targetUid;
  final FriendsRepository repository;
  final VoidCallback? onChanged;
  const FriendAction({
    super.key,
    required this.targetUid,
    required this.repository,
    this.onChanged,
  });
  @override
  State<FriendAction> createState() => _FriendActionState();
}

class _FriendActionState extends State<FriendAction> {
  late Future<RelationshipPolicy> _policy = widget.repository.policy(
    widget.targetUid,
  );
  bool _busy = false;
  void _reload() => setState(() {
    _policy = widget.repository.policy(widget.targetUid);
  });

  String _errorCode(Object error) =>
      error is FirebaseFunctionsException ? error.code : 'unknown';

  void _logFailure(String operation, Object error) {
    debugPrint(
      'Social mutation $operation failed (code: ${_errorCode(error)}).',
    );
  }

  void _notifyChanged(String operation) {
    try {
      widget.onChanged?.call();
    } catch (error) {
      debugPrint(
        'Social mutation $operation post-success refresh failed '
        '(code: ${_errorCode(error)}).',
      );
    }
  }

  Future<bool> _reconcileAddFriend() async {
    try {
      final policy = await widget.repository.policy(widget.targetUid);
      final established =
          policy.status == 'accepted' ||
          (policy.status == 'pending' &&
              policy.direction == FriendDirection.outgoing);
      debugPrint(
        'Social mutation requestFriend reconciliation '
        '${established ? 'established' : 'not-established'}.',
      );
      if (established && mounted) {
        setState(() {
          _policy = Future.value(policy);
        });
      }
      return established;
    } catch (error) {
      debugPrint(
        'Social mutation requestFriend reconciliation failed '
        '(code: ${_errorCode(error)}).',
      );
      return false;
    }
  }

  void _showUnavailable() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This social action is unavailable.')),
      );
    }
  }

  Future<void> _run(
    String operation,
    Future<void> Function() action, {
    bool reconcileAddFriend = false,
  }) async {
    setState(() => _busy = true);
    try {
      try {
        await action();
      } catch (error) {
        _logFailure(operation, error);
        if (reconcileAddFriend && await _reconcileAddFriend()) {
          _notifyChanged(operation);
          return;
        }
        _showUnavailable();
        return;
      }

      _notifyChanged(operation);
      if (mounted) {
        try {
          _reload();
        } catch (error) {
          debugPrint(
            'Social mutation $operation post-success reload failed '
            '(code: ${_errorCode(error)}).',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RelationshipPolicy>(
    future: _policy,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox(height: 40);
      final policy = snapshot.data!;
      if (!policy.interactionAllowed && !policy.blockedByViewer) {
        return const SizedBox.shrink();
      }
      if (policy.blockedByViewer) {
        return OutlinedButton(
          key: const Key('unblock-player'),
          onPressed: _busy
              ? null
              : () => _run(
                  'unblock',
                  () => widget.repository.unblock(widget.targetUid),
                ),
          child: const Text('Unblock'),
        );
      }
      if (policy.status == 'accepted') {
        return PopupMenuButton<String>(
          key: const Key('friends-action'),
          onSelected: (value) => _run(
            value == 'block' ? 'block' : 'removeFriend',
            value == 'block'
                ? () => widget.repository.block(widget.targetUid)
                : () => widget.repository.remove(widget.targetUid),
          ),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'unfriend', child: Text('Unfriend')),
            PopupMenuItem(value: 'block', child: Text('Block')),
          ],
          child: const Chip(label: Text('Friends')),
        );
      }
      if (policy.direction == FriendDirection.incoming) {
        return Wrap(
          spacing: 8,
          children: [
            FilledButton(
              key: const Key('accept-friend'),
              onPressed: _busy
                  ? null
                  : () => _run(
                      'respondToFriendRequest',
                      () => widget.repository.respond(widget.targetUid, true),
                    ),
              child: const Text('Accept'),
            ),
            OutlinedButton(
              key: const Key('decline-friend'),
              onPressed: _busy
                  ? null
                  : () => _run(
                      'respondToFriendRequest',
                      () => widget.repository.respond(widget.targetUid, false),
                    ),
              child: const Text('Decline'),
            ),
          ],
        );
      }
      if (policy.direction == FriendDirection.outgoing) {
        return OutlinedButton(
          key: const Key('cancel-friend-request'),
          onPressed: _busy
              ? null
              : () => _run(
                  'cancelFriendRequest',
                  () => widget.repository.cancel(widget.targetUid),
                ),
          child: const Text('Requested'),
        );
      }
      return Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            key: const Key('add-friend'),
            onPressed: _busy
                ? null
                : () => _run(
                    'requestFriend',
                    () => widget.repository.requestFriend(widget.targetUid),
                    reconcileAddFriend: true,
                  ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add Friend'),
          ),
          PopupMenuButton<String>(
            onSelected: (_) =>
                _run('block', () => widget.repository.block(widget.targetUid)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      );
    },
  );
}

class FriendsScreen extends StatefulWidget {
  final String viewerUid;
  final FriendsRepository repository;
  final void Function(BuildContext, PlayedWithPublicProfile)? onProfileTap;
  const FriendsScreen({
    super.key,
    required this.viewerUid,
    required this.repository,
    this.onProfileTap,
  });
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _Section {
  final String title;
  final String status;
  final FriendDirection? direction;
  const _Section(this.title, this.status, this.direction);
}

class _FriendsScreenState extends State<FriendsScreen> {
  static const sections = [
    _Section('Incoming Requests', 'pending', FriendDirection.incoming),
    _Section('Outgoing Requests', 'pending', FriendDirection.outgoing),
    _Section('Accepted Friends', 'accepted', null),
  ];
  late final List<GlobalKey<_FriendSectionState>> _sectionKeys;
  StreamSubscription<void>? _friendViewsSubscription;
  int _listenerGeneration = 0;
  bool _receivedInitialSnapshot = false;
  bool _refreshing = false;
  bool _refreshPending = false;

  @override
  void initState() {
    super.initState();
    _sectionKeys = List.generate(
      sections.length,
      (_) => GlobalKey<_FriendSectionState>(),
    );
    _startFriendViewsListener();
  }

  void _startFriendViewsListener() {
    _receivedInitialSnapshot = false;
    _friendViewsSubscription = widget.repository
        .watchFriendViews(widget.viewerUid)
        .listen(
          (_) {
            if (!_receivedInitialSnapshot) {
              _receivedInitialSnapshot = true;
              return;
            }
            unawaited(_refreshSections());
          },
          onError: (Object _) {
            debugPrint('Friends projection listener failed.');
          },
        );
  }

  Future<void> _restartFriendViewsListener(int generation) async {
    final previous = _friendViewsSubscription;
    _friendViewsSubscription = null;
    await previous?.cancel();
    if (!mounted || generation != _listenerGeneration) return;
    _startFriendViewsListener();
    await _refreshSections();
  }

  Future<void> _refreshSections() async {
    if (_refreshing) {
      _refreshPending = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshPending = false;
        await Future.wait([
          for (final key in _sectionKeys)
            if (key.currentState case final state?) state.refresh(),
        ]);
      } while (mounted && _refreshPending);
    } finally {
      _refreshing = false;
    }
  }

  @override
  void didUpdateWidget(covariant FriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerUid != widget.viewerUid ||
        oldWidget.repository != widget.repository) {
      _listenerGeneration++;
      unawaited(_restartFriendViewsListener(_listenerGeneration));
    }
  }

  @override
  void dispose() {
    _listenerGeneration++;
    unawaited(_friendViewsSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Friends')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var index = 0; index < sections.length; index++)
          _FriendSection(
            key: _sectionKeys[index],
            section: sections[index],
            viewerUid: widget.viewerUid,
            repository: widget.repository,
            onProfileTap: widget.onProfileTap,
          ),
      ],
    ),
  );
}

class _FriendSection extends StatefulWidget {
  final _Section section;
  final String viewerUid;
  final FriendsRepository repository;
  final void Function(BuildContext, PlayedWithPublicProfile)? onProfileTap;
  const _FriendSection({
    super.key,
    required this.section,
    required this.viewerUid,
    required this.repository,
    this.onProfileTap,
  });
  @override
  State<_FriendSection> createState() => _FriendSectionState();
}

class _FriendSectionState extends State<_FriendSection> {
  final List<FriendView> views = [];
  final Map<String, PlayedWithPublicProfile> profiles = {};
  Object? cursor;
  bool loading = false;
  bool hasMore = true;
  Object? error;
  bool _resetPending = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> _load({bool reset = false}) async {
    if (loading) {
      if (reset) _resetPending = true;
      return;
    }
    if (!hasMore && !reset) return;
    final requestedCursor = reset ? null : cursor;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await widget.repository.loadPage(
        widget.viewerUid,
        status: widget.section.status,
        direction: widget.section.direction,
        cursor: requestedCursor,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          views.clear();
          profiles.clear();
        }
        final known = views.map((item) => item.otherUid).toSet();
        views.addAll(page.views.where((item) => known.add(item.otherUid)));
        profiles.addAll(page.profiles);
        cursor = page.cursor;
        hasMore = page.hasMore;
      });
    } catch (value) {
      debugPrint('Friends section refresh failed.');
      if (mounted) setState(() => error = value);
    } finally {
      if (mounted) {
        setState(() => loading = false);
        if (_resetPending) {
          _resetPending = false;
          unawaited(_load(reset: true));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    key: Key('friends-section-${widget.section.title}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.section.title,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      if (views.isEmpty && loading)
        const LinearProgressIndicator()
      else if (views.isEmpty && error != null)
        TextButton(onPressed: _load, child: const Text('Try Again'))
      else if (views.isEmpty)
        Text(
          widget.section.status == 'accepted'
              ? 'No friends yet.'
              : 'No requests.',
        )
      else
        ...views.map((view) {
          final profile = profiles[view.otherUid];
          if (profile == null) return const SizedBox.shrink();
          return Card(
            child: ListTile(
              onTap: widget.onProfileTap == null
                  ? null
                  : () => widget.onProfileTap!(context, profile),
              leading: ProfileAvatar(
                uid: profile.uid,
                displayName: profile.displayName,
                avatarVersion: profile.avatarVersion,
              ),
              title: Text(profile.displayName),
              subtitle: Text(
                profile.level.isEmpty
                    ? 'Level not set'
                    : 'Level ${profile.level}',
              ),
              trailing: FriendAction(
                targetUid: view.otherUid,
                repository: widget.repository,
                onChanged: () => _load(reset: true),
              ),
            ),
          );
        }),
      if (hasMore && views.isNotEmpty)
        TextButton(
          key: Key('friends-load-more-${widget.section.title}'),
          onPressed: loading ? null : _load,
          child: Text(loading ? 'Loading…' : 'Load more'),
        ),
      const SizedBox(height: 24),
    ],
  );
}
