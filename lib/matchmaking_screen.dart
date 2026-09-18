import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'friends_repository.dart';
import 'location.dart';
import 'match_date_time_picker.dart';
import 'matchmaking_repository.dart';
import 'places.dart';
import 'places_autocomplete.dart';
import 'profile_avatar.dart';
import 'l10n/l10n.dart';
import 'design_system.dart';
import 'push_notifications.dart';

class MatchmakingScreen extends StatefulWidget {
  final String currentUid;
  final DiscoveryLocation discoveryLocation;
  final String level;
  final String preferredSide;
  final MatchmakingRepository repository;
  final FriendsRepository friendsRepository;
  final GooglePlacesClient? placesClient;
  final ValueChanged<String> onOpenMatch;
  final DateTime Function() now;
  final String timezone;
  final PushSettingsService? pushSettingsService;

  const MatchmakingScreen({
    super.key,
    required this.currentUid,
    required this.discoveryLocation,
    required this.level,
    required this.preferredSide,
    required this.repository,
    required this.friendsRepository,
    this.placesClient,
    required this.onOpenMatch,
    this.now = DateTime.now,
    this.timezone = 'America/Mexico_City',
    this.pushSettingsService,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with WidgetsBindingObserver {
  MatchmakingState? _state;
  StreamSubscription<void>? _subscription;
  Timer? _countdown;
  bool _loading = true;
  bool _mutating = false;
  bool _refreshing = false;
  bool _queuedRefresh = false;
  Object? _error;
  bool _initialSignal = true;
  bool? _pushDeliveryEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = widget.repository
        .watchStateInvalidations(widget.currentUid)
        .listen(
          (_) {
            if (_initialSignal) {
              _initialSignal = false;
              return;
            }
            _refresh();
          },
          onError: (_) {
            if (mounted && _state == null) {
              setState(() => _error = const MatchmakingUiException());
            }
          },
        );
    _countdown = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    unawaited(_loadPushState());
    _refresh();
  }

  Future<void> _loadPushState() async {
    final service = widget.pushSettingsService;
    if (service == null) return;
    try {
      final enabled = await service.isDeliveryEnabled(widget.currentUid);
      if (mounted) setState(() => _pushDeliveryEnabled = enabled);
    } catch (_) {
      if (mounted) setState(() => _pushDeliveryEnabled = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      _queuedRefresh = true;
      return;
    }
    _refreshing = true;
    do {
      _queuedRefresh = false;
      try {
        final next = await widget.repository.state();
        if (mounted) {
          setState(() {
            _state = next;
            _error = null;
            _loading = false;
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error;
            _loading = false;
          });
        }
      }
    } while (_queuedRefresh && mounted);
    _refreshing = false;
  }

  Future<void> _mutation(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.matchmakingActionFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }

  Map<String, dynamic>? get _proposal {
    for (final item in _state?.proposals ?? const []) {
      if (['confirming', 'venue_needed', 'promoted'].contains(item['status'])) {
        return item;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _request {
    for (final item in _state?.requests ?? const []) {
      if (['awaiting_partner', 'active', 'matched'].contains(item['status'])) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final proposal = _proposal;
    final request = _request;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.findMeAMatch)),
      body: SafeArea(
        child: _loading && _state == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _state == null
            ? _ErrorState(onRetry: _refresh)
            : proposal != null
            ? _ProposalView(
                proposal: proposal,
                busy: _mutating,
                now: widget.now(),
                onRespond: (accept) => _mutation(
                  () => widget.repository.respondToProposal(
                    proposal['proposalId'].toString(),
                    accept: accept,
                    requestId: _requestId('proposal'),
                  ),
                ),
                onSelectVenue: proposal['coordinator'] == true
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _VenueScreen(
                            proposal: proposal,
                            repository: widget.repository,
                            placesClient: widget.placesClient,
                            onPromoted: widget.onOpenMatch,
                          ),
                        ),
                      )
                    : null,
                onOpenMatch: proposal['matchId'] == null
                    ? null
                    : () => widget.onOpenMatch(proposal['matchId'].toString()),
              )
            : request != null
            ? _RequestView(
                request: request,
                busy: _mutating,
                showPushWarning: _pushDeliveryEnabled == false,
                onPartnerResponse:
                    request['role'] == 'partner' &&
                        request['status'] == 'awaiting_partner'
                    ? (accept) => _mutation(
                        () => widget.repository.respondToPartner(
                          request['requestId'].toString(),
                          accept: accept,
                        ),
                      )
                    : null,
                onCancel: () => _mutation(
                  () =>
                      widget.repository.cancel(request['requestId'].toString()),
                ),
              )
            : _CreateRequestView(
                widget: widget,
                busy: _mutating,
                showPushWarning: _pushDeliveryEnabled == false,
                onCreate: (input) => _mutation(() async {
                  await widget.repository.create(input);
                }),
              ),
      ),
    );
  }
}

String _requestId(String prefix) {
  final random = Random.secure();
  final suffix = List.generate(
    20,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$suffix';
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is Map && value['_seconds'] is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value['_seconds'] as num).toInt() * 1000,
      isUtc: true,
    );
  }
  return null;
}

String _dateTime(BuildContext context, Object? value) {
  final date = _date(value)?.toLocal();
  if (date == null) return context.l10n.dateTimeUnavailable;
  final locale = Localizations.localeOf(context).toString();
  return '${DateFormat('EEEE, MMM d', locale).format(date)} · '
      '${DateFormat.jm(locale).format(date)}';
}

String _locationSummary(
  BuildContext context,
  Object? cityValue,
  Object? areaValue,
) {
  final city = cityValue?.toString().trim() ?? '';
  final area = areaValue?.toString().trim() ?? '';
  return area.isEmpty ? city : context.l10n.searchLocationSummary(city, area);
}

class _CreateRequestView extends StatefulWidget {
  final MatchmakingScreen widget;
  final bool busy;
  final ValueChanged<MatchmakingRequestInput> onCreate;
  final bool showPushWarning;
  const _CreateRequestView({
    required this.widget,
    required this.busy,
    required this.onCreate,
    required this.showPushWarning,
  });
  @override
  State<_CreateRequestView> createState() => _CreateRequestViewState();
}

class _CreateRequestViewState extends State<_CreateRequestView> {
  MatchmakingMode _mode = MatchmakingMode.solo;
  DateTime? _start;
  DateTime? _end;
  int _radius = 10;
  late String _side = widget.widget.preferredSide;
  String? _partnerUid;
  List<({String uid, String name})> _partners = const [];

  Future<void> _chooseTime(bool start) async {
    final value = await showAdaptiveMatchDateTimePicker(
      context,
      now: widget.widget.now(),
      initialValue: start
          ? _start
          : (_end ?? _start?.add(const Duration(hours: 2))),
    );
    if (value != null && mounted) {
      setState(() {
        if (start) {
          _start = value;
          _end ??= value.add(const Duration(hours: 2));
        } else {
          _end = value;
        }
      });
    }
  }

  Future<void> _loadPartners() async {
    if (_partners.isNotEmpty) return;
    final page = await widget.widget.friendsRepository.loadPage(
      widget.widget.currentUid,
      status: 'accepted',
    );
    if (!mounted) return;
    setState(
      () => _partners = page.views
          .map(
            (view) => (
              uid: view.otherUid,
              name:
                  page.profiles[view.otherUid]?.displayName ??
                  context.l10n.player,
            ),
          )
          .toList(),
    );
  }

  void _submit() {
    if (_start == null ||
        _end == null ||
        !_end!.isAfter(_start!) ||
        (_mode == MatchmakingMode.partner && _partnerUid == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.completeMatchmakingRequest)),
      );
      return;
    }
    widget.onCreate(
      MatchmakingRequestInput(
        requestId: _requestId('search'),
        mode: _mode,
        partnerUid: _partnerUid,
        availability: [
          MatchmakingAvailability(earliestStart: _start!, latestStart: _end!),
        ],
        timezone: widget.widget.timezone,
        travelRadiusKm: _radius,
        preferredSide: _side,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('matchmaking-create'),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    children: [
      if (widget.showPushWarning) ...[
        const _PushWarning(),
        const SizedBox(height: PadelXSpace.md),
      ],
      PadelXSurface(
        strong: true,
        accent: PadelXColors.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bolt, color: PadelXColors.accent, size: 30),
            const SizedBox(height: PadelXSpace.sm),
            Text(
              context.l10n.matchmakingIntro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PadelXColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: PadelXSpace.xl),
      SegmentedButton<MatchmakingMode>(
        segments: [
          ButtonSegment(
            value: MatchmakingMode.solo,
            label: Text(context.l10n.solo),
            icon: const Icon(Icons.person_outline),
          ),
          ButtonSegment(
            value: MatchmakingMode.partner,
            label: Text(context.l10n.withPartner),
            icon: const Icon(Icons.group_outlined),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (value) {
          setState(() {
            _mode = value.first;
            _partnerUid = null;
          });
          if (_mode == MatchmakingMode.partner) _loadPartners();
        },
      ),
      if (_mode == MatchmakingMode.partner) ...[
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('matchmaking-partner'),
          initialValue: _partnerUid,
          decoration: InputDecoration(
            labelText: context.l10n.choosePartner,
            border: const OutlineInputBorder(),
          ),
          items: _partners
              .map(
                (partner) => DropdownMenuItem(
                  value: partner.uid,
                  child: Text(partner.name),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _partnerUid = value),
        ),
      ],
      const SizedBox(height: PadelXSpace.lg),
      PadelXSurface(
        child: Column(
          children: [
            ListTile(
              key: const Key('matchmaking-start'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: PadelXColors.accent),
              title: Text(context.l10n.availableFrom),
              subtitle: Text(_dateTime(context, _start)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _chooseTime(true),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('matchmaking-end'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.schedule_outlined,
                color: PadelXColors.accent,
              ),
              title: Text(context.l10n.availableUntil),
              subtitle: Text(_dateTime(context, _end)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _chooseTime(false),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      PadelXMetric(
        icon: Icons.location_on_outlined,
        label: _locationSummary(
          context,
          widget.widget.discoveryLocation.city,
          widget.widget.discoveryLocation.area,
        ),
      ),
      DropdownButtonFormField<int>(
        initialValue: _radius,
        decoration: InputDecoration(
          labelText: context.l10n.travelRadius,
          border: const OutlineInputBorder(),
        ),
        items: [5, 10, 20, 25]
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(context.l10n.radiusKm(value.toString())),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _radius = value ?? 10),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _side,
        decoration: InputDecoration(
          labelText: context.l10n.preferredSide,
          border: const OutlineInputBorder(),
        ),
        items: ['left', 'right', 'either']
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(
                  value == 'left'
                      ? context.l10n.leftSide
                      : value == 'right'
                      ? context.l10n.rightSide
                      : context.l10n.eitherSide,
                ),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _side = value ?? 'either'),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        key: const Key('start-matchmaking'),
        onPressed: widget.busy ? null : _submit,
        icon: const Icon(Icons.auto_awesome),
        label: Text(context.l10n.startSearching),
      ),
    ],
  );
}

class _RequestView extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool busy;
  final VoidCallback onCancel;
  final ValueChanged<bool>? onPartnerResponse;
  final bool showPushWarning;
  const _RequestView({
    required this.request,
    required this.busy,
    required this.onCancel,
    this.onPartnerResponse,
    required this.showPushWarning,
  });
  @override
  Widget build(BuildContext context) {
    final availabilityLabel =
        '${_dateTime(context, (request['availability'] as List?)?.firstOrNull?['earliestStart'])} – '
        '${_dateTime(context, (request['availability'] as List?)?.firstOrNull?['latestStart'])}';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (showPushWarning) ...[
          const _PushWarning(),
          const SizedBox(height: PadelXSpace.md),
        ],
        Icon(
          request['status'] == 'awaiting_partner'
              ? Icons.mark_email_unread_outlined
              : Icons.radar,
          size: 52,
          color: PadelXColors.accent,
        ),
        const SizedBox(height: 16),
        Text(
          request['status'] == 'awaiting_partner' &&
                  request['role'] == 'partner'
              ? context.l10n.partnerInvitation
              : context.l10n.findingYourMatch,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if ((request['inviterDisplayName'] ?? '').toString().isNotEmpty)
          Text(
            context.l10n.invitedBy(request['inviterDisplayName'].toString()),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: PadelXSpace.xl),
        PadelXSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PadelXMetric(icon: Icons.schedule, label: availabilityLabel),
              const SizedBox(height: PadelXSpace.md),
              PadelXMetric(
                icon: Icons.location_on_outlined,
                label: _locationSummary(
                  context,
                  request['city'],
                  request['area'],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (onPartnerResponse != null)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => onPartnerResponse!(false),
                  child: Text(context.l10n.decline),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : () => onPartnerResponse!(true),
                  child: Text(context.l10n.accept),
                ),
              ),
            ],
          )
        else
          OutlinedButton(
            onPressed: busy ? null : onCancel,
            child: Text(context.l10n.cancelSearch),
          ),
      ],
    );
  }
}

class _PushWarning extends StatelessWidget {
  const _PushWarning();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: PadelXSurface(
      accent: PadelXColors.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            color: PadelXColors.warning,
          ),
          const SizedBox(width: PadelXSpace.md),
          Expanded(child: Text(context.l10n.quickMatchPushWarning)),
        ],
      ),
    ),
  );
}

class _ProposalView extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final bool busy;
  final DateTime now;
  final ValueChanged<bool> onRespond;
  final VoidCallback? onSelectVenue;
  final VoidCallback? onOpenMatch;
  const _ProposalView({
    required this.proposal,
    required this.busy,
    required this.now,
    required this.onRespond,
    this.onSelectVenue,
    this.onOpenMatch,
  });
  @override
  Widget build(BuildContext context) {
    final expiry = _date(proposal['expiresAt']);
    final remaining = expiry?.difference(now);
    final expired = remaining == null || remaining.isNegative;
    final participants = (proposal['participants'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final confirmedCount = participants
        .where((item) => item['confirmation'] == 'accepted')
        .length;
    var teamOne = participants.where((item) => item['team'] == 1).toList();
    var teamTwo = participants.where((item) => item['team'] == 2).toList();
    if (teamOne.isEmpty && teamTwo.isEmpty) {
      teamOne = participants.take(2).toList();
      teamTwo = participants.skip(2).take(2).toList();
    }
    final status = proposal['status']?.toString() ?? '';
    final venueStatus = proposal['venueStatus']?.toString() ?? '';
    final memberCount = proposal['memberCount'] is int
        ? proposal['memberCount'] as int
        : participants.length;
    final allConfirmed = memberCount >= 4 && confirmedCount >= memberCount;
    final venueSelected =
        venueStatus == 'selected' || venueStatus == 'confirmed';
    // Older projections can carry a promoted/matchId shape before the venue
    // transition is actually complete. The participant and venue projection is
    // the truthful presentation source for that pre-venue state.
    final ready =
        status == 'venue_needed' ||
        (allConfirmed && !venueSelected && status != 'confirming');
    final promoted = status == 'promoted' && venueSelected;
    return ListView(
      key: const Key('matchmaking-proposal'),
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          ready ? Icons.check_circle_outline : Icons.groups_2_outlined,
          size: 52,
          color: PadelXColors.accent,
        ),
        Text(
          ready
              ? context.l10n.playersReady
              : promoted
              ? context.l10n.matchmakingMatchConfirmed
              : context.l10n.matchFound,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          _dateTime(context, proposal['scheduledAt']),
          textAlign: TextAlign.center,
        ),
        Text(
          _locationSummary(context, proposal['city'], proposal['area']),
          textAlign: TextAlign.center,
        ),
        if (ready)
          Text(
            context.l10n.courtNotSelected,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        Text(
          context.l10n.playersConfirmedCount(confirmedCount.toString()),
          textAlign: TextAlign.center,
        ),
        if (!expired && status == 'confirming')
          Text(
            context.l10n.offerExpiresMinutes(
              (remaining.inMinutes + 1).toString(),
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: PadelXSpace.lg),
        if (status == 'confirming' && proposal['confirmation'] != 'accepted')
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy || expired ? null : () => onRespond(false),
                  child: Text(context.l10n.decline),
                ),
              ),
              const SizedBox(width: PadelXSpace.md),
              Expanded(
                child: FilledButton(
                  key: const Key('accept-match'),
                  onPressed: busy || expired ? null : () => onRespond(true),
                  child: Text(context.l10n.confirmMySpot),
                ),
              ),
            ],
          ),
        if (proposal['confirmation'] == 'accepted' && status == 'confirming')
          PadelXSurface(
            accent: PadelXColors.success,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: PadelXColors.success),
                const SizedBox(width: PadelXSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.yourSpotConfirmed,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        context.l10n.findingRemainingPlayers,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (ready) ...[
          Text(
            onSelectVenue != null
                ? context.l10n.chooseVenueToFinish
                : context.l10n.waitingForVenue,
            textAlign: TextAlign.center,
          ),
          if (onSelectVenue != null)
            FilledButton(
              onPressed: onSelectVenue,
              child: Text(context.l10n.chooseVenue),
            ),
        ],
        if (promoted && onOpenMatch != null)
          FilledButton(
            onPressed: onOpenMatch,
            child: Text(context.l10n.openMatchDetails),
          ),
        const SizedBox(height: PadelXSpace.xl),
        _TeamPanel(team: 1, participants: teamOne, color: PadelXColors.teamOne),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: PadelXSpace.sm),
          child: Text(
            context.l10n.versus,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: PadelXColors.textSecondary,
            ),
          ),
        ),
        _TeamPanel(team: 2, participants: teamTwo, color: PadelXColors.teamTwo),
      ],
    );
  }
}

class _TeamPanel extends StatelessWidget {
  final int team;
  final List<Map<dynamic, dynamic>> participants;
  final Color color;

  const _TeamPanel({
    required this.team,
    required this.participants,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final slots = <Map<dynamic, dynamic>?>[
      ...participants.take(2),
      ...List<Map<dynamic, dynamic>?>.filled(
        max(0, 2 - participants.length),
        null,
      ),
    ];
    return Semantics(
      label: context.l10n.teamNumber(team.toString()),
      container: true,
      child: PadelXSurface(
        key: Key('matchmaking-team-$team'),
        accent: color.withValues(alpha: 0.38),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.teamNumber(team.toString()),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: color),
            ),
            const SizedBox(height: PadelXSpace.sm),
            ...slots.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: PadelXSpace.xs),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: color.withValues(alpha: 0.16),
                      foregroundColor: color,
                      child: item == null
                          ? const Icon(Icons.person_search_outlined, size: 19)
                          : Text(
                              avatarInitials(
                                    item['displayName']?.toString() ?? '',
                                  ).isEmpty
                                  ? context.l10n.player.characters.first
                                  : avatarInitials(
                                      item['displayName']?.toString() ?? '',
                                    ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(width: PadelXSpace.md),
                    Expanded(
                      child: Text(
                        item == null
                            ? context.l10n.findingAnotherPlayer
                            : item['displayName']?.toString().isEmpty == false
                            ? item['displayName'].toString()
                            : context.l10n.player,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item != null)
                      Icon(
                        item['confirmation'] == 'accepted'
                            ? Icons.check_circle
                            : Icons.schedule,
                        size: 19,
                        color: item['confirmation'] == 'accepted'
                            ? PadelXColors.success
                            : PadelXColors.warning,
                        semanticLabel: item['confirmation'] == 'accepted'
                            ? context.l10n.confirmed
                            : context.l10n.waiting,
                      ),
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

class _VenueScreen extends StatefulWidget {
  final Map<String, dynamic> proposal;
  final MatchmakingRepository repository;
  final GooglePlacesClient? placesClient;
  final ValueChanged<String> onPromoted;
  const _VenueScreen({
    required this.proposal,
    required this.repository,
    this.placesClient,
    required this.onPromoted,
  });
  @override
  State<_VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends State<_VenueScreen> {
  MatchmakingVenueType _type = MatchmakingVenueType.clubPublic;
  MatchLocation? _location;
  bool _busy = false;

  Map<dynamic, dynamic>? get _venueSearch =>
      widget.proposal['venueSearch'] is Map
      ? widget.proposal['venueSearch'] as Map
      : null;

  bool _publicVenueAllowed(MatchLocation location) {
    final search = _venueSearch;
    if (search == null ||
        location.countryCode.trim().toUpperCase() !=
            search['countryCode']?.toString().trim().toUpperCase()) {
      return false;
    }
    final distance = distanceBetweenKm(
      fromLatitude: (search['latitude'] as num?)?.toDouble(),
      fromLongitude: (search['longitude'] as num?)?.toDouble(),
      toLatitude: location.latitude,
      toLongitude: location.longitude,
    );
    final radius = (search['radiusKm'] as num?)?.toDouble();
    return distance != null && radius != null && distance <= radius;
  }

  Future<void> _submit() async {
    final location = _location;
    if (location == null ||
        location.latitude == null ||
        location.longitude == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final matchId = await widget.repository.resolveVenue(
        widget.proposal['proposalId'].toString(),
        _requestId('venue'),
        MatchmakingVenueInput(
          type: _type,
          label: _type == MatchmakingVenueType.privateFree
              ? context.l10n.privateCourt
              : location.clubName,
          placeId: location.placeId,
          address: location.formattedAddress,
          latitude: location.latitude!,
          longitude: location.longitude!,
          countryCode: location.countryCode,
          country: location.country,
          cityId:
              widget.proposal['cityId']?.toString() ??
              widget.proposal['canonicalCityId']?.toString() ??
              '',
          city: location.city,
          area: location.area,
        ),
      );
      if (!mounted) return;
      widget.onPromoted(matchId);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.matchmakingActionFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = _venueSearch;
    final publicSearchReady =
        search != null &&
        hasUsableCoordinates(
          (search['latitude'] as num?)?.toDouble(),
          (search['longitude'] as num?)?.toDouble(),
        ) &&
        (search['radiusKm'] as num?) != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.chooseVenue)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            context.l10n.playersReady,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: PadelXSpace.xs),
          Text(
            context.l10n.chooseVenueToFinish,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: PadelXColors.textSecondary),
          ),
          const SizedBox(height: PadelXSpace.xl),
          SegmentedButton<MatchmakingVenueType>(
            segments: [
              ButtonSegment(
                value: MatchmakingVenueType.clubPublic,
                label: Text(context.l10n.clubPublicCourt),
              ),
              ButtonSegment(
                value: MatchmakingVenueType.privateFree,
                label: Text(context.l10n.privateCourt),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() {
              _type = value.first;
              _location = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_type == MatchmakingVenueType.clubPublic &&
              publicSearchReady) ...[
            PadelXSurface(
              accent: PadelXColors.teamOne,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sports_tennis, color: PadelXColors.teamOne),
                  const SizedBox(width: PadelXSpace.md),
                  Expanded(
                    child: Text(
                      context.l10n.padelVenueRadiusExplanation(
                        ((search['radiusKm'] as num).toDouble())
                            .toStringAsFixed(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            PlacesAutocompleteField(
              key: const Key('padel-venue-search'),
              client: widget.placesClient,
              labelText: context.l10n.padelVenueSearchLabel,
              hintText: context.l10n.padelVenueSearchHint,
              padelVenuesOnly: true,
              countryCode: search['countryCode']?.toString() ?? '',
              biasLatitude: (search['latitude'] as num?)?.toDouble(),
              biasLongitude: (search['longitude'] as num?)?.toDouble(),
              restrictionRadiusKm: (search['radiusKm'] as num?)?.toDouble(),
              selectionValidator: _publicVenueAllowed,
              invalidSelectionMessage: context.l10n.padelVenueOutsideArea,
              emptyMessage: context.l10n.noPadelVenuesInArea,
              onSelected: (value) => setState(() => _location = value),
            ),
          ] else if (_type == MatchmakingVenueType.clubPublic)
            Text(context.l10n.padelVenueSearchUnavailable)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PadelXSurface(
                  accent: PadelXColors.teamTwo,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: PadelXColors.teamTwo,
                      ),
                      const SizedBox(width: PadelXSpace.md),
                      Expanded(
                        child: Text(context.l10n.privateCourtAddressHelp),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PadelXSpace.md),
                PlacesAutocompleteField(
                  client: widget.placesClient,
                  labelText: context.l10n.privateCourtLocation,
                  hintText: context.l10n.searchVenue,
                  onSelected: (value) => setState(() => _location = value),
                ),
              ],
            ),
          if (_location != null) ...[
            const SizedBox(height: PadelXSpace.md),
            PadelXSurface(
              strong: true,
              accent: PadelXColors.success,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: PadelXColors.success),
                  const SizedBox(width: PadelXSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _location!.clubName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: PadelXSpace.xs),
                        Text(
                          _location!.formattedAddress.trim().isNotEmpty
                              ? _location!.formattedAddress.trim()
                              : _location!.localityLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: PadelXSpace.md),
          Text(
            context.l10n.courtBookingSeparate,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed:
                _busy ||
                    _location == null ||
                    (_type == MatchmakingVenueType.privateFree &&
                        _location!.formattedAddress.trim().isEmpty)
                ? null
                : _submit,
            child: Text(context.l10n.confirmVenue),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.matchmakingUnavailable),
        TextButton(onPressed: onRetry, child: Text(context.l10n.tryAgain)),
      ],
    ),
  );
}

class MatchmakingUiException implements Exception {
  const MatchmakingUiException();
}
