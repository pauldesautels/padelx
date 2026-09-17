import 'dart:async';
import 'account_deletion.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'current_location.dart';
import 'location.dart';
import 'places.dart';
import 'places_autocomplete.dart';
import 'area_selector.dart';
import 'played_with.dart';
import 'played_with_repository.dart';
import 'played_with_screen.dart';
import 'social_profile.dart';
import 'friends_repository.dart';
import 'friends_screen.dart';
import 'friends.dart';
import 'relationship_policy.dart';
import 'messaging_repository.dart';
import 'messaging.dart';
import 'messages_screen.dart';
import 'conversation_screen.dart';
import 'play_again.dart';
import 'play_again_repository.dart';
import 'player_discovery_repository.dart';
import 'players_screen.dart';
import 'profile_avatar.dart';
import 'avatar_editor.dart';
import 'legal_acceptance.dart';
import 'legal.dart';
import 'rating_receipts.dart';

import 'firebase_app_check_configuration.dart';
import 'firebase_environment.dart';
import 'geohash.dart';
import 'discovery_refresh.dart';
import 'level.dart';
import 'match_date_time_picker.dart';
import 'match_actions_repository.dart';
import 'settings_screen.dart';
import 'push_notifications.dart';
import 'auth_landing.dart';
import 'branding.dart';
import 'design_system.dart';
import 'startup.dart';
import 'eligibility.dart';
import 'report_flow.dart';
import 'report_repository.dart';
import 'reporting.dart';
import 'account_access.dart';
import 'matchmaking_repository.dart';
import 'matchmaking_screen.dart';
import 'auth_language.dart';
import 'l10n/app_localizations.dart';
import 'locale_controller.dart';
import 'l10n/l10n.dart';

PushNotificationService? _pushNotificationService;
StreamSubscription<User?>? _pushAuthSubscription;
final Stopwatch _startupClock = Stopwatch();

String _localizedPreferredSide(BuildContext context, PreferredSide side) =>
    switch (side) {
      PreferredSide.left => context.l10n.leftSide,
      PreferredSide.right => context.l10n.rightSide,
      PreferredSide.either => context.l10n.eitherSide,
    };

String _localizedPlayFrequency(BuildContext context, PlayFrequency frequency) =>
    switch (frequency) {
      PlayFrequency.occasional => context.l10n.occasional,
      PlayFrequency.weekly => context.l10n.weekly,
      PlayFrequency.severalPerWeek => context.l10n.severalPerWeek,
    };
const bool _startupTimingEnabled = bool.fromEnvironment(
  'PADELX_STARTUP_TIMING',
);

void _logStartupTiming(String milestone) {
  if (kDebugMode || _startupTimingEnabled) {
    debugPrint(
      '[StartupTiming +${_startupClock.elapsedMilliseconds}ms dart] $milestone',
    );
  }
}

Future<void> _signOutWithPushCleanup() async {
  await signOutWithPushCleanup(
    pushService: _pushNotificationService,
    signOut: FirebaseAuth.instance.signOut,
  );
}

Future<void> main() async {
  _startupClock.start();
  _logStartupTiming('main entered');
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = PadelXLocaleController(
    store: SharedPreferencesLocalePreferenceStore(),
    systemLocales: WidgetsBinding.instance.platformDispatcher.locales,
  );
  await localeController.load();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _logStartupTiming('first Flutter frame');
  });
  runApp(PadelXApp(localeController: localeController));
  _logStartupTiming('runApp returned');
}

Future<void> initializePadelX(ValueChanged<double> reportProgress) async {
  _logStartupTiming('initialization entered');
  reportProgress(0.15);
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: firebaseOptionsForCurrentEnvironment(),
    );
  }
  _logStartupTiming('Firebase initialized');
  reportProgress(0.5);
  await activateAppCheckForCurrentEnvironment();
  _logStartupTiming('App Check activation completed');
  reportProgress(0.7);
  _pushNotificationService ??= PushNotificationService.firebase();
  _pushAuthSubscription ??= FirebaseAuth.instance.authStateChanges().listen(
    (user) => unawaited(_pushNotificationService!.startForUser(user?.uid)),
  );
  reportProgress(0.82);
  final user = await FirebaseAuth.instance.authStateChanges().first;
  _logStartupTiming('initial auth state resolved');
  reportProgress(0.9);
  if (user != null && user.emailVerified) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    _logStartupTiming('profile readiness completed');
  }
  reportProgress(0.95);
  _logStartupTiming('initialization completed');
}

class PadelXApp extends StatefulWidget {
  const PadelXApp({super.key, required this.localeController});

  final PadelXLocaleController localeController;

  @override
  State<PadelXApp> createState() => _PadelXAppState();
}

class _PadelXAppState extends State<PadelXApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    widget.localeController.updateSystemLocales(locales);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PadelXLocaleScope(
      controller: widget.localeController,
      child: AnimatedBuilder(
        animation: widget.localeController,
        builder: (context, _) => MaterialApp(
          title: 'PadelX',
          debugShowCheckedModeBanner: false,
          locale: widget.localeController.locale,
          supportedLocales: supportedPadelXLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildPadelXTheme(),
          home: StartupCoordinator(
            initialize: initializePadelX,
            destinationBuilder: (_) => const AuthGate(),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AccountAccessRepository _accountAccessRepository =
      FirebaseAccountAccessRepository();
  int _eligibilityGeneration = 0;
  int _legalGeneration = 0;

  void _eligibilityRecorded() {
    if (mounted) setState(() => _eligibilityGeneration++);
  }

  void _legalRecorded() {
    if (mounted) setState(() => _legalGeneration++);
  }

  bool _deleting = false;
  String? _deletionMessage;
  Future<void> _finishDeletion(String message) async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      setState(() {
        _deleting = false;
        _deletionMessage = message;
      });
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _openDeletion() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => DeleteAccountScreen(
          onFinished: _finishDeletion,
          onCancel: () => Navigator.of(routeContext).pop(),
          onSignOutAttempt: () async {
            await _pushNotificationService?.unregisterBeforeSignOut();
          },
        ),
      ),
    );
    if (mounted && _deleting) setState(() => _deleting = false);
  }

  void _continueAfterVerification() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_deletionMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_deletionMessage!),
                TextButton(
                  onPressed: () => setState(() => _deletionMessage = null),
                  child: Text(context.l10n.continueLabel),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // reload() updates FirebaseAuth.currentUser without guaranteeing a new
        // authStateChanges event, so prefer that refreshed instance here.
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          return AccountAccessGate(
            key: ValueKey('account-access-${user.uid}'),
            uid: user.uid,
            repository: _accountAccessRepository,
            onDeleteAccount: _openDeletion,
            onSignOut: _signOutWithPushCleanup,
            allowedBuilder: (_) => _buildAdmittedUser(user),
          );
        }

        return AuthLandingScreen(
          onEmail: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (routeContext) => AuthScreen(
                onEligibilityRecorded: _eligibilityRecorded,
                onLegalAcceptanceRecorded: _legalRecorded,
                onAuthenticationSucceeded: () =>
                    Navigator.of(routeContext).pop(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdmittedUser(User user) {
    if (!user.emailVerified) {
      return AgeEligibilityGate(
        key: ValueKey('eligibility-${user.uid}-$_eligibilityGeneration'),
        repository: EligibilityRepository.firebase(),
        onSignOut: _signOutWithPushCleanup,
        eligibleBuilder: (_) => LegalAcceptanceGate(
          key: ValueKey('legal-${user.uid}-$_legalGeneration'),
          repository: LegalAcceptanceRepository.firebase(),
          onSignOut: _signOutWithPushCleanup,
          acceptedBuilder: (_) => EmailVerificationScreen(
            email: user.email ?? '',
            onContinue: () async {
              await user.reload();
              final refreshedUser = FirebaseAuth.instance.currentUser;
              if (refreshedUser?.emailVerified != true) return false;
              await refreshedUser!.getIdToken(true);
              _continueAfterVerification();
              return true;
            },
            onResend: () async {
              await configureFirebaseAuthLanguage(
                FirebaseAuth.instance,
                Localizations.localeOf(context),
              );
              await user.sendEmailVerification();
            },
            onSignOut: _signOutWithPushCleanup,
            onDeleteAccount: _openDeletion,
          ),
        ),
      );
    }
    return AgeEligibilityGate(
      key: ValueKey('eligibility-${user.uid}-$_eligibilityGeneration'),
      repository: EligibilityRepository.firebase(),
      onSignOut: _signOutWithPushCleanup,
      eligibleBuilder: (_) => LegalAcceptanceGate(
        key: ValueKey('legal-${user.uid}-$_legalGeneration'),
        repository: LegalAcceptanceRepository.firebase(),
        onSignOut: _signOutWithPushCleanup,
        acceptedBuilder: (_) =>
            ProfileGate(user: user, onDeleteAccount: _openDeletion),
      ),
    );
  }
}

class UserProfile {
  final String uid;
  final String displayName;
  final String level;
  final String email;
  final bool hasCreatedAt;
  final Timestamp? createdAt;
  final DiscoveryLocation discoveryLocation;
  final SocialProfileData socialProfile;
  final int avatarVersion;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.level,
    required this.email,
    this.hasCreatedAt = false,
    this.createdAt,
    this.discoveryLocation = const DiscoveryLocation(
      country: '',
      countryCode: '',
      city: '',
    ),
    this.socialProfile = const SocialProfileData(),
    this.avatarVersion = 0,
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
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
      discoveryLocation: DiscoveryLocation.fromMap(data['discoveryLocation']),
      socialProfile: SocialProfileData.fromMap(data),
      avatarVersion: avatarVersionFromMap(data),
    );
  }

  bool get isComplete =>
      uid.isNotEmpty && displayName.isNotEmpty && level.isNotEmpty;
}

class PublicUserProfile {
  final String uid;
  final String displayName;
  final String level;
  final int ratingCount;
  final double ratingAverage;
  final int completedMatchCount;
  final int repeatPlayerCount;
  final String countryCode;
  final String city;
  final String area;
  final SocialProfileData socialProfile;
  final int avatarVersion;

  const PublicUserProfile({
    required this.uid,
    required this.displayName,
    required this.level,
    this.ratingCount = 0,
    this.ratingAverage = 0,
    this.completedMatchCount = 0,
    this.repeatPlayerCount = 0,
    this.countryCode = '',
    this.city = '',
    this.area = '',
    this.socialProfile = const SocialProfileData(),
    this.avatarVersion = 0,
  });

  factory PublicUserProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return PublicUserProfile(
      uid: data['uid']?.toString() ?? document.id,
      displayName: data['displayName']?.toString().trim() ?? '',
      level: data['level']?.toString().trim() ?? '',
      ratingCount: data['ratingCount'] is int ? data['ratingCount'] as int : 0,
      ratingAverage: data['ratingAverage'] is num
          ? (data['ratingAverage'] as num).toDouble()
          : 0,
      completedMatchCount: data['completedMatchCount'] is int
          ? data['completedMatchCount'] as int
          : 0,
      repeatPlayerCount: data['repeatPlayerCount'] is int
          ? data['repeatPlayerCount'] as int
          : 0,
      countryCode: data['countryCode']?.toString().trim() ?? '',
      city: data['city']?.toString().trim() ?? '',
      area: data['area']?.toString().trim() ?? '',
      socialProfile: SocialProfileData.fromMap(data),
      avatarVersion: avatarVersionFromMap(data),
    );
  }
}

class ProfileGate extends StatefulWidget {
  final User user;
  final VoidCallback? onDeleteAccount;

  const ProfileGate({super.key, required this.user, this.onDeleteAccount});

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
            onSignOut: _signOutWithPushCleanup,
          );
        }

        return HomeScreen(
          profile: profile,
          onDeleteAccount: widget.onDeleteAccount,
        );
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
              Text(
                context.l10n.loadProfileFailed,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(context.l10n.connectionRetry),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: widget.onRetry,
                child: Text(context.l10n.tryAgain),
              ),
              TextButton(
                onPressed: _signOutWithPushCleanup,
                child: Text(context.l10n.logOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final Future<bool> Function() onContinue;
  final Future<void> Function() onResend;
  final Future<void> Function() onSignOut;
  final VoidCallback? onDeleteAccount;
  final Duration resendCooldown;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.onContinue,
    required this.onResend,
    required this.onSignOut,
    this.onDeleteAccount,
    this.resendCooldown = const Duration(seconds: 30),
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _isChecking = false;
  bool _isResending = false;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownSeconds = widget.resendCooldown.inSeconds;
    if (_cooldownSeconds <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _continue() async {
    if (_isChecking || _isResending || _isSigningOut) return;
    final strings = context.l10n;
    setState(() => _isChecking = true);
    try {
      final verified = await widget.onContinue();
      if (!verified) {
        _showMessage(strings.emailNotVerified);
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(_verificationErrorMessage(error, strings));
    } catch (_) {
      _showMessage(strings.emailCheckFailed);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resend() async {
    if (_isChecking || _isResending || _isSigningOut || _cooldownSeconds > 0) {
      return;
    }
    final strings = context.l10n;
    setState(() => _isResending = true);
    try {
      await widget.onResend();
      if (!mounted) return;
      setState(_startCooldown);
      _showMessage(strings.verificationEmailSent);
    } on FirebaseAuthException catch (error) {
      _showMessage(_verificationErrorMessage(error, strings));
    } catch (_) {
      _showMessage(strings.verificationResendFailed);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    if (_isChecking || _isResending || _isSigningOut) return;
    final strings = context.l10n;
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } on FirebaseAuthException catch (error) {
      _showMessage(_verificationErrorMessage(error, strings));
    } catch (_) {
      _showMessage(strings.signOutFailed);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  String _verificationErrorMessage(
    FirebaseAuthException error,
    AppLocalizations strings,
  ) {
    switch (error.code) {
      case 'too-many-requests':
        return strings.tooManyAttemptsWait;
      case 'network-request-failed':
        return strings.networkRetry;
      case 'user-disabled':
        return strings.accountUnavailableSupport;
      case 'requires-recent-login':
        return strings.recentLoginRequired;
      default:
        return strings.requestFailedGeneric;
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
    final busy = _isChecking || _isResending || _isSigningOut;
    return Scaffold(
      backgroundColor: const Color(0xFF050605),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0D0C),
                  border: Border.all(color: const Color(0xFF343735)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0xFF1D2907),
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        size: 38,
                        color: Color(0xFFB8F20D),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.l10n.verifyEmail,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.verificationSent,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.email.isEmpty
                          ? context.l10n.emailAddressFallback
                          : widget.email,
                      key: const Key('verification-email'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB8F20D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.openVerificationLink,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        key: const Key('verification-continue'),
                        onPressed: busy ? null : _continue,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB8F20D),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _isChecking
                              ? context.l10n.checkingEllipsis
                              : context.l10n.verifiedMyEmail,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      key: const Key('verification-resend'),
                      onPressed: busy || _cooldownSeconds > 0 ? null : _resend,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB8F20D),
                      ),
                      child: Text(
                        _isResending
                            ? context.l10n.sendingEllipsis
                            : _cooldownSeconds > 0
                            ? context.l10n.resendAvailableIn(_cooldownSeconds)
                            : context.l10n.resendVerificationEmail,
                      ),
                    ),
                    if (widget.onDeleteAccount != null)
                      TextButton(
                        key: const Key('verification-delete-account'),
                        onPressed: busy ? null : widget.onDeleteAccount,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: Text(context.l10n.deleteAccountLower),
                      ),
                    TextButton(
                      key: const Key('verification-sign-out'),
                      onPressed: busy ? null : _signOut,
                      child: Text(
                        _isSigningOut
                            ? context.l10n.signingOutEllipsis
                            : context.l10n.signOut,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final Future<void> Function(String email)? passwordResetSender;
  final Future<void> Function(String email, String password)? loginHandler;
  final Future<void> Function(String email, String password)? signUpHandler;
  final Future<void> Function()? emailVerificationSender;
  final Future<void> Function(String requestId)? ageEligibilityRecorder;
  final Future<void> Function(String requestId)? legalAcceptanceRecorder;
  final VoidCallback? onEligibilityRecorded;
  final VoidCallback? onLegalAcceptanceRecorded;
  final VoidCallback? onAuthenticationSucceeded;

  const AuthScreen({
    super.key,
    this.passwordResetSender,
    this.loginHandler,
    this.signUpHandler,
    this.emailVerificationSender,
    this.ageEligibilityRecorder,
    this.legalAcceptanceRecorder,
    this.onEligibilityRecorded,
    this.onLegalAcceptanceRecorded,
    this.onAuthenticationSucceeded,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  bool _ageConfirmed = false;
  bool _legalAcknowledged = false;
  bool _eligibilitySetupPending = false;
  String? _eligibilityError;
  String? _eligibilityRequestId;
  String? _legalRequestId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final authLocale = Localizations.localeOf(context);
    final strings = context.l10n;
    if (!_isLogin && (!_ageConfirmed || !_legalAcknowledged)) {
      setState(() {
        _eligibilityError = !_ageConfirmed
            ? strings.ageConfirmContinue
            : strings.legalAgreeContinue;
      });
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = email.isEmpty
          ? strings.enterEmailPeriod
          : (!_looksLikeEmail(email) ? strings.validEmailRequired : null);
      _passwordError = password.isEmpty ? strings.enterPasswordPeriod : null;
    });
    if (_emailError != null || _passwordError != null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await (widget.loginHandler != null
            ? widget.loginHandler!(email, password)
            : FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              ));
      } else {
        if (!_eligibilitySetupPending) {
          if (widget.signUpHandler != null) {
            await widget.signUpHandler!(email, password);
          } else {
            final credential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                  email: email,
                  password: password,
                );
            if (credential.user == null) {
              throw FirebaseAuthException(code: 'missing-user');
            }
          }
          _eligibilitySetupPending = true;
          _eligibilityRequestId ??= newEligibilityRequestId();
          _legalRequestId ??= newLegalRequestId();
        }
        try {
          await (widget.ageEligibilityRecorder != null
              ? widget.ageEligibilityRecorder!(_eligibilityRequestId!)
              : EligibilityRepository.firebase().recordEligibility(
                  requestId: _eligibilityRequestId!,
                ));
        } catch (_) {
          if (mounted) {
            setState(() {
              _eligibilityError = strings.ageRecordAfterCreateFailed;
            });
          }
          return;
        }
        widget.onEligibilityRecorded?.call();
        try {
          if (widget.legalAcceptanceRecorder != null) {
            await widget.legalAcceptanceRecorder!(_legalRequestId!);
          } else if (widget.signUpHandler == null) {
            await LegalAcceptanceRepository.firebase().recordAcceptance(
              requestId: _legalRequestId!,
            );
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _eligibilityError = strings.legalRecordAfterCreateFailed;
            });
          }
          return;
        }
        widget.onLegalAcceptanceRecorded?.call();
        if (widget.emailVerificationSender != null) {
          await widget.emailVerificationSender!.call();
        } else {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null && !currentUser.emailVerified) {
            await configureFirebaseAuthLanguage(
              FirebaseAuth.instance,
              authLocale,
            );
            await currentUser.sendEmailVerification();
          }
        }
      }
      if (mounted) widget.onAuthenticationSucceeded?.call();
    } on FirebaseAuthException catch (error) {
      String message;

      switch (error.code) {
        case 'invalid-email':
          message = strings.validEmailRequired;
          break;
        case 'user-not-found':
          message = strings.accountNotFound;
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = strings.incorrectCredentials;
          break;
        case 'admin-restricted-operation':
        case 'operation-not-allowed':
          message = strings.createAccountFailed;
          break;
        case 'email-already-in-use':
          message = strings.emailAlreadyUsed;
          break;
        case 'weak-password':
          message = strings.weakPassword;
          break;
        case 'too-many-requests':
          message = strings.tooManyAttemptsLater;
          break;
        case 'network-request-failed':
          message = strings.networkRetry;
          break;
        default:
          message = _isLogin
              ? strings.loginFailed
              : strings.genericCreateAccountFailed;
      }

      _showMessage(message);
    } catch (_) {
      _showMessage(strings.somethingWrongRetry);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final authLocale = Localizations.localeOf(context);
    final strings = context.l10n;
    final emailSent = await showDialog<bool>(
      context: context,
      builder: (_) => PasswordResetDialog(
        initialEmail: _emailController.text.trim(),
        sender:
            widget.passwordResetSender ??
            (email) async {
              await configureFirebaseAuthLanguage(
                FirebaseAuth.instance,
                authLocale,
              );
              await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
            },
      ),
    );

    if (emailSent == true) {
      _showMessage(strings.passwordResetSent);
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
      _emailError = null;
      _passwordError = null;
      _obscurePassword = true;
      _ageConfirmed = false;
      _legalAcknowledged = false;
      _eligibilityError = null;
    });
  }

  bool _looksLikeEmail(String email) {
    final at = email.indexOf('@');
    return at > 0 && at < email.length - 3 && email.indexOf('.', at) > at + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: padelXBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              key: const Key('auth-content'),
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Column(
                    key: Key('padelx-wordmark'),
                    children: [
                      PadelXBrandMark(size: 96),
                      SizedBox(height: 6),
                      PadelXWordmark(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.signInOrCreate,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    decoration: BoxDecoration(
                      color: padelXSurface,
                      border: Border.all(color: padelXAuthBorder),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Theme(
                      key: const Key('auth-form-theme'),
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: padelXAuthFieldFill,
                          labelStyle: const TextStyle(color: Colors.white70),
                          floatingLabelStyle: const TextStyle(
                            color: padelXAuthAccent,
                          ),
                          prefixIconColor: Colors.white70,
                          suffixIconColor: padelXAuthAccent,
                          hintStyle: const TextStyle(color: Colors.white54),
                          errorStyle: const TextStyle(color: Color(0xFFFFA59C)),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: padelXAuthBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: padelXAuthAccent,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFFFA59C),
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFFFA59C),
                              width: 1.5,
                            ),
                          ),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: padelXAuthAccent,
                            disabledForegroundColor: Colors.white38,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isLogin ? context.l10n.logIn : context.l10n.signUp,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLogin
                                ? context.l10n.welcomeBackAuth
                                : context.l10n.createVerifyAuth,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            key: const Key('auth-email'),
                            controller: _emailController,
                            enabled: !_isLoading && !_eligibilitySetupPending,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: context.l10n.email,
                              hintText: context.l10n.enterEmail,
                              prefixIcon: Icon(Icons.email_outlined),
                              errorText: _emailError,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('auth-password'),
                            controller: _passwordController,
                            enabled: !_isLoading && !_eligibilitySetupPending,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: _isLogin
                                ? const [AutofillHints.password]
                                : const [AutofillHints.newPassword],
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                            onSubmitted: (_) {
                              if (_isLoading) return;
                              if (!_isLogin &&
                                  (!_ageConfirmed || !_legalAcknowledged)) {
                                FocusScope.of(context).unfocus();
                                _submit();
                                return;
                              }
                              _submit();
                            },
                            decoration: InputDecoration(
                              labelText: context.l10n.password,
                              hintText: _isLogin
                                  ? context.l10n.enterPasswordHint
                                  : context.l10n.createPassword,
                              prefixIcon: const Icon(Icons.lock_outline),
                              errorText: _passwordError,
                              suffixIcon: IconButton(
                                key: const Key('toggle-password-visibility'),
                                tooltip: _obscurePassword
                                    ? context.l10n.showPassword
                                    : context.l10n.hidePassword,
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
                                child: Text(context.l10n.forgotPassword),
                              ),
                            ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 8),
                            Material(
                              type: MaterialType.transparency,
                              child: CheckboxListTile(
                                key: const Key('signup-age-checkbox'),
                                value: _ageConfirmed,
                                onChanged:
                                    _isLoading || _eligibilitySetupPending
                                    ? null
                                    : (value) => setState(() {
                                        _ageConfirmed = value == true;
                                        _eligibilityError = null;
                                      }),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(context.l10n.ageConfirmation),
                              ),
                            ),
                            Material(
                              type: MaterialType.transparency,
                              child: CheckboxListTile(
                                key: const Key('signup-legal-checkbox'),
                                value: _legalAcknowledged,
                                onChanged:
                                    _isLoading || _eligibilitySetupPending
                                    ? null
                                    : (value) => setState(() {
                                        _legalAcknowledged = value == true;
                                        _eligibilityError = null;
                                      }),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Wrap(
                                  children: [
                                    Text(context.l10n.legalAgreePrefix),
                                    InkWell(
                                      onTap: () =>
                                          openLegalLink(context, '/terms'),
                                      child: Text(
                                        context.l10n.termsOfUse,
                                        style: TextStyle(
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    Text(context.l10n.legalAgreeMiddle),
                                    InkWell(
                                      onTap: () =>
                                          openLegalLink(context, '/privacy'),
                                      child: Text(
                                        context.l10n.privacyPolicy,
                                        style: TextStyle(
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    Text(context.l10n.period),
                                  ],
                                ),
                              ),
                            ),
                            if (_eligibilityError != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _eligibilityError!,
                                  key: const Key('signup-eligibility-error'),
                                  style: const TextStyle(
                                    color: Color(0xFFFFA59C),
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              key: const Key('auth-submit'),
                              onPressed:
                                  _isLoading ||
                                      (!_isLogin &&
                                          (!_ageConfirmed ||
                                              !_legalAcknowledged))
                                  ? null
                                  : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: padelXAuthPrimary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    padelXAuthPrimaryDisabled,
                                disabledForegroundColor: Colors.white60,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(
                                _isLoading
                                    ? (_isLogin
                                          ? context.l10n.loggingIn
                                          : context.l10n.creatingAccount)
                                    : (_isLogin
                                          ? context.l10n.logIn
                                          : (_eligibilitySetupPending
                                                ? context
                                                      .l10n
                                                      .retryAgeConfirmation
                                                : context.l10n.createAccount)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            key: const Key('auth-switch-mode'),
                            onPressed: _isLoading || _eligibilitySetupPending
                                ? null
                                : _switchMode,
                            child: Text(
                              _isLogin
                                  ? context.l10n.switchToSignUp
                                  : context.l10n.switchToLogin,
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
    final strings = context.l10n;

    if (email.isEmpty) {
      setState(() {
        _errorMessage = strings.enterEmailPeriod;
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
        if (error.code == 'user-not-found') {
          Navigator.of(context).pop(true);
          return;
        }
        setState(() {
          _errorMessage = _passwordResetErrorMessage(error, strings);
          _isSending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = strings.resetEmailFailed;
          _isSending = false;
        });
      }
    }
  }

  String _passwordResetErrorMessage(
    FirebaseAuthException error,
    AppLocalizations strings,
  ) {
    switch (error.code) {
      case 'invalid-email':
        return strings.validEmailRequired;
      case 'too-many-requests':
        return strings.tooManyRequestsLater;
      case 'network-request-failed':
        return strings.networkRetry;
      default:
        return strings.resetEmailFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.resetPassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.resetEmailHelp),
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
                labelText: context.l10n.email,
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
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSending ? null : _sendResetEmail,
          child: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.sendResetEmail),
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
  final String source;
  final String venueType;
  final bool autoFillEnabled;
  final String autoFillRequestId;
  final Map<int, List<String>> teams;

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
    this.source = '',
    this.venueType = '',
    this.autoFillEnabled = false,
    this.autoFillRequestId = '',
    this.teams = const {},
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
      creatorUid:
          data['organizer'] is Map && data['organizer']['deleted'] == true
          ? ''
          : matchCreatorUid(data),
      creatorEmail:
          data['organizer'] is Map && data['organizer']['deleted'] == true
          ? ''
          : matchCreatorEmail(data),
      creatorDisplayName:
          data['organizer'] is Map && data['organizer']['deleted'] == true
          ? 'Deleted player'
          : data['creatorDisplayName']?.toString() ?? '',
      creatorLevel:
          data['organizer'] is Map && data['organizer']['deleted'] == true
          ? ''
          : data['creatorLevel']?.toString() ?? '',
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
      source: data['source']?.toString() ?? '',
      venueType: data['venueType']?.toString() ?? '',
      autoFillEnabled: data['autoFillEnabled'] == true,
      autoFillRequestId: data['autoFillRequestId']?.toString() ?? '',
      teams: {
        for (final item
            in (data['teams'] is List ? data['teams'] as List : const []))
          if (item is Map && item['team'] is num)
            (item['team'] as num).toInt(): (item['participantUids'] is List
                ? (item['participantUids'] as List)
                      .map((uid) => uid.toString())
                      .where((uid) => uid.isNotEmpty)
                      .toList()
                : <String>[]),
      },
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

List<Match> mergeDiscoveryMatchGroups(Iterable<Iterable<Match>> groups) {
  final byId = <String, Match>{};
  for (final group in groups) {
    for (final match in group) {
      byId[match.id] = match;
    }
  }
  return sortedMatches(byId.values);
}

List<Match> discoveryWithoutMatch(Iterable<Match> matches, String matchId) =>
    matches.where((match) => match.id != matchId).toList();

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

String _localizedFriendlyDateTime(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toString();
  final local = value.toLocal();
  return '${DateFormat('EEEE, MMM d', locale).format(local)} · '
      '${DateFormat.jm(locale).format(local)}';
}

bool _isRawCanonicalDateTitle(String value) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(value.trim());

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
    if (data['deleted'] == true) {
      return const MatchPlayer(
        uid: '',
        email: '',
        displayName: 'Deleted player',
      );
    }
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
  final int lifetimeRatingCount;
  final double lifetimeRatingAverage;
  final int completedMatchCount;
  final int repeatPlayerCount;
  final String countryCode;
  final String city;
  final String area;
  final SocialProfileData socialProfile;
  final int avatarVersion;
  final String reliabilityStatus;
  final int? reliabilityPercent;
  final int reliabilitySampleSize;

  const PublicPlayerProfile({
    required this.uid,
    required this.displayName,
    required this.level,
    this.email = '',
    required this.matches,
    this.ratings = const [],
    this.lifetimeRatingCount = 0,
    this.lifetimeRatingAverage = 0,
    this.completedMatchCount = 0,
    this.repeatPlayerCount = 0,
    this.countryCode = '',
    this.city = '',
    this.area = '',
    this.socialProfile = const SocialProfileData(),
    this.avatarVersion = 0,
    this.reliabilityStatus = 'new_player',
    this.reliabilityPercent,
    this.reliabilitySampleSize = 0,
  });

  RatingSummary get ratingSummary =>
      RatingSummary(average: lifetimeRatingAverage, count: lifetimeRatingCount);
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

Future<PublicPlayerProfile> loadPublicPlayerIdentity(String uid) async {
  final document = await FirebaseFirestore.instance
      .collection('publicProfiles')
      .doc(uid)
      .get();
  final data = document.data() ?? const <String, dynamic>{};
  return PublicPlayerProfile(
    uid: uid,
    displayName: data['displayName']?.toString() ?? '',
    level: data['level']?.toString() ?? '',
    matches: const [],
    avatarVersion: avatarVersionFromMap(data),
  );
}

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
    firestore.collection('publicProfiles').doc(uid).get(),
    firestore
        .collection('matches')
        .where('participantUids', arrayContains: uid)
        .orderBy('scheduledAt', descending: true)
        .limit(20)
        .get(),
    firestore.collection('reliabilityProfiles').doc(uid).get(),
  ]);
  final userDocument = results[0] as DocumentSnapshot<Map<String, dynamic>>;
  final matchSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
  final reliabilityDocument =
      results[2] as DocumentSnapshot<Map<String, dynamic>>;
  final reliability = reliabilityDocument.data() ?? const <String, dynamic>{};
  final profile = userDocument.exists
      ? PublicUserProfile.fromDocument(userDocument)
      : null;
  // participantUids is a query index only. Re-check the authoritative match
  // fields before displaying results so a stale index cannot grant membership.
  final matches = matchSnapshot.docs
      .where((document) => matchIncludesPlayer(document.data(), uid))
      .map(Match.fromDocument)
      .toList();
  final viewerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final sharedMatches = viewerUid.isEmpty || viewerUid == uid
      ? const <Match>[]
      : matches.where((match) => matchIncludesIdentity(match, viewerUid, ''));
  final submittedByMatch = await Future.wait(
    sharedMatches.map(
      (match) async =>
          (match.id, await loadOwnRatingReceiptUids(match.id, [uid])),
    ),
  );
  final ratings = submittedByMatch
      .where((entry) => entry.$2.contains(uid))
      .map(
        (entry) => PlayerRating(
          matchId: entry.$1,
          raterUid: viewerUid,
          ratedUid: uid,
          rating: 0,
        ),
      )
      .toList();
  return PublicPlayerProfile(
    uid: uid,
    displayName: profile?.displayName ?? '',
    level: profile?.level ?? '',
    matches: matches,
    ratings: ratings,
    lifetimeRatingCount: profile?.ratingCount ?? 0,
    lifetimeRatingAverage: profile?.ratingAverage ?? 0,
    completedMatchCount: profile?.completedMatchCount ?? 0,
    repeatPlayerCount: profile?.repeatPlayerCount ?? 0,
    countryCode: profile?.countryCode ?? '',
    city: profile?.city ?? '',
    area: profile?.area ?? '',
    socialProfile: profile?.socialProfile ?? const SocialProfileData(),
    avatarVersion: profile?.avatarVersion ?? 0,
    reliabilityStatus: reliability['status']?.toString() ?? 'new_player',
    reliabilityPercent: reliability['percent'] is int
        ? reliability['percent'] as int
        : null,
    reliabilitySampleSize: reliability['sampleSize'] is int
        ? reliability['sampleSize'] as int
        : 0,
  );
}

bool isOrganizerIdentity(
  Map<dynamic, dynamic> matchData,
  String uid,
  String email,
) {
  final creatorUid = matchCreatorUid(matchData);
  return creatorUid.isNotEmpty && creatorUid == uid;
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
  final normalizedLevel = normalizePadelLevel(level);
  if (normalizedLevel == null) {
    throw const MatchActionException('Please choose a valid player level.');
  }
  return {
    'title': _friendlyDateTime(scheduledAt),
    'dateTime': _friendlyDateTime(scheduledAt),
    'scheduledAt': Timestamp.fromDate(scheduledAt),
    'club': location.clubName.trim(),
    'clubName': location.clubName.trim(),
    'location': location.toMap(),
    'level': matchLevelStorageValue(normalizedLevel),
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
    this.email = '',
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
    'status': status,
    'requestedAt': requestedAt == null
        ? Timestamp.now()
        : Timestamp.fromDate(requestedAt!),
    'eventId': eventId,
  };
}

enum AppNotificationType {
  unknown,
  joinRequest,
  joinApproved,
  joinDeclined,
  directMessage,
  matchMessage,
  friendRequest,
  friendAccepted,
  playAgainInvite,
  matchmakingPartnerInvite,
  matchmakingMatchFound,
  matchmakingReplacementFound,
  matchmakingMatchConfirmed,
}

extension AppNotificationTypeStorage on AppNotificationType {
  String get storageValue => switch (this) {
    AppNotificationType.unknown => 'unknown',
    AppNotificationType.joinRequest => 'join_request',
    AppNotificationType.joinApproved => 'join_approved',
    AppNotificationType.joinDeclined => 'join_declined',
    AppNotificationType.directMessage => 'direct_message',
    AppNotificationType.matchMessage => 'match_message',
    AppNotificationType.friendRequest => 'friend_request',
    AppNotificationType.friendAccepted => 'friend_accepted',
    AppNotificationType.playAgainInvite => 'play_again_invite',
    AppNotificationType.matchmakingPartnerInvite =>
      'matchmaking_partner_invite',
    AppNotificationType.matchmakingMatchFound => 'matchmaking_match_found',
    AppNotificationType.matchmakingReplacementFound =>
      'matchmaking_replacement_found',
    AppNotificationType.matchmakingMatchConfirmed =>
      'matchmaking_match_confirmed',
  };

  static AppNotificationType fromStorage(Object? value) => switch (value
      ?.toString()) {
    'join_approved' || 'joinApproved' => AppNotificationType.joinApproved,
    'join_declined' || 'joinDeclined' => AppNotificationType.joinDeclined,
    'direct_message' || 'directMessage' => AppNotificationType.directMessage,
    'match_message' || 'matchMessage' => AppNotificationType.matchMessage,
    'friend_request' || 'friendRequest' => AppNotificationType.friendRequest,
    'friend_accepted' || 'friendAccepted' => AppNotificationType.friendAccepted,
    'play_again_invite' ||
    'playAgainInvite' => AppNotificationType.playAgainInvite,
    'join_request' || 'joinRequest' => AppNotificationType.joinRequest,
    'matchmaking_partner_invite' =>
      AppNotificationType.matchmakingPartnerInvite,
    'matchmaking_match_found' => AppNotificationType.matchmakingMatchFound,
    'matchmaking_replacement_found' =>
      AppNotificationType.matchmakingReplacementFound,
    'matchmaking_match_confirmed' =>
      AppNotificationType.matchmakingMatchConfirmed,
    _ => AppNotificationType.unknown,
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
  final String conversationId;

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
    this.conversationId = '',
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
      conversationId: data['conversationId']?.toString() ?? '',
    );
  }
}

String localizedNotificationTitle(
  AppNotification notification,
  AppLocalizations strings,
) {
  final recognizedStoredTitle = switch (notification.type) {
    AppNotificationType.joinRequest => notification.title == 'New join request',
    AppNotificationType.joinApproved =>
      notification.title == 'Request approved',
    AppNotificationType.joinDeclined =>
      notification.title == 'Request declined',
    AppNotificationType.directMessage => notification.title == 'New message',
    AppNotificationType.matchMessage =>
      notification.title == 'New match message',
    AppNotificationType.friendRequest =>
      notification.title == 'New friend request',
    AppNotificationType.friendAccepted =>
      notification.title == 'Friend request accepted',
    AppNotificationType.playAgainInvite => notification.title == 'Play again',
    AppNotificationType.matchmakingPartnerInvite =>
      notification.title == 'Partner invitation',
    AppNotificationType.matchmakingMatchFound =>
      notification.title == 'Match found',
    AppNotificationType.matchmakingReplacementFound =>
      notification.title == 'Match spot found',
    AppNotificationType.matchmakingMatchConfirmed =>
      notification.title == 'Match confirmed',
    AppNotificationType.unknown => false,
  };
  if (!recognizedStoredTitle) return notification.title;
  return switch (notification.type) {
    AppNotificationType.joinRequest => strings.newJoinRequest,
    AppNotificationType.joinApproved => strings.requestApproved,
    AppNotificationType.joinDeclined => strings.requestDeclined,
    AppNotificationType.directMessage => strings.newDirectMessage,
    AppNotificationType.matchMessage => strings.newMatchMessage,
    AppNotificationType.friendRequest => strings.newFriendRequest,
    AppNotificationType.friendAccepted => strings.friendRequestAccepted,
    AppNotificationType.playAgainInvite => strings.playAgainInvite,
    AppNotificationType.matchmakingPartnerInvite => strings.partnerInvitation,
    AppNotificationType.matchmakingMatchFound => strings.matchFound,
    AppNotificationType.matchmakingReplacementFound =>
      strings.matchmakingSpotFound,
    AppNotificationType.matchmakingMatchConfirmed =>
      strings.matchmakingMatchConfirmed,
    AppNotificationType.unknown => notification.title,
  };
}

String localizedNotificationMessage(
  AppNotification notification,
  AppLocalizations strings,
) {
  if (localizedNotificationTitle(notification, strings) == notification.title &&
      notification.type != AppNotificationType.unknown) {
    return notification.message;
  }
  return switch (notification.type) {
    AppNotificationType.joinRequest => strings.joinRequestBody(
      notification.actorDisplayName,
      notification.matchClubName,
    ),
    AppNotificationType.joinApproved => strings.requestApprovedBody(
      notification.matchClubName,
    ),
    AppNotificationType.joinDeclined => strings.requestDeclinedBody(
      notification.matchClubName,
    ),
    AppNotificationType.directMessage => strings.newDirectMessageBody,
    AppNotificationType.matchMessage => strings.newMatchMessageBody,
    AppNotificationType.friendRequest => strings.friendRequestBody(
      notification.actorDisplayName,
    ),
    AppNotificationType.friendAccepted => strings.friendAcceptedBody(
      notification.actorDisplayName,
    ),
    AppNotificationType.playAgainInvite => strings.playAgainBody(
      notification.actorDisplayName,
    ),
    AppNotificationType.matchmakingPartnerInvite =>
      strings.matchmakingPartnerInviteBody,
    AppNotificationType.matchmakingMatchFound =>
      strings.matchmakingMatchFoundBody,
    AppNotificationType.matchmakingReplacementFound =>
      strings.matchmakingSpotFoundBody,
    AppNotificationType.matchmakingMatchConfirmed =>
      strings.matchmakingMatchConfirmedBody,
    AppNotificationType.unknown => notification.message,
  };
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
  return messagingInboxTime(createdAt, now: now);
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

class NotificationsTab extends StatefulWidget {
  final List<AppNotification> notifications;
  final bool isLoading;
  final bool error;
  final FutureOr<void> Function(AppNotification) onMarkRead;
  final ValueChanged<AppNotification> onOpen;
  final Future<void> Function()? onMarkAllRead;
  final VoidCallback? onRetry;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final Stream<Map<String, dynamic>?> Function(AppNotification)?
  joinRequestStream;
  final DateTime? now;
  final ValueChanged<AppNotification>? onDismiss;

  const NotificationsTab({
    super.key,
    required this.notifications,
    required this.isLoading,
    required this.error,
    required this.onMarkRead,
    required this.onOpen,
    this.onMarkAllRead,
    this.onRetry,
    this.hasMore = false,
    this.onLoadMore,
    this.joinRequestStream,
    this.now,
    this.onDismiss,
  });

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  bool _markingAllRead = false;
  List<AppNotification> _lastNotifications = const [];

  @override
  void initState() {
    super.initState();
    if (!widget.error) _lastNotifications = widget.notifications;
  }

  @override
  void didUpdateWidget(NotificationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.error) _lastNotifications = widget.notifications;
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead || widget.onMarkAllRead == null) return;
    setState(() => _markingAllRead = true);
    try {
      await widget.onMarkAllRead!();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.markAllReadFailed)));
      }
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    try {
      await widget.onMarkRead(notification);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.markReadFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotifications = widget.error && widget.notifications.isEmpty
        ? _lastNotifications
        : widget.notifications;
    final ordered = sortedNotifications(visibleNotifications);
    final hasUnread = unreadNotificationCount(ordered) > 0;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final action = hasUnread && widget.onMarkAllRead != null
                    ? TextButton(
                        key: const Key('mark-all-notifications-read'),
                        onPressed: _markingAllRead ? null : _markAllRead,
                        child: _markingAllRead
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.l10n.markAllRead),
                      )
                    : null;
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.notifications,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.l10n.matchUpdates,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                );
                if (constraints.maxWidth < 360 && action != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 4),
                      Align(alignment: Alignment.centerRight, child: action),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: title),
                    if (action != null) ...[const SizedBox(width: 8), action],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildContent(ordered)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<AppNotification> ordered) {
    if (widget.isLoading) {
      return Center(
        child: Semantics(
          label: context.l10n.loadingNotifications,
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (widget.error && ordered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 44,
                color: Colors.white54,
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.notificationsUnavailable,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.connectionRetry,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.tryAgainLower),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (ordered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_none,
                size: 52,
                color: Colors.white54,
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.noNotifications,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.notificationEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: ordered.length + (widget.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == ordered.length) {
          return Center(
            child: OutlinedButton(
              key: const Key('load-older-notifications'),
              onPressed: widget.onLoadMore,
              child: Text(context.l10n.loadOlderNotifications),
            ),
          );
        }
        final notification = ordered[index];
        return NotificationCard(
          notification: notification,
          now: widget.now ?? DateTime.now(),
          onMarkRead: _markRead,
          onOpen: widget.onOpen,
          requestStream: widget.joinRequestStream?.call(notification),
          onDismiss: widget.onDismiss,
        );
      },
    );
  }
}

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final DateTime now;
  final FutureOr<void> Function(AppNotification) onMarkRead;
  final ValueChanged<AppNotification> onOpen;
  final Stream<Map<String, dynamic>?>? requestStream;
  final ValueChanged<AppNotification>? onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.now,
    required this.onMarkRead,
    required this.onOpen,
    this.requestStream,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (requestStream != null &&
        notification.type == AppNotificationType.joinRequest) {
      return StreamBuilder<Map<String, dynamic>?>(
        stream: requestStream,
        builder: (context, snapshot) => _buildCard(
          context,
          snapshot.connectionState == ConnectionState.waiting
              ? null
              : joinRequestNotificationStatus(notification, snapshot.data),
        ),
      );
    }
    return _buildCard(context, null);
  }

  Widget _buildCard(BuildContext context, String? status) {
    final unread = !notification.read;
    final icon = switch (notification.type) {
      AppNotificationType.unknown => Icons.notifications_none,
      AppNotificationType.joinRequest => Icons.person_add_alt_1,
      AppNotificationType.joinApproved => Icons.check_circle_outline,
      AppNotificationType.joinDeclined => Icons.cancel_outlined,
      AppNotificationType.directMessage => Icons.chat_bubble_outline,
      AppNotificationType.matchMessage => Icons.forum_outlined,
      AppNotificationType.friendRequest => Icons.person_add_alt_1,
      AppNotificationType.friendAccepted => Icons.people_outline,
      AppNotificationType.playAgainInvite => Icons.replay,
      AppNotificationType.matchmakingPartnerInvite => Icons.group_add_outlined,
      AppNotificationType.matchmakingMatchFound => Icons.celebration_outlined,
      AppNotificationType.matchmakingReplacementFound =>
        Icons.person_search_outlined,
      AppNotificationType.matchmakingMatchConfirmed =>
        Icons.event_available_outlined,
    };
    final category = switch (notification.type) {
      AppNotificationType.joinApproved ||
      AppNotificationType.friendAccepted ||
      AppNotificationType.playAgainInvite => 1,
      AppNotificationType.matchmakingPartnerInvite ||
      AppNotificationType.matchmakingMatchFound ||
      AppNotificationType.matchmakingReplacementFound ||
      AppNotificationType.matchmakingMatchConfirmed => 1,
      AppNotificationType.joinDeclined => -1,
      _ => 0,
    };
    final accent = category < 0
        ? const Color(0xFFFFA59C)
        : category > 0
        ? const Color(0xFF74E8A0)
        : const Color(0xFF8EB9A1);
    final title = localizedNotificationTitle(notification, context.l10n);
    final message = localizedNotificationMessage(notification, context.l10n);
    final timestamp = notification.createdAt == null
        ? context.l10n.timeUnavailable
        : messagingInboxTime(
            notification.createdAt,
            now: now,
            locale: Localizations.localeOf(context),
            yesterdayLabel: context.l10n.yesterday,
          );
    final semanticsLabel = [
      unread ? context.l10n.unread : context.l10n.read,
      title,
      message,
      status ?? '',
      timestamp,
    ].where((value) => value.isNotEmpty).join(', ');
    return Semantics(
      key: ValueKey('notification-${notification.id}'),
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: Card(
        color: unread ? const Color(0xFF1D3027) : const Color(0xFF18211D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: unread ? accent.withValues(alpha: 0.24) : Colors.white10,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(notification),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: ValueKey('notification-type-${notification.type.name}'),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: unread ? 0.16 : 0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: 21,
                      color: unread ? accent : Colors.white60,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 8),
                            Semantics(
                              label: context.l10n.unreadNotification,
                              child: Container(
                                key: const ValueKey('unread-indicator'),
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message,
                        style: TextStyle(
                          height: 1.35,
                          color: unread ? Colors.white : Colors.white70,
                          fontWeight: unread
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              timestamp,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          if (unread)
                            Tooltip(
                              message: context.l10n.markAsRead,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white60,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () => unawaited(
                                  Future.sync(() => onMarkRead(notification)),
                                ),
                                child: Text(context.l10n.markRead),
                              ),
                            ),
                        ],
                      ),
                      if (status != null) ...[
                        const SizedBox(height: 7),
                        Container(
                          key: ValueKey('notification-status-$status'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (notification.type ==
                          AppNotificationType.playAgainInvite) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              key: const Key('view-play-again-match'),
                              onPressed: () => onOpen(notification),
                              child: Text(context.l10n.viewMatch),
                            ),
                            TextButton(
                              key: const Key('dismiss-play-again-invite'),
                              onPressed: onDismiss == null
                                  ? null
                                  : () => onDismiss!(notification),
                              child: Text(context.l10n.dismiss),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.chevron_right, color: Colors.white38),
                ),
              ],
            ),
          ),
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
    'participantUids': {
      matchCreatorUid(matchData),
      ...players.whereType<Map>().map(_playerUid),
    }.where((uid) => uid.isNotEmpty).toList(),
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
  throw const MatchActionException('Could not identify the match organizer.');
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
  final Future<List<Match>> Function()? discoveryLoader;
  final Stream<List<Match>> Function(
    MatchLocation? location,
    double radiusKm,
    int perCellLimit,
  )?
  discoveryStreamLoader;
  final Future<Map<String, dynamic>?> Function(String matchId)?
  matchDocumentLoader;
  final Widget Function()? createMatchScreenBuilder;
  final Duration indexRetryDelay;
  final int indexRetryAttempts;
  final PlayedWithRepository? playedWithRepository;
  final FriendsRepository? friendsRepository;
  final VoidCallback? onDeleteAccount;
  final MatchmakingRepository? matchmakingRepository;

  const HomeScreen({
    super.key,
    this.profile,
    this.discoveryLoader,
    this.discoveryStreamLoader,
    this.matchDocumentLoader,
    this.createMatchScreenBuilder,
    this.indexRetryDelay = const Duration(milliseconds: 400),
    this.indexRetryAttempts = 10,
    this.playedWithRepository,
    this.friendsRepository,
    this.onDeleteAccount,
    this.matchmakingRepository,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _notificationLimit = 50;
  int _myMatchLimit = 100;
  final List<Match> _discoveryMatches = [];
  StreamSubscription<List<Match>>? _discoverySubscription;
  bool _discoveryLoading = true;
  bool _discoveryError = false;
  int _discoveryGeneration = 0;
  MatchLocation? _discoveryOverride;
  double _discoveryRadiusKm = 25;
  int _discoveryPerCellLimit = discoveryInitialCellLimit;

  PlayedWithRepository get _playedWithRepository =>
      widget.playedWithRepository ??
      FirestorePlayedWithRepository(
        filter: FirebaseRelationshipPolicyService().filterPlayedWith,
      );

  FriendsRepository get _friendsRepository =>
      widget.friendsRepository ?? FirebaseFriendsRepository();

  MessagingRepository get _messagingRepository => FirebaseMessagingRepository();
  MatchmakingRepository get _matchmakingRepository =>
      widget.matchmakingRepository ?? FirebaseMatchmakingRepository();

  @override
  void initState() {
    super.initState();
    unawaited(_restartDiscovery());
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.discoveryLocation !=
            widget.profile?.discoveryLocation ||
        oldWidget.discoveryLoader != widget.discoveryLoader ||
        oldWidget.discoveryStreamLoader != widget.discoveryStreamLoader) {
      unawaited(_restartDiscovery());
    }
  }

  @override
  void dispose() {
    _discoveryGeneration++;
    unawaited(_discoverySubscription?.cancel());
    super.dispose();
  }

  void _openMessages() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MessagesScreen(currentUid: uid, repository: _messagingRepository),
      ),
    );
  }

  void _openMatchmaking() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final profile = widget.profile;
    if (uid == null || profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchmakingScreen(
          currentUid: uid,
          discoveryLocation: profile.discoveryLocation,
          level: profile.level,
          preferredSide: profile.socialProfile.preferredSide.value,
          repository: _matchmakingRepository,
          friendsRepository: _friendsRepository,
          onOpenMatch: (matchId) async {
            final document = await FirebaseFirestore.instance
                .collection('matches')
                .doc(matchId)
                .get();
            if (!mounted || !document.exists) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MatchDetailsScreen(
                  match: Match.fromDocument(document),
                  onMatchUpdated: _waitForIndexAndRefresh,
                  onMatchDeleted: _handleMatchDeleted,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openPlayedWithProfile(BuildContext context, PlayedWithPlayer player) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerProfileScreen(
          uid: player.profile.uid,
          fallbackName: player.profile.displayName,
          fallbackLevel: player.profile.level,
          playedWithRepository: _playedWithRepository,
          viewerUid: FirebaseAuth.instance.currentUser?.uid,
          friendsRepository: _friendsRepository,
          onPlayAgain: _openPlayAgain,
        ),
      ),
    );
  }

  Future<void> _openPlayAgain(PlayAgainTarget target) async {
    var resolved = target;
    if (target.sourceMatchId?.isNotEmpty == true && target.location == null) {
      try {
        final source = await FirebaseFirestore.instance
            .collection('matches')
            .doc(target.sourceMatchId)
            .get();
        if (source.exists) {
          final match = Match.fromDocument(source);
          resolved = PlayAgainTarget(
            uid: target.uid,
            displayName: target.displayName,
            sourceMatchId: target.sourceMatchId,
            location: match.location,
            level: match.level,
          );
        }
      } catch (_) {
        // Safe fallback: Create Match opens without stale source prefills.
      }
    }
    if (!mounted) return;
    final result = await Navigator.push<MatchMutationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMatchScreen(playAgainTarget: resolved),
      ),
    );
    if (result != null && mounted) await _waitForIndexAndRefresh(result);
  }

  void _openPlayedWithList() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayedWithScreen(
          viewerUid: uid,
          repository: _playedWithRepository,
          onProfileTap: _openPlayedWithProfile,
          onPlayAgain: _openPlayAgain,
        ),
      ),
    );
  }

  void _openFriends() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendsScreen(
          viewerUid: uid,
          repository: _friendsRepository,
          onProfileTap: (context, profile) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlayerProfileScreen(
                uid: profile.uid,
                fallbackName: profile.displayName,
                fallbackLevel: profile.level,
                viewerUid: uid,
                playedWithRepository: _playedWithRepository,
                friendsRepository: _friendsRepository,
                onPlayAgain: _openPlayAgain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    final onDeleteAccount = widget.onDeleteAccount;
    if (onDeleteAccount == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          friendsRepository: _friendsRepository,
          onDeleteAccount: onDeleteAccount,
          currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
          notificationPreferencesRepository:
              FirebaseNotificationPreferencesRepository(),
          pushSettingsService: _pushNotificationService,
        ),
      ),
    );
  }

  Future<void> _refreshDiscovery() async {
    await _restartDiscovery();
  }

  void _handleMatchDeleted(String matchId) {
    if (!mounted) return;
    setState(() {
      final retained = discoveryWithoutMatch(_discoveryMatches, matchId);
      _discoveryMatches
        ..clear()
        ..addAll(retained);
    });
  }

  Future<void> _restartDiscovery() async {
    final generation = ++_discoveryGeneration;
    final previous = _discoverySubscription;
    _discoverySubscription = null;
    await previous?.cancel();
    if (!mounted || generation != _discoveryGeneration) return;
    if (_discoveryMatches.isEmpty) {
      setState(() {
        _discoveryLoading = true;
        _discoveryError = false;
      });
    }
    final injectedStream = widget.discoveryStreamLoader;
    if (injectedStream != null) {
      _listenToDiscovery(
        injectedStream(
          _discoveryOverride,
          _discoveryRadiusKm,
          _discoveryPerCellLimit,
        ),
        generation,
      );
      return;
    }
    final injectedLoader = widget.discoveryLoader;
    if (injectedLoader != null) {
      try {
        final matches = await injectedLoader();
        if (!mounted || generation != _discoveryGeneration) return;
        setState(() {
          _discoveryMatches
            ..clear()
            ..addAll(sortedMatches(matches));
          _discoveryLoading = false;
          _discoveryError = false;
        });
      } catch (_) {
        if (!mounted || generation != _discoveryGeneration) return;
        debugPrint('Discover one-time test loader failed.');
        setState(() {
          _discoveryLoading = false;
          _discoveryError = _discoveryMatches.isEmpty;
        });
      }
      return;
    }
    _listenToDiscovery(_watchDiscoveryMatches(), generation);
  }

  void _listenToDiscovery(Stream<List<Match>> stream, int generation) {
    _discoverySubscription = stream.listen(
      (matches) {
        if (!mounted || generation != _discoveryGeneration) return;
        setState(() {
          _discoveryMatches
            ..clear()
            ..addAll(matches);
          _discoveryLoading = false;
          _discoveryError = false;
        });
      },
      onError: (Object _) {
        if (!mounted || generation != _discoveryGeneration) return;
        debugPrint('Discover match listener failed.');
        setState(() {
          _discoveryLoading = false;
          _discoveryError = _discoveryMatches.isEmpty;
        });
      },
    );
  }

  void _expandInitialDiscoveryIfNeeded({
    required int resultCount,
    required bool anyQueryHasMore,
  }) {
    if (!shouldExpandInitialDiscovery(
      requestedLimit: _discoveryPerCellLimit,
      filteredResultCount: resultCount,
      anyCellHasMore: anyQueryHasMore,
    )) {
      return;
    }
    _discoveryPerCellLimit = discoveryInitialCellLimit * 2;
    scheduleMicrotask(() => unawaited(_restartDiscovery()));
  }

  Stream<List<Match>> _watchDiscoveryMatches() {
    final profileLocation = widget.profile?.discoveryLocation;
    final selected = _discoveryOverride;
    final latitude = selected?.latitude ?? profileLocation?.latitude;
    final longitude = selected?.longitude ?? profileLocation?.longitude;
    if (latitude == null || longitude == null) {
      if (profileLocation == null || !profileLocation.isConfigured) {
        return Stream.value(const []);
      }
      final query = FirebaseFirestore.instance
          .collection('matches')
          .where('location.countryCode', isEqualTo: profileLocation.countryCode)
          .where('location.city', isEqualTo: profileLocation.city)
          .where(
            'scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()),
          )
          .orderBy('scheduledAt')
          .limit(_discoveryPerCellLimit + 1);
      return query.snapshots().map((snapshot) {
        final matches = sortedMatches(
          snapshot.docs.take(_discoveryPerCellLimit).map(Match.fromDocument),
        );
        _expandInitialDiscoveryIfNeeded(
          resultCount: matches.length,
          anyQueryHasMore: snapshot.docs.length > _discoveryPerCellLimit,
        );
        return matches;
      });
    }

    final cells = geohashCellsForRadius(
      latitude,
      longitude,
      _discoveryRadiusKm,
    );
    final hashField = cells.first.length == 4 ? 'geoHash4' : 'geoHash3';
    final controller = StreamController<List<Match>>();
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final results = <String, List<Match>>{};
    final hasMore = <String, bool>{};
    final ready = <String>{};
    var closed = false;

    void emit() {
      if (closed || ready.length != cells.length) return;
      final merged = mergeDiscoveryMatchGroups(results.values);
      _expandInitialDiscoveryIfNeeded(
        resultCount: merged.length,
        anyQueryHasMore: hasMore.values.any((value) => value),
      );
      controller.add(merged);
    }

    controller.onListen = () {
      for (final cell in cells) {
        final query = FirebaseFirestore.instance
            .collection('matches')
            .where(hashField, isEqualTo: cell)
            .where(
              'scheduledAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()),
            )
            .orderBy('scheduledAt')
            .limit(_discoveryPerCellLimit + 1);
        subscriptions.add(
          query.snapshots().listen((snapshot) {
            ready.add(cell);
            hasMore[cell] = snapshot.docs.length > _discoveryPerCellLimit;
            results[cell] = snapshot.docs
                .take(_discoveryPerCellLimit)
                .map(Match.fromDocument)
                .where((match) {
                  final distance = distanceBetweenKm(
                    fromLatitude: latitude,
                    fromLongitude: longitude,
                    toLatitude: match.location.latitude,
                    toLongitude: match.location.longitude,
                  );
                  return distance != null && distance <= _discoveryRadiusKm;
                })
                .toList();
            emit();
          }, onError: controller.addError),
        );
      }
    };
    controller.onCancel = () async {
      closed = true;
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
    };
    return controller.stream;
  }

  Stream<List<Match>> _watchPendingMatchDocuments(
    QuerySnapshot<Map<String, dynamic>> requestSnapshot,
  ) {
    final ids = requestSnapshot.docs
        .map(JoinRequest.fromDocument)
        .map((request) => request.matchId)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return Stream.value(const []);
    final controller = StreamController<List<Match>>();
    final subscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
    final matches = <String, Match>{};
    final ready = <String>{};
    var closed = false;

    void emit() {
      if (!closed && ready.length == ids.length) {
        controller.add(sortedMatches(matches.values));
      }
    }

    controller.onListen = () {
      for (final id in ids) {
        subscriptions.add(
          FirebaseFirestore.instance
              .collection('matches')
              .doc(id)
              .snapshots()
              .listen((document) {
                ready.add(id);
                if (document.exists) {
                  matches[id] = Match.fromDocument(document);
                } else {
                  matches.remove(id);
                }
                emit();
              }, onError: controller.addError),
        );
      }
    };
    controller.onCancel = () async {
      closed = true;
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
    };
    return controller.stream;
  }

  Future<void> _waitForIndexAndRefresh(MatchMutationResult result) async {
    await waitForMatchGeoIndex(
      result,
      loadDocument: widget.matchDocumentLoader ?? _loadMatchDocument,
      delay: widget.indexRetryDelay,
      maxAttempts: widget.indexRetryAttempts,
      isActive: () => mounted,
    );
    await _refreshDiscovery();
  }

  Future<Map<String, dynamic>?> _loadMatchDocument(String matchId) async =>
      (await FirebaseFirestore.instance
              .collection('matches')
              .doc(matchId)
              .get(const GetOptions(source: Source.server)))
          .data();

  void _changeDiscovery(MatchLocation? location, double radiusKm) {
    _discoveryOverride = location;
    _discoveryRadiusKm = radiusKm;
    _discoveryPerCellLimit = discoveryInitialCellLimit;
    _refreshDiscovery();
  }

  void _loadMoreDiscovery() {
    _discoveryPerCellLimit += discoveryInitialCellLimit;
    _refreshDiscovery();
  }

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

  Future<void> _openCreateMatchScreen() async {
    final result = await Navigator.push<MatchMutationResult>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            widget.createMatchScreenBuilder?.call() ??
            const CreateMatchScreen(),
      ),
    );
    if (result != null && mounted) await _waitForIndexAndRefresh(result);
  }

  Future<void> _markNotificationRead(AppNotification notification) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || notification.read) return;
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notification.id)
          .update(notificationReadUpdate());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.markReadFailed)));
      }
    }
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

  Future<void> _dismissPlayAgain(AppNotification notification) async {
    try {
      await FirebasePlayAgainRepository().dismiss(notification.matchId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dismissInviteFailed)),
        );
      }
    }
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
    final discoverySnapshot = AsyncSnapshot<List<Match>>.withData(
      _discoveryLoading ? ConnectionState.waiting : ConnectionState.active,
      List<Match>.unmodifiable(_discoveryMatches),
    );
    final matches = discoverySnapshot.data ?? <Match>[];
    final currentUid = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return _buildScaffold(
        discoverySnapshot,
        matches,
        const [],
        const [],
        '',
        discoveryError: _discoveryError,
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('participantUids', arrayContains: currentUid)
          .orderBy('scheduledAt', descending: true)
          .limit(_myMatchLimit)
          .snapshots(),
      builder: (context, myMatchSnapshot) {
        _reportStreamError('user matches', myMatchSnapshot);
        final myMatches = myMatchSnapshot.hasData
            ? myMatchSnapshot.data!.docs
                  .where((doc) => matchIncludesPlayer(doc.data(), currentUid))
                  .map(Match.fromDocument)
                  .toList()
            : <Match>[];
        return StreamBuilder<List<Match>>(
          stream: FirebaseFirestore.instance
              .collectionGroup('joinRequests')
              .where('userId', isEqualTo: currentUid)
              .where('status', isEqualTo: 'pending')
              .orderBy('requestedAt', descending: true)
              .limit(50)
              .snapshots()
              .asyncExpand(_watchPendingMatchDocuments),
          builder: (context, requestSnapshot) {
            _reportStreamError('current-user joinRequests', requestSnapshot);
            final pendingMatches = requestSnapshot.data ?? <Match>[];
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientUid', isEqualTo: currentUid)
                  .orderBy('createdAt', descending: true)
                  .limit(_notificationLimit)
                  .snapshots(),
              builder: (context, notificationSnapshot) {
                _reportStreamError('notifications', notificationSnapshot);
                final notifications = notificationSnapshot.hasData
                    ? notificationSnapshot.data!.docs
                          .map(AppNotification.fromDocument)
                          .toList()
                    : <AppNotification>[];
                return _buildScaffold(
                  discoverySnapshot,
                  matches,
                  myMatches,
                  pendingMatches,
                  currentUid,
                  discoveryError: _discoveryError,
                  requestsError: requestSnapshot.hasError,
                  hasMoreMyMatches:
                      myMatchSnapshot.hasData &&
                      myMatchSnapshot.data!.docs.length == _myMatchLimit,
                  notifications: notifications,
                  notificationsLoading:
                      notificationSnapshot.connectionState ==
                      ConnectionState.waiting,
                  notificationsError: notificationSnapshot.hasError,
                  hasMoreNotifications:
                      notificationSnapshot.hasData &&
                      notificationSnapshot.data!.docs.length ==
                          _notificationLimit,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    AsyncSnapshot<List<Match>> snapshot,
    List<Match> matches,
    List<Match> myMatches,
    List<Match> pendingMatches,
    String currentUid, {
    bool discoveryError = false,
    bool requestsError = false,
    bool hasMoreMyMatches = false,
    List<AppNotification> notifications = const [],
    bool notificationsLoading = false,
    bool notificationsError = false,
    bool hasMoreNotifications = false,
  }) {
    final now = DateTime.now();
    final currentEmail = Firebase.apps.isEmpty
        ? ''
        : FirebaseAuth.instance.currentUser?.email ?? '';
    final openMatches = sortedMatches(
      matches.where(
        (match) => isUpcomingMatch(match, now) && match.status != 'cancelled',
      ),
    );
    final screens = [
      HomeTab(
        onFindMatch: () => _onItemTapped(1),
        onFindMeAMatch: currentUid.isEmpty ? null : _openMatchmaking,
        onFindPlayers: () => _onItemTapped(2),
        onMessages: _openMessages,
        onCreateMatch: _openCreateMatchScreen,
        matches: openMatches,
        preferredLocation: widget.profile?.discoveryLocation,
        isLoading: snapshot.connectionState == ConnectionState.waiting,
        error: discoveryError,
        playedWithPreview: currentUid.isEmpty
            ? null
            : PlayedWithPreview(
                viewerUid: currentUid,
                repository: _playedWithRepository,
                onProfileTap: _openPlayedWithProfile,
                onViewAll: _openPlayedWithList,
                onPlayAgain: _openPlayAgain,
              ),
      ),
      MatchesDestination(
        discover: MatchesTab(
          matches: openMatches,
          currentUid: currentUid,
          currentEmail: currentEmail,
          pendingMatchIds: pendingMatches.map((match) => match.id).toSet(),
          preferredLocation: widget.profile?.discoveryLocation,
          onCreateMatch: _openCreateMatchScreen,
          onDiscoveryQueryChanged: _changeDiscovery,
          onLoadMoreNearby: _loadMoreDiscovery,
          isLoading: snapshot.connectionState == ConnectionState.waiting,
          error: discoveryError,
        ),
        mine: MyMatchesTab(
          matches: myMatches,
          pendingMatches: pendingMatches,
          currentUid: currentUid,
          currentEmail: currentEmail,
          onFindMatch: () => _onItemTapped(1),
          onCreateMatch: _openCreateMatchScreen,
          isLoading: snapshot.connectionState == ConnectionState.waiting,
          error: discoveryError || requestsError,
          hasMore: hasMoreMyMatches,
          onLoadMore: () => setState(() => _myMatchLimit += 100),
        ),
      ),
      currentUid.isEmpty
          ? Center(child: Text(context.l10n.signInDiscoverPlayers))
          : PlayersScreen(
              repository: FirebasePlayerDiscoveryRepository(),
              friendsRepository: _friendsRepository,
              discoveryLocation:
                  widget.profile?.discoveryLocation ??
                  const DiscoveryLocation(
                    country: '',
                    countryCode: '',
                    city: '',
                  ),
              onEditProfileLocation: FirebaseAuth.instance.currentUser == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileEditorScreen(
                          user: FirebaseAuth.instance.currentUser!,
                          profile: widget.profile,
                        ),
                      ),
                    ),
              onProfileTap: (context, player) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerProfileScreen(
                    uid: player.uid,
                    fallbackName: player.displayName,
                    fallbackLevel: player.level,
                    viewerUid: currentUid,
                    playedWithRepository: _playedWithRepository,
                    friendsRepository: _friendsRepository,
                    onPlayAgain: _openPlayAgain,
                  ),
                ),
              ),
              onPlayAgain: (player) => _openPlayAgain(
                PlayAgainTarget(
                  uid: player.uid,
                  displayName: player.displayName,
                ),
              ),
            ),
      NotificationsTab(
        notifications: notifications,
        isLoading: notificationsLoading,
        error: notificationsError,
        onMarkRead: _markNotificationRead,
        onMarkAllRead: () => _markAllNotificationsRead(notifications),
        onRetry: () => setState(() {}),
        hasMore: hasMoreNotifications,
        onLoadMore: () => setState(() => _notificationLimit += 50),
        joinRequestStream: _joinRequestForNotification,
        onDismiss: _dismissPlayAgain,
        onOpen: (notification) async {
          unawaited(_markNotificationRead(notification));
          if (notification.type == AppNotificationType.unknown) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.notificationUnavailable)),
            );
            return;
          }
          if (notification.type == AppNotificationType.friendRequest ||
              notification.type == AppNotificationType.friendAccepted) {
            _openFriends();
            return;
          }
          if (notification.type ==
                  AppNotificationType.matchmakingPartnerInvite ||
              notification.type == AppNotificationType.matchmakingMatchFound ||
              notification.type ==
                  AppNotificationType.matchmakingReplacementFound) {
            _openMatchmaking();
            return;
          }
          if ((notification.type == AppNotificationType.directMessage ||
                  notification.type == AppNotificationType.matchMessage) &&
              notification.conversationId.isNotEmpty) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConversationScreen(
                  conversationId: notification.conversationId,
                  currentUid: currentUid,
                  title: notification.type == AppNotificationType.matchMessage
                      ? context.l10n.matchChat
                      : context.l10n.messages,
                  repository: _messagingRepository,
                  conversationType:
                      notification.type == AppNotificationType.matchMessage
                      ? 'match'
                      : 'direct',
                ),
              ),
            );
            return;
          }
          var match = matchForNotification(notification, matches);
          if (match == null && notification.matchId.isNotEmpty) {
            final document = await FirebaseFirestore.instance
                .collection('matches')
                .doc(notification.matchId)
                .get();
            if (document.exists) match = Match.fromDocument(document);
          }
          if (!mounted) return;
          final resolvedMatch = match;
          if (resolvedMatch != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MatchDetailsScreen(
                  match: resolvedMatch,
                  onMatchUpdated: _waitForIndexAndRefresh,
                  onMatchDeleted: _handleMatchDeleted,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.thisMatchUnavailable)),
            );
          }
        },
      ),
      ProfileTab(
        profile: widget.profile,
        uid: currentUid,
        email: currentEmail,
        onFriends: _openFriends,
        onMessages: _openMessages,
        onSettings: widget.onDeleteAccount == null ? null : _openSettings,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PadelX',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: PadelXColors.background,
        elevation: 0,
        actions: [
          if (_selectedIndex == 1)
            IconButton(
              tooltip: context.l10n.refreshMatches,
              onPressed: _refreshDiscovery,
              color: PadelXColors.textSecondary,
              icon: const Icon(Icons.refresh, size: 20),
            ),
        ],
      ),
      body: screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _openCreateMatchScreen,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.create),
            )
          : null,
      bottomNavigationBar: PadelXBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        notificationCount: unreadNotificationCount(notifications),
      ),
    );
  }
}

class PadelXBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int notificationCount;

  const PadelXBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget destination({
      required int index,
      required Widget icon,
      Widget? selectedIcon,
      required String label,
    }) => _PadelXNavigationDestination(
      icon: icon,
      selectedIcon: selectedIcon,
      label: label,
      selected: selectedIndex == index,
      onTap: () => onDestinationSelected(index),
    );

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: PadelXColors.surface,
      destinations: [
        destination(
          index: 0,
          icon: const Icon(Icons.home),
          label: context.l10n.home,
        ),
        destination(
          index: 1,
          icon: const Icon(Icons.sports_tennis),
          label: context.l10n.matches,
        ),
        destination(
          index: 2,
          icon: const Icon(Icons.group_outlined),
          label: context.l10n.players,
        ),
        destination(
          index: 3,
          icon: NotificationBadge(count: notificationCount),
          selectedIcon: NotificationBadge(
            count: notificationCount,
            selected: true,
          ),
          label: context.l10n.notifications,
        ),
        destination(
          index: 4,
          icon: const Icon(Icons.person),
          label: context.l10n.profile,
        ),
      ],
    );
  }
}

class _PadelXNavigationDestination extends StatelessWidget {
  final Widget icon;
  final Widget? selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PadelXNavigationDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? PadelXColors.accent : colors.onSurfaceVariant;
    return Semantics(
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF204B36) : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconTheme(
                  data: IconThemeData(size: 24, color: foreground),
                  child: Center(child: selected ? selectedIcon ?? icon : icon),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: double.infinity,
                  height: 14,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: selected
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                              fontSize: 10,
                              height: 1.1,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  final VoidCallback onFindMatch;
  final VoidCallback? onFindMeAMatch;
  final VoidCallback? onFindPlayers;
  final VoidCallback? onMessages;
  final VoidCallback onCreateMatch;
  final List<Match> matches;
  final DiscoveryLocation? preferredLocation;
  final bool isLoading;
  final bool error;
  final Widget? playedWithPreview;

  const HomeTab({
    super.key,
    required this.onFindMatch,
    this.onFindMeAMatch,
    this.onFindPlayers,
    this.onMessages,
    required this.onCreateMatch,
    this.matches = const [],
    this.preferredLocation,
    this.isLoading = false,
    this.error = false,
    this.playedWithPreview,
  });

  String get _locationLabel {
    final location = preferredLocation;
    if (location == null || !location.isConfigured) return '';
    return <String>[
      if (location.area.trim().isNotEmpty) location.area.trim(),
      location.city.trim(),
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    // The parent supplies the same geographically discovered open matches to
    // Home and Matches. Place-name equality must not override that result.
    final relevantMatches = matches.take(3).toList();
    return ListView(
      key: const Key('home-scroll-view'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          key: const Key('home-hero'),
          padding: const EdgeInsets.all(PadelXSpace.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF173A2B), Color(0xFF0E231B)],
            ),
            borderRadius: BorderRadius.circular(PadelXRadii.feature),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0x2672F58B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt, color: PadelXColors.accent),
                  ),
                  const SizedBox(width: PadelXSpace.md),
                  Expanded(
                    child: Text(
                      context.l10n.findMeAMatch,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.quickMatchHomeDescription,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: PadelXColors.textSecondary,
                ),
              ),
              if (_locationLabel.isNotEmpty) ...[
                const SizedBox(height: PadelXSpace.md),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 19,
                      color: PadelXColors.accent,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _locationLabel,
                        style: const TextStyle(
                          color: PadelXColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: PadelXSpace.md),
              if (onFindMeAMatch != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('home-find-me-a-match'),
                    onPressed: onFindMeAMatch,
                    icon: const Icon(Icons.bolt),
                    label: Text(context.l10n.startQuickMatch),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: PadelXSpace.md),
        _HomeModeCard(
          key: const Key('home-find-match'),
          icon: Icons.search,
          title: context.l10n.findMatch,
          description: context.l10n.findMatchesHomeDescription,
          onTap: onFindMatch,
        ),
        const SizedBox(height: PadelXSpace.sm),
        _HomeModeCard(
          key: const Key('home-create-match'),
          icon: Icons.add_circle_outline,
          title: context.l10n.createAMatch,
          description: context.l10n.createMatchHomeDescription,
          onTap: onCreateMatch,
          quiet: true,
        ),
        const SizedBox(height: PadelXSpace.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('home-find-players'),
                onPressed: onFindPlayers,
                icon: const Icon(Icons.group_outlined),
                label: Text(context.l10n.findPlayers),
                style: FilledButton.styleFrom(
                  backgroundColor: PadelXColors.surfaceRaised,
                  foregroundColor: PadelXColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('home-messages'),
                onPressed: onMessages,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(context.l10n.messages),
                style: FilledButton.styleFrom(
                  backgroundColor: PadelXColors.surfaceRaised,
                  foregroundColor: PadelXColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PadelXSpace.xl),
        PadelXSectionHeader(
          title: context.l10n.upcomingMatches,
          actionLabel: context.l10n.seeAll,
          onAction: onFindMatch,
        ),
        const SizedBox(height: 14),
        if (isLoading)
          _HomeStatusCard(
            key: const Key('home-loading-state'),
            icon: Icons.sports_tennis,
            title: context.l10n.findingMatches,
            showProgress: true,
          )
        else if (error)
          _HomeStatusCard(
            key: const Key('home-error-state'),
            icon: Icons.cloud_off_outlined,
            title: context.l10n.matchesUnavailable,
            message: context.l10n.connectionRetry,
            actionLabel: context.l10n.browseMatches,
            onAction: onFindMatch,
          )
        else if (relevantMatches.isEmpty)
          _HomeStatusCard(
            key: const Key('home-empty-state'),
            icon: Icons.event_available_outlined,
            title: context.l10n.noMatchesNearby,
            message: context.l10n.createMatchGetStarted,
            actionLabel: context.l10n.createAMatch,
            onAction: onCreateMatch,
          )
        else
          ...relevantMatches.map((match) {
            final location = preferredLocation;
            final distance = location == null
                ? null
                : distanceBetweenKm(
                    fromLatitude: location.latitude,
                    fromLongitude: location.longitude,
                    toLatitude: match.location.latitude,
                    toLongitude: match.location.longitude,
                  );
            return MatchCard(
              match: match,
              distanceKm: distance,
              showSchedule: false,
              explicitLevelLabel: true,
            );
          }),
        if (playedWithPreview != null) ...[
          const SizedBox(height: 24),
          playedWithPreview!,
        ],
      ],
    );
  }
}

class _HomeStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showProgress;

  const _HomeStatusCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: Column(
          children: [
            if (showProgress)
              const SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              Icon(icon, size: 40, color: const Color(0xFF53D68A)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool quiet;

  const _HomeModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: quiet ? PadelXColors.surface : PadelXColors.surfaceStrong,
    borderRadius: BorderRadius.circular(PadelXRadii.card),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PadelXRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(PadelXSpace.lg),
        child: Row(
          children: [
            Icon(
              icon,
              color: quiet ? PadelXColors.textSecondary : PadelXColors.accent,
            ),
            const SizedBox(width: PadelXSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: PadelXSpace.xs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: PadelXColors.textSecondary),
          ],
        ),
      ),
    ),
  );
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
          (level == null || normalizePadelLevel(match.level) == level) &&
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
  final void Function(MatchLocation? location, double radiusKm)?
  onDiscoveryQueryChanged;
  final VoidCallback? onLoadMoreNearby;

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
    this.onDiscoveryQueryChanged,
    this.onLoadMoreNearby,
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
      widget.onDiscoveryQueryChanged?.call(_discoveryCenter, _radiusKm);
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
      return _MatchesStatusState(
        key: const Key('matches-loading-state'),
        icon: Icons.sports_tennis,
        title: context.l10n.findingOpenMatches,
        showProgress: true,
      );
    }

    if (widget.error) {
      return _MatchesStatusState(
        key: const Key('matches-error-state'),
        icon: Icons.cloud_off_outlined,
        title: context.l10n.matchesUnavailable,
        message: context.l10n.connectionRetry,
      );
    }

    final availableLevels = widget.matches
        .map((match) => normalizePadelLevel(match.level))
        .whereType<String>()
        .toSet();
    final levels = padelLevelValues
        .where(availableLevels.contains)
        .toList(growable: false);
    final center = _discoveryCenter;
    final matchesNearLocation = center == null
        ? widget.matches
        : filterNearbyMatches(
            widget.matches,
            centerLatitude: center.latitude!,
            centerLongitude: center.longitude!,
            radiusKm: _radiusKm,
          );
    final filteredMatches = _filteredMatches;
    return ListView(
      key: const Key('matches-scroll-view'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
      children: [
        Text(
          context.l10n.openMatches,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.joinGames,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        Container(
          key: const Key('matches-location-controls'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF151E1A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.findMatchesNear,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              PlacesAutocompleteField(
                key: ValueKey(
                  _usingCurrentLocation
                      ? 'current-location'
                      : (_discoveryCenter?.placeId ?? 'discovery-location'),
                ),
                labelText: context.l10n.cityOrArea,
                hintText: context.l10n.searchCityArea,
                initialText: _usingCurrentLocation
                    ? context.l10n.currentLocation
                    : (_discoveryCenter?.localityLabel ?? ''),
                onSelected: (location) {
                  if (!hasUsableCoordinates(
                    location.latitude,
                    location.longitude,
                  )) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.locationNoCoordinates),
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
                  widget.onDiscoveryQueryChanged?.call(
                    _discoveryCenter,
                    _radiusKm,
                  );
                },
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                key: const Key('use-current-location'),
                onPressed: _findingCurrentLocation ? null : _useCurrentLocation,
                icon: _findingCurrentLocation
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 19),
                label: Text(
                  _findingCurrentLocation
                      ? context.l10n.findingYourLocation
                      : context.l10n.useCurrentLocation,
                ),
              ),
            ],
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
                      ? context.l10n.currentLocationRadius(_radiusKm.round())
                      : context.l10n.searchRadius(_radiusKm.round()),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _discoveryCenter = null;
                  _usingCurrentLocation = false;
                  _currentLocationError = null;
                  widget.onDiscoveryQueryChanged?.call(null, _radiusKm);
                }),
                child: Text(context.l10n.clearLocation),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [25.0, 50.0, 100.0]
                .map(
                  (radius) => ChoiceChip(
                    label: Text(
                      context.l10n.radiusKm(radius.round().toString()),
                    ),
                    selected: _radiusKm == radius,
                    onSelected: (_) {
                      setState(() => _radiusKm = radius);
                      widget.onDiscoveryQueryChanged?.call(
                        _discoveryCenter,
                        radius,
                      );
                    },
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          context.l10n.filterMatches,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('match-search-field'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: context.l10n.searchClubLocation,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: MatchDateFilter.values.map((filter) {
            final label = switch (filter) {
              MatchDateFilter.all => context.l10n.all,
              MatchDateFilter.today => context.l10n.today,
              MatchDateFilter.tomorrow => context.l10n.tomorrow,
              MatchDateFilter.thisWeek => context.l10n.thisWeek,
            };
            return ChoiceChip(
              label: Text(label),
              selected: _dateFilter == filter,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _dateFilter = filter),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 360;
            final level = KeyedSubtree(
              key: const Key('level-filter'),
              child: DropdownButtonFormField<String>(
                key: _levelFieldKey,
                initialValue: _levelFilter,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.playerLevel,
                  prefixIcon: const Icon(Icons.leaderboard),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: levels
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text(
                          context.l10n.levelValue(level),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (level) => setState(() => _levelFilter = level),
              ),
            );
            final spots = FilterChip(
              key: const Key('available-spots-filter'),
              avatar: const Icon(Icons.group, size: 18),
              label: Text(context.l10n.spots),
              selected: _availableOnly,
              onSelected: (selected) =>
                  setState(() => _availableOnly = selected),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  level,
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft, child: spots),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: level),
                const SizedBox(width: 8),
                spots,
              ],
            );
          },
        ),
        if (_hasFilters)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('clear-match-filters'),
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: Text(context.l10n.clearFilters),
            ),
          )
        else
          const SizedBox(height: 16),
        if (filteredMatches.isEmpty)
          Padding(
            key: const Key('matches-empty-state'),
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                const Icon(Icons.search_off, size: 44, color: Colors.white54),
                const SizedBox(height: 12),
                Text(
                  widget.matches.isEmpty
                      ? context.l10n.noOpenMatches
                      : (_hasFilters
                            ? context.l10n.noMatchesFilters
                            : _discoveryCenter != null &&
                                  matchesNearLocation.isEmpty
                            ? context.l10n.noMatchesRadius(_radiusKm.round())
                            : context.l10n.noOpenMatches),
                ),
                if (widget.matches.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.beFirstMatch,
                    style: TextStyle(color: Colors.white70),
                  ),
                ] else if (_hasFilters) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all),
                    label: Text(context.l10n.clearFilters),
                  ),
                ] else if (_discoveryCenter != null &&
                    matchesNearLocation.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.widerRadius,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _radiusKm = 100),
                    child: Text(context.l10n.expand100),
                  ),
                ],
                if (widget.matches.isEmpty && widget.onCreateMatch != null)
                  FilledButton.icon(
                    onPressed: widget.onCreateMatch,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.createMatch),
                  ),
              ],
            ),
          )
        else
          ...filteredMatches.map((match) {
            final state =
                _isMatchOrganizer(match, widget.currentUid, widget.currentEmail)
                ? context.l10n.organizer
                : match.players.any((player) => player.uid == widget.currentUid)
                ? context.l10n.joined
                : widget.pendingMatchIds.contains(match.id)
                ? context.l10n.pending
                : match.spotsLeft <= 0
                ? context.l10n.full
                : context.l10n.open;
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
              dateTimeHeadline: true,
              explicitLevelLabel: true,
            );
          }),
        if (widget.matches.isNotEmpty && widget.onLoadMoreNearby != null) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              key: const Key('load-more-nearby-matches'),
              onPressed: widget.onLoadMoreNearby,
              child: Text(context.l10n.loadMoreNearby),
            ),
          ),
        ],
      ],
    );
  }
}

class MatchCard extends StatelessWidget {
  final Match match;
  final String? relationshipLabel;
  final double? distanceKm;
  final bool historical;
  final bool showSchedule;
  final bool explicitLevelLabel;
  final bool dateTimeHeadline;

  const MatchCard({
    super.key,
    required this.match,
    this.relationshipLabel,
    this.distanceKm,
    this.historical = false,
    this.showSchedule = true,
    this.explicitLevelLabel = false,
    this.dateTimeHeadline = false,
  });

  String get _levelLabel {
    final level = match.level.trim();
    if (!explicitLevelLabel || level.isEmpty) return level;
    return level.toLowerCase().startsWith('level ') ? level : 'Level $level';
  }

  @override
  Widget build(BuildContext context) {
    final headline =
        (dateTimeHeadline || _isRawCanonicalDateTitle(match.title)) &&
            match.scheduledAt != null
        ? _localizedFriendlyDateTime(context, match.scheduledAt!)
        : match.title;
    return Card(
      margin: const EdgeInsets.only(bottom: PadelXSpace.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(PadelXRadii.card),
        onTap: () {
          final refresh = context
              .findAncestorStateOfType<_HomeScreenState>()
              ?._waitForIndexAndRefresh;
          final removeDeleted = context
              .findAncestorStateOfType<_HomeScreenState>()
              ?._handleMatchDeleted;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchDetailsScreen(
                match: match,
                onMatchUpdated: refresh,
                onMatchDeleted: removeDeleted,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(PadelXSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (historical) ...[
                Chip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text(context.l10n.completed),
                  backgroundColor: Color(0xFF3A403D),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: PadelXColors.surfaceRaised,
                    foregroundColor: PadelXColors.accent,
                    child: Icon(Icons.sports_tennis),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (relationshipLabel != null) ...[
                          const SizedBox(height: 6),
                          _MatchStatusLabel(label: relationshipLabel!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 14),
              Text(match.club, style: Theme.of(context).textTheme.bodyLarge),
              if (match.locationLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  match.locationLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_levelLabel.isNotEmpty)
                    _InfoChip(text: _levelLabel, icon: Icons.leaderboard),
                  if (showSchedule &&
                      !dateTimeHeadline &&
                      match.scheduledAt != null)
                    _InfoChip(
                      text: _localizedFriendlyDateTime(
                        context,
                        match.scheduledAt!,
                      ),
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

class _MatchStatusLabel extends StatelessWidget {
  final String label;

  const _MatchStatusLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final icon = normalized.contains('organiz')
        ? Icons.star_outline
        : normalized.contains('pending')
        ? Icons.schedule_outlined
        : normalized == 'open'
        ? Icons.lock_open_outlined
        : normalized == 'full'
        ? Icons.group_outlined
        : Icons.check_circle_outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: PadelXColors.surfaceRaised,
        borderRadius: BorderRadius.circular(PadelXRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PadelXColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: PadelXColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchesStatusState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool showProgress;

  const _MatchesStatusState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.white54),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (showProgress) ...[
              const SizedBox(height: 18),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum MatchesDestinationView { discover, mine }

class MatchesDestination extends StatefulWidget {
  final Widget discover;
  final Widget mine;
  const MatchesDestination({
    super.key,
    required this.discover,
    required this.mine,
  });
  @override
  State<MatchesDestination> createState() => _MatchesDestinationState();
}

class _MatchesDestinationState extends State<MatchesDestination> {
  MatchesDestinationView selected = MatchesDestinationView.discover;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<MatchesDestinationView>(
            key: const Key('matches-destination-control'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: MatchesDestinationView.discover,
                label: Text(context.l10n.discover),
              ),
              ButtonSegment(
                value: MatchesDestinationView.mine,
                label: Text(context.l10n.myMatches),
              ),
            ],
            selected: {selected},
            onSelectionChanged: (value) =>
                setState(() => selected = value.single),
          ),
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: selected.index,
          children: [widget.discover, widget.mine],
        ),
      ),
    ],
  );
}

enum MyMatchesView { upcoming, past }

class MyMatchesTab extends StatefulWidget {
  final List<Match> matches;
  final List<Match> pendingMatches;
  final String currentUid;
  final String currentEmail;
  final VoidCallback? onFindMatch;
  final VoidCallback? onCreateMatch;
  final bool isLoading;
  final bool error;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final DateTime Function() nowProvider;

  const MyMatchesTab({
    super.key,
    required this.matches,
    this.pendingMatches = const [],
    required this.currentUid,
    this.currentEmail = '',
    this.onFindMatch,
    this.onCreateMatch,
    required this.isLoading,
    required this.error,
    this.hasMore = false,
    this.onLoadMore,
    DateTime Function()? nowProvider,
  }) : nowProvider = nowProvider ?? DateTime.now;

  @override
  State<MyMatchesTab> createState() => _MyMatchesTabState();
}

class _MyMatchesTabState extends State<MyMatchesTab> {
  MyMatchesView _selectedView = MyMatchesView.upcoming;

  @override
  Widget build(BuildContext context) {
    final now = widget.nowProvider();
    final upcomingMatches = sortedMatches(
      widget.matches.where((match) => isUpcomingMatch(match, now)),
    );
    final pastMatches = sortedMatches(
      widget.matches.where((match) => isPastMatch(match, now)),
    ).reversed.toList();

    return ListView(
      key: const Key('my-matches-scroll-view'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
      children: [
        Text(
          context.l10n.myMatches,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.organizedJoinedMatches,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<MyMatchesView>(
            key: const Key('my-matches-view-control'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: MyMatchesView.upcoming,
                label: Text(context.l10n.upcoming),
                icon: const Icon(Icons.upcoming_outlined, size: 18),
              ),
              ButtonSegment(
                value: MyMatchesView.past,
                label: Text(context.l10n.past),
                icon: const Icon(Icons.history, size: 18),
              ),
            ],
            selected: {_selectedView},
            onSelectionChanged: (selection) {
              setState(() => _selectedView = selection.single);
            },
          ),
        ),
        const SizedBox(height: 18),
        if (widget.isLoading)
          _MatchesStatusState(
            key: const Key('my-matches-loading-state'),
            icon: Icons.event_available_outlined,
            title: context.l10n.loadingYourMatches,
            showProgress: true,
          )
        else if (widget.error)
          _MatchesStatusState(
            key: const Key('my-matches-error-state'),
            icon: Icons.cloud_off_outlined,
            title: context.l10n.yourMatchesUnavailable,
            message: context.l10n.connectionRetry,
          )
        else if (_selectedView == MyMatchesView.upcoming) ...[
          if (widget.pendingMatches.isNotEmpty) ...[
            Text(
              context.l10n.pendingRequests,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...sortedMatches(widget.pendingMatches).map(
              (match) => MatchCard(
                match: match,
                relationshipLabel: context.l10n.requestPending,
                dateTimeHeadline: true,
                explicitLevelLabel: true,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (upcomingMatches.isEmpty && widget.pendingMatches.isEmpty)
            _MyMatchesEmptyState(
              key: const Key('no-upcoming-matches'),
              icon: Icons.calendar_today_outlined,
              title: context.l10n.noUpcomingMatches,
              message: context.l10n.findOpenOrOrganize,
              onFindMatch: widget.onFindMatch,
              onCreateMatch: widget.onCreateMatch,
            )
          else
            ...upcomingMatches.map(
              (match) => MatchCard(
                match: match,
                relationshipLabel:
                    _isMatchOrganizer(
                      match,
                      widget.currentUid,
                      widget.currentEmail,
                    )
                    ? context.l10n.organizing
                    : context.l10n.joined,
                dateTimeHeadline: true,
                explicitLevelLabel: true,
              ),
            ),
        ] else if (pastMatches.isEmpty)
          _MyMatchesEmptyState(
            key: const Key('no-past-matches'),
            icon: Icons.history,
            title: context.l10n.noPastMatches,
            message: context.l10n.completedAppearHere,
          )
        else
          ...pastMatches.map(
            (match) => MatchCard(
              match: match,
              historical: true,
              relationshipLabel:
                  _isMatchOrganizer(
                    match,
                    widget.currentUid,
                    widget.currentEmail,
                  )
                  ? context.l10n.organizing
                  : context.l10n.joined,
              dateTimeHeadline: true,
              explicitLevelLabel: true,
            ),
          ),
        if (widget.hasMore) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              key: const Key('load-older-matches'),
              onPressed: widget.onLoadMore,
              child: Text(context.l10n.loadOlderMatches),
            ),
          ),
        ],
      ],
    );
  }
}

class _MyMatchesEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onFindMatch;
  final VoidCallback? onCreateMatch;

  const _MyMatchesEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onFindMatch,
    this.onCreateMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.white54),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          if (onFindMatch != null || onCreateMatch != null) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onFindMatch != null)
                  FilledButton.icon(
                    key: const Key('find-match-empty-action'),
                    onPressed: onFindMatch,
                    icon: const Icon(Icons.search),
                    label: Text(context.l10n.findMatch),
                  ),
                if (onCreateMatch != null)
                  OutlinedButton.icon(
                    key: const Key('create-match-empty-action'),
                    onPressed: onCreateMatch,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.createMatch),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String profileLevelLabel(String level) {
  return padelLevelLabel(level);
}

bool isValidProfileLevel(String value) => isValidPadelLevel(value);

class ProfileTab extends StatefulWidget {
  final UserProfile? profile;
  final String uid;
  final String email;
  final PublicPlayerProfileLoader loader;
  final VoidCallback? onEdit;
  final VoidCallback? onFriends;
  final VoidCallback? onMessages;
  final VoidCallback? onSettings;

  const ProfileTab({
    super.key,
    this.profile,
    this.uid = '',
    this.email = '',
    this.loader = loadPublicPlayerProfile,
    this.onEdit,
    this.onFriends,
    this.onMessages,
    this.onSettings,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<PublicPlayerProfile> _stats;

  String get _uid => widget.uid.isNotEmpty
      ? widget.uid
      : Firebase.apps.isEmpty
      ? ''
      : FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _stats = widget.loader(_uid);
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid || oldWidget.loader != widget.loader) {
      _stats = widget.loader(_uid);
    }
  }

  void _retry() => setState(() => _stats = widget.loader(_uid));

  @override
  Widget build(BuildContext context) {
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    final profile = widget.profile;

    void edit() {
      if (widget.onEdit != null) return widget.onEdit!();
      if (user == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileEditorScreen(user: user, profile: profile),
        ),
      );
    }

    if (profile == null || !profile.isComplete) {
      return _ProfileMessageState(
        icon: Icons.person_off_outlined,
        title: context.l10n.profileNeedsInfo,
        message: context.l10n.addNameLevel,
        actionLabel: widget.onEdit != null || user != null
            ? context.l10n.completeProfile
            : null,
        onAction: widget.onEdit != null || user != null ? edit : null,
      );
    }

    final email = widget.email.isNotEmpty
        ? widget.email
        : profile.email.isNotEmpty
        ? profile.email
        : user?.email ?? '';
    return FutureBuilder<PublicPlayerProfile>(
      future: _stats,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _ProfileOverview(
            profile: profile,
            email: email,
            onEdit: edit,
            onFriends: widget.onFriends,
            onMessages: widget.onMessages,
            onSettings: widget.onSettings,
            loadingStats: true,
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ProfileMessageState(
            icon: Icons.cloud_off_outlined,
            title: context.l10n.profileStatsFailed,
            message: context.l10n.profileDetailsSafe,
            actionLabel: context.l10n.tryAgain,
            onAction: _retry,
          );
        }
        return _ProfileOverview(
          profile: profile,
          email: email,
          stats: snapshot.data,
          onEdit: edit,
          onFriends: widget.onFriends,
          onMessages: widget.onMessages,
          onSettings: widget.onSettings,
        );
      },
    );
  }
}

class _ProfileOverview extends StatelessWidget {
  final UserProfile profile;
  final String email;
  final PublicPlayerProfile? stats;
  final bool loadingStats;
  final VoidCallback? onEdit;
  final VoidCallback? onFriends;
  final VoidCallback? onMessages;
  final VoidCallback? onSettings;

  const _ProfileOverview({
    required this.profile,
    required this.email,
    this.stats,
    this.loadingStats = false,
    this.onEdit,
    this.onFriends,
    this.onMessages,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final summary = stats?.ratingSummary;
    final ratingText = loadingStats
        ? '—'
        : summary == null || summary.count == 0
        ? context.l10n.notRated
        : '${summary.average.toStringAsFixed(1)} ★';
    final countText = loadingStats ? '—' : '${summary?.count ?? 0}';
    final matchesText = loadingStats ? '—' : '${stats?.matches.length ?? 0}';
    return ListView(
      key: const Key('private-profile-overview'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileAvatar(
                      uid: profile.uid,
                      displayName: profile.displayName,
                      avatarVersion: profile.avatarVersion,
                      radius: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            key: const Key('private-profile-name'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              email,
                              key: const Key('private-profile-email'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  key: const Key('private-profile-level'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    profileLevelLabel(profile.level),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Row(
              children: [
                _ProfileStat(label: context.l10n.rating, value: ratingText),
                const _ProfileStatDivider(),
                _ProfileStat(label: context.l10n.ratings, value: countText),
                const _ProfileStatDivider(),
                _ProfileStat(label: context.l10n.matches, value: matchesText),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        context.l10n.preferredSideDisplay(
                          _localizedPreferredSide(
                            context,
                            profile.socialProfile.preferredSide,
                          ),
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        _localizedPlayFrequency(
                          context,
                          profile.socialProfile.playFrequency,
                        ),
                      ),
                    ),
                    Chip(
                      key: const Key('private-profile-reliability'),
                      label: Text(
                        stats?.reliabilityStatus == 'established' &&
                                stats?.reliabilityPercent != null
                            ? context.l10n.reliabilityPercent(
                                stats!.reliabilityPercent!,
                              )
                            : context.l10n.reliabilityNewPlayer,
                      ),
                    ),
                  ],
                ),
                if (profile.socialProfile.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(profile.socialProfile.bio),
                ],
                const SizedBox(height: 8),
                Text(
                  profile.socialProfile.discoverable
                      ? context.l10n.visibleDiscovery
                      : context.l10n.hiddenDiscovery,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        if (profile.discoveryLocation.isConfigured) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: Colors.greenAccent,
              ),
              title: Text(context.l10n.matchDiscovery),
              subtitle: Text(
                '${profile.discoveryLocation.city}, ${profile.discoveryLocation.country}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (onFriends != null) ...[
          OutlinedButton.icon(
            key: const Key('open-friends'),
            onPressed: onFriends,
            icon: const Icon(Icons.people_outline),
            label: Text(context.l10n.friends),
          ),
          const SizedBox(height: 8),
        ],
        if (onMessages != null) ...[
          OutlinedButton.icon(
            key: const Key('open-messages'),
            onPressed: onMessages,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(context.l10n.messages),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          key: const Key('edit-profile-action'),
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: Text(context.l10n.editProfile),
        ),
        if (onSettings != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('open-settings'),
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
            label: Text(context.l10n.settings),
          ),
        ],
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        ),
      ],
    ),
  );
}

class _ProfileStatDivider extends StatelessWidget {
  const _ProfileStatDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: Colors.white12);
}

class _ProfileMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _ProfileMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Colors.white54),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

@visibleForTesting
Future<void> saveProfileWithLegacyLocationFallback({
  required bool hasCanonicalLocation,
  required Future<void> Function(bool includeCanonicalLocation) write,
}) async {
  try {
    await write(true);
  } on FirebaseException catch (error) {
    if (!hasCanonicalLocation || error.code != 'permission-denied') rethrow;
    debugPrint(
      'Profile save canonical location fields were rejected; '
      'retrying with the legacy location shape.',
    );
    await write(false);
  }
}

class ProfileEditorScreen extends StatefulWidget {
  final User? user;
  final UserProfile? profile;
  final bool isRequired;
  final String _testUid;
  final String _testEmail;
  final String _testDisplayName;
  final VoidCallback? onSignOut;
  final GooglePlacesClient? placesClient;
  final Future<void> Function(UserProfile profile)? saveOverride;
  final ValueChanged<UserProfile>? onRequiredSaved;

  const ProfileEditorScreen({
    super.key,
    required this.user,
    this.profile,
    this.isRequired = false,
    this.onSignOut,
    this.placesClient,
    this.saveOverride,
    this.onRequiredSaved,
  }) : _testUid = '',
       _testEmail = '',
       _testDisplayName = '';

  @visibleForTesting
  const ProfileEditorScreen.test({
    super.key,
    required String uid,
    String email = '',
    String displayName = '',
    this.profile,
    this.isRequired = false,
    this.onSignOut,
    this.placesClient,
    this.saveOverride,
    this.onRequiredSaved,
  }) : user = null,
       _testUid = uid,
       _testEmail = email,
       _testDisplayName = displayName;

  String get uid => user?.uid ?? _testUid;
  String get email => user?.email ?? _testEmail;
  String get displayName => user?.displayName ?? _testDisplayName;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _discoveryCountryController;
  late final TextEditingController _discoveryCountryCodeController;
  late final TextEditingController _discoveryCityController;
  late final TextEditingController _discoveryAreaController;
  late String _discoveryCityId;
  late String _discoveryAreaId;
  late final TextEditingController _bioController;
  late PreferredSide _preferredSide;
  late PlayFrequency _playFrequency;
  late bool _discoverable;
  late int _avatarVersion;
  double? _discoveryLatitude;
  double? _discoveryLongitude;
  bool _isSaving = false;
  String? _level;
  String? _legacyLevel;
  String? _levelError;

  bool get _placesConfigured =>
      widget.placesClient?.isConfigured ?? googlePlacesApiKey.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile?.displayName ?? widget.displayName,
    );
    final initialLevel = widget.profile?.level;
    _level = normalizePadelLevel(initialLevel);
    _legacyLevel = _level == null && (initialLevel?.trim().isNotEmpty ?? false)
        ? initialLevel!.trim()
        : null;
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
    _discoveryCityId = widget.profile?.discoveryLocation.cityId ?? '';
    _discoveryAreaId = widget.profile?.discoveryLocation.areaId ?? '';
    _bioController = TextEditingController(
      text: widget.profile?.socialProfile.bio ?? '',
    );
    _preferredSide =
        widget.profile?.socialProfile.preferredSide ?? PreferredSide.either;
    _playFrequency =
        widget.profile?.socialProfile.playFrequency ?? PlayFrequency.occasional;
    // Only a genuinely absent profile is new. Existing and legacy profiles
    // preserve their parsed value (including the privacy-safe missing=false).
    _discoverable = widget.profile?.socialProfile.discoverable ?? true;
    _avatarVersion = widget.profile?.avatarVersion ?? 0;
    _discoveryLatitude = widget.profile?.discoveryLocation.latitude;
    _discoveryLongitude = widget.profile?.discoveryLocation.longitude;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _discoveryCountryController.dispose();
    _discoveryCountryCodeController.dispose();
    _discoveryCityController.dispose();
    _discoveryAreaController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final displayName = _displayNameController.text.trim();
    final level = _level;
    final discovery = DiscoveryLocation(
      country: _discoveryCountryController.text,
      countryCode: _discoveryCountryCodeController.text,
      city: _discoveryCityController.text,
      cityId: _discoveryCityId,
      area: _discoveryAreaController.text,
      areaId: _discoveryAreaId,
      latitude: _discoveryLatitude,
      longitude: _discoveryLongitude,
    );
    final bio = _bioController.text.trim();
    if (displayName.length < 2) {
      _showMessage(context.l10n.displayNameTooShort);
      return;
    }
    if (displayName.length > 40) {
      _showMessage(context.l10n.displayNameTooLong);
      return;
    }
    if (level == null) {
      setState(() => _levelError = context.l10n.chooseLevelRange);
      _showMessage(context.l10n.chooseLevelRange);
      return;
    }
    if (bio.length > socialProfileBioMaxLength) {
      _showMessage(context.l10n.bioTooLong);
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
      _showMessage(context.l10n.discoveryLocationRequired);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final savedProfile = UserProfile(
        uid: widget.uid,
        displayName: displayName,
        level: profileLevelStorageValue(level),
        email: widget.email.isNotEmpty
            ? widget.email
            : widget.profile?.email ?? '',
        discoveryLocation: discovery,
        socialProfile: SocialProfileData(
          preferredSide: _preferredSide,
          playFrequency: _playFrequency,
          bio: bio,
          discoverable: _discoverable,
        ),
        avatarVersion: _avatarVersion,
      );
      if (widget.saveOverride case final saveOverride?) {
        await saveOverride(savedProfile);
      } else {
        await _persistProfile(savedProfile);
      }

      if (!mounted) return;
      if (widget.isRequired) {
        widget.onRequiredSaved?.call(savedProfile);
      } else {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.profileUpdated)),
        );
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Profile save failed [${error.code}]: ${error.message}\n$stackTrace',
      );
      _showMessage(context.l10n.profileSaveFailed);
    } catch (_) {
      _showMessage(context.l10n.profileSaveFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _persistProfile(UserProfile profile) async {
    final hasCanonicalLocation =
        profile.discoveryLocation.cityId.isNotEmpty ||
        profile.discoveryLocation.areaId.isNotEmpty;
    await saveProfileWithLegacyLocationFallback(
      hasCanonicalLocation: hasCanonicalLocation,
      write: (includeCanonicalLocation) async {
        final discovery = includeCanonicalLocation
            ? profile.discoveryLocation
            : DiscoveryLocation(
                country: profile.discoveryLocation.country,
                countryCode: profile.discoveryLocation.countryCode,
                city: profile.discoveryLocation.city,
                area: profile.discoveryLocation.area,
                latitude: profile.discoveryLocation.latitude,
                longitude: profile.discoveryLocation.longitude,
              );
        final firestore = FirebaseFirestore.instance;
        final privateReference = firestore.collection('users').doc(widget.uid);
        final publicReference = firestore
            .collection('publicProfiles')
            .doc(widget.uid);
        final batch = firestore.batch();
        final timestamp = FieldValue.serverTimestamp();
        final createdAt = widget.profile?.createdAt ?? timestamp;
        final sharedSocialData = profile.socialProfile.toMap();
        final publicLocation = coarsePublicLocation(discovery.toMap());
        batch.set(privateReference, {
          'uid': widget.uid,
          'displayName': profile.displayName,
          'level': profile.level,
          'email': profile.email,
          'discoveryLocation': discovery.toMap(),
          'countryCode': FieldValue.delete(),
          'city': FieldValue.delete(),
          'area': FieldValue.delete(),
          'createdAt': createdAt,
          'updatedAt': timestamp,
          ...sharedSocialData,
        }, SetOptions(merge: true));
        batch.set(publicReference, {
          'uid': widget.uid,
          'displayName': profile.displayName,
          'level': profile.level,
          ...publicLocation,
          ...sharedSocialData,
        }, SetOptions(merge: true));
        await batch.commit();
      },
    );
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
          widget.isRequired
              ? context.l10n.completeYourProfile
              : context.l10n.editProfile,
        ),
        backgroundColor: const Color(0xFF0F1412),
        actions: widget.isRequired
            ? [
                IconButton(
                  tooltip: context.l10n.logOut,
                  onPressed: _isSaving
                      ? null
                      : widget.onSignOut ??
                            () => unawaited(FirebaseAuth.instance.signOut()),
                  icon: const Icon(Icons.logout),
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AvatarEditor(
            uid: widget.uid,
            displayName: _displayNameController.text,
            avatarVersion: _avatarVersion,
            onChanged: (value) => setState(() => _avatarVersion = value),
          ),
          const SizedBox(height: 24),
          Text(
            widget.isRequired
                ? context.l10n.profileRequiredIntro
                : context.l10n.profileEditIntro,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _displayNameController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: context.l10n.displayName,
              prefixIcon: const Icon(Icons.person_outline),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          PadelLevelSelector(
            fieldKey: const Key('profile-level-field'),
            value: _level,
            legacyValue: _legacyLevel,
            errorText: _levelError,
            onChanged: _isSaving
                ? null
                : (value) => setState(() {
                    _level = value;
                    _legacyLevel = null;
                    _levelError = null;
                  }),
            labelText: context.l10n.level,
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.padelProfile,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PreferredSide>(
            key: const Key('preferred-side-field'),
            isExpanded: true,
            initialValue: _preferredSide,
            decoration: InputDecoration(
              labelText: context.l10n.preferredSide,
              prefixIcon: const Icon(Icons.swap_horiz),
              border: const OutlineInputBorder(),
            ),
            items: PreferredSide.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _preferredSide = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PlayFrequency>(
            key: const Key('play-frequency-field'),
            isExpanded: true,
            initialValue: _playFrequency,
            decoration: InputDecoration(
              labelText: context.l10n.playFrequency,
              prefixIcon: Icon(Icons.calendar_month_outlined),
              border: const OutlineInputBorder(),
            ),
            items: PlayFrequency.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _playFrequency = value!),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-bio-field'),
            controller: _bioController,
            enabled: !_isSaving,
            maxLength: socialProfileBioMaxLength,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.l10n.shortBio,
              hintText: context.l10n.tellPlayersGame,
              border: const OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            key: const Key('profile-discoverable-field'),
            value: _discoverable,
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.discoverability),
            subtitle: Text(context.l10n.profileVisibilityHelp),
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _discoverable = value),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.preferredLocation,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.city,
            key: Key('profile-city-heading'),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_placesConfigured)
            PlacesAutocompleteField(
              key: const Key('profile-city-selector'),
              labelText: _discoveryCityController.text.trim().isEmpty
                  ? context.l10n.chooseCity
                  : context.l10n.changeCity,
              hintText: context.l10n.searchCitiesOnly,
              initialText: _discoveryCityController.text,
              citiesOnly: true,
              enabled: !_isSaving,
              client: widget.placesClient,
              onSelected: (location) => setState(() {
                final sameCity =
                    _discoveryCityId.isNotEmpty &&
                    _discoveryCityId == location.placeId.trim();
                _discoveryCountryController.text = location.country;
                _discoveryCountryCodeController.text = location.countryCode;
                _discoveryCityController.text = location.city;
                _discoveryCityId = location.placeId.trim();
                if (!sameCity) {
                  _discoveryAreaController.clear();
                  _discoveryAreaId = '';
                }
                _discoveryLatitude = location.latitude;
                _discoveryLongitude = location.longitude;
              }),
            )
          else ...[
            Text(
              context.l10n.citySuggestionsUnavailable,
              key: Key('profile-city-fallback-message'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discoveryCountryController,
              enabled: !_isSaving,
              onChanged: (_) => setState(() {
                _discoveryAreaController.clear();
                _discoveryCityId = '';
                _discoveryAreaId = '';
                _discoveryLatitude = null;
                _discoveryLongitude = null;
              }),
              decoration: InputDecoration(
                labelText: context.l10n.country,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discoveryCountryCodeController,
              enabled: !_isSaving,
              onChanged: (_) => setState(() {
                _discoveryAreaController.clear();
                _discoveryCityId = '';
                _discoveryAreaId = '';
                _discoveryLatitude = null;
                _discoveryLongitude = null;
              }),
              textCapitalization: TextCapitalization.characters,
              maxLength: 2,
              decoration: InputDecoration(
                labelText: context.l10n.isoCountryCode,
                hintText: 'ES',
                counterText: '',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discoveryCityController,
              enabled: !_isSaving,
              onChanged: (_) => setState(() {
                _discoveryAreaController.clear();
                _discoveryCityId = '';
                _discoveryAreaId = '';
                _discoveryLatitude = null;
                _discoveryLongitude = null;
              }),
              decoration: InputDecoration(
                labelText: context.l10n.city,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AreaSelectorField(
            key: const Key('profile-area-field'),
            value: _discoveryAreaController.text,
            location: DiscoveryLocation(
              country: _discoveryCountryController.text,
              countryCode: _discoveryCountryCodeController.text,
              city: _discoveryCityController.text,
              cityId: _discoveryCityId,
              area: _discoveryAreaController.text,
              areaId: _discoveryAreaId,
              latitude: _discoveryLatitude,
              longitude: _discoveryLongitude,
            ),
            placesClient: widget.placesClient,
            enabled: !_isSaving,
            labelText: context.l10n.areaOptional,
            helperText: _discoveryAreaController.text.trim().isEmpty
                ? context.l10n.optionalNeighborhoodCity
                : context.l10n.legacyAreaHelp,
            onChanged: (value) => setState(() {
              _discoveryAreaController.text = value.label;
              _discoveryAreaId = value.id;
            }),
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
                : Text(context.l10n.saveProfile),
          ),
        ],
      ),
    );
  }
}

typedef MatchCreator = Future<String> Function(Map<String, dynamic> match);

class CreateMatchScreen extends StatefulWidget {
  final GooglePlacesClient? placesClient;
  final MatchCreator? creator;
  final MatchLocation? initialLocation;
  final DateTime? initialScheduledAt;
  final String? initialLevel;
  final PlayAgainTarget? playAgainTarget;
  final PlayAgainRepository? playAgainRepository;
  final DateTime Function() nowProvider;
  final MatchDateTimePicker dateTimePicker;

  const CreateMatchScreen({
    super.key,
    this.placesClient,
    this.creator,
    this.initialLocation,
    this.initialScheduledAt,
    this.initialLevel,
    this.playAgainTarget,
    this.playAgainRepository,
    this.nowProvider = DateTime.now,
    this.dateTimePicker = showAdaptiveMatchDateTimePicker,
  });

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
  bool _isCreating = false;
  bool _editingLocationDetails = googlePlacesApiKey.isEmpty;
  DateTime? _scheduledAt;
  String? _level;
  int _totalPlayers = 4;
  String? _locationError;
  String? _dateTimeError;
  String? _levelError;
  String _placeId = '';
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final location =
        widget.initialLocation ?? widget.playAgainTarget?.safeLocation;
    if (location != null) {
      _clubController.text = location.clubName;
      _countryController.text = location.country;
      _countryCodeController.text = location.countryCode;
      _regionController.text = location.region;
      _cityController.text = location.city;
      _areaController.text = location.area;
      _placeId = location.placeId;
      _latitude = location.latitude;
      _longitude = location.longitude;
      _editingLocationDetails = false;
    }
    // Play Again always requires a freshly selected future time.
    _scheduledAt = widget.playAgainTarget == null
        ? widget.initialScheduledAt
        : null;
    if (_scheduledAt != null) {
      _dateTimeController.text = _friendlyDateTime(_scheduledAt!);
    }
    _level = normalizePadelLevel(
      widget.initialLevel ?? widget.playAgainTarget?.safeLevel,
    );
  }

  @override
  void dispose() {
    _clubController.dispose();
    _countryController.dispose();
    _countryCodeController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _dateTimeController.dispose();
    super.dispose();
  }

  Future<void> _createMatch() async {
    if (_isCreating) return;
    final club = _clubController.text.trim();
    final dateTime = _dateTimeController.text.trim();
    final level = _level;
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

    final locationError = !location.isValid
        ? context.l10n.selectPadelClub
        : null;
    final now = widget.nowProvider();
    final dateTimeError = dateTime.isEmpty || _scheduledAt == null
        ? context.l10n.chooseDateTimePeriod
        : !_scheduledAt!.isAfter(now)
        ? context.l10n.chooseFutureDate
        : null;
    final levelError = level == null ? context.l10n.choosePlayerLevel : null;
    if (locationError != null || dateTimeError != null || levelError != null) {
      setState(() {
        _locationError = locationError;
        _dateTimeError = dateTimeError;
        _levelError = levelError;
        if (locationError != null && club.isNotEmpty) {
          _editingLocationDetails = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locationError ?? dateTimeError ?? levelError!)),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final user = widget.creator == null
          ? FirebaseAuth.instance.currentUser
          : null;
      if (widget.creator == null && user == null) {
        throw const MatchActionException('Please log in to create a match.');
      }
      final profile = user == null ? null : await _loadUserProfile(user.uid);
      final match = <String, dynamic>{
        'title': dateTime,
        'club': club,
        'clubName': club,
        'location': location.toMap(),
        'dateTime': dateTime,
        'scheduledAt': Timestamp.fromDate(_scheduledAt!),
        'level': matchLevelStorageValue(level!),
        'spotsLeft': _totalPlayers - 1,
        'players': <Map<String, String>>[],
        'participantUids': <String>[if (user != null) user.uid],
        'creatorUid': user?.uid ?? '',
        'creatorDisplayName': profile?.displayName ?? '',
        'creatorLevel': profile?.level ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      final matchId = widget.creator != null
          ? await widget.creator!(match)
          : (await FirebaseFirestore.instance.collection('matches').add(match))
                .id;

      var invitationSent = false;
      var invitationFailed = false;
      if (widget.playAgainTarget != null) {
        try {
          await (widget.playAgainRepository ?? FirebasePlayAgainRepository())
              .invite(
                matchId: matchId,
                inviteeUid: widget.playAgainTarget!.uid,
                sourceMatchId: widget.playAgainTarget!.sourceMatchId,
              );
          invitationSent = true;
        } catch (_) {
          invitationFailed = true;
        }
      }

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, MatchMutationResult(matchId, location));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            invitationSent
                ? context.l10n.matchCreatedInvited
                : invitationFailed
                ? context.l10n.matchCreatedInviteFailed
                : context.l10n.matchCreated,
          ),
        ),
      );
    } on MatchActionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.createMatchFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _selectDateTime() async {
    final now = widget.nowProvider();
    final selected = await widget.dateTimePicker(
      context,
      now: now,
      initialValue: _scheduledAt,
    );
    if (selected == null || !mounted) return;
    if (!selected.isAfter(now)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.chooseFutureDate)));
      return;
    }

    setState(() {
      _scheduledAt = selected;
      _dateTimeController.text = _friendlyDateTime(selected);
      _dateTimeError = null;
    });
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );

  void _useLocation(MatchLocation location) => setState(() {
    _clubController.text = location.clubName;
    _countryController.text = location.country;
    _countryCodeController.text = location.countryCode;
    _regionController.text = location.region;
    _cityController.text = location.city;
    _areaController.text = location.area;
    _placeId = location.placeId;
    _latitude = location.latitude;
    _longitude = location.longitude;
    _locationError = null;
    _editingLocationDetails = false;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.createMatch),
        backgroundColor: const Color(0xFF0F1412),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Text(
            context.l10n.setUpGame,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.chooseClubTimePlayers,
            style: TextStyle(color: Colors.white70),
          ),
          if (widget.playAgainTarget != null) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.inviteAfterCreate(
                widget.playAgainTarget!.displayName,
              ),
              key: const Key('play-again-create-context'),
              style: const TextStyle(
                color: Color(0xFF74E8A0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _sectionTitle(context.l10n.where),
          PlacesAutocompleteField(
            client: widget.placesClient,
            labelText: context.l10n.searchPadelClub,
            hintText: context.l10n.clubNameAddress,
            enabled: !_isCreating,
            onSelected: _useLocation,
          ),
          if (_clubController.text.isNotEmpty && !_editingLocationDetails) ...[
            const SizedBox(height: 12),
            Card(
              key: const Key('selected-venue-card'),
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(_clubController.text),
                subtitle: Text(
                  MatchLocation(
                    clubName: _clubController.text,
                    countryCode: _countryCodeController.text,
                    country: _countryController.text,
                    region: _regionController.text,
                    city: _cityController.text,
                    area: _areaController.text,
                  ).localityLabel,
                ),
              ),
            ),
          ],
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _locationError!,
                key: const Key('location-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('edit-location-details'),
              onPressed: _isCreating
                  ? null
                  : () => setState(
                      () => _editingLocationDetails = !_editingLocationDetails,
                    ),
              child: Text(
                _editingLocationDetails
                    ? context.l10n.hideLocationDetails
                    : context.l10n.editLocationDetails,
              ),
            ),
          ),
          if (_editingLocationDetails) ...[
            TextField(
              controller: _clubController,
              onChanged: (_) {
                _placeId = '';
                _latitude = null;
                _longitude = null;
              },
              decoration: InputDecoration(
                labelText: context.l10n.clubName,
                prefixIcon: Icon(Icons.location_on),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('country-field'),
              controller: _countryController,
              onChanged: (_) {
                _latitude = null;
                _longitude = null;
              },
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.l10n.country,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('country-code-field'),
              controller: _countryCodeController,
              onChanged: (_) {
                _latitude = null;
                _longitude = null;
              },
              textCapitalization: TextCapitalization.characters,
              maxLength: 2,
              decoration: InputDecoration(
                labelText: context.l10n.countryCode,
                hintText: 'US',
                counterText: '',
                border: const OutlineInputBorder(),
              ),
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
              decoration: InputDecoration(
                labelText: context.l10n.regionOptional,
                border: const OutlineInputBorder(),
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
              decoration: InputDecoration(
                labelText: context.l10n.city,
                border: const OutlineInputBorder(),
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
              decoration: InputDecoration(
                labelText: context.l10n.areaOptional,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _sectionTitle(context.l10n.when),
          const SizedBox(height: 16),
          TextField(
            key: const Key('create-date-time-field'),
            controller: _dateTimeController,
            readOnly: true,
            onTap: _selectDateTime,
            decoration: InputDecoration(
              labelText: context.l10n.dateTime,
              hintText: context.l10n.chooseDateTime,
              prefixIcon: const Icon(Icons.calendar_month),
              border: const OutlineInputBorder(),
              errorText: null,
            ),
          ),
          if (_dateTimeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _dateTimeError!,
                key: const Key('date-time-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          _sectionTitle(context.l10n.matchDetailsSection),
          const SizedBox(height: 16),
          PadelLevelSelector(
            fieldKey: const Key('player-level-field'),
            value: _level,
            errorText: _levelError,
            errorKey: const Key('level-error'),
            onChanged: _isCreating
                ? null
                : (value) => setState(() {
                    _level = value;
                    _levelError = null;
                  }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const Key('total-players-field'),
            initialValue: _totalPlayers,
            decoration: InputDecoration(
              labelText: context.l10n.totalPlayers,
              border: const OutlineInputBorder(),
              helperText: context.l10n.capacityHelp,
            ),
            items: [
              DropdownMenuItem(
                value: 2,
                child: Text(context.l10n.playerCountChoice(2)),
              ),
              DropdownMenuItem(
                value: 3,
                child: Text(context.l10n.playerCountChoice(3)),
              ),
              DropdownMenuItem(
                value: 4,
                child: Text(context.l10n.playerCountChoice(4)),
              ),
            ],
            onChanged: _isCreating
                ? null
                : (value) => setState(() => _totalPlayers = value ?? 4),
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
              label: Text(
                _isCreating
                    ? context.l10n.creatingMatch
                    : context.l10n.createMatch,
              ),
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
  final DateTime Function() nowProvider;
  final MatchDateTimePicker dateTimePicker;

  const EditMatchScreen({
    super.key,
    required this.match,
    this.saver,
    this.nowProvider = DateTime.now,
    this.dateTimePicker = showAdaptiveMatchDateTimePicker,
  });

  @override
  State<EditMatchScreen> createState() => _EditMatchScreenState();
}

class _EditMatchScreenState extends State<EditMatchScreen> {
  late final TextEditingController _clubController;
  late final TextEditingController _dateTimeController;
  late final TextEditingController _capacityController;
  late MatchLocation _location;
  DateTime? _scheduledAt;
  bool _isSaving = false;
  String? _level;
  String? _legacyLevel;
  String? _levelError;

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
    _level = normalizePadelLevel(widget.match.level);
    _legacyLevel = _level == null && widget.match.level.trim().isNotEmpty
        ? widget.match.level.trim()
        : null;
    _capacityController = TextEditingController(
      text: matchTotalCapacity(widget.match).toString(),
    );
  }

  @override
  void dispose() {
    _clubController.dispose();
    _dateTimeController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final now = widget.nowProvider();
    final selected = await widget.dateTimePicker(
      context,
      now: now,
      initialValue: _scheduledAt,
    );
    if (selected == null || !mounted) return;
    if (!selected.isAfter(now)) {
      _showMessage(context.l10n.chooseFutureDate);
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
      if (!scheduledAt.isAfter(widget.nowProvider())) {
        throw const MatchActionException(
          'Please choose a future date and time.',
        );
      }
      final level = _level;
      if (level == null) {
        setState(() => _levelError = context.l10n.chooseLevelRange);
        throw const MatchActionException('Choose a level from 1 to 7.');
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
        level: level,
        totalCapacity: capacity,
      );
      setState(() => _isSaving = true);
      if (widget.saver != null) {
        await widget.saver!(update);
      } else {
        await _saveToFirestore(update);
      }
      if (!mounted) return;
      Navigator.pop(context, MatchMutationResult(widget.match.id, _location));
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Match edit failed [${error.code}]: ${error.message}\n$stackTrace',
      );
      _showMessage(context.l10n.saveMatchFailed);
    } catch (_) {
      _showMessage(context.l10n.saveMatchFailed);
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
        level: _level!,
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
        title: Text(context.l10n.editMatch),
        backgroundColor: const Color(0xFF0F1412),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.l10n.updateMatchDetails,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.preservePlayersRequests,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          PlacesAutocompleteField(
            initialText: widget.match.club,
            labelText: context.l10n.searchPadelClub,
            hintText: context.l10n.clubNameAddress,
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
              labelText: context.l10n.club,
              helperText: _location.localityLabel.isEmpty
                  ? context.l10n.legacyLocationHelp
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
            decoration: InputDecoration(
              labelText: context.l10n.dateTime,
              prefixIcon: const Icon(Icons.calendar_month),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          PadelLevelSelector(
            fieldKey: const Key('edit-level-field'),
            value: _level,
            legacyValue: _legacyLevel,
            errorText: _levelError,
            onChanged: _isSaving
                ? null
                : (value) => setState(() {
                    _level = value;
                    _legacyLevel = null;
                    _levelError = null;
                  }),
            labelText: context.l10n.level,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-capacity-field'),
            controller: _capacityController,
            enabled: !_isSaving,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.totalCapacity,
              helperText: context.l10n.confirmedPlayersCapacity(confirmedCount),
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
              label: Text(
                _isSaving
                    ? context.l10n.savingEllipsis
                    : context.l10n.saveChanges,
              ),
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
  final PlayedWithRepository? playedWithRepository;
  final FriendsRepository? friendsRepository;
  final MessagingRepository? messagingRepository;
  final ValueChanged<PlayAgainTarget>? onPlayAgain;
  final ReportRepository? reportRepository;

  const PlayerProfileScreen({
    super.key,
    required this.uid,
    this.fallbackName = '',
    this.fallbackLevel = '',
    this.loader = loadPublicPlayerProfile,
    this.viewerUid,
    this.viewerEmail,
    this.playedWithRepository,
    this.friendsRepository,
    this.messagingRepository,
    this.onPlayAgain,
    this.reportRepository,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late Future<PublicPlayerProfile> _profile = widget.loader(widget.uid);
  late Future<PlayedWithRelationship?> _playedTogether = _loadPlayedTogether();
  late Future<(bool, PlayedWithRelationship?)> _playAgainEligibility =
      _loadPlayAgainEligibility();

  User? get _firebaseUser =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  String get _viewerUid => widget.viewerUid ?? _firebaseUser?.uid ?? '';

  Future<void> _reportPlayer(String name, bool isAcceptedFriend) =>
      showReportFlow(
        context: context,
        repository: widget.reportRepository ?? FirebaseReportRepository(),
        subjectType: ReportSubjectType.player,
        subjectId: widget.uid,
        subjectLabel: name.isEmpty ? context.l10n.player : name,
        onBlockPlayer: () =>
            (widget.friendsRepository ?? FirebaseFriendsRepository()).block(
              widget.uid,
            ),
        friendshipWillBeRemoved: isAcceptedFriend,
      );

  Future<void> _message(String name, int avatarVersion) async {
    final repository =
        widget.messagingRepository ?? FirebaseMessagingRepository();
    try {
      final id = await repository.ensureDirect(widget.uid);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: id,
            currentUid: _viewerUid,
            title: name.isEmpty ? context.l10n.player : name,
            repository: repository,
            otherUid: widget.uid,
            avatarVersion: avatarVersion,
            conversationType: 'direct',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.acceptedFriendsMessaging)),
        );
      }
    }
  }

  Future<PlayedWithRelationship?> _loadPlayedTogether() {
    final viewerUid = _viewerUid;
    if (viewerUid.isEmpty ||
        viewerUid == widget.uid ||
        (widget.playedWithRepository == null && Firebase.apps.isEmpty)) {
      return Future.value();
    }
    return (widget.playedWithRepository ?? FirestorePlayedWithRepository())
        .relationship(viewerUid, widget.uid);
  }

  Future<(bool, PlayedWithRelationship?)> _loadPlayAgainEligibility() async {
    if (_viewerUid.isEmpty ||
        _viewerUid == widget.uid ||
        widget.onPlayAgain == null) {
      return (false, null);
    }
    try {
      final results = await Future.wait<Object?>([
        _loadPlayedTogether(),
        (widget.friendsRepository ?? FirebaseFriendsRepository()).policy(
          widget.uid,
        ),
      ]);
      final relationship = results[0] as PlayedWithRelationship?;
      final policy = results[1] as RelationshipPolicy;
      return (
        policy.interactionAllowed &&
            (relationship != null || policy.status == 'accepted'),
        relationship,
      );
    } catch (_) {
      return (false, null);
    }
  }

  void _retry() => setState(() {
    _profile = widget.loader(widget.uid);
    _playedTogether = _loadPlayedTogether();
    _playAgainEligibility = _loadPlayAgainEligibility();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.playerProfile),
        backgroundColor: const Color(0xFF0F1412),
      ),
      body: FutureBuilder<PublicPlayerProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ProfileMessageState(
              icon: Icons.cloud_off_outlined,
              title: context.l10n.playerProfileFailed,
              message: context.l10n.connectionRetry,
              actionLabel: context.l10n.tryAgain,
              onAction: _retry,
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
          final summary = profile.ratingSummary;
          final recentMatches = recentPlayerMatches(
            profile.matches,
            limit: profile.matches.length,
          );
          final viewerUid = _viewerUid;
          final viewerEmail = widget.viewerEmail ?? _firebaseUser?.email ?? '';
          final ratingsByMatch = {
            for (final rating in profile.ratings)
              if (rating.raterUid == viewerUid) rating.matchId: rating,
          };
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ProfileAvatar(
                  uid: profile.uid,
                  displayName: name,
                  avatarVersion: profile.avatarVersion,
                  radius: 44,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name.isEmpty ? context.l10n.player : name,
                key: const Key('public-profile-name'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                profileLevelLabel(level),
                key: const Key('public-profile-level'),
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      context.l10n.preferredSideDisplay(
                        _localizedPreferredSide(
                          context,
                          profile.socialProfile.preferredSide,
                        ),
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      _localizedPlayFrequency(
                        context,
                        profile.socialProfile.playFrequency,
                      ),
                    ),
                  ),
                  Chip(
                    key: const Key('public-profile-reliability'),
                    label: Text(
                      profile.reliabilityStatus == 'established' &&
                              profile.reliabilityPercent != null
                          ? context.l10n.reliabilityPercent(
                              profile.reliabilityPercent!,
                            )
                          : context.l10n.reliabilityNewPlayer,
                    ),
                  ),
                ],
              ),
              if (profile.socialProfile.bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(profile.socialProfile.bio),
              ],
              if (profile.city.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  [
                    profile.area,
                    profile.city,
                    profile.countryCode,
                  ].where((value) => value.isNotEmpty).join(', '),
                  key: const Key('public-profile-location'),
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
              const SizedBox(height: 24),
              FutureBuilder<(bool, PlayedWithRelationship?)>(
                future: _playAgainEligibility,
                builder: (context, eligibility) {
                  if (eligibility.data?.$1 != true) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton.icon(
                      key: const Key('play-again-profile'),
                      onPressed: () => widget.onPlayAgain!(
                        PlayAgainTarget(
                          uid: widget.uid,
                          displayName: name.isEmpty
                              ? context.l10n.player
                              : name,
                          sourceMatchId: eligibility.data?.$2?.lastMatchId,
                        ),
                      ),
                      icon: const Icon(Icons.replay),
                      label: Text(context.l10n.playAgain),
                    ),
                  );
                },
              ),
              if (viewerUid.isNotEmpty &&
                  viewerUid != widget.uid &&
                  (widget.friendsRepository != null ||
                      Firebase.apps.isNotEmpty)) ...[
                FriendAction(
                  targetUid: widget.uid,
                  repository:
                      widget.friendsRepository ?? FirebaseFriendsRepository(),
                  onChanged: _retry,
                  onReport: (isAcceptedFriend) =>
                      _reportPlayer(name, isAcceptedFriend),
                ),
                FutureBuilder<RelationshipPolicy>(
                  future:
                      (widget.friendsRepository ?? FirebaseFriendsRepository())
                          .policy(widget.uid),
                  builder: (context, policy) =>
                      policy.data?.status == 'accepted'
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton.icon(
                            key: const Key('message-friend'),
                            onPressed: () =>
                                _message(name, profile.avatarVersion),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: Text(context.l10n.message),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
              ],
              FutureBuilder<PlayedWithRelationship?>(
                future: _playedTogether,
                builder: (context, relationshipSnapshot) {
                  final relationship = relationshipSnapshot.data;
                  if (relationship == null) return const SizedBox.shrink();
                  final count = relationship.completedMatchCount;
                  return Card(
                    key: const Key('public-profile-played-together'),
                    child: ListTile(
                      leading: const Icon(Icons.group_outlined),
                      title: Text(context.l10n.playedTogetherCount(count)),
                      subtitle: Text(
                        context.l10n.lastPlayed(
                          playedWithShortDate(
                            relationship.lastPlayedAt,
                            locale: Localizations.localeOf(context),
                            unavailableLabel: context.l10n.dateUnavailable,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      _ProfileStat(
                        label: context.l10n.completedMatches,
                        value: '${profile.completedMatchCount}',
                      ),
                      const _ProfileStatDivider(),
                      _ProfileStat(
                        label: context.l10n.repeatPlayers,
                        value: '${profile.repeatPlayerCount}',
                      ),
                      if (profile.matches.isNotEmpty) ...[
                        const _ProfileStatDivider(),
                        _ProfileStat(
                          label: context.l10n.sharedMatches,
                          value: '${profile.matches.length}',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: summary.count == 0
                      ? Text(
                          context.l10n.noRatings,
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
                              context.l10n.ratingSummary(
                                summary.average.toStringAsFixed(1),
                                summary.count,
                              ),
                              key: const Key('public-profile-rating-summary'),
                            ),
                          ],
                        ),
                ),
              ),
              if (recentMatches.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  context.l10n.sharedMatchRatings,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
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
                        match.club.isEmpty ? context.l10n.match : match.club,
                      ),
                      trailing: existing != null
                          ? Text(
                              existing.rating > 0
                                  ? context.l10n.submittedStars(existing.rating)
                                  : context.l10n.ratingSubmitted,
                              key: Key('existing-rating-${match.id}'),
                            )
                          : eligible
                          ? TextButton(
                              key: Key('rate-player-${match.id}'),
                              onPressed: null,
                              child: Text(context.l10n.rateInDetails),
                            )
                          : null,
                    ),
                  );
                }),
              ],
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

String explicitLevel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.toLowerCase().startsWith('level ')) return trimmed;
  return 'Level $trimmed';
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
  final match = await FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .get();
  final candidates = match.exists
      ? ratingCandidates(Match.fromDocument(match), raterUid)
      : const <MatchPlayer>[];
  final submitted = await loadOwnRatingReceiptUids(
    matchId,
    candidates.map((p) => p.uid).toList(),
  );
  return submitted
      .map(
        (ratedUid) => PlayerRating(
          matchId: matchId,
          raterUid: raterUid,
          ratedUid: ratedUid,
          rating: 0,
        ),
      )
      .toList();
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
        email: '',
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
  final PublicPlayerProfileLoader identityLoader;

  const RatePlayersSection({
    super.key,
    required this.match,
    required this.currentUid,
    this.currentEmail = '',
    this.ratingsLoader = loadMatchRatings,
    this.ratingSubmitter = submitMatchRating,
    this.profileLoader = loadPublicPlayerProfile,
    this.identityLoader = loadPublicPlayerIdentity,
  });

  @override
  State<RatePlayersSection> createState() => _RatePlayersSectionState();
}

class _RatePlayersSectionState extends State<RatePlayersSection> {
  final Set<String> _submitting = {};
  final Map<String, Future<PublicPlayerProfile>> _profiles = {};
  List<PlayerRating>? _loadedRatings;
  Object? _ratingLoadError;
  bool _loadingRatings = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRatings());
  }

  Future<void> _loadRatings() async {
    if (_loadedRatings == null && mounted) {
      setState(() {
        _loadingRatings = true;
        _ratingLoadError = null;
      });
    }
    try {
      final ratings = await widget.ratingsLoader(
        widget.match.id,
        widget.currentUid,
      );
      if (!mounted) return;
      setState(() {
        final byPlayer = {
          for (final rating in _loadedRatings ?? const <PlayerRating>[])
            rating.ratedUid: rating,
          for (final rating in ratings) rating.ratedUid: rating,
        };
        _loadedRatings = byPlayer.values.toList();
        _ratingLoadError = null;
        _loadingRatings = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ratingLoadError = error;
        _loadingRatings = false;
      });
    }
  }

  void _retry() => unawaited(_loadRatings());

  Future<void> _rate(MatchPlayer player) async {
    var selected = 0;
    final rating = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.l10n.rateNamedPlayer(
              player.displayName.isEmpty
                  ? context.l10n.player.toLowerCase()
                  : player.displayName,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    key: Key('match-rating-star-$value'),
                    tooltip: '$value star${value == 1 ? '' : 's'}',
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: () => setDialogState(() => selected = value),
                    icon: Icon(
                      value <= selected ? Icons.star : Icons.star_border,
                      color: selected == 0 ? Colors.white54 : Colors.amber,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  selected == 0
                      ? context.l10n.selectRating
                      : context.l10n.ratingSelected(selected),
                  key: const Key('rating-selection-label'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: selected == 0
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: Text(context.l10n.submitRating),
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
        _loadedRatings = [
          ...?_loadedRatings,
          PlayerRating(
            matchId: widget.match.id,
            raterUid: widget.currentUid,
            ratedUid: player.uid,
            rating: rating,
          ),
        ];
      });
      unawaited(_loadRatings());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.ratingSubmitted)));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _submitting.remove(player.uid));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? context.l10n.ratingNotEligible
                : context.l10n.ratingSubmitFailed,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting.remove(player.uid));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.ratingSubmitFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ratingCandidates(widget.match, widget.currentUid);
    return Column(
      key: const Key('rate-players-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.ratePlayers,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (candidates.isEmpty)
          Text(
            context.l10n.noOtherPlayersRate,
            style: TextStyle(color: Colors.white70),
          )
        else if (_loadedRatings == null && _loadingRatings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Semantics(
                label: context.l10n.loadingSubmittedRatings,
                child: CircularProgressIndicator(),
              ),
            ),
          )
        else if (_loadedRatings == null && _ratingLoadError != null)
          _InlineLoadError(
            message: context.l10n.submittedRatingsFailed,
            onRetry: _retry,
          )
        else ...[
          ...candidates.map((player) {
            final prior = _loadedRatings
                ?.where((rating) => rating.ratedUid == player.uid)
                .firstOrNull;
            return _RatingPlayerCard(
              player: player,
              role: player.uid == widget.match.creatorUid
                  ? context.l10n.organizer
                  : context.l10n.confirmedRole,
              prior: prior,
              submitting: _submitting.contains(player.uid),
              profile: _profiles.putIfAbsent(
                player.uid,
                () => widget.identityLoader(player.uid),
              ),
              onOpenProfile: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerProfileScreen(
                    uid: player.uid,
                    fallbackName: player.displayName,
                    fallbackLevel: player.level,
                    loader: widget.profileLoader,
                    viewerUid: widget.currentUid,
                    viewerEmail: widget.currentEmail,
                  ),
                ),
              ),
              onRate: () => _rate(player),
            );
          }),
          if (_loadedRatings != null &&
              candidates.every(
                (player) => _loadedRatings!.any(
                  (rating) => rating.ratedUid == player.uid,
                ),
              ))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                context.l10n.allPlayersRated,
                key: Key('all-players-rated'),
                style: const TextStyle(color: Colors.white60),
              ),
            ),
        ],
      ],
    );
  }
}

class _RatingPlayerCard extends StatelessWidget {
  final MatchPlayer player;
  final String role;
  final PlayerRating? prior;
  final bool submitting;
  final Future<PublicPlayerProfile> profile;
  final VoidCallback onOpenProfile;
  final VoidCallback onRate;

  const _RatingPlayerCard({
    required this.player,
    required this.role,
    required this.prior,
    required this.submitting,
    required this.profile,
    required this.onOpenProfile,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final name = player.displayName.isEmpty
        ? context.l10n.player
        : player.displayName;
    final metadata = _playerSubtitle(role, player.level);
    final resolved = prior != null;
    return Semantics(
      label: resolved
          ? '$name, $metadata, rating submitted${prior!.rating > 0 ? ', ${prior!.rating} stars' : ''}'
          : '$name, $metadata, rating available',
      container: true,
      child: Card(
        key: Key('rating-card-${player.uid}'),
        color: resolved ? const Color(0xFF18211D) : const Color(0xFF1B2B24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: resolved ? Colors.white10 : const Color(0x3374E8A0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: Key('rating-player-${player.uid}'),
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    FutureBuilder<PublicPlayerProfile>(
                      future: profile,
                      builder: (context, snapshot) {
                        final profile = snapshot.data;
                        return ProfileAvatar(
                          key: Key('rating-avatar-${player.uid}'),
                          uid: player.uid,
                          displayName: profile?.displayName ?? name,
                          avatarVersion: profile?.avatarVersion ?? 0,
                          radius: 22,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            metadata,
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (resolved)
                Row(
                  key: Key('rated-match-player-${player.uid}'),
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF74E8A0),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prior!.rating > 0
                            ? context.l10n.ratingSubmittedStars(prior!.rating)
                            : context.l10n.ratingSubmitted,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                )
              else ...[
                Text(
                  context.l10n.howWasPlaying(name),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: Key('rate-match-player-${player.uid}'),
                    onPressed: submitting ? null : onRate,
                    child: submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.ratePlayer),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('inline-load-error'),
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF18211D),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.tryAgain),
        ),
      ],
    ),
  );
}

class MatchDetailsScreen extends StatefulWidget {
  final Match match;
  final Future<void> Function(MatchMutationResult)? onMatchUpdated;
  final ValueChanged<String>? onMatchDeleted;
  final ReportRepository? reportRepository;
  final Future<String?> Function(String matchId)? privateVenueLoader;
  final MatchmakingRepository? matchmakingRepository;
  final MatchActionsRepository? matchActionsRepository;

  const MatchDetailsScreen({
    super.key,
    required this.match,
    this.onMatchUpdated,
    this.onMatchDeleted,
    this.reportRepository,
    this.privateVenueLoader,
    this.matchmakingRepository,
    this.matchActionsRepository,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class MatchAutoFillCard extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onToggle;

  const MatchAutoFillCard({
    super.key,
    required this.enabled,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => PadelXSurface(
    strong: enabled,
    accent: enabled ? PadelXColors.accent : null,
    padding: const EdgeInsets.all(PadelXSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              enabled ? Icons.radar : Icons.person_add_alt_1,
              color: PadelXColors.accent,
            ),
            const SizedBox(width: PadelXSpace.sm),
            Expanded(
              child: Text(
                context.l10n.findAPlayer,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(context.l10n.autoFillExplanation),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('match-autofill-action'),
          onPressed: busy ? null : onToggle,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(enabled ? Icons.stop_circle_outlined : Icons.auto_awesome),
          label: Text(
            enabled ? context.l10n.stopAutoFill : context.l10n.findAPlayer,
          ),
        ),
        if (enabled)
          Text(
            context.l10n.findingAnotherPlayer,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    ),
  );
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  bool _isRequesting = false;
  bool _isLeaving = false;
  bool _isCancelling = false;
  bool _isAutoFillBusy = false;
  final Set<String> _processingRequestIds = {};
  String? _privateVenueAddress;

  @override
  void initState() {
    super.initState();
    _loadPrivateVenue();
  }

  Future<void> _loadPrivateVenue() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (widget.match.venueType != 'private_free' ||
        uid == null ||
        (widget.match.creatorUid != uid &&
            !widget.match.players.any((player) => player.uid == uid))) {
      return;
    }
    try {
      final address = widget.privateVenueLoader != null
          ? await widget.privateVenueLoader!(widget.match.id)
          : (await FirebaseFirestore.instance
                    .collection('matchPrivateVenues')
                    .doc(widget.match.id)
                    .get())
                .data()?['address']
                ?.toString();
      if (mounted && address != null && address.trim().isNotEmpty) {
        setState(() => _privateVenueAddress = address.trim());
      }
    } on FirebaseException {
      // Approximate canonical venue remains visible if authorization changes.
    }
  }

  Future<void> _reportMatch(Match match) => showReportFlow(
    context: context,
    repository: widget.reportRepository ?? FirebaseReportRepository(),
    subjectType: ReportSubjectType.match,
    subjectId: match.id,
    subjectLabel: match.club.isEmpty ? context.l10n.match : match.club,
  );

  Future<void> _playAgain(Match match, String uid, String name) async {
    final result = await Navigator.of(context).push<MatchMutationResult>(
      MaterialPageRoute(
        builder: (_) => CreateMatchScreen(
          playAgainTarget: PlayAgainTarget(
            uid: uid,
            displayName: name,
            sourceMatchId: match.id,
            location: match.location,
            level: match.level,
          ),
        ),
      ),
    );
    if (result != null) await widget.onMatchUpdated?.call(result);
  }

  Future<void> _openMatchChat(Match match) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final repository = FirebaseMessagingRepository();
    try {
      final ensured = await repository.ensureMatch(match.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: ensured.conversationId,
            currentUid: uid,
            title: match.club.isEmpty ? context.l10n.matchChat : match.club,
            repository: repository,
            conversationType: 'match',
          ),
        ),
      );
    } catch (_) {
      if (mounted) _showMessage(context.l10n.matchChatUnavailable);
    }
  }

  Future<void> _toggleAutoFill(Match match) async {
    if (_isAutoFillBusy) return;
    final failureMessage = context.l10n.matchmakingActionFailed;
    setState(() => _isAutoFillBusy = true);
    final repository =
        widget.matchmakingRepository ?? FirebaseMatchmakingRepository();
    try {
      if (match.autoFillEnabled && match.autoFillRequestId.isNotEmpty) {
        await repository.cancel(match.autoFillRequestId);
      } else {
        final scheduled = match.scheduledAt;
        if (scheduled == null) {
          throw const MatchActionException('Match time unavailable.');
        }
        await repository.create(
          MatchmakingRequestInput(
            requestId:
                'autofill_${DateTime.now().microsecondsSinceEpoch}_${match.id.hashCode.abs()}',
            mode: MatchmakingMode.autofill,
            sourceMatchId: match.id,
            autoFillAfterCancellation: true,
            availability: [
              MatchmakingAvailability(
                earliestStart: scheduled,
                latestStart: scheduled.add(const Duration(hours: 2)),
              ),
            ],
            timezone: 'America/Mexico_City',
            travelRadiusKm: 25,
            preferredSide: 'either',
          ),
        );
      }
    } catch (_) {
      _showMessage(failureMessage);
    } finally {
      if (mounted) setState(() => _isAutoFillBusy = false);
    }
  }

  Future<void> _requestToJoin() async {
    final strings = context.l10n;
    if (!matchAllowsChanges(widget.match, DateTime.now())) {
      _showMessage(strings.completedMatchNoChanges);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(strings.loginJoinMatch);
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

      _showMessage(strings.joinRequestSent);
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Join request failed [${error.code}]: ${error.message}\n$stackTrace',
      );
      _showMessage(strings.joinRequestFailed);
    } catch (_) {
      _showMessage(strings.joinRequestFailed);
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _reviewRequest(JoinRequest request, bool approve) async {
    final strings = context.l10n;
    if (!matchAllowsChanges(widget.match, DateTime.now())) {
      _showMessage(strings.completedMatchesNoChanges);
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
        approve ? strings.joinRequestApproved : strings.joinRequestDeclined,
      );
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Join request ${approve ? 'approval' : 'decline'} failed '
        '[${error.code}]: ${error.message}\n$stackTrace',
      );
      _showMessage(
        approve ? strings.approveRequestFailed : strings.declineRequestFailed,
      );
    } catch (error, stackTrace) {
      final unboxed = _unboxWebError(error, stackTrace);
      debugPrint(
        'Join request $action failed '
        '[${unboxed.error.runtimeType}]: ${unboxed.error}\n'
        '${unboxed.stackTrace}',
      );
      _showMessage(
        approve ? strings.approveRequestFailed : strings.declineRequestFailed,
      );
    } finally {
      if (mounted) {
        setState(() => _processingRequestIds.remove(request.userId));
      }
    }
  }

  Future<void> _leaveMatch() async {
    final strings = context.l10n;
    if (!matchAllowsChanges(widget.match, DateTime.now())) {
      _showMessage(context.l10n.completedMatchesNoChanges);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(strings.loginLeaveMatch);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.leaveMatchQuestion),
        content: Text(context.l10n.spotAvailable),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.stay),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.leaveMatch),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _isLeaving) return;

    setState(() => _isLeaving = true);

    try {
      final repository =
          widget.matchActionsRepository ?? FirebaseMatchActionsRepository();
      await repository.leaveMatch(
        widget.match.id,
        'leave_${DateTime.now().microsecondsSinceEpoch}_${widget.match.id.hashCode.abs()}',
      );

      _showMessage(strings.leftMatch);
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Leave match failed [${error.code}]: ${error.message}\n$stackTrace',
      );
      _showMessage(strings.leaveMatchFailed);
    } catch (_) {
      _showMessage(strings.leaveMatchFailed);
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _cancelMatch() async {
    final strings = context.l10n;
    if (!matchAllowsChanges(widget.match, DateTime.now())) {
      _showMessage(strings.completedMatchesNoChanges);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(strings.loginCancelMatch);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.cancelMatchQuestion),
        content: Text(context.l10n.cancelMatchWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.keepMatch),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.cancelMatch),
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
      widget.onMatchDeleted?.call(widget.match.id);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.matchCancelled)),
      );
    } on MatchActionException catch (error) {
      _showMessage(error.message);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Cancel match failed [${error.code}]: ${error.message}\n$stackTrace',
      );
      _showMessage(strings.cancelMatchFailed);
    } catch (_) {
      _showMessage(strings.cancelMatchFailed);
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
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.matchDetails)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || (snapshot.hasData && !snapshot.data!.exists)) {
          debugPrint('Match details unavailable: ${snapshot.error}');
          return const _UnavailableMatchView();
        }
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
            ? requestsCollection
                  .where('status', isEqualTo: 'pending')
                  .orderBy('requestedAt')
                  .limit(25)
                  .snapshots()
                  .map(
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
                title: Text(context.l10n.matchDetails),
                backgroundColor: PadelXColors.background,
                actions: [
                  if (isOrganizer &&
                      !completed &&
                      match.source != 'matchmaking')
                    TextButton.icon(
                      key: const Key('edit-match-action'),
                      onPressed: isBusy
                          ? null
                          : () async {
                              final updated = await Navigator.of(context)
                                  .push<MatchMutationResult>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditMatchScreen(match: match),
                                    ),
                                  );
                              if (updated != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.l10n.matchUpdated),
                                  ),
                                );
                                await widget.onMatchUpdated?.call(updated);
                              }
                            },
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(context.l10n.editMatch),
                    ),
                  if (!isOrganizer)
                    PopupMenuButton<String>(
                      key: const Key('match-safety-actions'),
                      tooltip: context.l10n.moreSafetyActions,
                      onSelected: (value) {
                        if (value == 'report') _reportMatch(match);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              const Icon(Icons.flag_outlined),
                              const SizedBox(width: 12),
                              Text(context.l10n.reportMatch),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  MatchDetailsSummary(
                    match: match,
                    completed: completed,
                    privateVenueAddress: _privateVenueAddress,
                  ),
                  if (isOrganizer || hasJoined) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('open-match-chat'),
                      onPressed: () => _openMatchChat(match),
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(context.l10n.matchChat),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    completed
                        ? context.l10n.playersFromMatch
                        : context.l10n.players,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (match.teams.isNotEmpty)
                    _MatchTeams(
                      match: match,
                      currentUid: currentUid,
                      completed: completed,
                      onPlayAgain: (uid, name) => _playAgain(match, uid, name),
                    )
                  else if ((match.creatorUid.isNotEmpty ||
                          match.creatorEmail.isNotEmpty ||
                          match.creatorDisplayName == 'Deleted player') &&
                      (!completed || match.creatorUid != currentUid))
                    ProfilePlayerTile(
                      uid: match.creatorUid,
                      fallbackName: match.creatorDisplayName.isNotEmpty
                          ? match.creatorDisplayName
                          : context.l10n.organizer,
                      fallbackLevel: match.creatorLevel,
                      role: context.l10n.organizer,
                      historical: completed,
                      onPlayAgain: completed && match.creatorUid.isNotEmpty
                          ? () => _playAgain(
                              match,
                              match.creatorUid,
                              match.creatorDisplayName.isEmpty
                                  ? context.l10n.organizer
                                  : match.creatorDisplayName,
                            )
                          : null,
                    ),
                  if (match.teams.isEmpty)
                    ...match.players.map(
                      (player) =>
                          player.uid == match.creatorUid ||
                              (completed && player.uid == currentUid)
                          ? const SizedBox.shrink()
                          : ProfilePlayerTile(
                              uid: player.uid,
                              fallbackName: player.displayName.isNotEmpty
                                  ? player.displayName
                                  : context.l10n.player,
                              fallbackLevel: player.level,
                              role: context.l10n.confirmedRole,
                              historical: completed,
                              onPlayAgain: completed && player.uid.isNotEmpty
                                  ? () => _playAgain(
                                      match,
                                      player.uid,
                                      player.displayName.isEmpty
                                          ? context.l10n.player
                                          : player.displayName,
                                    )
                                  : null,
                            ),
                    ),
                  if (!completed &&
                      participationState == MatchParticipationState.organizer &&
                      match.source != 'matchmaking') ...[
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
                  if (!completed && isOrganizer && match.spotsLeft > 0) ...[
                    const SizedBox(height: 24),
                    MatchAutoFillCard(
                      enabled: match.autoFillEnabled,
                      busy: _isAutoFillBusy,
                      onToggle: () => _toggleAutoFill(match),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
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
                          _isCancelling
                              ? context.l10n.cancellingEllipsis
                              : context.l10n.cancelMatch,
                        ),
                      ),
                    )
                  else if (participationState ==
                      MatchParticipationState.confirmed)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
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
                        label: Text(
                          _isLeaving
                              ? context.l10n.leavingEllipsis
                              : context.l10n.leaveMatch,
                        ),
                      ),
                    )
                  else if (requestIsLoading || requestReadFailed)
                    _ParticipationStatus(
                      icon: requestReadFailed
                          ? Icons.error_outline
                          : Icons.hourglass_top,
                      label: requestReadFailed
                          ? context.l10n.requestStatusFailed
                          : context.l10n.loadingRequestStatus,
                    )
                  else if (participationState ==
                          MatchParticipationState.pending ||
                      match.spotsLeft <= 0)
                    _ParticipationStatus(
                      icon:
                          participationState == MatchParticipationState.pending
                          ? Icons.schedule
                          : Icons.group_off_outlined,
                      label:
                          participationState == MatchParticipationState.pending
                          ? context.l10n.requestPending
                          : context.l10n.matchFull,
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            isBusy || requestIsLoading || requestReadFailed
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
                              ? context.l10n.requestingEllipsis
                              : requestIsLoading
                              ? context.l10n.loadingRequest
                              : requestReadFailed
                              ? context.l10n.loadRequestFailed
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

class _MatchTeams extends StatelessWidget {
  final Match match;
  final String? currentUid;
  final bool completed;
  final void Function(String uid, String name) onPlayAgain;

  const _MatchTeams({
    required this.match,
    required this.currentUid,
    required this.completed,
    required this.onPlayAgain,
  });

  MatchPlayer? _player(String uid) {
    if (uid == match.creatorUid) {
      return MatchPlayer(
        uid: uid,
        email: match.creatorEmail,
        displayName: match.creatorDisplayName,
        level: match.creatorLevel,
      );
    }
    return match.players.where((player) => player.uid == uid).firstOrNull;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [1, 2].map((team) {
      final color = team == 1 ? PadelXColors.teamOne : PadelXColors.teamTwo;
      final members = match.teams[team] ?? const <String>[];
      return Padding(
        padding: const EdgeInsets.only(bottom: PadelXSpace.md),
        child: PadelXSurface(
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
              ...members.map((uid) {
                final player = _player(uid);
                final name = player?.displayName.isNotEmpty == true
                    ? player!.displayName
                    : context.l10n.player;
                return ProfilePlayerTile(
                  uid: uid,
                  fallbackName: name,
                  fallbackLevel: player?.level ?? '',
                  role: uid == match.creatorUid
                      ? context.l10n.organizer
                      : context.l10n.confirmedRole,
                  historical: completed,
                  onPlayAgain: completed && uid.isNotEmpty && uid != currentUid
                      ? () => onPlayAgain(uid, name)
                      : null,
                );
              }),
            ],
          ),
        ),
      );
    }).toList(),
  );
}

class MatchDetailsSummary extends StatelessWidget {
  final Match match;
  final bool completed;
  final String? privateVenueAddress;

  const MatchDetailsSummary({
    super.key,
    required this.match,
    required this.completed,
    this.privateVenueAddress,
  });

  @override
  Widget build(BuildContext context) {
    final dateTime = match.scheduledAt == null
        ? context.l10n.dateTimeUnavailable
        : _localizedFriendlyDateTime(context, match.scheduledAt!);
    return PadelXSurface(
      key: const Key('match-details-summary'),
      strong: true,
      accent: PadelXColors.border,
      padding: const EdgeInsets.all(PadelXSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateTime,
            key: const Key('match-details-date-time'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(match.club, style: Theme.of(context).textTheme.titleMedium),
          if (match.locationLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              match.locationLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (privateVenueAddress != null) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.privateVenueExactLocation(privateVenueAddress!),
              key: const Key('private-venue-exact-location'),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (explicitLevel(match.level).isNotEmpty)
                _InfoChip(
                  text: explicitLevel(match.level),
                  icon: Icons.leaderboard,
                ),
              _InfoChip(
                text: completed ? context.l10n.completed : match.spotsLeftLabel,
                icon: completed ? Icons.history : Icons.group,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParticipationStatus extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ParticipationStatus({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    key: Key('participation-status-$label'),
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF18211D),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white60),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

class _UnavailableMatchView extends StatelessWidget {
  const _UnavailableMatchView();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.matchDetails)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_busy_outlined,
              size: 52,
              color: Colors.white54,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.matchUnavailable,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.matchMayRemoved,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    ),
  );
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
        Text(
          context.l10n.joinRequests,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (loading)
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(context.l10n.loadingJoinRequests),
            ],
          )
        else if (errorMessage != null)
          Text(errorMessage!, style: const TextStyle(color: Colors.redAccent))
        else if (requests.isEmpty)
          Row(
            children: [
              const Icon(Icons.inbox_outlined, color: Colors.white54),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.noPendingRequests,
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ...requests.map((request) {
          final isProcessing = processingUserIds.contains(request.userId);
          return Card(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actions = Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isProcessing ? null : () => onDecline(request),
                      child: Text(context.l10n.decline),
                    ),
                    FilledButton(
                      onPressed: isProcessing ? null : () => onApprove(request),
                      child: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.l10n.approve),
                    ),
                  ],
                );
                return ListTile(
                  title: Text(
                    request.displayName.isEmpty
                        ? context.l10n.player
                        : request.displayName,
                  ),
                  subtitle: constraints.maxWidth < 380
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              explicitLevel(request.level).isEmpty
                                  ? context.l10n.levelNotSet
                                  : explicitLevel(request.level),
                            ),
                            actions,
                          ],
                        )
                      : Text(
                          explicitLevel(request.level).isEmpty
                              ? context.l10n.levelNotSet
                              : explicitLevel(request.level),
                        ),
                  trailing: constraints.maxWidth < 380 ? null : actions,
                  isThreeLine: constraints.maxWidth < 380,
                );
              },
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
  final String uid;
  final int avatarVersion;
  final bool deleted;
  final VoidCallback? onTap;
  final VoidCallback? onPlayAgain;

  const _PlayerTile({
    required this.name,
    required this.subtitle,
    this.uid = '',
    this.avatarVersion = 0,
    this.deleted = false,
    this.onTap,
    this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: ProfileAvatar(
          uid: uid,
          displayName: name,
          avatarVersion: avatarVersion,
          deleted: deleted,
        ),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: onPlayAgain != null
            ? IconButton(
                key: const Key('play-again-match-player'),
                tooltip: context.l10n.playAgain,
                onPressed: onPlayAgain,
                icon: const Icon(Icons.replay),
              )
            : onTap == null
            ? null
            : const Icon(Icons.chevron_right),
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
  final bool historical;
  final VoidCallback? onPlayAgain;

  const ProfilePlayerTile({
    super.key,
    required this.uid,
    required this.fallbackName,
    required this.fallbackLevel,
    required this.role,
    this.profileLoader,
    this.historical = false,
    this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final viewerUid = Firebase.apps.isEmpty
        ? ''
        : FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty && viewerUid.isNotEmpty && viewerUid != uid) {
      return FutureBuilder<Map<String, RelationshipPolicy>>(
        future: FirebaseRelationshipPolicyService().policies([uid]),
        builder: (context, snapshot) {
          if (snapshot.hasData &&
              snapshot.data![uid]?.interactionAllowed == false) {
            if (!historical) return const SizedBox.shrink();
            return _PlayerTile(
              name: fallbackName.isEmpty ? 'Player' : fallbackName,
              subtitle: _playerSubtitle(role, fallbackLevel),
            );
          }
          return _buildVisible(context, allowPlayAgain: snapshot.hasData);
        },
      );
    }
    return _buildVisible(context, allowPlayAgain: true);
  }

  Widget _buildVisible(BuildContext context, {required bool allowPlayAgain}) {
    void openProfile() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerProfileScreen(
            uid: uid,
            fallbackName: fallbackName,
            fallbackLevel: fallbackLevel,
            loader: profileLoader ?? loadPublicPlayerProfile,
            onPlayAgain: onPlayAgain == null
                ? null
                : (target) => onPlayAgain!(),
          ),
        ),
      );
    }

    if (uid.isEmpty) {
      return _PlayerTile(
        name: fallbackName.isEmpty ? 'Player' : fallbackName,
        subtitle: fallbackName == 'Deleted player'
            ? role
            : _playerSubtitle(role, fallbackLevel),
        onTap: fallbackName == 'Deleted player' ? null : openProfile,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.hasData && snapshot.data!.exists
            ? PublicUserProfile.fromDocument(snapshot.data!)
            : null;
        final missing =
            snapshot.connectionState != ConnectionState.waiting &&
            (snapshot.hasError || snapshot.data?.exists != true);
        if (missing) {
          return _PlayerTile(
            name: context.l10n.deletedPlayer,
            subtitle: context.l10n.playerUnavailable,
            deleted: true,
          );
        }
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
          uid: uid,
          avatarVersion: profile?.avatarVersion ?? 0,
          onTap: openProfile,
          onPlayAgain: allowPlayAgain ? onPlayAgain : null,
        );
      },
    );
  }
}

String _playerSubtitle(String role, String level) {
  final displayLevel = explicitLevel(level);
  return displayLevel.isEmpty ? role : '$displayLevel\n$role';
}
