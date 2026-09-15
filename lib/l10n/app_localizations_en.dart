// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get useDeviceLanguage => 'Use device language';

  @override
  String get english => 'English';

  @override
  String get spanishMexico => 'Español (México)';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get settings => 'Settings';

  @override
  String get authHeadline => 'Find your next match.';

  @override
  String get authSubtitle => 'Play more padel with players near you.';

  @override
  String get continueWithEmail => 'Continue with email';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get languageSelectorTooltip => 'Change language';

  @override
  String get languageSelectorSemantics => 'Change application language';

  @override
  String welcomePlayer(String name) {
    return 'Welcome, $name';
  }

  @override
  String matchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
      zero: 'No matches',
    );
    return '$_temp0';
  }
}
