import 'package:flutter/material.dart';

import 'blocked_players_screen.dart';
import 'friends_repository.dart';
import 'push_notifications.dart';
import 'safety_policy.dart';
import 'legal.dart';

class SettingsScreen extends StatelessWidget {
  final FriendsRepository friendsRepository;
  final VoidCallback onDeleteAccount;
  final String currentUid;
  final NotificationPreferencesRepository? notificationPreferencesRepository;
  final PushSettingsService? pushSettingsService;

  const SettingsScreen({
    super.key,
    required this.friendsRepository,
    required this.onDeleteAccount,
    this.currentUid = '',
    this.notificationPreferencesRepository,
    this.pushSettingsService,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        const _SettingsHeader('Account'),
        ListTile(
          key: const Key('settings-account'),
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('Account'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AccountSettingsScreen(onDeleteAccount: onDeleteAccount),
            ),
          ),
        ),
        const Divider(),
        const _SettingsHeader('Notifications'),
        ListTile(
          key: const Key('settings-notifications'),
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Notifications'),
          subtitle: const Text('Push permission and notification categories'),
          trailing: const Icon(Icons.chevron_right),
          onTap:
              currentUid.isEmpty ||
                  notificationPreferencesRepository == null ||
                  pushSettingsService == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationSettingsScreen(
                      uid: currentUid,
                      repository: notificationPreferencesRepository!,
                      pushService: pushSettingsService!,
                    ),
                  ),
                ),
        ),
        const Divider(),
        const _SettingsHeader('Help & Safety'),
        ListTile(
          key: const Key('settings-help-safety'),
          leading: const Icon(Icons.health_and_safety_outlined),
          title: const Text('Help & Safety'),
          subtitle: const Text('Reporting, blocking, and age eligibility'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  HelpSafetyScreen(friendsRepository: friendsRepository),
            ),
          ),
        ),
        const Divider(),
        const _SettingsHeader('Privacy'),
        ListTile(
          key: const Key('settings-blocked-players'),
          leading: const Icon(Icons.block_outlined),
          title: const Text('Blocked Players'),
          subtitle: const Text('Review and unblock players'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  BlockedPlayersScreen(repository: friendsRepository),
            ),
          ),
        ),
        const Divider(),
        const _SettingsHeader('Legal'),
        for (final entry in const [
          ('settings-terms', 'Terms of Use', '/terms'),
          ('settings-privacy', 'Privacy Policy', '/privacy'),
          (
            'settings-community-legal',
            'Community Guidelines',
            '/community-guidelines',
          ),
          (
            'settings-account-deletion-info',
            'Account Deletion',
            '/account-deletion',
          ),
        ])
          ListTile(
            key: Key(entry.$1),
            leading: const Icon(Icons.open_in_new),
            title: Text(entry.$2),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openLegalLink(context, entry.$3),
          ),
      ],
    ),
  );
}

class HelpSafetyScreen extends StatelessWidget {
  final FriendsRepository friendsRepository;
  final PadelXSupportConfiguration supportConfiguration;
  final SupportUriLauncher supportLauncher;

  const HelpSafetyScreen({
    super.key,
    required this.friendsRepository,
    this.supportConfiguration = PadelXSupportConfiguration.beta,
    this.supportLauncher = launchSupportUri,
  });

  Future<void> _contactSupport(BuildContext context) async {
    final uri = supportConfiguration.mailtoUri;
    if (uri == null) return;
    var launched = false;
    try {
      launched = await supportLauncher(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open your email app. You can contact us at ${supportConfiguration.displayLabel}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & Safety')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Semantics(
          header: true,
          child: const Text(
            'Safety',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        const ListTile(
          leading: Icon(Icons.person_outline),
          title: Text('How to report a player'),
          subtitle: Text(
            'Open the player’s profile, tap More actions, then Report player.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.chat_bubble_outline),
          title: Text('How to report a message'),
          subtitle: Text(
            'Press and hold a message from another player, then choose Report message.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.sports_tennis_outlined),
          title: Text('How to report a match'),
          subtitle: Text(
            'Open Match Details, then choose Report match from the safety actions.',
          ),
        ),
        ListTile(
          key: const Key('help-safety-blocked-players'),
          leading: const Icon(Icons.block_outlined),
          title: const Text('Blocked Players'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  BlockedPlayersScreen(repository: friendsRepository),
            ),
          ),
        ),
        const Divider(height: 36),
        Semantics(
          header: true,
          child: const Text(
            '18+ eligibility',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        const Text('PadelX is for adults 18 and older.'),
        const Divider(height: 36),
        Semantics(
          header: true,
          child: const Text(
            'Support & Safety',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Need help or want to report a safety concern?'),
        const SizedBox(height: 8),
        if (supportConfiguration.mailtoUri != null)
          ListTile(
            key: const Key('contact-padelx-support'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contact PadelX Support'),
            subtitle: Text(supportConfiguration.displayLabel),
            onTap: () => _contactSupport(context),
          ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Emergency safety guidance',
          child: const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Immediate danger',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(emergencySafetyGuidance),
                  SizedBox(height: 6),
                  Text(notEmergencyServiceGuidance),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 36),
        ListTile(
          key: const Key('help-safety-community-guidelines'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('Community Guidelines'),
          subtitle: const Text('Safety expectations for the PadelX beta'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommunityGuidelinesScreen(
                supportConfiguration: supportConfiguration,
                supportLauncher: supportLauncher,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class CommunityGuidelinesScreen extends StatelessWidget {
  final PadelXSupportConfiguration supportConfiguration;
  final SupportUriLauncher supportLauncher;

  const CommunityGuidelinesScreen({
    super.key,
    this.supportConfiguration = PadelXSupportConfiguration.beta,
    this.supportLauncher = launchSupportUri,
  });

  Future<void> _contactSupport(BuildContext context) async {
    final uri = supportConfiguration.mailtoUri;
    if (uri == null) return;
    var launched = false;
    try {
      launched = await supportLauncher(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open your email app. You can contact us at ${supportConfiguration.displayLabel}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community Guidelines')),
    body: ListView(
      key: const Key('community-guidelines-list'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        for (final section in communityGuidelineSections) ...[
          Semantics(
            header: true,
            child: Text(
              section.heading,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 6),
          for (final paragraph in section.paragraphs) ...[
            Text(paragraph),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
        Semantics(
          header: true,
          child: Text(
            'Questions or safety concerns',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 6),
        if (supportConfiguration.mailtoUri != null)
          TextButton.icon(
            key: const Key('guidelines-contact-support'),
            onPressed: () => _contactSupport(context),
            icon: const Icon(Icons.email_outlined),
            label: Text(supportConfiguration.displayLabel),
          ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            'Emergency',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 6),
        const Text(emergencySafetyGuidance),
        const SizedBox(height: 6),
        const Text(notEmergencyServiceGuidance),
      ],
    ),
  );
}

class NotificationSettingsScreen extends StatefulWidget {
  final String uid;
  final NotificationPreferencesRepository repository;
  final PushSettingsService pushService;

  const NotificationSettingsScreen({
    super.key,
    required this.uid,
    required this.repository,
    required this.pushService,
  });

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  PushPermissionState? _permission;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final permission = await widget.pushService.permissionState();
    if (mounted) setState(() => _permission = permission);
  }

  Future<void> _togglePush(
    NotificationPreferences preferences,
    bool enabled,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (enabled) {
        final permission = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable push notifications?'),
            content: const Text(
              'PadelX will ask iOS for permission and register this device. '
              'You can change individual categories at any time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (permission != true || !mounted) return;
        final state = await widget.pushService.enable(widget.uid);
        if (mounted) setState(() => _permission = state);
        if (state == PushPermissionState.denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are blocked in device settings. Enable them there '
                'to receive PadelX push notifications.',
              ),
            ),
          );
        }
      } else {
        await widget.pushService.disable(widget.uid);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Push notification settings could not be updated.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(NotificationPreferences preferences) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.save(widget.uid, preferences);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification preferences could not be saved.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _permissionLabel(NotificationPreferences preferences) {
    return switch (_permission) {
      PushPermissionState.allowed =>
        preferences.pushEnabled
            ? 'Push notifications on'
            : 'Push notifications off',
      PushPermissionState.denied => 'Notifications blocked in device settings',
      PushPermissionState.notDetermined => 'Push notifications off',
      PushPermissionState.unsupported => 'Unavailable in this build',
      null =>
        preferences.pushEnabled
            ? 'Checking device permission…'
            : 'Push notifications off',
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: StreamBuilder<NotificationPreferences>(
      stream: widget.repository.watch(widget.uid),
      initialData: const NotificationPreferences(),
      builder: (context, snapshot) {
        final preferences = snapshot.data ?? const NotificationPreferences();
        return ListView(
          children: [
            SwitchListTile(
              key: const Key('push-notifications-toggle'),
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Push notifications'),
              subtitle: Text(_permissionLabel(preferences)),
              value:
                  _permission != PushPermissionState.unsupported &&
                  preferences.pushEnabled,
              onChanged:
                  _busy ||
                      _permission == null ||
                      _permission == PushPermissionState.unsupported
                  ? null
                  : (value) => _togglePush(preferences, value),
            ),
            if (_permission == PushPermissionState.unsupported)
              const Padding(
                key: Key('push-build-unavailable'),
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Push notifications are not configured for this build. '
                  'Notification categories can still be prepared below.',
                ),
              ),
            if (_permission == PushPermissionState.denied)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Open your device Settings, select PadelX, then enable '
                  'Notifications before trying again.',
                ),
              ),
            const Divider(),
            const _SettingsHeader('Categories'),
            _category(
              'Match messages',
              preferences.matchMessages,
              (value) => preferences.copyWith(matchMessages: value),
            ),
            _category(
              'Join requests',
              preferences.joinRequests,
              (value) => preferences.copyWith(joinRequests: value),
            ),
            _category(
              'Friend requests',
              preferences.friendRequests,
              (value) => preferences.copyWith(friendRequests: value),
            ),
            _category(
              'Friend accepted',
              preferences.friendAccepted,
              (value) => preferences.copyWith(friendAccepted: value),
            ),
            _category(
              'Match updates',
              preferences.matchUpdates,
              (value) => preferences.copyWith(matchUpdates: value),
            ),
            _category(
              'Play Again',
              preferences.playAgain,
              (value) => preferences.copyWith(playAgain: value),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'These categories are saved now and will control push delivery '
                'as notification types are enabled in later phases.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _category(
    String title,
    bool value,
    NotificationPreferences Function(bool) changed,
  ) => SwitchListTile(
    title: Text(title),
    value: value,
    onChanged: _busy ? null : (next) => _save(changed(next)),
  );
}

class AccountSettingsScreen extends StatelessWidget {
  final VoidCallback onDeleteAccount;

  const AccountSettingsScreen({super.key, required this.onDeleteAccount});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account')),
    body: ListView(
      children: [
        const _SettingsHeader('Account management'),
        ListTile(
          key: const Key('account-delete-account'),
          leading: Icon(
            Icons.person_remove_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Delete Account'),
          subtitle: const Text('Permanently delete your PadelX account'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onDeleteAccount,
        ),
      ],
    ),
  );
}

class _SettingsHeader extends StatelessWidget {
  final String label;
  const _SettingsHeader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
