import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'current_location.dart';
import 'location.dart';
import 'places.dart';
import 'places_autocomplete.dart';

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
  final DiscoveryLocation discoveryLocation;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.level,
    required this.email,
    this.hasCreatedAt = false,
    this.discoveryLocation = const DiscoveryLocation(
      country: '',
      countryCode: '',
      city: '',
    ),
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
      discoveryLocation: DiscoveryLocation.fromMap(data['discoveryLocation']),
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

        return HomeScreen(profile: profile);
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
  final MatchLocation? _location;
  final String status;

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
    MatchLocation? location,
    this.status = '',
  }) : _location = location;

  String get spotsLeftLabel =>
      spotsLeft == 1 ? '1 spot left' : '$spotsLeft spots left';

  MatchLocation get location =>
      _location ??
      MatchLocation(
        clubName: club,
        countryCode: '',
        country: '',
        region: '',
        city: '',
      );

  factory Match.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Match(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      club: data['clubName']?.toString() ?? data['club']?.toString() ?? '',
      level: data['level']?.toString() ?? '',
      spotsLeft: _parseSpotsLeft(data['spotsLeft']),
      creatorUid: matchCreatorUid(data),
      creatorEmail: matchCreatorEmail(data),
      creatorDisplayName: data['creatorDisplayName']?.toString() ?? '',
      creatorLevel: data['creatorLevel']?.toString() ?? '',
      scheduledAt: _parseScheduledAt(data['scheduledAt']),
      players: matchPlayersFromValue(data['players']),
      location: MatchLocation.fromMap(
        data,
        legacyClub: data['club']?.toString() ?? '',
        legacyLocation: data['location'] is String
            ? data['location'].toString()
            : '',
      ),
      status: data['status']?.toString().toLowerCase() ?? '',
    );
  }

  String get locationLabel => location.localityLabel;
}

List<MatchPlayer> matchPlayersFromValue(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((player) => MatchPlayer.fromMap(player))
      .toList();
}

String matchCreatorUid(Map<dynamic, dynamic> data) =>
    data['creatorUid']?.toString() ?? data['createdBy']?.toString() ?? '';

String matchCreatorEmail(Map<dynamic, dynamic> data) =>
    data['creatorEmail']?.toString() ??
    data['createdByEmail']?.toString() ??
    '';

DateTime? _parseScheduledAt(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

bool isPastMatch(Match match, DateTime now) =>
    match.scheduledAt?.isBefore(now) ?? false;

bool isUpcomingMatch(Match match, DateTime now) =>
    match.scheduledAt?.isAfter(now) ?? false;

bool matchAllowsChanges(Match match, DateTime now) =>
    isUpcomingMatch(match, now);

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
      uid: data['uid']?.toString() ?? data['userId']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      level: data['level']?.toString() ?? '',
    );
  }
}

class PublicPlayerProfile {
  final String uid;
  final String displayName;
  final String level;
  final String email;
  final List<Match> matches;
  final List<PlayerRating> ratings;

  const PublicPlayerProfile({
    required this.uid,
    required this.displayName,
    required this.level,
    this.email = '',
    required this.matches,
    this.ratings = const [],
  });

  RatingSummary get ratingSummary => RatingSummary.fromRatings(ratings);
}

class PlayerRating {
  final String matchId;
  final String raterUid;
  final String ratedUid;
  final int rating;
  final DateTime? createdAt;

  const PlayerRating({
    required this.matchId,
    required this.raterUid,
    required this.ratedUid,
    required this.rating,
    this.createdAt,
  });

  factory PlayerRating.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return PlayerRating(
      matchId: data['matchId']?.toString() ?? '',
      raterUid: data['raterUid']?.toString() ?? '',
      ratedUid: data['ratedUid']?.toString() ?? '',
      rating: data['rating'] is int ? data['rating'] as int : 0,
      createdAt: _parseScheduledAt(data['createdAt']),
    );
  }
}

class RatingSummary {
  final double average;
  final int count;

  const RatingSummary({required this.average, required this.count});

  factory RatingSummary.fromRatings(Iterable<PlayerRating> ratings) {
    final valid = ratings.where((item) => item.rating >= 1 && item.rating <= 5);
    final count = valid.length;
    final total = valid.fold<int>(0, (total, item) => total + item.rating);
    return RatingSummary(average: count == 0 ? 0 : total / count, count: count);
  }
}

bool isValidRatingValue(int rating) => rating >= 1 && rating <= 5;

bool matchIncludesIdentity(Match match, String uid, String email) {
  if (uid.isEmpty) return false;
  if (match.creatorUid == uid) return true;
  if (match.creatorEmail.isNotEmpty && email.isNotEmpty) {
    if (match.creatorEmail.toLowerCase() == email.toLowerCase()) return true;
  }
  return match.players.any((player) => player.uid == uid);
}

List<Match> matchesForUser(Iterable<Match> matches, String uid, String email) =>
    matches.where((match) => matchIncludesIdentity(match, uid, email)).toList();

bool canRatePlayerForMatch({
  required Match match,
  required String raterUid,
  required String raterEmail,
  required String ratedUid,
  required String ratedEmail,
  required DateTime now,
  PlayerRating? existingRating,
}) {
  return raterUid.isNotEmpty &&
      ratedUid.isNotEmpty &&
      raterUid != ratedUid &&
      existingRating == null &&
      isPastMatch(match, now) &&
      matchIncludesIdentity(match, raterUid, raterEmail) &&
      matchIncludesIdentity(match, ratedUid, ratedEmail);
}

typedef PublicPlayerProfileLoader =
    Future<PublicPlayerProfile> Function(String uid);

bool matchIncludesPlayer(Map<dynamic, dynamic> data, String uid) {
  if (uid.isEmpty) return false;
  if (matchCreatorUid(data) == uid) return true;
  final players = data['players'];
  return players is List &&
      players.whereType<Map>().any((player) => _playerUid(player) == uid);
}

List<Match> recentPlayerMatches(Iterable<Match> matches, {int limit = 5}) {
  final sorted = matches.toList()
    ..sort((a, b) {
      final aDate = a.scheduledAt;
      final bDate = b.scheduledAt;
      if (aDate == null && bDate == null) return a.id.compareTo(b.id);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
  return sorted.take(limit).toList();
}

Future<PublicPlayerProfile> loadPublicPlayerProfile(String uid) async {
  if (uid.isEmpty) {
    return const PublicPlayerProfile(
      uid: '',
      displayName: '',
      level: '',
      matches: [],
    );
  }

  final firestore = FirebaseFirestore.instance;
  final results = await Future.wait([
    firestore.collection('users').doc(uid).get(),
    firestore.collection('matches').get(),
    firestore
        .collectionGroup('ratings')
        .where('ratedUid', isEqualTo: uid)
        .get(),
  ]);
  final userDocument = results[0] as DocumentSnapshot<Map<String, dynamic>>;
  final matchSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
  final ratingSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
  final profile = userDocument.exists
      ? UserProfile.fromDocument(userDocument)
      : null;
  final matches = matchSnapshot.docs
      .where((document) => matchIncludesPlayer(document.data(), uid))
      .map(Match.fromDocument)
      .toList();

  return PublicPlayerProfile(
    uid: uid,
    displayName: profile?.displayName ?? '',
    level: profile?.level ?? '',
    email: profile?.email ?? '',
    matches: matches,
    ratings: ratingSnapshot.docs.map(PlayerRating.fromDocument).toList(),
  );
}

bool isOrganizerIdentity(
  Map<dynamic, dynamic> matchData,
  String uid,
  String email,
) {
  final creatorUid = matchCreatorUid(matchData);
  if (creatorUid.isNotEmpty) return creatorUid == uid;
  final creatorEmail = matchCreatorEmail(matchData).toLowerCase();
  return creatorEmail.isNotEmpty && creatorEmail == email.toLowerCase();
}

bool _isMatchOrganizer(Match match, String uid, String email) =>
    isOrganizerIdentity(
      {'creatorUid': match.creatorUid, 'creatorEmail': match.creatorEmail},
      uid,
      email,
    );

bool canEditMatch(Match match, String? uid, String email) =>
    uid != null && _isMatchOrganizer(match, uid, email);

int matchTotalCapacity(Match match) =>
    (1 + match.players.length + match.spotsLeft).clamp(
      1 + match.players.length,
      4,
    );

Map<String, dynamic> buildMatchEditUpdate({
  required Match match,
  required MatchLocation location,
  required DateTime scheduledAt,
  required String level,
  required int totalCapacity,
}) {
  final confirmedCount = 1 + match.players.length;
  if (totalCapacity < confirmedCount) {
    throw MatchActionException(
      'Capacity cannot be lower than the $confirmedCount confirmed players.',
    );
  }
  if (totalCapacity > 4) {
    throw const MatchActionException(
      'A padel match can have at most 4 players.',
    );
  }
  if (!location.isValid) {
    throw const MatchActionException('Please select a complete club location.');
  }
  if (level.trim().isEmpty) {
    throw const MatchActionException('Please enter a player level.');
  }
  return {
    'title': _friendlyDateTime(scheduledAt),
    'dateTime': _friendlyDateTime(scheduledAt),
    'scheduledAt': Timestamp.fromDate(scheduledAt),
    'club': location.clubName.trim(),
    'clubName': location.clubName.trim(),
    'location': location.toMap(),
    'level': level.trim(),
    'spotsLeft': totalCapacity - confirmedCount,
  };
}

String _playerUid(Map<dynamic, dynamic> player) =>
    player['uid']?.toString() ?? player['userId']?.toString() ?? '';

class JoinRequest {
  final String matchId;
  final String userId;
  final String displayName;
  final String level;
  final String email;
  final String status;
  final DateTime? requestedAt;
  final String eventId;

  const JoinRequest({
    this.matchId = '',
    required this.userId,
    required this.displayName,
    required this.level,
    required this.email,
    required this.status,
    this.requestedAt,
    this.eventId = '',
  });

  factory JoinRequest.fromMap(Map<dynamic, dynamic> data) {
    return JoinRequest(
      userId: data['userId']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      level: data['level']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      requestedAt: _parseScheduledAt(data['requestedAt']),
      eventId: data['eventId']?.toString() ?? '',
    );
  }

  factory JoinRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final request = JoinRequest.fromMap(
      document.data() ?? const <String, dynamic>{},
    );
    return JoinRequest(
      matchId: document.reference.parent.parent?.id ?? '',
      userId: request.userId,
      displayName: request.displayName,
      level: request.level,
      email: request.email,
      status: request.status,
      requestedAt: request.requestedAt,
      eventId: request.eventId,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'displayName': displayName,
    'level': level,
    'email': email,
    'status': status,
    'requestedAt': requestedAt == null
        ? Timestamp.now()
        : Timestamp.fromDate(requestedAt!),
    'eventId': eventId,
  };
}

enum AppNotificationType { joinRequest, joinApproved, joinDeclined }

extension AppNotificationTypeStorage on AppNotificationType {
  String get storageValue => switch (this) {
    AppNotificationType.joinRequest => 'join_request',
    AppNotificationType.joinApproved => 'join_approved',
    AppNotificationType.joinDeclined => 'join_declined',
  };

  static AppNotificationType fromStorage(Object? value) =>
      switch (value?.toString()) {
        'join_approved' || 'joinApproved' => AppNotificationType.joinApproved,
        'join_declined' || 'joinDeclined' => AppNotificationType.joinDeclined,
        _ => AppNotificationType.joinRequest,
      };
}

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String recipientUid;
  final String matchId;
  final String matchClubName;
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;
  final String eventId;
  final String actorUid;
  final String actorDisplayName;

  const AppNotification({
    required this.id,
    required this.type,
    required this.recipientUid,
    required this.matchId,
    this.matchClubName = '',
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    required this.eventId,
    this.actorUid = '',
    this.actorDisplayName = '',
  });

  factory AppNotification.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return AppNotification.fromMap(document.id, document.data());
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic>? value) {
    final data = value ?? const <String, dynamic>{};
    return AppNotification(
      id: id,
      type: AppNotificationTypeStorage.fromStorage(data['type']),
      recipientUid: data['recipientUid']?.toString() ?? '',
      matchId: data['matchId']?.toString() ?? '',
      matchClubName: data['matchClubName']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      read: data['isRead'] == true || data['read'] == true,
      createdAt: _parseScheduledAt(data['createdAt']),
      eventId: data['eventId']?.toString() ?? '',
      actorUid: data['actorUid']?.toString() ?? '',
      actorDisplayName: data['actorDisplayName']?.toString() ?? '',
    );
  }
}

String notificationDocumentId(
  AppNotificationType type,
  String matchId,
  String eventId,
) => '${type.storageValue}_${matchId}_$eventId';

Map<String, dynamic> buildJoinRequestNotification({
  required String recipientUid,
  required String matchId,
  required String matchClubName,
  required String eventId,
  required String actorUid,
  required String actorDisplayName,
}) => {
  'type': AppNotificationType.joinRequest.storageValue,
  'recipientUid': recipientUid,
  'matchId': matchId,
  'matchClubName': matchClubName,
  'title': 'New join request',
  'message':
      '$actorDisplayName requested to join your match at $matchClubName.',
  'isRead': false,
  'createdAt': FieldValue.serverTimestamp(),
  'eventId': eventId,
  'actorUid': actorUid,
  'actorDisplayName': actorDisplayName,
};

Map<String, dynamic> buildReviewNotification({
  required bool approve,
  required String recipientUid,
  required String matchId,
  required String club,
  required String eventId,
  required String actorUid,
  required String actorDisplayName,
}) => {
  'type': approve
      ? AppNotificationType.joinApproved.storageValue
      : AppNotificationType.joinDeclined.storageValue,
  'recipientUid': recipientUid,
  'matchId': matchId,
  'matchClubName': club,
  'title': approve ? 'Request approved' : 'Request declined',
  'message':
      'Your request to join the match at $club was '
      '${approve ? 'approved' : 'declined'}.',
  'isRead': false,
  'createdAt': FieldValue.serverTimestamp(),
  'eventId': eventId,
  'actorUid': actorUid,
  'actorDisplayName': actorDisplayName,
};

int unreadNotificationCount(Iterable<AppNotification> notifications) =>
    notifications.where((notification) => !notification.read).length;

List<AppNotification> sortedNotifications(
  Iterable<AppNotification> notifications,
) {
  final sorted = notifications.toList();
  sorted.sort((a, b) {
    if (a.createdAt == null && b.createdAt == null) {
      return b.id.compareTo(a.id);
    }
    if (a.createdAt == null) return 1;
    if (b.createdAt == null) return -1;
    return b.createdAt!.compareTo(a.createdAt!);
  });
  return sorted;
}

String relativeNotificationTime(DateTime? createdAt, DateTime now) {
  if (createdAt == null) return 'Time unavailable';
  final difference = now.difference(createdAt);
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) {
    return '${difference.inHours} hr${difference.inHours == 1 ? '' : 's'} ago';
  }
  if (difference.inHours < 48) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays} days ago';
  return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
}

String? joinRequestNotificationStatus(
  AppNotification notification,
  Map<String, dynamic>? requestData,
) {
  if (notification.type != AppNotificationType.joinRequest ||
      notification.eventId.isEmpty) {
    return null;
  }
  if (requestData == null) return 'No longer active';
  final requestEventId = requestData['eventId']?.toString() ?? '';
  if (requestEventId != notification.eventId) return 'No longer active';
  return switch (requestData['status']?.toString()) {
    'pending' => 'Pending',
    'approved' => 'Approved',
    'declined' => 'Declined',
    _ => 'No longer active',
  };
}

bool canReadNotification(String authenticatedUid, String recipientUid) =>
    authenticatedUid.isNotEmpty && authenticatedUid == recipientUid;

Map<String, bool> notificationReadUpdate() => const {'isRead': true};

Match? matchForNotification(
  AppNotification notification,
  Iterable<Match> matches,
) {
  if (notification.matchId.isEmpty) return null;
  for (final match in matches) {
    if (match.id == notification.matchId) return match;
  }
  return null;
}

class NotificationBadge extends StatelessWidget {
  final int count;
  final bool selected;

  const NotificationBadge({
    super.key,
    required this.count,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(
        selected ? Icons.notifications : Icons.notifications_outlined,
      ),
    );
  }
}

class NotificationsTab extends StatelessWidget {
  final List<AppNotification> notifications;
  final bool isLoading;
  final bool error;
  final ValueChanged<AppNotification> onMarkRead;
  final ValueChanged<AppNotification> onOpen;
  final VoidCallback? onMarkAllRead;
  final Stream<Map<String, dynamic>?> Function(AppNotification)?
  joinRequestStream;
  final DateTime? now;

  const NotificationsTab({
    super.key,
    required this.notifications,
    required this.isLoading,
    required this.error,
    required this.onMarkRead,
    required this.onOpen,
    this.onMarkAllRead,
    this.joinRequestStream,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error) {
      return const Center(child: Text('Could not load notifications.'));
    }
    if (notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none, size: 52, color: Colors.white54),
              SizedBox(height: 14),
              Text(
                'No notifications yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Join request updates will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      );
    }
    final ordered = sortedNotifications(notifications);
    final hasUnread = unreadNotificationCount(ordered) > 0;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: ordered.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Row(
            children: [
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              if (hasUnread && onMarkAllRead != null)
                TextButton(
                  onPressed: onMarkAllRead,
                  child: const Text('Mark all as read'),
                ),
            ],
          );
        }
        final notification = ordered[index - 1];
        return NotificationCard(
          notification: notification,
          now: now ?? DateTime.now(),
          onMarkRead: onMarkRead,
          onOpen: onOpen,
          requestStream: joinRequestStream?.call(notification),
        );
      },
    );
  }
}

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final DateTime now;
  final ValueChanged<AppNotification> onMarkRead;
  final ValueChanged<AppNotification> onOpen;
  final Stream<Map<String, dynamic>?>? requestStream;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.now,
    required this.onMarkRead,
    required this.onOpen,
    this.requestStream,
  });

  @override
  Widget build(BuildContext context) {
    if (requestStream != null &&
        notification.type == AppNotificationType.joinRequest) {
      return StreamBuilder<Map<String, dynamic>?>(
        stream: requestStream,
        builder: (context, snapshot) => _buildCard(
          snapshot.connectionState == ConnectionState.waiting
              ? null
              : joinRequestNotificationStatus(notification, snapshot.data),
        ),
      );
    }
    return _buildCard(null);
  }

  Widget _buildCard(String? status) {
    return Card(
      key: ValueKey('notification-${notification.id}'),
      color: notification.read
          ? const Color(0xFF18211D)
          : const Color(0xFF203A2D),
      child: ListTile(
        onTap: () => onOpen(notification),
        leading: Icon(
          notification.type == AppNotificationType.joinRequest
              ? Icons.person_add_alt_1
              : notification.type == AppNotificationType.joinApproved
              ? Icons.check_circle_outline
              : Icons.cancel_outlined,
          color: notification.read ? Colors.white60 : Colors.greenAccent,
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.message),
              const SizedBox(height: 5),
              Text(
                [
                  relativeNotificationTime(notification.createdAt, now),
                  ?status,
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
        ),
        trailing: notification.read
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: 'Mark as read',
                onPressed: () => onMarkRead(notification),
                icon: const Icon(Icons.mark_email_read_outlined),
              ),
      ),
    );
  }
}

enum MatchParticipationState { organizer, confirmed, pending, available }

MatchParticipationState resolveMatchParticipationState({
  required bool isOrganizer,
  required bool isConfirmedPlayer,
  String? requestStatus,
}) {
  if (isOrganizer) return MatchParticipationState.organizer;
  if (isConfirmedPlayer) return MatchParticipationState.confirmed;
  if (requestStatus == 'pending') return MatchParticipationState.pending;
  return MatchParticipationState.available;
}

String matchParticipationButtonLabel(
  MatchParticipationState state, {
  required int spotsLeft,
}) {
  return switch (state) {
    MatchParticipationState.organizer => 'Cancel Match',
    MatchParticipationState.confirmed => 'Leave Match',
    MatchParticipationState.pending => 'Request Pending',
    MatchParticipationState.available when spotsLeft <= 0 => 'Match Full',
    MatchParticipationState.available => 'Request to Join',
  };
}

int _parseSpotsLeft(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(
        RegExp(r'\d+').firstMatch(value?.toString() ?? '')?.group(0) ?? '',
      ) ??
      0;
}

Object? normalizeFirestoreValue(Object? value) {
  if (value == null ||
      value is String ||
      value is num ||
      value is bool ||
      value is Timestamp ||
      value is GeoPoint ||
      value is Blob ||
      value is DocumentReference) {
    return value;
  }
  if (value is DateTime) return Timestamp.fromDate(value);
  if (value is Map) {
    final normalized = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException(
          'Firestore map keys must be strings, found ${entry.key.runtimeType}.',
        );
      }
      normalized[entry.key as String] = normalizeFirestoreValue(entry.value);
    }
    return normalized;
  }
  if (value is Iterable) {
    return value.map(normalizeFirestoreValue).toList(growable: true);
  }
  throw FormatException(
    'Unsupported Firestore player value type: ${value.runtimeType}.',
  );
}

List<Map<String, dynamic>> normalizeLegacyPlayers(Object? value) {
  if (value == null) return <Map<String, dynamic>>[];
  final normalized = normalizeFirestoreValue(value);
  if (normalized is! List) {
    throw FormatException(
      'The legacy players field must be a list, found ${value.runtimeType}.',
    );
  }
  return normalized
      .map((player) {
        if (player is! Map<String, dynamic>) {
          throw FormatException(
            'Every legacy player must be a map, found ${player.runtimeType}.',
          );
        }
        return player;
      })
      .toList(growable: true);
}

({Object error, StackTrace stackTrace}) _unboxWebError(
  Object error,
  StackTrace stackTrace,
) {
  try {
    final dynamic boxedError = error;
    final dynamic innerError = boxedError.error;
    if (innerError is Object) {
      final dynamic innerStack = boxedError.stack;
      return (
        error: innerError,
        stackTrace: innerStack is StackTrace
            ? innerStack
            : StackTrace.fromString(
                innerStack?.toString() ?? stackTrace.toString(),
              ),
      );
    }
  } catch (_) {
    // Native platforms and ordinary Dart errors do not expose boxed JS fields.
  }
  return (error: error, stackTrace: stackTrace);
}

void validateJoinRequest(
  Map<String, dynamic> matchData,
  Map<String, dynamic>? existingRequestData,
  JoinRequest request,
) {
  final players = normalizeLegacyPlayers(matchData['players']);
  if (players.whereType<Map>().any(
    (player) => _playerUid(player) == request.userId,
  )) {
    throw const MatchActionException(
      'You are already a confirmed player in this match.',
    );
  }

  if (existingRequestData?['status']?.toString() == 'pending') {
    throw const MatchActionException('Your request is already pending.');
  }
  if (existingRequestData?['status']?.toString() == 'approved') {
    throw const MatchActionException(
      'You are already a confirmed player in this match.',
    );
  }
}

Map<String, dynamic> buildReviewRequestUpdate(
  Map<String, dynamic> matchData,
  Map<String, dynamic> requestData, {
  void Function(String checkpoint, Object? details)? onCheckpoint,
}) {
  void checkpoint(String name, [Object? details]) =>
      onCheckpoint?.call(name, details);

  checkpoint('request status access starting');
  if (requestData['status']?.toString() != 'pending') {
    throw const MatchActionException(
      'This join request has already been reviewed.',
    );
  }
  checkpoint('request status validated');

  checkpoint('legacy player normalization starting');
  final players = normalizeLegacyPlayers(matchData['players']);
  checkpoint('legacy player normalization complete', 'count=${players.length}');
  checkpoint('confirmed ID calculation starting');
  final confirmedIds = players
      .whereType<Map>()
      .map(_playerUid)
      .where((uid) => uid.isNotEmpty)
      .toSet();
  checkpoint(
    'confirmed ID calculation complete',
    'count=${confirmedIds.length}',
  );
  checkpoint('request userId access starting');
  final requestUserId = requestData['userId']?.toString() ?? '';
  checkpoint(
    'request userId access complete',
    'isEmpty=${requestUserId.isEmpty}',
  );
  checkpoint('duplicate check starting');
  if (confirmedIds.contains(requestUserId)) {
    throw const MatchActionException('This player is already confirmed.');
  }
  checkpoint('duplicate check complete');
  checkpoint(
    'spotsLeft parsing starting',
    'type=${matchData['spotsLeft'].runtimeType}',
  );
  final spotsLeft = _parseSpotsLeft(matchData['spotsLeft']);
  checkpoint('spotsLeft parsing complete', spotsLeft);
  checkpoint('capacity check starting');
  if (confirmedIds.length >= 3 || spotsLeft <= 0) {
    throw const MatchActionException(
      'This match is full. The request was not approved.',
    );
  }
  checkpoint('capacity check complete');
  checkpoint('approved player construction starting');
  players.add({
    'uid': requestUserId,
    'email': requestData['email']?.toString() ?? '',
    'displayName': requestData['displayName']?.toString() ?? '',
    'level': requestData['level']?.toString() ?? '',
  });
  checkpoint(
    'approved player construction complete',
    players.last.keys.toList(),
  );
  checkpoint('remaining capacity calculation starting');
  final capacityRemaining = 3 - (confirmedIds.length + 1);
  final configuredRemaining = spotsLeft - 1;
  checkpoint(
    'remaining capacity calculation complete',
    'configured=$configuredRemaining, capacity=$capacityRemaining',
  );
  return {
    'players': players,
    'spotsLeft': configuredRemaining < capacityRemaining
        ? configuredRemaining
        : capacityRemaining,
  };
}

Map<String, dynamic> buildRequestStatusUpdate(
  Map<String, dynamic> requestData, {
  required bool approve,
  String? eventId,
}) {
  if (requestData['status']?.toString() != 'pending') {
    throw const MatchActionException(
      'This join request has already been reviewed.',
    );
  }
  return {
    'status': approve ? 'approved' : 'declined',
    if ((requestData['eventId']?.toString() ?? '').isEmpty && eventId != null)
      'eventId': eventId,
  };
}

Future<String> resolveOrganizerNotificationUid(
  Map<String, dynamic> matchData,
) async {
  final uid = matchCreatorUid(matchData);
  if (uid.isNotEmpty) return uid;
  final email = matchCreatorEmail(matchData);
  if (email.isEmpty) {
    throw const MatchActionException('Could not identify the match organizer.');
  }
  final profiles = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email)
      .limit(2)
      .get();
  if (profiles.docs.length != 1) {
    throw const MatchActionException('Could not identify the match organizer.');
  }
  return profiles.docs.single.id;
}

Future<UserProfile?> _loadUserProfile(String uid) async {
  final document = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  return document.exists ? UserProfile.fromDocument(document) : null;
}

class HomeScreen extends StatefulWidget {
  final UserProfile? profile;
  const HomeScreen({super.key, this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _reportStreamError(String streamName, AsyncSnapshot<Object?> snapshot) {
    if (!snapshot.hasError) return;
    final error = snapshot.error;
    if (error is FirebaseException) {
      debugPrint(
        'Firestore $streamName stream failed '
        '[${error.plugin}/${error.code}]: ${error.message}',
      );
    } else {
      debugPrint('$streamName stream failed: $error');
    }
    if (snapshot.stackTrace != null) {
      debugPrintStack(stackTrace: snapshot.stackTrace);
    }
  }

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

  Future<void> _markNotificationRead(AppNotification notification) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || notification.read) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notification.id)
        .update(notificationReadUpdate());
  }

  Future<void> _markAllNotificationsRead(
    List<AppNotification> notifications,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final unread = notifications.where((notification) => !notification.read);
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final notification in unread) {
      batch.update(
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id),
        notificationReadUpdate(),
      );
    }
    await batch.commit();
  }

  Stream<Map<String, dynamic>?> _joinRequestForNotification(
    AppNotification notification,
  ) {
    if (notification.actorUid.isEmpty || notification.matchId.isEmpty) {
      return Stream.value(null);
    }
    return FirebaseFirestore.instance
        .collection('matches')
        .doc(notification.matchId)
        .collection('joinRequests')
        .doc(notification.actorUid)
        .snapshots()
        .map((document) => document.data());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        _reportStreamError('matches', snapshot);
        final matches = snapshot.hasData
            ? snapshot.data!.docs.map((doc) => Match.fromDocument(doc)).toList()
            : <Match>[];
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid == null) {
          return _buildScaffold(snapshot, matches, const [], '');
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collectionGroup('joinRequests')
              .where('userId', isEqualTo: currentUid)
              .snapshots(),
          builder: (context, requestSnapshot) {
            _reportStreamError('current-user joinRequests', requestSnapshot);
            final pendingMatchIds = requestSnapshot.hasData
                ? requestSnapshot.data!.docs
                      .map(JoinRequest.fromDocument)
                      .where((request) => request.status == 'pending')
                      .map((request) => request.matchId)
                      .toSet()
                : <String>{};
            final pendingMatches = matches
                .where((match) => pendingMatchIds.contains(match.id))
                .toList();
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientUid', isEqualTo: currentUid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, notificationSnapshot) {
                _reportStreamError('notifications', notificationSnapshot);
                final notifications = notificationSnapshot.hasData
                    ? notificationSnapshot.data!.docs
                          .map(AppNotification.fromDocument)
                          .toList()
                    : <AppNotification>[];
                return _buildScaffold(
                  snapshot,
                  matches,
                  pendingMatches,
                  currentUid,
                  requestsError: requestSnapshot.hasError,
                  notifications: notifications,
                  notificationsLoading:
                      notificationSnapshot.connectionState ==
                      ConnectionState.waiting,
                  notificationsError: notificationSnapshot.hasError,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    List<Match> matches,
    List<Match> pendingMatches,
    String currentUid, {
    bool requestsError = false,
    List<AppNotification> notifications = const [],
    bool notificationsLoading = false,
    bool notificationsError = false,
  }) {
    final now = DateTime.now();
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final openMatches = sortedMatches(
      matches.where(
        (match) => isUpcomingMatch(match, now) && match.status != 'cancelled',
      ),
    );
    final myMatches = matchesForUser(matches, currentUid, currentEmail);
    final screens = [
      HomeTab(
        onCreateMatch: _openCreateMatchScreen,
        openMatchesCount: openMatches.length,
      ),
      MatchesTab(
        matches: openMatches,
        currentUid: currentUid,
        currentEmail: currentEmail,
        pendingMatchIds: pendingMatches.map((match) => match.id).toSet(),
        preferredLocation: widget.profile?.discoveryLocation,
        onCreateMatch: _openCreateMatchScreen,
        isLoading: snapshot.connectionState == ConnectionState.waiting,
        error: snapshot.hasError,
      ),
      MyMatchesTab(
        matches: myMatches,
        pendingMatches: pendingMatches,
        currentUid: currentUid,
        currentEmail: currentEmail,
        isLoading: snapshot.connectionState == ConnectionState.waiting,
        error: snapshot.hasError || requestsError,
      ),
      NotificationsTab(
        notifications: notifications,
        isLoading: notificationsLoading,
        error: notificationsError,
        onMarkRead: _markNotificationRead,
        onMarkAllRead: () => _markAllNotificationsRead(notifications),
        joinRequestStream: _joinRequestForNotification,
        onOpen: (notification) {
          _markNotificationRead(notification);
          final match = matchForNotification(notification, matches);
          if (match != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MatchDetailsScreen(match: match),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This match is no longer available.'),
              ),
            );
          }
        },
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
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(
            icon: Icon(Icons.sports_tennis),
            label: 'Matches',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_available),
            label: 'My Matches',
          ),
          NavigationDestination(
            icon: NotificationBadge(
              count: unreadNotificationCount(notifications),
            ),
            selectedIcon: NotificationBadge(
              count: unreadNotificationCount(notifications),
              selected: true,
            ),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
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

enum MatchDateFilter { all, today, tomorrow, thisWeek }

List<Match> filterDiscoveredMatches(
  Iterable<Match> matches, {
  String search = '',
  String? country,
  String? city,
  String? area,
  MatchDateFilter date = MatchDateFilter.all,
  String? level,
  bool availableOnly = false,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final start = DateTime(current.year, current.month, current.day);
  final tomorrow = start.add(const Duration(days: 1));
  final dayAfterTomorrow = tomorrow.add(const Duration(days: 1));
  final nextWeek = start.add(
    Duration(days: DateTime.daysPerWeek - current.weekday + 1),
  );
  bool matchesDate(Match match) {
    if (date == MatchDateFilter.all) return true;
    final value = match.scheduledAt;
    if (value == null) return false;
    return switch (date) {
      MatchDateFilter.all => true,
      MatchDateFilter.today =>
        !value.isBefore(start) && value.isBefore(tomorrow),
      MatchDateFilter.tomorrow =>
        !value.isBefore(tomorrow) && value.isBefore(dayAfterTomorrow),
      MatchDateFilter.thisWeek =>
        !value.isBefore(start) && value.isBefore(nextWeek),
    };
  }

  final query = search.trim().toLowerCase();
  return sortedMatches(
    matches.where(
      (match) =>
          !isPastMatch(match, current) &&
          match.status != 'cancelled' &&
          (query.isEmpty ||
              match.club.toLowerCase().contains(query) ||
              match.locationLabel.toLowerCase().contains(query)) &&
          sameLocationValue(match.location.country, country) &&
          sameLocationValue(match.location.city, city) &&
          sameLocationValue(match.location.area, area) &&
          (level == null || match.level == level) &&
          (!availableOnly || match.spotsLeft > 0) &&
          matchesDate(match),
    ),
  );
}

List<Match> filterNearbyMatches(
  Iterable<Match> matches, {
  required double centerLatitude,
  required double centerLongitude,
  double radiusKm = 25,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final distances = <String, double>{};
  final nearby = matches.where((match) {
    if (isPastMatch(match, current) || match.status == 'cancelled') {
      return false;
    }
    final distance = distanceBetweenKm(
      fromLatitude: centerLatitude,
      fromLongitude: centerLongitude,
      toLatitude: match.location.latitude,
      toLongitude: match.location.longitude,
    );
    if (distance == null || distance > radiusKm) return false;
    distances[match.id] = distance;
    return true;
  }).toList();
  nearby.sort((a, b) {
    final aDate = a.scheduledAt;
    final bDate = b.scheduledAt;
    if (aDate == null && bDate != null) return 1;
    if (aDate != null && bDate == null) return -1;
    final dateComparison = aDate?.compareTo(bDate!) ?? 0;
    if (dateComparison != 0) return dateComparison;
    return distances[a.id]!.compareTo(distances[b.id]!);
  });
  return nearby;
}

class MatchesTab extends StatefulWidget {
  final List<Match> matches;
  final bool isLoading;
  final bool error;
  final String currentUid;
  final String currentEmail;
  final Set<String> pendingMatchIds;
  final DiscoveryLocation? preferredLocation;
  final VoidCallback? onCreateMatch;
  final CurrentLocationProvider? currentLocationProvider;

  const MatchesTab({
    super.key,
    required this.matches,
    required this.isLoading,
    required this.error,
    this.currentUid = '',
    this.currentEmail = '',
    this.pendingMatchIds = const {},
    this.preferredLocation,
    this.onCreateMatch,
    this.currentLocationProvider,
  });

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<FormFieldState<String>> _levelFieldKey = GlobalKey();
  MatchDateFilter _dateFilter = MatchDateFilter.all;
  String? _levelFilter;
  bool _availableOnly = false;
  MatchLocation? _discoveryCenter;
  double _radiusKm = 25;
  bool _usingCurrentLocation = false;
  bool _findingCurrentLocation = false;
  String? _currentLocationError;

  @override
  void initState() {
    super.initState();
    final preferred = widget.preferredLocation;
    if (preferred?.isConfigured == true) {
      final configured = preferred!;
      if (hasUsableCoordinates(configured.latitude, configured.longitude)) {
        _discoveryCenter = MatchLocation(
          clubName: '',
          countryCode: configured.countryCode,
          country: configured.country,
          region: '',
          city: configured.city,
          area: configured.area,
          latitude: configured.latitude,
          longitude: configured.longitude,
        );
      }
    }
  }

  bool get _hasFilters =>
      _searchController.text.isNotEmpty ||
      _dateFilter != MatchDateFilter.all ||
      _levelFilter != null ||
      _availableOnly;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Match> get _filteredMatches {
    final center = _discoveryCenter;
    final locationMatches = center == null
        ? widget.matches
        : filterNearbyMatches(
            widget.matches,
            centerLatitude: center.latitude!,
            centerLongitude: center.longitude!,
            radiusKm: _radiusKm,
          );
    return filterDiscoveredMatches(
      locationMatches,
      search: _searchController.text,
      date: _dateFilter,
      level: _levelFilter,
      availableOnly: _availableOnly,
    );
  }

  void _clearFilters() {
    _levelFieldKey.currentState?.reset();
    setState(() {
      _searchController.clear();
      _dateFilter = MatchDateFilter.all;
      _levelFilter = null;
      _availableOnly = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _findingCurrentLocation = true;
      _currentLocationError = null;
    });
    try {
      final coordinates =
          await (widget.currentLocationProvider ??
                  const GeolocatorCurrentLocationProvider())
              .getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _discoveryCenter = MatchLocation(
          clubName: '',
          countryCode: '',
          country: '',
          region: '',
          city: '',
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        );
        _usingCurrentLocation = true;
        _radiusKm = 25;
      });
    } on CurrentLocationException catch (error) {
      if (!mounted) return;
      setState(() => _currentLocationError = error.userMessage);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    } finally {
      if (mounted) setState(() => _findingCurrentLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.error) {
      return const Center(child: Text('Could not load matches.'));
    }

    final levels =
        widget.matches
            .map((match) => match.level)
            .where((level) => level.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final filteredMatches = _filteredMatches;
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
        const SizedBox(height: 16),
        PlacesAutocompleteField(
          key: ValueKey(
            _usingCurrentLocation
                ? 'current-location'
                : (_discoveryCenter?.placeId ?? 'discovery-location'),
          ),
          labelText: 'Find matches near',
          hintText: 'Search for a city or area',
          initialText: _usingCurrentLocation
              ? 'Current location'
              : (_discoveryCenter?.localityLabel ?? ''),
          onSelected: (location) {
            if (!hasUsableCoordinates(location.latitude, location.longitude)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('That location has no coordinates.'),
                ),
              );
              return;
            }
            setState(() {
              _discoveryCenter = location;
              _usingCurrentLocation = false;
              _currentLocationError = null;
              _radiusKm = 25;
            });
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('use-current-location'),
            onPressed: _findingCurrentLocation ? null : _useCurrentLocation,
            icon: _findingCurrentLocation
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _findingCurrentLocation
                  ? 'Finding your location…'
                  : 'Use my current location',
            ),
          ),
        ),
        if (_currentLocationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _currentLocationError!,
              key: const Key('current-location-error'),
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        if (_discoveryCenter != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.radar, size: 18, color: Color(0xFF53D68A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _usingCurrentLocation
                      ? 'Current location · ${_radiusKm.round()} km radius'
                      : 'Search radius: ${_radiusKm.round()} km',
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _discoveryCenter = null;
                  _usingCurrentLocation = false;
                  _currentLocationError = null;
                }),
                child: const Text('Clear location'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [25.0, 50.0, 100.0]
                .map(
                  (radius) => ChoiceChip(
                    label: Text('${radius.round()} km'),
                    selected: _radiusKm == radius,
                    onSelected: (_) => setState(() => _radiusKm = radius),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('match-search-field'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search club or location',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: MatchDateFilter.values.map((filter) {
              final label = switch (filter) {
                MatchDateFilter.all => 'All',
                MatchDateFilter.today => 'Today',
                MatchDateFilter.tomorrow => 'Tomorrow',
                MatchDateFilter.thisWeek => 'This Week',
              };
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: _dateFilter == filter,
                  onSelected: (_) => setState(() => _dateFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: const Key('level-filter'),
                child: DropdownButtonFormField<String>(
                  key: _levelFieldKey,
                  initialValue: _levelFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Player level',
                    prefixIcon: Icon(Icons.leaderboard),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: levels
                      .map(
                        (level) => DropdownMenuItem(
                          value: level,
                          child: Text(level, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (level) => setState(() => _levelFilter = level),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              key: const Key('available-spots-filter'),
              avatar: const Icon(Icons.group, size: 18),
              label: const Text('Spots'),
              selected: _availableOnly,
              onSelected: (selected) =>
                  setState(() => _availableOnly = selected),
            ),
          ],
        ),
        if (_hasFilters)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('clear-match-filters'),
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear filters'),
            ),
          )
        else
          const SizedBox(height: 16),
        if (filteredMatches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                const Icon(Icons.search_off, size: 44, color: Colors.white54),
                const SizedBox(height: 12),
                Text(
                  _discoveryCenter != null
                      ? 'No matches within ${_radiusKm.round()} km'
                      : (_hasFilters
                            ? 'No matches found'
                            : 'No open matches yet'),
                ),
                if (_discoveryCenter != null) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Try a wider radius or create a match nearby.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: widget.onCreateMatch,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Match'),
                  ),
                ],
                if (_hasFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Reset filters'),
                  ),
              ],
            ),
          )
        else
          ...filteredMatches.map((match) {
            final state =
                _isMatchOrganizer(match, widget.currentUid, widget.currentEmail)
                ? 'ORGANIZER'
                : match.players.any((player) => player.uid == widget.currentUid)
                ? 'JOINED'
                : widget.pendingMatchIds.contains(match.id)
                ? 'PENDING'
                : match.spotsLeft <= 0
                ? 'FULL'
                : 'OPEN';
            final center = _discoveryCenter;
            final distance = center == null
                ? null
                : distanceBetweenKm(
                    fromLatitude: center.latitude,
                    fromLongitude: center.longitude,
                    toLatitude: match.location.latitude,
                    toLongitude: match.location.longitude,
                  );
            return MatchCard(
              match: match,
              relationshipLabel: state,
              distanceKm: distance,
            );
          }),
      ],
    );
  }
}

class MatchCard extends StatelessWidget {
  final Match match;
  final String? relationshipLabel;
  final double? distanceKm;
  final bool historical;

  const MatchCard({
    super.key,
    required this.match,
    this.relationshipLabel,
    this.distanceKm,
    this.historical = false,
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
              if (historical) ...[
                const Chip(
                  avatar: Icon(Icons.history, size: 18),
                  label: Text('Completed'),
                  backgroundColor: Color(0xFF3A403D),
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
              if (match.locationLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  match.locationLabel,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(text: match.level, icon: Icons.leaderboard),
                  if (match.scheduledAt != null)
                    _InfoChip(
                      text: _friendlyDateTime(match.scheduledAt!),
                      icon: Icons.schedule,
                    ),
                  if (!historical)
                    _InfoChip(text: match.spotsLeftLabel, icon: Icons.group),
                  if (distanceKm != null)
                    _InfoChip(
                      text: '${distanceKm!.toStringAsFixed(1)} km away',
                      icon: Icons.near_me_outlined,
                    ),
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
  final List<Match> pendingMatches;
  final String currentUid;
  final String currentEmail;
  final bool isLoading;
  final bool error;
  final DateTime Function() nowProvider;

  const MyMatchesTab({
    super.key,
    required this.matches,
    this.pendingMatches = const [],
    required this.currentUid,
    this.currentEmail = '',
    required this.isLoading,
    required this.error,
    DateTime Function()? nowProvider,
  }) : nowProvider = nowProvider ?? DateTime.now;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error) {
      return const Center(child: Text('Could not load your matches.'));
    }

    if (matches.isEmpty && pendingMatches.isEmpty) {
      return const Center(child: Text('You have no matches yet'));
    }

    final now = nowProvider();
    final upcomingMatches = sortedMatches(
      matches.where((match) => isUpcomingMatch(match, now)),
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
        if (pendingMatches.isNotEmpty) ...[
          const Text(
            'Pending Requests',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...sortedMatches(pendingMatches).map(
            (match) =>
                MatchCard(match: match, relationshipLabel: 'Request Pending'),
          ),
          const SizedBox(height: 12),
        ],
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
            relationshipLabel:
                _isMatchOrganizer(match, currentUid, currentEmail)
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
            'No past matches yet.',
            key: Key('no-past-matches'),
            style: TextStyle(color: Colors.white70),
          ),
        if (pastMatches.isNotEmpty)
          ...pastMatches.map(
            (match) => MatchCard(
              match: match,
              historical: true,
              relationshipLabel:
                  _isMatchOrganizer(match, currentUid, currentEmail)
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
            if (profile.discoveryLocation.isConfigured) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Match discovery'),
                  subtitle: Text(
                    '${profile.discoveryLocation.city}, ${profile.discoveryLocation.country}',
                  ),
                ),
              ),
            ],
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
  late final TextEditingController _discoveryCountryController;
  late final TextEditingController _discoveryCountryCodeController;
  late final TextEditingController _discoveryCityController;
  late final TextEditingController _discoveryAreaController;
  double? _discoveryLatitude;
  double? _discoveryLongitude;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile?.displayName ?? widget.user.displayName ?? '',
    );
    _levelController = TextEditingController(text: widget.profile?.level ?? '');
    _discoveryCountryController = TextEditingController(
      text: widget.profile?.discoveryLocation.country ?? '',
    );
    _discoveryCountryCodeController = TextEditingController(
      text: widget.profile?.discoveryLocation.countryCode ?? '',
    );
    _discoveryCityController = TextEditingController(
      text: widget.profile?.discoveryLocation.city ?? '',
    );
    _discoveryAreaController = TextEditingController(
      text: widget.profile?.discoveryLocation.area ?? '',
    );
    _discoveryLatitude = widget.profile?.discoveryLocation.latitude;
    _discoveryLongitude = widget.profile?.discoveryLocation.longitude;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _levelController.dispose();
    _discoveryCountryController.dispose();
    _discoveryCountryCodeController.dispose();
    _discoveryCityController.dispose();
    _discoveryAreaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final displayName = _displayNameController.text.trim();
    final level = _levelController.text.trim();
    final discovery = DiscoveryLocation(
      country: _discoveryCountryController.text,
      countryCode: _discoveryCountryCodeController.text,
      city: _discoveryCityController.text,
      area: _discoveryAreaController.text,
      latitude: _discoveryLatitude,
      longitude: _discoveryLongitude,
    );
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
    final hasDiscoveryValue =
        discovery.country.isNotEmpty ||
        discovery.countryCode.isNotEmpty ||
        discovery.city.isNotEmpty ||
        discovery.area.isNotEmpty;
    if (hasDiscoveryValue &&
        (discovery.country.isEmpty ||
            discovery.countryCode.length != 2 ||
            discovery.city.isEmpty)) {
      _showMessage(
        'Enter a country, 2-letter country code, and city for discovery.',
      );
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
        'discoveryLocation': discovery.toMap(),
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
          const SizedBox(height: 16),
          const Text(
            'Preferred discovery location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          PlacesAutocompleteField(
            labelText: 'Search for your city',
            hintText: 'Start typing a city',
            citiesOnly: true,
            enabled: !_isSaving,
            onSelected: (location) => setState(() {
              _discoveryCountryController.text = location.country;
              _discoveryCountryCodeController.text = location.countryCode;
              _discoveryCityController.text = location.city;
              _discoveryAreaController.text = location.area;
              _discoveryLatitude = location.latitude;
              _discoveryLongitude = location.longitude;
            }),
          ),
          if (googlePlacesApiKey.isNotEmpty) const SizedBox(height: 12),
          TextField(
            controller: _discoveryCountryController,
            onChanged: (_) {
              _discoveryLatitude = null;
              _discoveryLongitude = null;
            },
            decoration: const InputDecoration(
              labelText: 'Country',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discoveryCountryCodeController,
            onChanged: (_) {
              _discoveryLatitude = null;
              _discoveryLongitude = null;
            },
            textCapitalization: TextCapitalization.characters,
            maxLength: 2,
            decoration: const InputDecoration(
              labelText: 'ISO country code',
              hintText: 'ES',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discoveryCityController,
            onChanged: (_) {
              _discoveryLatitude = null;
              _discoveryLongitude = null;
            },
            decoration: const InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discoveryAreaController,
            onChanged: (_) {
              _discoveryLatitude = null;
              _discoveryLongitude = null;
            },
            decoration: const InputDecoration(
              labelText: 'Area / Neighborhood (optional)',
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
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _countryCodeController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _spotsController = TextEditingController();
  bool _isCreating = false;
  DateTime? _scheduledAt;
  String _placeId = '';
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _clubController.dispose();
    _countryController.dispose();
    _countryCodeController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _areaController.dispose();
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
    final location = MatchLocation(
      clubName: club,
      countryCode: _countryCodeController.text,
      country: _countryController.text,
      region: _regionController.text,
      city: _cityController.text,
      area: _areaController.text,
      placeId: _placeId,
      latitude: _latitude,
      longitude: _longitude,
    );

    if (club.isEmpty ||
        dateTime.isEmpty ||
        _scheduledAt == null ||
        level.isEmpty ||
        spots.isEmpty ||
        !location.isValid) {
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
    if (spotsLeft > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A padel match can have at most 4 players.'),
        ),
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
        'clubName': club,
        'location': location.toMap(),
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
          PlacesAutocompleteField(
            labelText: 'Search for a padel club',
            hintText: 'Club name or address',
            enabled: !_isCreating,
            onSelected: (location) => setState(() {
              _clubController.text = location.clubName;
              _countryController.text = location.country;
              _countryCodeController.text = location.countryCode;
              _regionController.text = location.region;
              _cityController.text = location.city;
              _areaController.text = location.area;
              _placeId = location.placeId;
              _latitude = location.latitude;
              _longitude = location.longitude;
            }),
          ),
          if (googlePlacesApiKey.isNotEmpty) const SizedBox(height: 16),
          TextField(
            controller: _clubController,
            onChanged: (_) {
              _placeId = '';
              _latitude = null;
              _longitude = null;
            },
            decoration: const InputDecoration(
              labelText: 'Club name',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('country-field'),
                  controller: _countryController,
                  onChanged: (_) {
                    _latitude = null;
                    _longitude = null;
                  },
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  key: const Key('country-code-field'),
                  controller: _countryCodeController,
                  onChanged: (_) {
                    _latitude = null;
                    _longitude = null;
                  },
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  decoration: const InputDecoration(
                    labelText: 'ISO code',
                    hintText: 'US',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('region-field'),
            controller: _regionController,
            onChanged: (_) {
              _latitude = null;
              _longitude = null;
            },
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Region / State / Province (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('city-field'),
            controller: _cityController,
            onChanged: (_) {
              _latitude = null;
              _longitude = null;
            },
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('area-field'),
            controller: _areaController,
            onChanged: (_) {
              _latitude = null;
              _longitude = null;
            },
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Area / Neighborhood (optional)',
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
              key: const Key('create-match-submit'),
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

typedef MatchEditSaver = Future<void> Function(Map<String, dynamic> update);

class EditMatchScreen extends StatefulWidget {
  final Match match;
  final MatchEditSaver? saver;

  const EditMatchScreen({super.key, required this.match, this.saver});

  @override
  State<EditMatchScreen> createState() => _EditMatchScreenState();
}

class _EditMatchScreenState extends State<EditMatchScreen> {
  late final TextEditingController _clubController;
  late final TextEditingController _dateTimeController;
  late final TextEditingController _levelController;
  late final TextEditingController _capacityController;
  late MatchLocation _location;
  DateTime? _scheduledAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _location = widget.match.location;
    _scheduledAt = widget.match.scheduledAt;
    _clubController = TextEditingController(text: widget.match.club);
    _dateTimeController = TextEditingController(
      text: _scheduledAt == null
          ? widget.match.title
          : _friendlyDateTime(_scheduledAt!),
    );
    _levelController = TextEditingController(text: widget.match.level);
    _capacityController = TextEditingController(
      text: matchTotalCapacity(widget.match).toString(),
    );
  }

  @override
  void dispose() {
    _clubController.dispose();
    _dateTimeController.dispose();
    _levelController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt != null && _scheduledAt!.isAfter(now)
        ? _scheduledAt!
        : now.add(const Duration(hours: 1));
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
      _showMessage('Please choose a future date and time.');
      return;
    }
    setState(() {
      _scheduledAt = selected;
      _dateTimeController.text = _friendlyDateTime(selected);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    try {
      final scheduledAt = _scheduledAt;
      if (scheduledAt == null) {
        throw const MatchActionException('Please choose a date and time.');
      }
      final capacity = int.tryParse(_capacityController.text.trim());
      if (capacity == null) {
        throw const MatchActionException(
          'Please enter a valid total capacity.',
        );
      }
      final update = buildMatchEditUpdate(
        match: widget.match,
        location: _location,
        scheduledAt: scheduledAt,
        level: _levelController.text,
        totalCapacity: capacity,
      );
      setState(() => _isSaving = true);
      if (widget.saver != null) {
        await widget.saver!(update);
      } else {
        await _saveToFirestore(update);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not save match changes.');
    } catch (_) {
      _showMessage('Could not save match changes. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveToFirestore(Map<String, dynamic> update) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const MatchActionException('Please log in to edit this match.');
    }
    final reference = FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.match.id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw const MatchActionException('This match no longer exists.');
      }
      final data = snapshot.data() ?? <String, dynamic>{};
      if (!isOrganizerIdentity(data, user.uid, user.email ?? '')) {
        throw const MatchActionException(
          'Only the organizer can edit this match.',
        );
      }
      final latest = Match.fromDocument(snapshot);
      final capacity =
          (update['spotsLeft'] as int) + 1 + widget.match.players.length;
      if (latest.players.length != widget.match.players.length ||
          latest.players.asMap().entries.any(
            (entry) => entry.value.uid != widget.match.players[entry.key].uid,
          )) {
        throw const MatchActionException(
          'The player list changed. Reopen the editor and try again.',
        );
      }
      final safeUpdate = buildMatchEditUpdate(
        match: latest,
        location: _location,
        scheduledAt: _scheduledAt!,
        level: _levelController.text,
        totalCapacity: capacity,
      );
      transaction.update(reference, safeUpdate);
    });
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmedCount = 1 + widget.match.players.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Match'),
        backgroundColor: const Color(0xFF0F1412),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Update match details',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Confirmed players and join requests will be preserved.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          PlacesAutocompleteField(
            initialText: widget.match.club,
            labelText: 'Search for a padel club',
            hintText: 'Club name or address',
            enabled: !_isSaving,
            onSelected: (location) => setState(() {
              _location = location;
              _clubController.text = location.clubName;
            }),
          ),
          if (googlePlacesApiKey.isNotEmpty) const SizedBox(height: 16),
          TextField(
            key: const Key('edit-club-field'),
            controller: _clubController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Club',
              helperText: _location.localityLabel.isEmpty
                  ? 'Legacy location — search above to choose a structured location.'
                  : _location.localityLabel,
              prefixIcon: const Icon(Icons.location_on),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-date-time-field'),
            controller: _dateTimeController,
            readOnly: true,
            enabled: !_isSaving,
            onTap: _selectDateTime,
            decoration: const InputDecoration(
              labelText: 'Date and time',
              prefixIcon: Icon(Icons.calendar_month),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-level-field'),
            controller: _levelController,
            enabled: !_isSaving,
            decoration: const InputDecoration(
              labelText: 'Level',
              prefixIcon: Icon(Icons.leaderboard),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-capacity-field'),
            controller: _capacityController,
            enabled: !_isSaving,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Total player capacity',
              helperText:
                  '$confirmedCount player${confirmedCount == 1 ? '' : 's'} currently confirmed · maximum 4',
              prefixIcon: const Icon(Icons.group),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const Key('edit-match-submit'),
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerProfileScreen extends StatefulWidget {
  final String uid;
  final String fallbackName;
  final String fallbackLevel;
  final PublicPlayerProfileLoader loader;
  final String? viewerUid;
  final String? viewerEmail;

  const PlayerProfileScreen({
    super.key,
    required this.uid,
    this.fallbackName = '',
    this.fallbackLevel = '',
    this.loader = loadPublicPlayerProfile,
    this.viewerUid,
    this.viewerEmail,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late Future<PublicPlayerProfile> _profile = widget.loader(widget.uid);
  bool _isSubmittingRating = false;

  User? get _firebaseUser =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  String get _viewerUid => widget.viewerUid ?? _firebaseUser?.uid ?? '';
  String get _viewerEmail => widget.viewerEmail ?? _firebaseUser?.email ?? '';

  Future<void> _ratePlayer(Match match) async {
    final user = _firebaseUser;
    if (user == null || _isSubmittingRating) return;
    var selected = 0;
    final rating = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate player'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                key: Key('rating-star-$value'),
                tooltip: '$value star${value == 1 ? '' : 's'}',
                onPressed: () => setDialogState(() => selected = value),
                icon: Icon(
                  value <= selected ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == 0
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    if (rating == null || !mounted) return;

    setState(() => _isSubmittingRating = true);
    try {
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .collection('ratingRaters')
          .doc(user.uid)
          .collection('ratings')
          .doc(widget.uid)
          .set({
            'matchId': match.id,
            'raterUid': user.uid,
            'ratedUid': widget.uid,
            'rating': rating,
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      setState(() {
        _profile = widget.loader(widget.uid);
        _isSubmittingRating = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rating submitted.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingRating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'This match is not eligible for rating.'
                : 'Could not submit rating.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
        backgroundColor: const Color(0xFF0F1412),
      ),
      body: FutureBuilder<PublicPlayerProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load this player profile.'),
              ),
            );
          }

          final profile = snapshot.data!;
          final fallbackName = _publicFallbackName(widget.fallbackName);
          final name = profile.displayName.isNotEmpty
              ? profile.displayName
              : fallbackName;
          final level = profile.level.isNotEmpty
              ? profile.level
              : widget.fallbackLevel.trim();
          final recentMatches = recentPlayerMatches(
            profile.matches,
            limit: profile.matches.length,
          );
          final summary = profile.ratingSummary;
          final viewerUid = _viewerUid;
          final viewerEmail = _viewerEmail;
          final ratingsByMatch = {
            for (final rating in profile.ratings)
              if (rating.raterUid == viewerUid) rating.matchId: rating,
          };
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                name.isEmpty ? 'Player' : name,
                key: const Key('public-profile-name'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                level.isEmpty ? 'Level not set' : level,
                key: const Key('public-profile-level'),
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.sports_tennis),
                  title: const Text('Matches played'),
                  trailing: Text(
                    '${profile.matches.length}',
                    key: const Key('public-profile-match-count'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: summary.count == 0
                      ? const Text(
                          'No ratings yet',
                          key: Key('public-profile-no-ratings'),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(
                                5,
                                (index) => Icon(
                                  index < summary.average.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${summary.average.toStringAsFixed(1)} ★ '
                              '(${summary.count} '
                              '${summary.count == 1 ? 'rating' : 'ratings'})',
                              key: const Key('public-profile-rating-summary'),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Match history',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (recentMatches.isEmpty)
                const Text(
                  'No matches to show yet.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                ...recentMatches.map((match) {
                  final existing = ratingsByMatch[match.id];
                  final eligible =
                      viewerUid.isNotEmpty &&
                      canRatePlayerForMatch(
                        match: match,
                        raterUid: viewerUid,
                        raterEmail: viewerEmail,
                        ratedUid: profile.uid,
                        ratedEmail: profile.email,
                        now: DateTime.now(),
                        existingRating: existing,
                      );
                  return Card(
                    child: ListTile(
                      title: Text(
                        match.club.isEmpty ? 'Padel match' : match.club,
                      ),
                      subtitle: Text(
                        match.scheduledAt == null
                            ? (match.level.isEmpty
                                  ? 'Date unavailable'
                                  : match.level)
                            : '${_friendlyDateTime(match.scheduledAt!)}'
                                  '${match.level.isEmpty ? '' : ' · ${match.level}'}',
                      ),
                      trailing: existing != null
                          ? Text(
                              '${existing.rating} ★',
                              key: Key('existing-rating-${match.id}'),
                            )
                          : eligible
                          ? TextButton(
                              key: Key('rate-player-${match.id}'),
                              onPressed: _isSubmittingRating
                                  ? null
                                  : () => _ratePlayer(match),
                              child: const Text('Rate player'),
                            )
                          : null,
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

String _publicFallbackName(String value) {
  final trimmed = value.trim();
  return trimmed.contains('@') ? '' : trimmed;
}

typedef MatchRatingsLoader =
    Future<List<PlayerRating>> Function(String matchId, String raterUid);
typedef MatchRatingSubmitter =
    Future<void> Function(
      String matchId,
      String raterUid,
      String ratedUid,
      int rating,
    );

Future<List<PlayerRating>> loadMatchRatings(
  String matchId,
  String raterUid,
) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .collection('ratingRaters')
      .doc(raterUid)
      .collection('ratings')
      .get();
  return snapshot.docs.map(PlayerRating.fromDocument).toList();
}

Future<void> submitMatchRating(
  String matchId,
  String raterUid,
  String ratedUid,
  int rating,
) async {
  if (!isValidRatingValue(rating)) return;
  await FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .collection('ratingRaters')
      .doc(raterUid)
      .collection('ratings')
      .doc(ratedUid)
      .set({
        'matchId': matchId,
        'raterUid': raterUid,
        'ratedUid': ratedUid,
        'rating': rating,
        'createdAt': FieldValue.serverTimestamp(),
      });
}

List<MatchPlayer> ratingCandidates(Match match, String currentUid) {
  final candidates = <MatchPlayer>[
    if (match.creatorUid.isNotEmpty)
      MatchPlayer(
        uid: match.creatorUid,
        email: match.creatorEmail,
        displayName: match.creatorDisplayName,
        level: match.creatorLevel,
      ),
    ...match.players,
  ];
  final seen = <String>{};
  return candidates
      .where(
        (player) =>
            player.uid.isNotEmpty &&
            player.uid != currentUid &&
            seen.add(player.uid),
      )
      .toList();
}

class RatePlayersSection extends StatefulWidget {
  final Match match;
  final String currentUid;
  final String currentEmail;
  final MatchRatingsLoader ratingsLoader;
  final MatchRatingSubmitter ratingSubmitter;
  final PublicPlayerProfileLoader profileLoader;

  const RatePlayersSection({
    super.key,
    required this.match,
    required this.currentUid,
    this.currentEmail = '',
    this.ratingsLoader = loadMatchRatings,
    this.ratingSubmitter = submitMatchRating,
    this.profileLoader = loadPublicPlayerProfile,
  });

  @override
  State<RatePlayersSection> createState() => _RatePlayersSectionState();
}

class _RatePlayersSectionState extends State<RatePlayersSection> {
  late Future<List<PlayerRating>> _ratings = widget.ratingsLoader(
    widget.match.id,
    widget.currentUid,
  );
  final Set<String> _submitting = {};

  Future<void> _rate(MatchPlayer player) async {
    var selected = 0;
    final rating = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Rate ${player.displayName.isEmpty ? 'player' : player.displayName}',
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                key: Key('match-rating-star-$value'),
                tooltip: '$value star${value == 1 ? '' : 's'}',
                onPressed: () => setDialogState(() => selected = value),
                icon: Icon(
                  value <= selected ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == 0
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('Submit rating'),
            ),
          ],
        ),
      ),
    );
    if (rating == null || _submitting.contains(player.uid)) return;
    setState(() => _submitting.add(player.uid));
    try {
      await widget.ratingSubmitter(
        widget.match.id,
        widget.currentUid,
        player.uid,
        rating,
      );
      if (!mounted) return;
      setState(() {
        _submitting.remove(player.uid);
        _ratings = widget.ratingsLoader(widget.match.id, widget.currentUid);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rating submitted.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _submitting.remove(player.uid));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'This rating was already submitted or is not eligible.'
                : 'Could not submit rating.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ratingCandidates(widget.match, widget.currentUid);
    return Column(
      key: const Key('rate-players-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rate players',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (candidates.isEmpty)
          const Text(
            'No other confirmed players to rate.',
            style: TextStyle(color: Colors.white70),
          )
        else
          FutureBuilder<List<PlayerRating>>(
            future: _ratings,
            builder: (context, snapshot) {
              final existing = {
                for (final rating in snapshot.data ?? const <PlayerRating>[])
                  rating.ratedUid: rating,
              };
              return Column(
                children: candidates.map((player) {
                  final prior = existing[player.uid];
                  final name = player.displayName.isNotEmpty
                      ? player.displayName
                      : player.email.isNotEmpty
                      ? player.email
                      : 'Player';
                  return Card(
                    child: ListTile(
                      key: Key('rating-player-${player.uid}'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerProfileScreen(
                            uid: player.uid,
                            fallbackName: name,
                            fallbackLevel: player.level,
                            loader: widget.profileLoader,
                            viewerUid: widget.currentUid,
                            viewerEmail: widget.currentEmail,
                          ),
                        ),
                      ),
                      leading: CircleAvatar(
                        child: Text(name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(name),
                      subtitle: Text(
                        player.uid == widget.match.creatorUid
                            ? 'Organizer'
                            : 'Confirmed',
                      ),
                      trailing: prior == null
                          ? TextButton(
                              key: Key('rate-match-player-${player.uid}'),
                              onPressed:
                                  snapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      _submitting.contains(player.uid)
                                  ? null
                                  : () => _rate(player),
                              child: const Text('Rate player'),
                            )
                          : Text(
                              'Submitted · ${prior.rating} ★',
                              key: Key('rated-match-player-${player.uid}'),
                            ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
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
  bool _isRequesting = false;
  bool _isLeaving = false;
  bool _isCancelling = false;
  final Set<String> _processingRequestIds = {};

  Future<void> _requestToJoin() async {
    if (!matchAllowsChanges(widget.match, DateTime.now())) {
      _showMessage('This match has already been completed.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please log in to request to join a match.');
      return;
    }

    setState(() => _isRequesting = true);

    try {
      final profile = await _loadUserProfile(user.uid);
      final matchRef = FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id);
      final requestRef = matchRef.collection('joinRequests').doc(user.uid);
      final initialMatch = await matchRef.get();
      if (!initialMatch.exists) {
        throw const MatchActionException('This match no longer exists.');
      }
      final organizerUid = await resolveOrganizerNotificationUid(
        initialMatch.data() ?? <String, dynamic>{},
      );
      final eventId = FirebaseFirestore.instance.collection('events').doc().id;
      final request = JoinRequest(
        userId: user.uid,
        email: user.email ?? profile?.email ?? '',
        displayName: profile?.displayName ?? '',
        level: profile?.level ?? '',
        status: 'pending',
        requestedAt: DateTime.now(),
        eventId: eventId,
      );
      final notificationRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc(
            notificationDocumentId(
              AppNotificationType.joinRequest,
              widget.match.id,
              eventId,
            ),
          );

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);
        final requestSnapshot = await transaction.get(requestRef);
        if (!snapshot.exists) {
          throw const MatchActionException('This match no longer exists.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        if (isOrganizerIdentity(data, user.uid, user.email ?? '')) {
          throw const MatchActionException(
            'The organizer cannot join their own match.',
          );
        }
        validateJoinRequest(data, requestSnapshot.data(), request);
        transaction.set(requestRef, {
          ...request.toMap(),
          'requestedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
          notificationRef,
          buildJoinRequestNotification(
            recipientUid: organizerUid,
            matchId: widget.match.id,
            matchClubName: data['club']?.toString() ?? widget.match.club,
            eventId: eventId,
            actorUid: user.uid,
            actorDisplayName: request.displayName,
          ),
        );
      });

      _showMessage('Join request sent.');
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not send your join request.');
    } catch (_) {
      _showMessage('Could not send your join request. Please try again.');
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _reviewRequest(JoinRequest request, bool approve) async {
    if (!matchAllowsChanges(widget.match, DateTime.now())) {
      _showMessage('Completed matches cannot be changed.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _processingRequestIds.contains(request.userId)) return;
    setState(() => _processingRequestIds.add(request.userId));

    final action = approve ? 'approval' : 'decline';
    final fallbackEventId = FirebaseFirestore.instance
        .collection('events')
        .doc()
        .id;
    void logCheckpoint(String checkpoint, [Object? details]) {
      debugPrint(
        'Join request $action [match=${widget.match.id}, '
        'request=${request.userId}] $checkpoint'
        '${details == null ? '' : ': $details'}',
      );
    }

    try {
      final matchRef = FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.match.id);
      final requestRef = matchRef
          .collection('joinRequests')
          .doc(request.userId);
      logCheckpoint('transaction start');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        logCheckpoint('match read starting');
        final snapshot = await transaction.get(matchRef);
        logCheckpoint(
          'match read complete',
          'exists=${snapshot.exists}, fields=${snapshot.data()?.keys.toList()}',
        );
        logCheckpoint('request read starting');
        final requestSnapshot = await transaction.get(requestRef);
        logCheckpoint(
          'request read complete',
          'exists=${requestSnapshot.exists}, '
              'status=${requestSnapshot.data()?['status']}',
        );
        if (!snapshot.exists) {
          throw const MatchActionException('This match no longer exists.');
        }
        final data = snapshot.data() ?? <String, dynamic>{};
        logCheckpoint(
          'organizer identity check starting',
          'uidField=${matchCreatorUid(data).isNotEmpty}, '
              'emailField=${matchCreatorEmail(data).isNotEmpty}',
        );
        final organizerRecognized = isOrganizerIdentity(
          data,
          user.uid,
          user.email ?? '',
        );
        logCheckpoint(
          'organizer identity check complete',
          'recognized=$organizerRecognized',
        );
        if (!organizerRecognized) {
          throw const MatchActionException(
            'Only the organizer can review join requests.',
          );
        }
        if (!requestSnapshot.exists) {
          throw const MatchActionException(
            'This join request no longer exists.',
          );
        }
        final requestData = requestSnapshot.data()!;
        final eventId = requestData['eventId']?.toString().isNotEmpty == true
            ? requestData['eventId'].toString()
            : fallbackEventId;

        if (approve) {
          logCheckpoint(
            'player normalization starting',
            'rawType=${data['players'].runtimeType}',
          );
          final matchUpdate = buildReviewRequestUpdate(
            data,
            requestData,
            onCheckpoint: logCheckpoint,
          );
          final normalizedPlayers = matchUpdate['players'] as List;
          logCheckpoint(
            'player normalization complete',
            'count=${normalizedPlayers.length}, '
                'types=${normalizedPlayers.map((player) => player.runtimeType).toList()}',
          );
          transaction.update(matchRef, matchUpdate);
          logCheckpoint('match update queued');
        }
        final requestUpdate = buildRequestStatusUpdate(
          requestData,
          approve: approve,
          eventId: eventId,
        );
        transaction.update(requestRef, requestUpdate);
        logCheckpoint('request update queued', requestUpdate);
        final notificationType = approve
            ? AppNotificationType.joinApproved
            : AppNotificationType.joinDeclined;
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc(
              notificationDocumentId(
                notificationType,
                widget.match.id,
                eventId,
              ),
            );
        transaction.set(
          notificationRef,
          buildReviewNotification(
            approve: approve,
            recipientUid: request.userId,
            matchId: widget.match.id,
            club: data['club']?.toString() ?? '',
            eventId: eventId,
            actorUid: user.uid,
            actorDisplayName: data['creatorDisplayName']?.toString() ?? '',
          ),
        );
      });
      logCheckpoint('transaction completion');
      _showMessage(
        approve ? 'Join request approved.' : 'Join request declined.',
      );
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Join request ${approve ? 'approval' : 'decline'} failed '
        '[${error.code}]: ${error.message}\n$stackTrace',
      );
      _showMessage(
        'Could not ${approve ? 'approve' : 'decline'} request '
        '(${error.code}). ${error.message ?? 'Please try again.'}',
      );
    } catch (error, stackTrace) {
      final unboxed = _unboxWebError(error, stackTrace);
      debugPrint(
        'Join request $action failed '
        '[${unboxed.error.runtimeType}]: ${unboxed.error}\n'
        '${unboxed.stackTrace}',
      );
      _showMessage(
        'Could not ${approve ? 'approve' : 'decline'} request. '
        'Error: ${unboxed.error}',
      );
    } finally {
      if (mounted) {
        setState(() => _processingRequestIds.remove(request.userId));
      }
    }
  }

  Future<void> _leaveMatch() async {
    if (!matchAllowsChanges(widget.match, DateTime.now())) {
      _showMessage('Completed matches cannot be changed.');
      return;
    }
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
      final requestRef = matchRef.collection('joinRequests').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);
        final requestSnapshot = await transaction.get(requestRef);
        if (!snapshot.exists) {
          throw const MatchActionException('This match no longer exists.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        if (isOrganizerIdentity(data, user.uid, user.email ?? '')) {
          throw const MatchActionException(
            'The organizer cannot leave their own match.',
          );
        }

        final players = List<dynamic>.from(
          data['players'] as List? ?? const [],
        );
        final playerIndex = players.indexWhere(
          (player) => player is Map && _playerUid(player) == user.uid,
        );

        if (playerIndex == -1) {
          throw const MatchActionException('You have not joined this match.');
        }

        players.removeAt(playerIndex);
        final spotsLeft = _parseSpotsLeft(data['spotsLeft']);
        final capacityRemaining = 3 - players.length;
        final restoredSpots = spotsLeft + 1;
        transaction.update(matchRef, {
          'players': players,
          'spotsLeft': restoredSpots < capacityRemaining
              ? restoredSpots
              : capacityRemaining,
        });
        if (requestSnapshot.exists &&
            requestSnapshot.data()?['status']?.toString() == 'approved') {
          transaction.update(requestRef, {'status': 'declined'});
        }
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
    if (!matchAllowsChanges(widget.match, DateTime.now())) {
      _showMessage('Completed matches cannot be changed.');
      return;
    }
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

        final data = snapshot.data() ?? <String, dynamic>{};
        if (!isOrganizerIdentity(data, user.uid, user.email ?? '')) {
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
            currentUid != null &&
            _isMatchOrganizer(
              match,
              currentUid,
              FirebaseAuth.instance.currentUser?.email ?? '',
            );
        final completed = isPastMatch(match, DateTime.now());
        final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        final requestsCollection = FirebaseFirestore.instance
            .collection('matches')
            .doc(match.id)
            .collection('joinRequests');
        final requestsStream = completed
            ? Stream.value(const <JoinRequest>[])
            : isOrganizer
            ? requestsCollection.snapshots().map(
                (snapshot) =>
                    snapshot.docs.map(JoinRequest.fromDocument).toList(),
              )
            : requestsCollection
                  .doc(currentUid ?? '__signed_out__')
                  .snapshots()
                  .map(
                    (document) => document.exists
                        ? [JoinRequest.fromDocument(document)]
                        : <JoinRequest>[],
                  );

        return StreamBuilder<List<JoinRequest>>(
          stream: requestsStream,
          builder: (context, requestSnapshot) {
            final requests = requestSnapshot.data ?? const <JoinRequest>[];
            final ownRequest = isOrganizer || requests.isEmpty
                ? null
                : requests.first;
            final participationState = resolveMatchParticipationState(
              isOrganizer: isOrganizer,
              isConfirmedPlayer: hasJoined,
              requestStatus: ownRequest?.status,
            );
            final pendingRequests = requests
                .where((request) => request.status == 'pending')
                .toList();
            final isBusy = _isRequesting || _isLeaving || _isCancelling;
            final requestIsLoading =
                !isOrganizer &&
                requestSnapshot.connectionState == ConnectionState.waiting;
            final requestReadFailed = requestSnapshot.hasError;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Match Details'),
                backgroundColor: const Color(0xFF0F1412),
                actions: [
                  if (isOrganizer && !completed)
                    TextButton.icon(
                      key: const Key('edit-match-action'),
                      onPressed: isBusy
                          ? null
                          : () async {
                              final updated = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditMatchScreen(match: match),
                                    ),
                                  );
                              if (updated == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Match updated successfully.',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Match'),
                    ),
                ],
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
                  if (match.locationLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      match.locationLabel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(text: match.level, icon: Icons.leaderboard),
                      if (match.scheduledAt != null)
                        _InfoChip(
                          text: _friendlyDateTime(match.scheduledAt!),
                          icon: Icons.schedule,
                        ),
                      if (!completed)
                        _InfoChip(
                          text: match.spotsLeftLabel,
                          icon: Icons.group,
                        ),
                      if (completed)
                        const _InfoChip(text: 'Completed', icon: Icons.history),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Players',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (match.creatorUid.isNotEmpty ||
                      match.creatorEmail.isNotEmpty)
                    ProfilePlayerTile(
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
                        : ProfilePlayerTile(
                            uid: player.uid,
                            fallbackName: player.displayName.isNotEmpty
                                ? player.displayName
                                : player.email,
                            fallbackLevel: player.level,
                            role: 'Confirmed',
                          ),
                  ),
                  if (!completed &&
                      participationState ==
                          MatchParticipationState.organizer) ...[
                    const SizedBox(height: 24),
                    JoinRequestsSection(
                      requests: pendingRequests,
                      loading:
                          requestSnapshot.connectionState ==
                          ConnectionState.waiting,
                      errorMessage: requestReadFailed
                          ? joinRequestReadErrorMessage(requestSnapshot.error)
                          : null,
                      processingUserIds: _processingRequestIds,
                      onApprove: (request) => _reviewRequest(request, true),
                      onDecline: (request) => _reviewRequest(request, false),
                    ),
                  ],
                  if (completed &&
                      currentUid != null &&
                      matchIncludesIdentity(
                        match,
                        currentUid,
                        currentEmail,
                      )) ...[
                    const SizedBox(height: 24),
                    RatePlayersSection(
                      match: match,
                      currentUid: currentUid,
                      currentEmail: currentEmail,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (completed)
                    const SizedBox.shrink()
                  else if (participationState ==
                      MatchParticipationState.organizer)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : _cancelMatch,
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: Text(
                          _isCancelling ? 'Cancelling...' : 'Cancel Match',
                        ),
                      ),
                    )
                  else if (participationState ==
                      MatchParticipationState.confirmed)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : _leaveMatch,
                        icon: _isLeaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                        onPressed:
                            isBusy ||
                                requestIsLoading ||
                                requestReadFailed ||
                                match.spotsLeft <= 0 ||
                                participationState ==
                                    MatchParticipationState.pending
                            ? null
                            : _requestToJoin,
                        icon: _isRequesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.group_add),
                        label: Text(
                          _isRequesting
                              ? 'Requesting...'
                              : requestIsLoading
                              ? 'Loading request...'
                              : requestReadFailed
                              ? 'Could not load request'
                              : matchParticipationButtonLabel(
                                  participationState,
                                  spotsLeft: match.spotsLeft,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class JoinRequestsSection extends StatelessWidget {
  final List<JoinRequest> requests;
  final bool loading;
  final String? errorMessage;
  final Set<String> processingUserIds;
  final ValueChanged<JoinRequest> onApprove;
  final ValueChanged<JoinRequest> onDecline;

  const JoinRequestsSection({
    super.key,
    required this.requests,
    this.loading = false,
    this.errorMessage,
    this.processingUserIds = const {},
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Join Requests',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading join requests...'),
            ],
          )
        else if (errorMessage != null)
          Text(errorMessage!, style: const TextStyle(color: Colors.redAccent))
        else if (requests.isEmpty)
          const Text(
            'No pending requests.',
            style: TextStyle(color: Colors.white70),
          ),
        ...requests.map((request) {
          final isProcessing = processingUserIds.contains(request.userId);
          return Card(
            child: ListTile(
              title: Text(
                request.displayName.isEmpty
                    ? request.email
                    : request.displayName,
              ),
              subtitle: Text(
                request.level.isEmpty ? 'Level not set' : request.level,
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: isProcessing ? null : () => onDecline(request),
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed: isProcessing ? null : () => onApprove(request),
                    child: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Approve'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

String joinRequestReadErrorMessage(Object? error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Permission denied while loading join requests.';
  }
  return 'Could not load join requests.';
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
  final VoidCallback? onTap;

  const _PlayerTile({required this.name, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final firstLetter = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : '?';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(firstLetter)),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class ProfilePlayerTile extends StatelessWidget {
  final String uid;
  final String fallbackName;
  final String fallbackLevel;
  final String role;
  final PublicPlayerProfileLoader? profileLoader;

  const ProfilePlayerTile({
    super.key,
    required this.uid,
    required this.fallbackName,
    required this.fallbackLevel,
    required this.role,
    this.profileLoader,
  });

  @override
  Widget build(BuildContext context) {
    void openProfile() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerProfileScreen(
            uid: uid,
            fallbackName: fallbackName,
            fallbackLevel: fallbackLevel,
            loader: profileLoader ?? loadPublicPlayerProfile,
          ),
        ),
      );
    }

    if (uid.isEmpty) {
      return _PlayerTile(
        name: fallbackName.isEmpty ? 'Player' : fallbackName,
        subtitle: _playerSubtitle(role, fallbackLevel),
        onTap: openProfile,
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
        return _PlayerTile(
          name: name,
          subtitle: _playerSubtitle(role, level),
          onTap: openProfile,
        );
      },
    );
  }
}

String _playerSubtitle(String role, String level) {
  return level.isEmpty ? role : '$role · $level';
}
