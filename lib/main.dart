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
          return ProfileGate(user: snapshot.data!);
        }

        return const AuthScreen();
      },
    );
  }
}

class UserProfile {
  final String uid;
  final String displayName;
  final String level;
  final String email;
  final bool hasCreatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.level,
    required this.email,
    this.hasCreatedAt = false,
  });

  factory UserProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return UserProfile(
      uid: data['uid']?.toString() ?? document.id,
      displayName: data['displayName']?.toString().trim() ?? '',
      level: data['level']?.toString().trim() ?? '',
      email: data['email']?.toString().trim() ?? '',
      hasCreatedAt: data['createdAt'] != null,
    );
  }

  bool get isComplete =>
      uid.isNotEmpty && displayName.isNotEmpty && level.isNotEmpty;
}

class ProfileGate extends StatefulWidget {
  final User user;

  const ProfileGate({super.key, required this.user});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _profileStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return ProfileLoadError(onRetry: () => setState(_refresh));
        }

        final profile = snapshot.data?.exists == true
            ? UserProfile.fromDocument(snapshot.data!)
            : null;
        if (profile == null || !profile.isComplete) {
          return ProfileEditorScreen(
            user: widget.user,
            profile: profile,
            isRequired: true,
          );
        }

        return const HomeScreen();
      },
    );
  }
}

class ProfileLoadError extends StatefulWidget {
  final VoidCallback onRetry;

  const ProfileLoadError({super.key, required this.onRetry});

  @override
  State<ProfileLoadError> createState() => _ProfileLoadErrorState();
}

class _ProfileLoadErrorState extends State<ProfileLoadError> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Could not load your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Check your connection and try again.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: widget.onRetry,
                child: const Text('Try Again'),
              ),
              TextButton(
                onPressed: FirebaseAuth.instance.signOut,
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final Future<void> Function(String email)? passwordResetSender;

  const AuthScreen({super.key, this.passwordResetSender});

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

  Future<void> _showPasswordResetDialog() async {
    final emailSent = await showDialog<bool>(
      context: context,
      builder: (_) => PasswordResetDialog(
        initialEmail: _emailController.text.trim(),
        sender:
            widget.passwordResetSender ??
            (email) =>
                FirebaseAuth.instance.sendPasswordResetEmail(email: email),
      ),
    );

    if (emailSent == true) {
      _showMessage('Password reset email sent. Check your inbox.');
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
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _showPasswordResetDialog,
                              child: const Text('Forgot password?'),
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

class PasswordResetDialog extends StatefulWidget {
  final String initialEmail;
  final Future<void> Function(String email) sender;

  const PasswordResetDialog({
    super.key,
    required this.initialEmail,
    required this.sender,
  });

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  late final TextEditingController _emailController;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await widget.sender(email);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _passwordResetErrorMessage(error);
          _isSending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not send the reset email. Please try again.';
          _isSending = false;
        });
      }
    }
  }

  String _passwordResetErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account was found with that email.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      default:
        return error.message ??
            'Could not send the reset email. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your email and we’ll send you a link to reset your password.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              enabled: !_isSending,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofocus: true,
              onSubmitted: (_) {
                if (!_isSending) {
                  _sendResetEmail();
                }
              },
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSending ? null : _sendResetEmail,
          child: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send reset email'),
        ),
      ],
    );
  }
}

class Match {
  final String id;
  final String title;
  final String club;
  final String level;
  final int spotsLeft;
  final String creatorUid;
  final String creatorEmail;
  final String creatorDisplayName;
  final String creatorLevel;
  final List<MatchPlayer> players;
  final DateTime? scheduledAt;

  const Match({
    required this.id,
    required this.title,
    required this.club,
    required this.level,
    required this.spotsLeft,
    required this.creatorUid,
    required this.creatorEmail,
    this.creatorDisplayName = '',
    this.creatorLevel = '',
    required this.players,
    this.scheduledAt,
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
      creatorUid: data['creatorUid']?.toString() ?? '',
      creatorEmail: data['creatorEmail']?.toString() ?? '',
      creatorDisplayName: data['creatorDisplayName']?.toString() ?? '',
      creatorLevel: data['creatorLevel']?.toString() ?? '',
      scheduledAt: _parseScheduledAt(data['scheduledAt']),
      players: (data['players'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((player) => MatchPlayer.fromMap(player))
          .toList(),
    );
  }
}

DateTime? _parseScheduledAt(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

bool isPastMatch(Match match, DateTime now) =>
    match.scheduledAt?.isBefore(now) ?? false;

List<Match> sortedMatches(Iterable<Match> matches) {
  final sorted = matches.toList();
  sorted.sort((a, b) {
    final aDate = a.scheduledAt;
    final bDate = b.scheduledAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return sorted;
}

String _friendlyDateTime(DateTime value) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '${weekdays[value.weekday - 1]}, ${months[value.month - 1]} '
      '${value.day} · $hour:$minute $period';
}

class MatchPlayer {
  final String uid;
  final String email;
  final String displayName;
  final String level;

  const MatchPlayer({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.level = '',
  });

  factory MatchPlayer.fromMap(Map<dynamic, dynamic> data) {
    return MatchPlayer(
      uid: data['uid']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      level: data['level']?.toString() ?? '',
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

Future<UserProfile?> _loadUserProfile(String uid) async {
  final document = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  return document.exists ? UserProfile.fromDocument(document) : null;
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
        final now = DateTime.now();
        final openMatches = sortedMatches(
          matches.where((match) => !isPastMatch(match, now)),
        );
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final myMatches = currentUid == null
            ? <Match>[]
            : matches
                  .where(
                    (match) =>
                        match.creatorUid == currentUid ||
                        match.players.any((player) => player.uid == currentUid),
                  )
                  .toList();

        final screens = [
          HomeTab(
            onCreateMatch: _openCreateMatchScreen,
            openMatchesCount: openMatches.length,
          ),
          MatchesTab(
            matches: openMatches,
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.hasError,
          ),
          MyMatchesTab(
            matches: myMatches,
            currentUid: currentUid ?? '',
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
              NavigationDestination(
                icon: Icon(Icons.event_available),
                label: 'My Matches',
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
  final String? relationshipLabel;

  const MatchCard({super.key, required this.match, this.relationshipLabel});

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
              if (relationshipLabel != null) ...[
                Chip(
                  avatar: Icon(
                    relationshipLabel == 'Organizing'
                        ? Icons.star_outline
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(relationshipLabel!),
                  backgroundColor: const Color(0xFF1F7A4D),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 12),
              ],
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

class MyMatchesTab extends StatelessWidget {
  final List<Match> matches;
  final String currentUid;
  final bool isLoading;
  final bool error;

  const MyMatchesTab({
    super.key,
    required this.matches,
    required this.currentUid,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error) {
      return const Center(child: Text('Could not load your matches.'));
    }

    if (matches.isEmpty) {
      return const Center(child: Text('You have no matches yet'));
    }

    final now = DateTime.now();
    final upcomingMatches = sortedMatches(
      matches.where((match) => !isPastMatch(match, now)),
    );
    final pastMatches = sortedMatches(
      matches.where((match) => isPastMatch(match, now)),
    ).reversed;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'My Matches',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Matches you organize or have joined.',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        const Text(
          'Upcoming',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (upcomingMatches.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'No upcoming matches.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ...upcomingMatches.map(
          (match) => MatchCard(
            match: match,
            relationshipLabel: match.creatorUid == currentUid
                ? 'Organizing'
                : 'Joined',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Past',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (pastMatches.isEmpty)
          const Text(
            'No past matches.',
            style: TextStyle(color: Colors.white70),
          ),
        if (pastMatches.isNotEmpty)
          ...pastMatches.map(
            (match) => MatchCard(
              match: match,
              relationshipLabel: match.creatorUid == currentUid
                  ? 'Organizing'
                  : 'Joined',
            ),
          ),
      ],
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?.exists != true) {
          return const Center(child: Text('Could not load your profile.'));
        }

        final profile = UserProfile.fromDocument(snapshot.data!);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 44)),
            const SizedBox(height: 20),
            Text(
              profile.displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              profile.email.isEmpty ? user.email ?? '' : profile.email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.trending_up),
                title: const Text('Level'),
                subtitle: Text(profile.level),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfileEditorScreen(user: user, profile: profile),
                ),
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
          ],
        );
      },
    );
  }
}

class ProfileEditorScreen extends StatefulWidget {
  final User user;
  final UserProfile? profile;
  final bool isRequired;

  const ProfileEditorScreen({
    super.key,
    required this.user,
    this.profile,
    this.isRequired = false,
  });

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _levelController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile?.displayName ?? widget.user.displayName ?? '',
    );
    _levelController = TextEditingController(text: widget.profile?.level ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final displayName = _displayNameController.text.trim();
    final level = _levelController.text.trim();
    if (displayName.length < 2) {
      _showMessage('Please enter a display name with at least 2 characters.');
      return;
    }
    if (displayName.length > 40) {
      _showMessage('Display name must be 40 characters or fewer.');
      return;
    }
    if (level.isEmpty) {
      _showMessage('Please enter your level.');
      return;
    }
    if (level.length > 30) {
      _showMessage('Level must be 30 characters or fewer.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final reference = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid);
      await reference.set({
        'uid': widget.user.uid,
        'displayName': displayName,
        'level': level,
        'email': widget.user.email ?? widget.profile?.email ?? '',
        if (widget.profile?.hasCreatedAt != true)
          'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      if (!widget.isRequired) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not save your profile.');
    } catch (_) {
      _showMessage('Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isRequired,
        title: Text(
          widget.isRequired ? 'Complete Your Profile' : 'Edit Profile',
        ),
        backgroundColor: const Color(0xFF0F1412),
        actions: widget.isRequired
            ? [
                IconButton(
                  tooltip: 'Log out',
                  onPressed: _isSaving ? null : FirebaseAuth.instance.signOut,
                  icon: const Icon(Icons.logout),
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.isRequired) ...[
            const Text(
              'Tell other players who they will be sharing the court with.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
          ],
          TextField(
            controller: _displayNameController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Display name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _levelController,
            enabled: !_isSaving,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'Level',
              hintText: 'e.g. 3.5 or Intermediate',
              prefixIcon: Icon(Icons.trending_up),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Profile'),
          ),
        ],
      ),
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
  DateTime? _scheduledAt;

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

    if (club.isEmpty ||
        dateTime.isEmpty ||
        _scheduledAt == null ||
        level.isEmpty ||
        spots.isEmpty) {
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
      final profile = await _loadUserProfile(user.uid);
      await FirebaseFirestore.instance.collection('matches').add({
        'title': dateTime,
        'club': club,
        'dateTime': dateTime,
        'scheduledAt': Timestamp.fromDate(_scheduledAt!),
        'level': level,
        'spotsLeft': spotsLeft,
        'players': <Map<String, String>>[],
        'creatorUid': user.uid,
        'creatorEmail': user.email ?? '',
        'creatorDisplayName': profile?.displayName ?? '',
        'creatorLevel': profile?.level ?? '',
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

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!selected.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a future date and time.')),
      );
      return;
    }

    setState(() {
      _scheduledAt = selected;
      _dateTimeController.text = _friendlyDateTime(selected);
    });
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
            readOnly: true,
            onTap: _selectDateTime,
            decoration: const InputDecoration(
              labelText: 'Date and time',
              hintText: 'Choose a date and time',
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
  bool _isLeaving = false;
  bool _isCancelling = false;

  Future<void> _joinMatch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please log in to join a match.');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final profile = await _loadUserProfile(user.uid);
      final matchRef = FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);
        if (!snapshot.exists) {
          throw const JoinMatchException('This match no longer exists.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        if (data['creatorUid']?.toString() == user.uid) {
          throw const MatchActionException(
            'The organizer cannot join their own match.',
          );
        }
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

        players.add({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': profile?.displayName ?? '',
          'level': profile?.level ?? '',
        });
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

  Future<void> _leaveMatch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please log in to leave a match.');
      return;
    }

    setState(() => _isLeaving = true);

    try {
      final matchRef = FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);
        if (!snapshot.exists) {
          throw const MatchActionException('This match no longer exists.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        if (data['creatorUid']?.toString() == user.uid) {
          throw const MatchActionException(
            'The organizer cannot leave their own match.',
          );
        }

        final players = List<dynamic>.from(
          data['players'] as List? ?? const [],
        );
        final playerIndex = players.indexWhere(
          (player) => player is Map && player['uid']?.toString() == user.uid,
        );

        if (playerIndex == -1) {
          throw const MatchActionException('You have not joined this match.');
        }

        players.removeAt(playerIndex);
        final spotsLeft = _parseSpotsLeft(data['spotsLeft']);
        transaction.update(matchRef, {
          'players': players,
          'spotsLeft': spotsLeft + 1,
        });
      });

      _showMessage('You left the match.');
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not leave the match.');
    } catch (_) {
      _showMessage('Could not leave the match. Please try again.');
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _cancelMatch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please log in to cancel a match.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel match?'),
        content: const Text(
          'This will remove the match for everyone and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Match'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Match'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isCancelling = true);

    try {
      final matchRef = FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);
        if (!snapshot.exists) {
          throw const MatchActionException('This match no longer exists.');
        }

        final creatorUid = snapshot.data()?['creatorUid']?.toString() ?? '';
        if (creatorUid != user.uid) {
          throw const MatchActionException(
            'Only the organizer can cancel this match.',
          );
        }

        transaction.delete(matchRef);
      });

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Match cancelled.')));
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not cancel the match.');
    } catch (_) {
      _showMessage('Could not cancel the match. Please try again.');
    } finally {
      if (mounted) setState(() => _isCancelling = false);
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
        final isOrganizer =
            currentUid != null && match.creatorUid == currentUid;
        final isBusy = _isJoining || _isLeaving || _isCancelling;

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
              if (match.creatorUid.isNotEmpty || match.creatorEmail.isNotEmpty)
                _ProfilePlayerTile(
                  uid: match.creatorUid,
                  fallbackName: match.creatorDisplayName.isNotEmpty
                      ? match.creatorDisplayName
                      : match.creatorEmail,
                  fallbackLevel: match.creatorLevel,
                  role: 'Organizer',
                ),
              ...match.players.map(
                (player) => player.uid == match.creatorUid
                    ? const SizedBox.shrink()
                    : _ProfilePlayerTile(
                        uid: player.uid,
                        fallbackName: player.displayName.isNotEmpty
                            ? player.displayName
                            : player.email,
                        fallbackLevel: player.level,
                        role: 'Confirmed',
                      ),
              ),
              const SizedBox(height: 24),
              if (isOrganizer)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : _cancelMatch,
                    icon: _isCancelling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(
                      _isCancelling ? 'Cancelling...' : 'Cancel Match',
                    ),
                  ),
                )
              else if (hasJoined)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : _leaveMatch,
                    icon: _isLeaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                    label: Text(_isLeaving ? 'Leaving...' : 'Leave Match'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: isBusy || match.spotsLeft <= 0
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

class MatchActionException implements Exception {
  final String message;

  const MatchActionException(this.message);
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

class _ProfilePlayerTile extends StatelessWidget {
  final String uid;
  final String fallbackName;
  final String fallbackLevel;
  final String role;

  const _ProfilePlayerTile({
    required this.uid,
    required this.fallbackName,
    required this.fallbackLevel,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return _PlayerTile(
        name: fallbackName.isEmpty ? 'Player' : fallbackName,
        subtitle: _playerSubtitle(role, fallbackLevel),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.hasData && snapshot.data!.exists
            ? UserProfile.fromDocument(snapshot.data!)
            : null;
        final name = profile?.displayName.isNotEmpty == true
            ? profile!.displayName
            : fallbackName.isEmpty
            ? 'Player'
            : fallbackName;
        final level = profile?.level.isNotEmpty == true
            ? profile!.level
            : fallbackLevel;
        return _PlayerTile(name: name, subtitle: _playerSubtitle(role, level));
      },
    );
  }
}

String _playerSubtitle(String role, String level) {
  return level.isEmpty ? role : '$role · $level';
}
