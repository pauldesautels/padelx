import 'package:flutter/material.dart';

void main() {
  runApp(const PadelXApp());
}

class PadelXApp extends StatelessWidget {
  const PadelXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PadelX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.greenAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1412),
        cardTheme: CardThemeData(
          color: const Color(0xFF18211D),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class Match {
  final String title;
  final String club;
  final String level;
  final String spotsLeft;

  const Match({
    required this.title,
    required this.club,
    required this.level,
    required this.spotsLeft,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Match> _matches = [
    const Match(
      title: 'Today · 7:00 PM',
      club: 'Club Padel MX',
      level: 'Level 3–4',
      spotsLeft: '1 spot left',
    ),
    const Match(
      title: 'Tomorrow · 8:30 AM',
      club: 'Padel Center',
      level: 'Level 2–3',
      spotsLeft: '2 spots left',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _addMatch(Match match) {
    setState(() {
      _matches.add(match);
      _selectedIndex = 1;
    });
  }

  void _openCreateMatchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMatchScreen(onMatchCreated: _addMatch),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(
        onCreateMatch: _openCreateMatchScreen,
        openMatchesCount: _matches.length,
      ),
      MatchesTab(matches: _matches),
      const ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PadelX',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F1412),
        elevation: 0,
      ),
      body: screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _openCreateMatchScreen,
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: const Color(0xFF121A16),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.sports_tennis),
            label: 'Matches',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  final VoidCallback onCreateMatch;
  final int openMatchesCount;

  const HomeTab({
    super.key,
    required this.onCreateMatch,
    required this.openMatchesCount,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1F7A4D),
                Color(0xFF194A37),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find your next match',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Create games, fill missing spots, and play more padel.',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Open matches',
                value: '$openMatchesCount',
                icon: Icons.sports_tennis,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _StatCard(
                label: 'Your level',
                value: '3.5',
                icon: Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            onTap: onCreateMatch,
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(
              child: Icon(Icons.add),
            ),
            title: const Text(
              'Create a match',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Set time, place, level, and spots'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: CircleAvatar(
              child: Icon(Icons.search),
            ),
            title: Text(
              'Find open matches',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Join games near you'),
          ),
        ),
      ],
    );
  }
}

class MatchesTab extends StatelessWidget {
  final List<Match> matches;

  const MatchesTab({
    super.key,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(child: Text('No open matches yet'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Open matches',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Join games that need players.',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        ...matches.map((match) => MatchCard(match: match)),
      ],
    );
  }
}

class MatchCard extends StatelessWidget {
  final Match match;

  const MatchCard({
    super.key,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchDetailsScreen(match: match),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.sports_tennis),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      match.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 14),
              Text(match.club, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(text: match.level, icon: Icons.leaderboard),
                  _InfoChip(text: match.spotsLeft, icon: Icons.group),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Profile 👤', style: TextStyle(fontSize: 24)),
    );
  }
}

class CreateMatchScreen extends StatefulWidget {
  final void Function(Match match) onMatchCreated;

  const CreateMatchScreen({
    super.key,
    required this.onMatchCreated,
  });

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final TextEditingController _clubController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _spotsController = TextEditingController();

  @override
  void dispose() {
    _clubController.dispose();
    _dateTimeController.dispose();
    _levelController.dispose();
    _spotsController.dispose();
    super.dispose();
  }

  void _createMatch() {
    final club = _clubController.text.trim();
    final dateTime = _dateTimeController.text.trim();
    final level = _levelController.text.trim();
    final spots = _spotsController.text.trim();

    if (club.isEmpty || dateTime.isEmpty || level.isEmpty || spots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final newMatch = Match(
      title: dateTime,
      club: club,
      level: level,
      spotsLeft: spots,
    );

    widget.onMatchCreated(newMatch);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Match'),
        backgroundColor: const Color(0xFF0F1412),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Set up a new game',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add the basic match info so other players can join.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _clubController,
            decoration: const InputDecoration(
              labelText: 'Club name',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dateTimeController,
            decoration: const InputDecoration(
              labelText: 'Date and time',
              hintText: 'Example: Friday · 6:00 PM',
              prefixIcon: Icon(Icons.calendar_month),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _levelController,
            decoration: const InputDecoration(
              labelText: 'Level',
              hintText: 'Example: Level 3–4',
              prefixIcon: Icon(Icons.leaderboard),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _spotsController,
            decoration: const InputDecoration(
              labelText: 'Spots left',
              hintText: 'Example: 1 spot left',
              prefixIcon: Icon(Icons.group),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _createMatch,
              icon: const Icon(Icons.add),
              label: const Text('Create Match'),
            ),
          ),
        ],
      ),
    );
  }
}

class MatchDetailsScreen extends StatelessWidget {
  final Match match;

  const MatchDetailsScreen({
    super.key,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
        backgroundColor: const Color(0xFF0F1412),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            match.title,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(match.club, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(text: match.level, icon: Icons.leaderboard),
              _InfoChip(text: match.spotsLeft, icon: Icons.group),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Players',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const _PlayerTile(name: 'Paul', subtitle: 'Organizer · Level 3.5'),
          const _PlayerTile(name: 'Player 2', subtitle: 'Confirmed'),
          const _PlayerTile(name: 'Player 3', subtitle: 'Confirmed'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                debugPrint('Join match tapped');
              },
              icon: const Icon(Icons.group_add),
              label: const Text('Join Match'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InfoChip({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
      backgroundColor: const Color(0xFF243128),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final String name;
  final String subtitle;

  const _PlayerTile({
    required this.name,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.substring(0, 1)),
        ),
        title: Text(name),
        subtitle: Text(subtitle),
      ),
    );
  }
}