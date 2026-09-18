import 'package:flutter/material.dart';

import 'blocked_players_screen.dart';
import 'friends_repository.dart';
import 'push_notifications.dart';
import 'safety_policy.dart';
import 'legal.dart';
import 'l10n/app_localizations.dart';
import 'locale_controller.dart';
import 'l10n/l10n.dart';

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
  Widget build(BuildContext context) {
    final localeController = PadelXLocaleScope.maybeOf(context);
    final strings = localeController == null
        ? null
        : AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings?.settings ?? 'Settings')),
      body: ListView(
        children: [
          if (localeController != null) ...[
            _SettingsHeader(strings!.language),
            const PadelXLanguageSettingsTile(),
            const Divider(),
          ],
          _SettingsHeader(context.l10n.account),
          ListTile(
            key: const Key('settings-account'),
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(context.l10n.account),
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
          _SettingsHeader(context.l10n.notifications),
          ListTile(
            key: const Key('settings-notifications'),
            leading: const Icon(Icons.notifications_outlined),
            title: Text(context.l10n.notifications),
            subtitle: Text(context.l10n.pushPermissionCategories),
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
          _SettingsHeader(context.l10n.helpSafety),
          ListTile(
            key: const Key('settings-help-safety'),
            leading: const Icon(Icons.health_and_safety_outlined),
            title: Text(context.l10n.helpSafety),
            subtitle: Text(context.l10n.reportingBlockingAge),
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
          _SettingsHeader(context.l10n.privacy),
          ListTile(
            key: const Key('settings-blocked-players'),
            leading: const Icon(Icons.block_outlined),
            title: Text(context.l10n.blockedPlayers),
            subtitle: Text(context.l10n.reviewUnblock),
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
          _SettingsHeader(context.l10n.legal),
          for (final entry in [
            ('settings-terms', context.l10n.termsOfUse, '/terms'),
            ('settings-privacy', context.l10n.privacyPolicy, '/privacy'),
            (
              'settings-community-legal',
              context.l10n.communityGuidelines,
              '/community-guidelines',
            ),
            (
              'settings-account-deletion-info',
              context.l10n.accountDeletionInfo,
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
            context.l10n.emailAppFailed(supportConfiguration.displayLabel),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.helpSafety)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.safety,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(context.l10n.howReportPlayer),
          subtitle: Text(context.l10n.openReportPlayerHelp),
        ),
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: Text(context.l10n.howReportMessage),
          subtitle: Text(context.l10n.pressHoldReport),
        ),
        ListTile(
          leading: const Icon(Icons.sports_tennis_outlined),
          title: Text(context.l10n.howReportMatch),
          subtitle: Text(context.l10n.openReportMatchHelp),
        ),
        ListTile(
          key: const Key('help-safety-blocked-players'),
          leading: const Icon(Icons.block_outlined),
          title: Text(context.l10n.blockedPlayers),
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
          child: Text(
            context.l10n.ageEligibility,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        Text(context.l10n.adultOnly),
        const Divider(height: 36),
        Semantics(
          header: true,
          child: Text(
            context.l10n.supportSafety,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        Text(context.l10n.needHelp),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(context.l10n.attendanceReliabilityConcerns),
          subtitle: Text(context.l10n.attendanceReliabilitySupport),
        ),
        if (supportConfiguration.mailtoUri != null)
          ListTile(
            key: const Key('contact-padelx-support'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: Text(context.l10n.contactSupport),
            subtitle: Text(supportConfiguration.displayLabel),
            onTap: () => _contactSupport(context),
          ),
        const SizedBox(height: 12),
        Semantics(
          label: context.l10n.emergencySafetyGuidanceLabel,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.immediateDanger,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(context.l10n.immediateDangerBody),
                  SizedBox(height: 6),
                  Text(context.l10n.notEmergencyService),
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
          title: Text(context.l10n.communityGuidelines),
          subtitle: Text(context.l10n.safetyExpectations),
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
            context.l10n.emailAppFailed(supportConfiguration.displayLabel),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.communityGuidelines)),
    body: ListView(
      key: const Key('community-guidelines-list'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        for (final section in localizedCommunityGuidelineSections(
          context.l10n,
        )) ...[
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
            context.l10n.questionsSafety,
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
            context.l10n.emergency,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 6),
        Text(context.l10n.immediateDangerBody),
        const SizedBox(height: 6),
        Text(context.l10n.notEmergencyService),
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
            title: Text(context.l10n.enablePushQuestion),
            content: Text(context.l10n.pushPermissionExplanation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.notNow),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.continueLabel),
              ),
            ],
          ),
        );
        if (permission != true || !mounted) return;
        final state = await widget.pushService.enable(widget.uid);
        if (mounted) setState(() => _permission = state);
        if (state == PushPermissionState.denied && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.pushBlockedHelp)));
        }
      } else {
        await widget.pushService.disable(widget.uid);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.pushUpdateFailed)));
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
          SnackBar(content: Text(context.l10n.notificationPreferencesFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _permissionLabel(
    BuildContext context,
    NotificationPreferences preferences,
  ) {
    return switch (_permission) {
      PushPermissionState.allowed =>
        preferences.pushEnabled ? context.l10n.pushOn : context.l10n.pushOff,
      PushPermissionState.denied => context.l10n.notificationsBlockedSettings,
      PushPermissionState.notDetermined => context.l10n.pushOff,
      PushPermissionState.unsupported => context.l10n.pushUnavailableBuild,
      null =>
        preferences.pushEnabled
            ? context.l10n.checkingDevicePermission
            : context.l10n.pushOff,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.notifications)),
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
              title: Text(context.l10n.pushNotifications),
              subtitle: Text(_permissionLabel(context, preferences)),
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
              Padding(
                key: const Key('push-build-unavailable'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(context.l10n.pushBuildUnavailable),
              ),
            if (_permission == PushPermissionState.denied)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(context.l10n.pushSettingsHelp),
              ),
            const Divider(),
            _SettingsHeader(context.l10n.categories),
            _category(
              context.l10n.matchMessages,
              preferences.matchMessages,
              (value) => preferences.copyWith(matchMessages: value),
            ),
            _category(
              context.l10n.joinRequestsCategory,
              preferences.joinRequests,
              (value) => preferences.copyWith(joinRequests: value),
            ),
            _category(
              context.l10n.friendRequestsCategory,
              preferences.friendRequests,
              (value) => preferences.copyWith(friendRequests: value),
            ),
            _category(
              context.l10n.friendAcceptedCategory,
              preferences.friendAccepted,
              (value) => preferences.copyWith(friendAccepted: value),
            ),
            _category(
              context.l10n.matchUpdatesCategory,
              preferences.matchUpdates,
              (value) => preferences.copyWith(matchUpdates: value),
            ),
            _category(
              context.l10n.playAgain,
              preferences.playAgain,
              (value) => preferences.copyWith(playAgain: value),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.pushCategoriesFuture,
                style: const TextStyle(color: Colors.white60),
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
    appBar: AppBar(title: Text(context.l10n.account)),
    body: ListView(
      children: [
        _SettingsHeader(context.l10n.accountManagement),
        ListTile(
          key: const Key('account-delete-account'),
          leading: Icon(
            Icons.person_remove_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(context.l10n.deleteAccount),
          subtitle: Text(context.l10n.permanentlyDelete),
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
