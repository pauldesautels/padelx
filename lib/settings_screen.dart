import 'package:flutter/material.dart';

import 'blocked_players_screen.dart';
import 'friends_repository.dart';

class SettingsScreen extends StatelessWidget {
  final FriendsRepository friendsRepository;
  final VoidCallback onDeleteAccount;

  const SettingsScreen({
    super.key,
    required this.friendsRepository,
    required this.onDeleteAccount,
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
      ],
    ),
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
