import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      String message;

      switch (error.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-not-found':
          message = 'No account was found with that email.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with that email.';
          break;
        case 'weak-password':
          message = 'Your password must be at least 6 characters.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = error.message ?? 'Authentication failed.';
      }

      _showMessage(message);
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _switchMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'PadelX',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find matches. Fill spots. Play more padel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isLogin ? 'Welcome back' : 'Create your account',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Log in to continue to PadelX.'
                              : 'Create an account to start playing.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) {
                            if (!_isLoading) {
                              _submit();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(_isLogin ? 'Log In' : 'Create Account'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isLoading ? null : _switchMode,
                          child: Text(
                            _isLogin
                                ? 'New to PadelX? Create an account'
                                : 'Already have an account? Log in',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Match {
  final String id;
  final String title;
  final String club;
  final String level;
  final int spotsLeft;
  final String creatorEmail;
  final List<MatchPlayer> players;

  const Match({
    required this.id,
    required this.title,
    required this.club,
    required this.level,
    required this.spotsLeft,
    required this.creatorEmail,
    required this.players,
  });

  String get spotsLeftLabel =>
      spotsLeft == 1 ? '1 spot left' : '$spotsLeft spots left';

  factory Match.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Match(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      club: data['club']?.toString() ?? '',
      level: data['level']?.toString() ?? '',
      spotsLeft: _parseSpotsLeft(data['spotsLeft']),
      creatorEmail: data['creatorEmail']?.toString() ?? '',
      players: (data['players'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((player) => MatchPlayer.fromMap(player))
          .toList(),
    );
  }
}

class MatchPlayer {
  final String uid;
  final String email;

  const MatchPlayer({required this.uid, required this.email});

  factory MatchPlayer.fromMap(Map<dynamic, dynamic> data) {
    return MatchPlayer(
      uid: data['uid']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
    );
  }
}

int _parseSpotsLeft(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(
        RegExp(r'\d+').firstMatch(value?.toString() ?? '')?.group(0) ?? '',
      ) ??
      0;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openCreateMatchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateMatchScreen()),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final matches = snapshot.hasData
            ? snapshot.data!.docs.map((doc) => Match.fromDocument(doc)).toList()
            : <Match>[];

        final screens = [
          HomeTab(
            onCreateMatch: _openCreateMatchScreen,
            openMatchesCount: matches.length,
          ),
          MatchesTab(
            matches: matches,
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.hasError,
          ),
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
            actions: [
              IconButton(
                tooltip: 'Log out',
                onPressed: _logout,
                icon: const Icon(Icons.logout),
              ),
            ],
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
      },
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
              colors: [Color(0xFF1F7A4D), Color(0xFF194A37)],
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
            leading: const CircleAvatar(child: Icon(Icons.add)),
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
            leading: CircleAvatar(child: Icon(Icons.search)),
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
  final bool isLoading;
  final bool error;

  const MatchesTab({
    super.key,
    required this.matches,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error) {
      return const Center(child: Text('Could not load matches.'));
    }

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

  const MatchCard({super.key, required this.match});

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
                  const CircleAvatar(child: Icon(Icons.sports_tennis)),
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
                  _InfoChip(text: match.spotsLeftLabel, icon: Icons.group),
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
    final user = FirebaseAuth.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 44)),
        const SizedBox(height: 20),
        const Text(
          'Your Profile',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          user?.email ?? 'No email',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        const Card(
          child: ListTile(
            leading: Icon(Icons.trending_up),
            title: Text('Level'),
            subtitle: Text('3.5'),
          ),
        ),
      ],
    );
  }
}

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final TextEditingController _clubController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _spotsController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _clubController.dispose();
    _dateTimeController.dispose();
    _levelController.dispose();
    _spotsController.dispose();
    super.dispose();
  }

  Future<void> _createMatch() async {
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

    final spotsLeft = _parseSpotsLeft(spots);
    if (spotsLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least 1 spot.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create a match.')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      await FirebaseFirestore.instance.collection('matches').add({
        'title': dateTime,
        'club': club,
        'dateTime': dateTime,
        'level': level,
        'spotsLeft': spotsLeft,
        'players': <Map<String, String>>[],
        'creatorUid': user.uid,
        'creatorEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Match created successfully.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not create the match.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the match.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
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
              onPressed: _isCreating ? null : _createMatch,
              icon: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isCreating ? 'Creating...' : 'Create Match'),
            ),
          ),
        ],
      ),
    );
  }
}

class MatchDetailsScreen extends StatefulWidget {
  final Match match;

  const MatchDetailsScreen({super.key, required this.match});

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  bool _isJoining = false;

  Future<void> _joinMatch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please log in to join a match.');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final matchRef = FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);
        if (!snapshot.exists) {
          throw const JoinMatchException('This match no longer exists.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        final players = List<dynamic>.from(
          data['players'] as List? ?? const [],
        );
        final hasJoined = players.whereType<Map>().any(
          (player) => player['uid']?.toString() == user.uid,
        );

        if (hasJoined) {
          throw const JoinMatchException('You have already joined this match.');
        }

        final spotsLeft = _parseSpotsLeft(data['spotsLeft']);
        if (spotsLeft <= 0) {
          throw const JoinMatchException('This match has no spots remaining.');
        }

        players.add({'uid': user.uid, 'email': user.email ?? ''});
        transaction.update(matchRef, {
          'players': players,
          'spotsLeft': spotsLeft - 1,
        });
      });

      _showMessage('You joined the match successfully.');
    } on JoinMatchException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not join the match.');
    } catch (_) {
      _showMessage('Could not join the match. Please try again.');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id)
          .snapshots(),
      builder: (context, snapshot) {
        final match = snapshot.hasData && snapshot.data!.exists
            ? Match.fromDocument(snapshot.data!)
            : widget.match;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final hasJoined = match.players.any(
          (player) => player.uid == currentUid,
        );

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
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(match.club, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(text: match.level, icon: Icons.leaderboard),
                  _InfoChip(text: match.spotsLeftLabel, icon: Icons.group),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Players',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (match.creatorEmail.isNotEmpty)
                _PlayerTile(name: match.creatorEmail, subtitle: 'Organizer'),
              ...match.players.map(
                (player) => _PlayerTile(
                  name: player.email.isEmpty ? 'Player' : player.email,
                  subtitle: 'Confirmed',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isJoining || hasJoined || match.spotsLeft <= 0
                      ? null
                      : _joinMatch,
                  icon: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.group_add),
                  label: Text(
                    _isJoining
                        ? 'Joining...'
                        : hasJoined
                        ? 'Already Joined'
                        : match.spotsLeft <= 0
                        ? 'Match Full'
                        : 'Join Match',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class JoinMatchException implements Exception {
  final String message;

  const JoinMatchException(this.message);
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

  const _InfoChip({required this.text, required this.icon});

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

  const _PlayerTile({required this.name, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final firstLetter = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : '?';

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(firstLetter)),
        title: Text(name),
        subtitle: Text(subtitle),
      ),
    );
  }
}
