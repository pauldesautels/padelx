import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('es', 'MX'),
  ];

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @useDeviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use device language'**
  String get useDeviceLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanishMexico.
  ///
  /// In en, this message translates to:
  /// **'Español (México)'**
  String get spanishMexico;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @authHeadline.
  ///
  /// In en, this message translates to:
  /// **'Find your next match.'**
  String get authHeadline;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play more padel with players near you.'**
  String get authSubtitle;

  /// No description provided for @continueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get continueWithEmail;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @languageSelectorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get languageSelectorTooltip;

  /// No description provided for @languageSelectorSemantics.
  ///
  /// In en, this message translates to:
  /// **'Change application language'**
  String get languageSelectorSemantics;

  /// No description provided for @welcomePlayer.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomePlayer(String name);

  /// No description provided for @matchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches} =1{1 match} other{{count} matches}}'**
  String matchCount(int count);

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @tryAgainLower.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgainLower;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get saveProfile;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterEmail;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @sendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Send reset email'**
  String get sendResetEmail;

  /// No description provided for @signInOrCreate.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create your account.'**
  String get signInOrCreate;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmail;

  /// No description provided for @openVerificationLink.
  ///
  /// In en, this message translates to:
  /// **'Open the link in that message, then return here to continue.'**
  String get openVerificationLink;

  /// No description provided for @beforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Before continuing'**
  String get beforeContinuing;

  /// No description provided for @ageConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I confirm that I am 18 years of age or older.'**
  String get ageConfirmation;

  /// No description provided for @ageRequired.
  ///
  /// In en, this message translates to:
  /// **'To continue, confirm that you are at least 18 years old.'**
  String get ageRequired;

  /// No description provided for @ageEligibility.
  ///
  /// In en, this message translates to:
  /// **'18+ eligibility'**
  String get ageEligibility;

  /// No description provided for @ageCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check age eligibility.'**
  String get ageCheckFailed;

  /// No description provided for @adultOnly.
  ///
  /// In en, this message translates to:
  /// **'PadelX is for adults 18 and older.'**
  String get adultOnly;

  /// No description provided for @legalAcknowledgement.
  ///
  /// In en, this message translates to:
  /// **'Legal acknowledgement'**
  String get legalAcknowledgement;

  /// No description provided for @legalReviewIntro.
  ///
  /// In en, this message translates to:
  /// **'Review the Terms of Use and Privacy Policy for the PadelX closed beta.'**
  String get legalReviewIntro;

  /// No description provided for @legalLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Acceptance status could not be loaded.'**
  String get legalLoadFailed;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matches;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @myMatches.
  ///
  /// In en, this message translates to:
  /// **'My Matches'**
  String get myMatches;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createMatch.
  ///
  /// In en, this message translates to:
  /// **'Create Match'**
  String get createMatch;

  /// No description provided for @createAMatch.
  ///
  /// In en, this message translates to:
  /// **'Create a Match'**
  String get createAMatch;

  /// No description provided for @editMatch.
  ///
  /// In en, this message translates to:
  /// **'Edit Match'**
  String get editMatch;

  /// No description provided for @matchDetails.
  ///
  /// In en, this message translates to:
  /// **'Match Details'**
  String get matchDetails;

  /// No description provided for @findMatch.
  ///
  /// In en, this message translates to:
  /// **'Find a Match'**
  String get findMatch;

  /// No description provided for @findPlayers.
  ///
  /// In en, this message translates to:
  /// **'Find Players'**
  String get findPlayers;

  /// No description provided for @players.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get players;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @playerProfile.
  ///
  /// In en, this message translates to:
  /// **'Player Profile'**
  String get playerProfile;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @friend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get friend;

  /// No description provided for @addFriend.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get addFriend;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @unfriend.
  ///
  /// In en, this message translates to:
  /// **'Unfriend'**
  String get unfriend;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @reportPlayer.
  ///
  /// In en, this message translates to:
  /// **'Report player'**
  String get reportPlayer;

  /// No description provided for @reportMessage.
  ///
  /// In en, this message translates to:
  /// **'Report message'**
  String get reportMessage;

  /// No description provided for @reportMatch.
  ///
  /// In en, this message translates to:
  /// **'Report match'**
  String get reportMatch;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get reportSubmitted;

  /// No description provided for @matchChat.
  ///
  /// In en, this message translates to:
  /// **'Match Chat'**
  String get matchChat;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @refreshMessages.
  ///
  /// In en, this message translates to:
  /// **'Refresh messages'**
  String get refreshMessages;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get noMessages;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get noConversations;

  /// No description provided for @messagesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Messages are unavailable right now.'**
  String get messagesUnavailable;

  /// No description provided for @couldNotSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not send this message.'**
  String get couldNotSendMessage;

  /// No description provided for @loadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load older'**
  String get loadOlder;

  /// No description provided for @loadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingEllipsis;

  /// No description provided for @markRead.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get markRead;

  /// No description provided for @markAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get markAsRead;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @viewMatch.
  ///
  /// In en, this message translates to:
  /// **'View Match'**
  String get viewMatch;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @playerLevel.
  ///
  /// In en, this message translates to:
  /// **'Player level'**
  String get playerLevel;

  /// No description provided for @chooseLevel.
  ///
  /// In en, this message translates to:
  /// **'Choose a level'**
  String get chooseLevel;

  /// No description provided for @preferredSide.
  ///
  /// In en, this message translates to:
  /// **'Preferred side'**
  String get preferredSide;

  /// No description provided for @areaOptional.
  ///
  /// In en, this message translates to:
  /// **'Area / Neighborhood (optional)'**
  String get areaOptional;

  /// No description provided for @anyArea.
  ///
  /// In en, this message translates to:
  /// **'Any area'**
  String get anyArea;

  /// No description provided for @searchAreas.
  ///
  /// In en, this message translates to:
  /// **'Search areas'**
  String get searchAreas;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @countryCode.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get countryCode;

  /// No description provided for @changeCity.
  ///
  /// In en, this message translates to:
  /// **'Change city'**
  String get changeCity;

  /// No description provided for @searchCitiesOnly.
  ///
  /// In en, this message translates to:
  /// **'Search cities only'**
  String get searchCitiesOnly;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @shortBio.
  ///
  /// In en, this message translates to:
  /// **'Short bio (optional)'**
  String get shortBio;

  /// No description provided for @discoverability.
  ///
  /// In en, this message translates to:
  /// **'Let other players find me'**
  String get discoverability;

  /// No description provided for @preferredLocation.
  ///
  /// In en, this message translates to:
  /// **'Preferred discovery location'**
  String get preferredLocation;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdated;

  /// No description provided for @helpSafety.
  ///
  /// In en, this message translates to:
  /// **'Help & Safety'**
  String get helpSafety;

  /// No description provided for @supportSafety.
  ///
  /// In en, this message translates to:
  /// **'Support & Safety'**
  String get supportSafety;

  /// No description provided for @communityGuidelines.
  ///
  /// In en, this message translates to:
  /// **'Community Guidelines'**
  String get communityGuidelines;

  /// No description provided for @blockedPlayers.
  ///
  /// In en, this message translates to:
  /// **'Blocked Players'**
  String get blockedPlayers;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact PadelX Support'**
  String get contactSupport;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountLower.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountLower;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safety;

  /// No description provided for @reportingBlockingAge.
  ///
  /// In en, this message translates to:
  /// **'Reporting, blocking, and age eligibility'**
  String get reportingBlockingAge;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @ratingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Rating submitted.'**
  String get ratingSubmitted;

  /// No description provided for @ratePlayer.
  ///
  /// In en, this message translates to:
  /// **'Rate player'**
  String get ratePlayer;

  /// No description provided for @ratePlayers.
  ///
  /// In en, this message translates to:
  /// **'Rate players'**
  String get ratePlayers;

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get submitRating;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get playAgain;

  /// No description provided for @cancelMatch.
  ///
  /// In en, this message translates to:
  /// **'Cancel Match'**
  String get cancelMatch;

  /// No description provided for @leaveMatch.
  ///
  /// In en, this message translates to:
  /// **'Leave Match'**
  String get leaveMatch;

  /// No description provided for @matchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Match unavailable'**
  String get matchUnavailable;

  /// No description provided for @noMatchesNearby.
  ///
  /// In en, this message translates to:
  /// **'No matches nearby yet.'**
  String get noMatchesNearby;

  /// No description provided for @matchesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Matches are unavailable right now.'**
  String get matchesUnavailable;

  /// No description provided for @findingMatches.
  ///
  /// In en, this message translates to:
  /// **'Finding nearby matches…'**
  String get findingMatches;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @filterMatches.
  ///
  /// In en, this message translates to:
  /// **'Filter matches'**
  String get filterMatches;

  /// No description provided for @club.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get club;

  /// No description provided for @dateTime.
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get dateTime;

  /// No description provided for @chooseDateTime.
  ///
  /// In en, this message translates to:
  /// **'Choose date and time'**
  String get chooseDateTime;

  /// No description provided for @totalPlayers.
  ///
  /// In en, this message translates to:
  /// **'Total players'**
  String get totalPlayers;

  /// No description provided for @spots.
  ///
  /// In en, this message translates to:
  /// **'Spots'**
  String get spots;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @whyReporting.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get whyReporting;

  /// No description provided for @additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details (optional)'**
  String get additionalDetails;

  /// No description provided for @couldNotOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Could not open this page. Contact {email}.'**
  String couldNotOpenPage(String email);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @unreadMessages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread message} other{{count} unread messages}}'**
  String unreadMessages(int count);

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @unreadNotification.
  ///
  /// In en, this message translates to:
  /// **'Unread notification'**
  String get unreadNotification;

  /// No description provided for @timeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Time unavailable'**
  String get timeUnavailable;

  /// No description provided for @newJoinRequest.
  ///
  /// In en, this message translates to:
  /// **'New join request'**
  String get newJoinRequest;

  /// No description provided for @joinRequestBody.
  ///
  /// In en, this message translates to:
  /// **'{name} requested to join your match at {club}.'**
  String joinRequestBody(String name, String club);

  /// No description provided for @requestApproved.
  ///
  /// In en, this message translates to:
  /// **'Request approved'**
  String get requestApproved;

  /// No description provided for @requestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get requestDeclined;

  /// No description provided for @requestApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Your request to join the match at {club} was approved.'**
  String requestApprovedBody(String club);

  /// No description provided for @requestDeclinedBody.
  ///
  /// In en, this message translates to:
  /// **'Your request to join the match at {club} was declined.'**
  String requestDeclinedBody(String club);

  /// No description provided for @newDirectMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newDirectMessage;

  /// No description provided for @newDirectMessageBody.
  ///
  /// In en, this message translates to:
  /// **'You have an unread direct message.'**
  String get newDirectMessageBody;

  /// No description provided for @newMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'New match message'**
  String get newMatchMessage;

  /// No description provided for @newMatchMessageBody.
  ///
  /// In en, this message translates to:
  /// **'You have an unread message in Match Chat.'**
  String get newMatchMessageBody;

  /// No description provided for @newFriendRequest.
  ///
  /// In en, this message translates to:
  /// **'New friend request'**
  String get newFriendRequest;

  /// No description provided for @friendRequestBody.
  ///
  /// In en, this message translates to:
  /// **'{name} sent you a friend request.'**
  String friendRequestBody(String name);

  /// No description provided for @friendRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Friend request accepted'**
  String get friendRequestAccepted;

  /// No description provided for @friendAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your friend request.'**
  String friendAcceptedBody(String name);

  /// No description provided for @playAgainInvite.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get playAgainInvite;

  /// No description provided for @playAgainBody.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to play again.'**
  String playAgainBody(String name);

  /// No description provided for @harassmentBullying.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get harassmentBullying;

  /// No description provided for @hateAbuse.
  ///
  /// In en, this message translates to:
  /// **'Hate or abusive content'**
  String get hateAbuse;

  /// No description provided for @sexualInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Sexual or inappropriate content'**
  String get sexualInappropriate;

  /// No description provided for @threatsUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Threats or unsafe behavior'**
  String get threatsUnsafe;

  /// No description provided for @spamScam.
  ///
  /// In en, this message translates to:
  /// **'Spam or scam'**
  String get spamScam;

  /// No description provided for @impersonation.
  ///
  /// In en, this message translates to:
  /// **'Impersonation'**
  String get impersonation;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @reportSubject.
  ///
  /// In en, this message translates to:
  /// **'Report {subject}'**
  String reportSubject(String subject);

  /// No description provided for @reportAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'You already reported this.'**
  String get reportAlreadySubmitted;

  /// No description provided for @reportRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You’ve submitted several reports recently. Please try again later.'**
  String get reportRateLimited;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Report could not be submitted. Please try again.'**
  String get reportFailed;

  /// No description provided for @thanksForSafety.
  ///
  /// In en, this message translates to:
  /// **'Thanks for helping keep PadelX safe.'**
  String get thanksForSafety;

  /// No description provided for @blockPlayer.
  ///
  /// In en, this message translates to:
  /// **'Block player'**
  String get blockPlayer;

  /// No description provided for @blockThisPlayer.
  ///
  /// In en, this message translates to:
  /// **'Block this player?'**
  String get blockThisPlayer;

  /// No description provided for @playerBlocked.
  ///
  /// In en, this message translates to:
  /// **'Player blocked.'**
  String get playerBlocked;

  /// No description provided for @playerBlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Player could not be blocked.'**
  String get playerBlockFailed;

  /// No description provided for @sharedMatchBlockExplanation.
  ///
  /// In en, this message translates to:
  /// **'Blocking prevents normal social discovery and contact. Shared-match access still follows match membership.'**
  String get sharedMatchBlockExplanation;

  /// No description provided for @friendBlockExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your friendship will be removed and normal social discovery and contact will be prevented. Shared-match access still follows match membership.'**
  String get friendBlockExplanation;

  /// No description provided for @nonFriendBlockExplanation.
  ///
  /// In en, this message translates to:
  /// **'Normal social discovery and contact with this player will be prevented. Shared-match access still follows match membership.'**
  String get nonFriendBlockExplanation;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @allPlayersRated.
  ///
  /// In en, this message translates to:
  /// **'All players rated.'**
  String get allPlayersRated;

  /// No description provided for @areaSuggestionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Area suggestions are unavailable. You can choose Any area.'**
  String get areaSuggestionsUnavailable;

  /// No description provided for @beFirstMatch.
  ///
  /// In en, this message translates to:
  /// **'Be the first to get a game started.'**
  String get beFirstMatch;

  /// No description provided for @cancelMatchQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel match?'**
  String get cancelMatchQuestion;

  /// No description provided for @checkAccessAgain.
  ///
  /// In en, this message translates to:
  /// **'Check access again'**
  String get checkAccessAgain;

  /// No description provided for @connectionRetry.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get connectionRetry;

  /// No description provided for @chooseClubTimePlayers.
  ///
  /// In en, this message translates to:
  /// **'Choose a club, time, and who the game is for.'**
  String get chooseClubTimePlayers;

  /// No description provided for @cityOrArea.
  ///
  /// In en, this message translates to:
  /// **'City or area'**
  String get cityOrArea;

  /// No description provided for @citySuggestionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'City suggestions are unavailable. Enter your city details below; Area can remain blank.'**
  String get citySuggestionsUnavailable;

  /// No description provided for @clearLocation.
  ///
  /// In en, this message translates to:
  /// **'Clear location'**
  String get clearLocation;

  /// No description provided for @closeAreaSelector.
  ///
  /// In en, this message translates to:
  /// **'Close area selector'**
  String get closeAreaSelector;

  /// No description provided for @closeLevelSelector.
  ///
  /// In en, this message translates to:
  /// **'Close level selector'**
  String get closeLevelSelector;

  /// No description provided for @clubName.
  ///
  /// In en, this message translates to:
  /// **'Club name'**
  String get clubName;

  /// No description provided for @clubNameAddress.
  ///
  /// In en, this message translates to:
  /// **'Club name or address'**
  String get clubNameAddress;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get confirmPassword;

  /// No description provided for @preservePlayersRequests.
  ///
  /// In en, this message translates to:
  /// **'Confirmed players and join requests will be preserved.'**
  String get preservePlayersRequests;

  /// No description provided for @createMatchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the match.'**
  String get createMatchFailed;

  /// No description provided for @dismissInviteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not dismiss this invitation.'**
  String get dismissInviteFailed;

  /// No description provided for @loadLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load that location.'**
  String get loadLocationFailed;

  /// No description provided for @loadProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile.'**
  String get loadProfileFailed;

  /// No description provided for @markReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not mark notification as read.'**
  String get markReadFailed;

  /// No description provided for @markAllReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not mark notifications as read.'**
  String get markAllReadFailed;

  /// No description provided for @ratingSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit rating.'**
  String get ratingSubmitFailed;

  /// No description provided for @accessCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify account access.'**
  String get accessCheckFailed;

  /// No description provided for @editProfileLocation.
  ///
  /// In en, this message translates to:
  /// **'Edit profile location'**
  String get editProfileLocation;

  /// No description provided for @enablePushQuestion.
  ///
  /// In en, this message translates to:
  /// **'Enable push notifications?'**
  String get enablePushQuestion;

  /// No description provided for @endFriendship.
  ///
  /// In en, this message translates to:
  /// **'End this friendship and direct social connection'**
  String get endFriendship;

  /// No description provided for @expand100.
  ///
  /// In en, this message translates to:
  /// **'Expand to 100 km'**
  String get expand100;

  /// No description provided for @findMatchesNear.
  ///
  /// In en, this message translates to:
  /// **'Find matches near'**
  String get findMatchesNear;

  /// No description provided for @findPadelMatches.
  ///
  /// In en, this message translates to:
  /// **'Find padel matches near you.'**
  String get findPadelMatches;

  /// No description provided for @findPadelPlayers.
  ///
  /// In en, this message translates to:
  /// **'Find padel players you may want to play with.'**
  String get findPadelPlayers;

  /// No description provided for @playFrequency.
  ///
  /// In en, this message translates to:
  /// **'How often do you play?'**
  String get playFrequency;

  /// No description provided for @howReportMatch.
  ///
  /// In en, this message translates to:
  /// **'How to report a match'**
  String get howReportMatch;

  /// No description provided for @howReportMessage.
  ///
  /// In en, this message translates to:
  /// **'How to report a message'**
  String get howReportMessage;

  /// No description provided for @howReportPlayer.
  ///
  /// In en, this message translates to:
  /// **'How to report a player'**
  String get howReportPlayer;

  /// No description provided for @isoCountryCode.
  ///
  /// In en, this message translates to:
  /// **'ISO country code'**
  String get isoCountryCode;

  /// No description provided for @immediateDanger.
  ///
  /// In en, this message translates to:
  /// **'Immediate danger'**
  String get immediateDanger;

  /// No description provided for @joinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join Requests'**
  String get joinRequests;

  /// No description provided for @joinGames.
  ///
  /// In en, this message translates to:
  /// **'Join games that need players.'**
  String get joinGames;

  /// No description provided for @keepMatch.
  ///
  /// In en, this message translates to:
  /// **'Keep Match'**
  String get keepMatch;

  /// No description provided for @loadingPadelX.
  ///
  /// In en, this message translates to:
  /// **'LOADING PADELX'**
  String get loadingPadelX;

  /// No description provided for @leaveMatchQuestion.
  ///
  /// In en, this message translates to:
  /// **'Leave match?'**
  String get leaveMatchQuestion;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @loadMoreNearby.
  ///
  /// In en, this message translates to:
  /// **'Load more nearby matches'**
  String get loadMoreNearby;

  /// No description provided for @loadOlderMatches.
  ///
  /// In en, this message translates to:
  /// **'Load older matches'**
  String get loadOlderMatches;

  /// No description provided for @loadOlderNotifications.
  ///
  /// In en, this message translates to:
  /// **'Load older notifications'**
  String get loadOlderNotifications;

  /// No description provided for @loadingJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Loading join requests...'**
  String get loadingJoinRequests;

  /// No description provided for @matchCancelled.
  ///
  /// In en, this message translates to:
  /// **'Match cancelled.'**
  String get matchCancelled;

  /// No description provided for @matchDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Match discovery'**
  String get matchDiscovery;

  /// No description provided for @matchUpdated.
  ///
  /// In en, this message translates to:
  /// **'Match updated successfully.'**
  String get matchUpdated;

  /// No description provided for @notificationEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Match, message, and social updates will appear here.'**
  String get notificationEmptyBody;

  /// No description provided for @organizedJoinedMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches you organize or have joined.'**
  String get organizedJoinedMatches;

  /// No description provided for @acceptedFriendsMessaging.
  ///
  /// In en, this message translates to:
  /// **'Messaging is available to accepted friends.'**
  String get acceptedFriendsMessaging;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @moreSafetyActions.
  ///
  /// In en, this message translates to:
  /// **'More safety actions'**
  String get moreSafetyActions;

  /// No description provided for @needHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help or want to report a safety concern?'**
  String get needHelp;

  /// No description provided for @neighborhoodArea.
  ///
  /// In en, this message translates to:
  /// **'Neighborhood or area'**
  String get neighborhoodArea;

  /// No description provided for @noOtherPlayersRate.
  ///
  /// In en, this message translates to:
  /// **'No other players from this match to rate.'**
  String get noOtherPlayersRate;

  /// No description provided for @noPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get noPendingRequests;

  /// No description provided for @noRatings.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get noRatings;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @notificationPreferencesFailed.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences could not be saved.'**
  String get notificationPreferencesFailed;

  /// No description provided for @notificationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notifications are unavailable right now.'**
  String get notificationsUnavailable;

  /// No description provided for @openReportMatchHelp.
  ///
  /// In en, this message translates to:
  /// **'Open Match Details, then choose Report match from the safety actions.'**
  String get openReportMatchHelp;

  /// No description provided for @openMatches.
  ///
  /// In en, this message translates to:
  /// **'Open matches'**
  String get openMatches;

  /// No description provided for @openReportPlayerHelp.
  ///
  /// In en, this message translates to:
  /// **'Open the player’s profile, tap More actions, then Report player.'**
  String get openReportPlayerHelp;

  /// No description provided for @pendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending Requests'**
  String get pendingRequests;

  /// No description provided for @playedWith.
  ///
  /// In en, this message translates to:
  /// **'People you\'ve played with'**
  String get playedWith;

  /// No description provided for @permanentlyDelete.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your PadelX account'**
  String get permanentlyDelete;

  /// No description provided for @photoCropHelp.
  ///
  /// In en, this message translates to:
  /// **'Photos are center-cropped and saved as a 512×512 JPEG.'**
  String get photoCropHelp;

  /// No description provided for @unblockedNotice.
  ///
  /// In en, this message translates to:
  /// **'Player unblocked. Friendship is not restored automatically.'**
  String get unblockedNotice;

  /// No description provided for @chooseFutureDate.
  ///
  /// In en, this message translates to:
  /// **'Please choose a future date and time.'**
  String get chooseFutureDate;

  /// No description provided for @policyCategory.
  ///
  /// In en, this message translates to:
  /// **'Policy category'**
  String get policyCategory;

  /// No description provided for @pressHoldReport.
  ///
  /// In en, this message translates to:
  /// **'Press and hold a message from another player, then choose Report message.'**
  String get pressHoldReport;

  /// No description provided for @preventSocialContact.
  ///
  /// In en, this message translates to:
  /// **'Prevent normal social discovery and contact'**
  String get preventSocialContact;

  /// No description provided for @pushUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Push notification settings could not be updated.'**
  String get pushUpdateFailed;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get pushNotifications;

  /// No description provided for @pushPermissionCategories.
  ///
  /// In en, this message translates to:
  /// **'Push permission and notification categories'**
  String get pushPermissionCategories;

  /// No description provided for @questionsSafety.
  ///
  /// In en, this message translates to:
  /// **'Questions or safety concerns'**
  String get questionsSafety;

  /// No description provided for @rateInDetails.
  ///
  /// In en, this message translates to:
  /// **'Rate in match details'**
  String get rateInDetails;

  /// No description provided for @refreshMatches.
  ///
  /// In en, this message translates to:
  /// **'Refresh matches'**
  String get refreshMatches;

  /// No description provided for @regionOptional.
  ///
  /// In en, this message translates to:
  /// **'Region / State / Province (optional)'**
  String get regionOptional;

  /// No description provided for @relationshipActions.
  ///
  /// In en, this message translates to:
  /// **'Relationship actions'**
  String get relationshipActions;

  /// No description provided for @restrictionEnds.
  ///
  /// In en, this message translates to:
  /// **'Restriction ends'**
  String get restrictionEnds;

  /// No description provided for @reviewUnblock.
  ///
  /// In en, this message translates to:
  /// **'Review and unblock players'**
  String get reviewUnblock;

  /// No description provided for @safetyExpectations.
  ///
  /// In en, this message translates to:
  /// **'Safety expectations for the PadelX beta'**
  String get safetyExpectations;

  /// No description provided for @searchClubLocation.
  ///
  /// In en, this message translates to:
  /// **'Search club or location'**
  String get searchClubLocation;

  /// No description provided for @searchCityArea.
  ///
  /// In en, this message translates to:
  /// **'Search for a city or area'**
  String get searchCityArea;

  /// No description provided for @searchPadelClub.
  ///
  /// In en, this message translates to:
  /// **'Search for a padel club'**
  String get searchPadelClub;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @sendPrivateReport.
  ///
  /// In en, this message translates to:
  /// **'Send a private safety report'**
  String get sendPrivateReport;

  /// No description provided for @setUpGame.
  ///
  /// In en, this message translates to:
  /// **'Set up your game'**
  String get setUpGame;

  /// No description provided for @sharedMatchRatings.
  ///
  /// In en, this message translates to:
  /// **'Shared match ratings'**
  String get sharedMatchRatings;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @tellPlayersGame.
  ///
  /// In en, this message translates to:
  /// **'Tell players a little about your game'**
  String get tellPlayersGame;

  /// No description provided for @thisMatchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This match is no longer available.'**
  String get thisMatchUnavailable;

  /// No description provided for @matchMayRemoved.
  ///
  /// In en, this message translates to:
  /// **'This match may have been cancelled or removed.'**
  String get matchMayRemoved;

  /// No description provided for @notificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This notification is unavailable.'**
  String get notificationUnavailable;

  /// No description provided for @socialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This social action is unavailable.'**
  String get socialUnavailable;

  /// No description provided for @cancelMatchWarning.
  ///
  /// In en, this message translates to:
  /// **'This will remove the match for everyone and cannot be undone.'**
  String get cancelMatchWarning;

  /// No description provided for @totalCapacity.
  ///
  /// In en, this message translates to:
  /// **'Total player capacity'**
  String get totalCapacity;

  /// No description provided for @widerRadius.
  ///
  /// In en, this message translates to:
  /// **'Try a wider radius or change location.'**
  String get widerRadius;

  /// No description provided for @loadMoreRetry.
  ///
  /// In en, this message translates to:
  /// **'Try loading more again'**
  String get loadMoreRetry;

  /// No description provided for @upcomingMatches.
  ///
  /// In en, this message translates to:
  /// **'Upcoming matches'**
  String get upcomingMatches;

  /// No description provided for @updateMatchDetails.
  ///
  /// In en, this message translates to:
  /// **'Update match details'**
  String get updateMatchDetails;

  /// No description provided for @matchUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates about your matches and requests.'**
  String get matchUpdates;

  /// No description provided for @usePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use photo'**
  String get usePhoto;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @profileVisibilityHelp.
  ///
  /// In en, this message translates to:
  /// **'When off, your profile will not appear in Find Players. Players may still see it through matches, friendships, messages, invitations, or shared history.'**
  String get profileVisibilityHelp;

  /// No description provided for @capacityHelp.
  ///
  /// In en, this message translates to:
  /// **'You count as one player · maximum 4'**
  String get capacityHelp;

  /// No description provided for @noBlockedPlayers.
  ///
  /// In en, this message translates to:
  /// **'You have not blocked any players.'**
  String get noBlockedPlayers;

  /// No description provided for @spotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Your confirmed spot will become available.'**
  String get spotAvailable;

  /// No description provided for @padelProfile.
  ///
  /// In en, this message translates to:
  /// **'Your padel profile'**
  String get padelProfile;

  /// No description provided for @couldNotOpenEmail.
  ///
  /// In en, this message translates to:
  /// **'Could not open email. Contact support.padelx@gmail.com.'**
  String get couldNotOpenEmail;

  /// No description provided for @blockedPlayersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Blocked players are unavailable right now.'**
  String get blockedPlayersUnavailable;

  /// No description provided for @startupFailed.
  ///
  /// In en, this message translates to:
  /// **'PadelX could not start.'**
  String get startupFailed;

  /// No description provided for @verificationSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to'**
  String get verificationSent;

  /// No description provided for @legalAgreement.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Use and acknowledge the Privacy Policy.'**
  String get legalAgreement;

  /// No description provided for @resetEmailHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we’ll send you a link to reset your password.'**
  String get resetEmailHelp;

  /// No description provided for @signInDiscoverPlayers.
  ///
  /// In en, this message translates to:
  /// **'Sign in to discover players.'**
  String get signInDiscoverPlayers;

  /// No description provided for @locationNoCoordinates.
  ///
  /// In en, this message translates to:
  /// **'That location has no coordinates.'**
  String get locationNoCoordinates;

  /// No description provided for @levelValue.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelValue(String level);

  /// No description provided for @radiusKm.
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String radiusKm(String distance);

  /// No description provided for @playerCountChoice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 player} other{{count} players}}'**
  String playerCountChoice(int count);

  /// No description provided for @playersIn.
  ///
  /// In en, this message translates to:
  /// **'Players in\n{city}'**
  String playersIn(String city);

  /// No description provided for @chooseAreaIn.
  ///
  /// In en, this message translates to:
  /// **'Choose an area in {city}'**
  String chooseAreaIn(String city);

  /// No description provided for @chooseAreaInCountry.
  ///
  /// In en, this message translates to:
  /// **'Choose an area in {city}, {countryCode}.'**
  String chooseAreaInCountry(String city, String countryCode);

  /// No description provided for @currentArea.
  ///
  /// In en, this message translates to:
  /// **'Current area: {area}'**
  String currentArea(String area);

  /// No description provided for @preferredSideDisplay.
  ///
  /// In en, this message translates to:
  /// **'{side} side'**
  String preferredSideDisplay(String side);

  /// No description provided for @leftSide.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get leftSide;

  /// No description provided for @rightSide.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get rightSide;

  /// No description provided for @eitherSide.
  ///
  /// In en, this message translates to:
  /// **'Either'**
  String get eitherSide;

  /// No description provided for @playedTogetherCount.
  ///
  /// In en, this message translates to:
  /// **'Played together {count, plural, =1{1 time} other{{count} times}}'**
  String playedTogetherCount(int count);

  /// No description provided for @lastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played {date}'**
  String lastPlayed(String date);

  /// No description provided for @ratingAverage.
  ///
  /// In en, this message translates to:
  /// **'{average} stars'**
  String ratingAverage(String average);

  /// No description provided for @rateNamedPlayer.
  ///
  /// In en, this message translates to:
  /// **'Rate {name}'**
  String rateNamedPlayer(String name);

  /// No description provided for @howWasPlaying.
  ///
  /// In en, this message translates to:
  /// **'How was playing with {name}?'**
  String howWasPlaying(String name);

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @playedWithFilter.
  ///
  /// In en, this message translates to:
  /// **'Played With'**
  String get playedWithFilter;

  /// No description provided for @noAreasFound.
  ///
  /// In en, this message translates to:
  /// **'No areas found.'**
  String get noAreasFound;

  /// No description provided for @playerLevelSide.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · {side} side'**
  String playerLevelSide(String level, String side);

  /// No description provided for @playerNoRatingsMatches.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet · {matches, plural, =1{1 completed match} other{{matches} completed matches}}'**
  String playerNoRatingsMatches(int matches);

  /// No description provided for @playerRatingMatches.
  ///
  /// In en, this message translates to:
  /// **'{rating} stars ({ratings}) · {matches, plural, =1{1 completed match} other{{matches} completed matches}}'**
  String playerRatingMatches(String rating, int ratings, int matches);

  /// No description provided for @emailAppFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open your email app. You can contact us at {email}.'**
  String emailAppFailed(String email);

  /// No description provided for @pushPermissionExplanation.
  ///
  /// In en, this message translates to:
  /// **'PadelX will ask iOS for permission and register this device. You can change individual categories at any time.'**
  String get pushPermissionExplanation;

  /// No description provided for @pushBlockedHelp.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked in device settings. Enable them there to receive PadelX push notifications.'**
  String get pushBlockedHelp;

  /// No description provided for @pushBuildUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are not configured for this build. Notification categories can still be prepared below.'**
  String get pushBuildUnavailable;

  /// No description provided for @pushSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Open your device Settings, select PadelX, then enable Notifications before trying again.'**
  String get pushSettingsHelp;

  /// No description provided for @pushCategoriesFuture.
  ///
  /// In en, this message translates to:
  /// **'These categories are saved now and will control push delivery as notification types are enabled in later phases.'**
  String get pushCategoriesFuture;

  /// No description provided for @inviteAfterCreate.
  ///
  /// In en, this message translates to:
  /// **'Invite {name} after creating'**
  String inviteAfterCreate(String name);

  /// No description provided for @ratingSummary.
  ///
  /// In en, this message translates to:
  /// **'{average} stars ({count, plural, =1{1 rating} other{{count} ratings}})'**
  String ratingSummary(String average, int count);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @browseMatches.
  ///
  /// In en, this message translates to:
  /// **'Browse Matches'**
  String get browseMatches;

  /// No description provided for @loadingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications'**
  String get loadingNotifications;

  /// No description provided for @loadingYourMatches.
  ///
  /// In en, this message translates to:
  /// **'Loading your matches…'**
  String get loadingYourMatches;

  /// No description provided for @yourMatchesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your matches are unavailable right now.'**
  String get yourMatchesUnavailable;

  /// No description provided for @noUpcomingMatches.
  ///
  /// In en, this message translates to:
  /// **'No upcoming matches.'**
  String get noUpcomingMatches;

  /// No description provided for @findOpenOrOrganize.
  ///
  /// In en, this message translates to:
  /// **'Find an open match or organize your next game.'**
  String get findOpenOrOrganize;

  /// No description provided for @noPastMatches.
  ///
  /// In en, this message translates to:
  /// **'No past matches yet.'**
  String get noPastMatches;

  /// No description provided for @completedAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Completed matches will appear here.'**
  String get completedAppearHere;

  /// No description provided for @profileNeedsInfo.
  ///
  /// In en, this message translates to:
  /// **'Your profile needs a little more information'**
  String get profileNeedsInfo;

  /// No description provided for @addNameLevel.
  ///
  /// In en, this message translates to:
  /// **'Add your display name and level to finish setting it up.'**
  String get addNameLevel;

  /// No description provided for @profileStatsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile stats'**
  String get profileStatsFailed;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @ratings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get ratings;

  /// No description provided for @completedMatches.
  ///
  /// In en, this message translates to:
  /// **'Completed matches'**
  String get completedMatches;

  /// No description provided for @repeatPlayers.
  ///
  /// In en, this message translates to:
  /// **'Repeat players'**
  String get repeatPlayers;

  /// No description provided for @sharedMatches.
  ///
  /// In en, this message translates to:
  /// **'Shared matches'**
  String get sharedMatches;

  /// No description provided for @playerProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this player profile'**
  String get playerProfileFailed;

  /// No description provided for @loadingSubmittedRatings.
  ///
  /// In en, this message translates to:
  /// **'Loading submitted ratings'**
  String get loadingSubmittedRatings;

  /// No description provided for @submittedRatingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load submitted ratings.'**
  String get submittedRatingsFailed;

  /// No description provided for @playerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Player unavailable'**
  String get playerUnavailable;

  /// No description provided for @dateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Date unavailable'**
  String get dateUnavailable;

  /// No description provided for @occasional.
  ///
  /// In en, this message translates to:
  /// **'Occasionally'**
  String get occasional;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @severalPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Several times a week'**
  String get severalPerWeek;

  /// No description provided for @legalAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get legalAgreePrefix;

  /// No description provided for @legalAgreeMiddle.
  ///
  /// In en, this message translates to:
  /// **' and acknowledge the '**
  String get legalAgreeMiddle;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get period;

  /// No description provided for @matchesTogether.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match together} other{{count} matches together}}'**
  String matchesTogether(int count);

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get completeProfile;

  /// No description provided for @requestPending.
  ///
  /// In en, this message translates to:
  /// **'Request Pending'**
  String get requestPending;

  /// No description provided for @organizing.
  ///
  /// In en, this message translates to:
  /// **'Organizing'**
  String get organizing;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @ratingNotEligible.
  ///
  /// In en, this message translates to:
  /// **'This rating was already submitted or is not eligible.'**
  String get ratingNotEligible;

  /// No description provided for @match.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get match;

  /// No description provided for @findingOpenMatches.
  ///
  /// In en, this message translates to:
  /// **'Finding open matches…'**
  String get findingOpenMatches;

  /// No description provided for @deletedPlayer.
  ///
  /// In en, this message translates to:
  /// **'Deleted player'**
  String get deletedPlayer;

  /// No description provided for @signOutLower.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutLower;

  /// No description provided for @createMatchGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Create a match and get a game started.'**
  String get createMatchGetStarted;

  /// No description provided for @creatingMatch.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creatingMatch;

  /// No description provided for @emailAddressFallback.
  ///
  /// In en, this message translates to:
  /// **'your email address'**
  String get emailAddressFallback;

  /// No description provided for @checkingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checkingEllipsis;

  /// No description provided for @verifiedMyEmail.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified my email'**
  String get verifiedMyEmail;

  /// No description provided for @sendingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sendingEllipsis;

  /// No description provided for @resendAvailableIn.
  ///
  /// In en, this message translates to:
  /// **'Resend available in {seconds}s'**
  String resendAvailableIn(Object seconds);

  /// No description provided for @resendVerificationEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get resendVerificationEmail;

  /// No description provided for @signingOutEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Signing out...'**
  String get signingOutEllipsis;

  /// No description provided for @emailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Your email is not verified yet. Open the link in your email, then try again.'**
  String get emailNotVerified;

  /// No description provided for @emailCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check your email yet. Please try again.'**
  String get emailCheckFailed;

  /// No description provided for @verificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'A new verification email was sent.'**
  String get verificationEmailSent;

  /// No description provided for @verificationResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resend the email. Please try again.'**
  String get verificationResendFailed;

  /// No description provided for @signOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign out. Please try again.'**
  String get signOutFailed;

  /// No description provided for @tooManyAttemptsWait.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get tooManyAttemptsWait;

  /// No description provided for @networkRetry.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get networkRetry;

  /// No description provided for @accountUnavailableSupport.
  ///
  /// In en, this message translates to:
  /// **'This account is unavailable. Contact PadelX support.'**
  String get accountUnavailableSupport;

  /// No description provided for @recentLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign out, log in again, and retry.'**
  String get recentLoginRequired;

  /// No description provided for @requestFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not complete that request. Please try again.'**
  String get requestFailedGeneric;

  /// No description provided for @ageConfirmContinue.
  ///
  /// In en, this message translates to:
  /// **'Confirm that you are 18 years of age or older to continue.'**
  String get ageConfirmContinue;

  /// No description provided for @legalAgreeContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree to the Terms of Use and acknowledge the Privacy Policy to continue.'**
  String get legalAgreeContinue;

  /// No description provided for @enterEmailPeriod.
  ///
  /// In en, this message translates to:
  /// **'Enter your email.'**
  String get enterEmailPeriod;

  /// No description provided for @validEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get validEmailRequired;

  /// No description provided for @enterPasswordPeriod.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get enterPasswordPeriod;

  /// No description provided for @ageRecordAfterCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Your account was created, but age eligibility could not be confirmed. Try again to continue.'**
  String get ageRecordAfterCreateFailed;

  /// No description provided for @legalRecordAfterCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Your account was created, but legal acknowledgement could not be recorded. Try again to continue.'**
  String get legalRecordAfterCreateFailed;

  /// No description provided for @accountNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account was found with that email.'**
  String get accountNotFound;

  /// No description provided for @incorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get incorrectCredentials;

  /// No description provided for @createAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create your account. Please try again.'**
  String get createAccountFailed;

  /// No description provided for @emailAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'An account already uses that email. Try logging in.'**
  String get emailAlreadyUsed;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Your password must be at least 6 characters.'**
  String get weakPassword;

  /// No description provided for @tooManyAttemptsLater.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get tooManyAttemptsLater;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not log in. Please try again.'**
  String get loginFailed;

  /// No description provided for @genericCreateAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create your account. Please try again.'**
  String get genericCreateAccountFailed;

  /// No description provided for @somethingWrongRetry.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWrongRetry;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get passwordResetSent;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @welcomeBackAuth.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. Your next match is waiting.'**
  String get welcomeBackAuth;

  /// No description provided for @createVerifyAuth.
  ///
  /// In en, this message translates to:
  /// **'Create your account, then verify your email to get started.'**
  String get createVerifyAuth;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get createPassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @loggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging in...'**
  String get loggingIn;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get creatingAccount;

  /// No description provided for @retryAgeConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Retry age confirmation'**
  String get retryAgeConfirmation;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @switchToSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don’t have an account? Sign Up'**
  String get switchToSignUp;

  /// No description provided for @switchToLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get switchToLogin;

  /// No description provided for @resetEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the reset email. Please try again.'**
  String get resetEmailFailed;

  /// No description provided for @tooManyRequestsLater.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get tooManyRequestsLater;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// No description provided for @legacyLevelHelp.
  ///
  /// In en, this message translates to:
  /// **'Current value \"{value}\" is legacy. Choose a numeric level.'**
  String legacyLevelHelp(Object value);

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @chooseAnotherPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose another'**
  String get chooseAnotherPhoto;

  /// No description provided for @unblockingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Unblocking…'**
  String get unblockingEllipsis;

  /// No description provided for @profileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Profile unavailable'**
  String get profileUnavailable;

  /// No description provided for @levelNotSet.
  ///
  /// In en, this message translates to:
  /// **'Level not set'**
  String get levelNotSet;

  /// No description provided for @couldNotLoadPlayers.
  ///
  /// In en, this message translates to:
  /// **'Could not load players.'**
  String get couldNotLoadPlayers;

  /// No description provided for @playedWithEmpty.
  ///
  /// In en, this message translates to:
  /// **'People you play with will appear here after completed matches.'**
  String get playedWithEmpty;

  /// No description provided for @notRated.
  ///
  /// In en, this message translates to:
  /// **'Not rated'**
  String get notRated;

  /// No description provided for @locationSuggestionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location suggestions are temporarily unavailable.'**
  String get locationSuggestionsUnavailable;

  /// No description provided for @conversationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Conversation unavailable'**
  String get conversationUnavailable;

  /// No description provided for @conversationReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This conversation is read-only.'**
  String get conversationReadOnly;

  /// No description provided for @loadOlderMessages.
  ///
  /// In en, this message translates to:
  /// **'Load older messages'**
  String get loadOlderMessages;

  /// No description provided for @messageFrom.
  ///
  /// In en, this message translates to:
  /// **'Message from {name}'**
  String messageFrom(Object name);

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @enterPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPasswordHint;

  /// No description provided for @reasonHarassmentAbuse.
  ///
  /// In en, this message translates to:
  /// **'Harassment or abusive conduct'**
  String get reasonHarassmentAbuse;

  /// No description provided for @reasonHateDiscrimination.
  ///
  /// In en, this message translates to:
  /// **'Hate or discriminatory conduct'**
  String get reasonHateDiscrimination;

  /// No description provided for @reasonSexualMisconduct.
  ///
  /// In en, this message translates to:
  /// **'Sexual or inappropriate conduct'**
  String get reasonSexualMisconduct;

  /// No description provided for @reasonThreatsUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Threats or unsafe behavior'**
  String get reasonThreatsUnsafe;

  /// No description provided for @reasonSpamScams.
  ///
  /// In en, this message translates to:
  /// **'Spam or scams'**
  String get reasonSpamScams;

  /// No description provided for @reasonPrivacyViolation.
  ///
  /// In en, this message translates to:
  /// **'Privacy violation'**
  String get reasonPrivacyViolation;

  /// No description provided for @reasonFraudDeception.
  ///
  /// In en, this message translates to:
  /// **'Fraud or deception'**
  String get reasonFraudDeception;

  /// No description provided for @reasonMaliciousReporting.
  ///
  /// In en, this message translates to:
  /// **'Misuse of reporting'**
  String get reasonMaliciousReporting;

  /// No description provided for @accountTemporarilySuspended.
  ///
  /// In en, this message translates to:
  /// **'Account temporarily suspended'**
  String get accountTemporarilySuspended;

  /// No description provided for @accountRestricted.
  ///
  /// In en, this message translates to:
  /// **'Account restricted'**
  String get accountRestricted;

  /// No description provided for @accessTemporarilyRestricted.
  ///
  /// In en, this message translates to:
  /// **'Your access to PadelX has been temporarily restricted.'**
  String get accessTemporarilyRestricted;

  /// No description provided for @accessRestricted.
  ///
  /// In en, this message translates to:
  /// **'Your access to PadelX has been restricted.'**
  String get accessRestricted;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// No description provided for @findingYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get findingYourLocation;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useCurrentLocation;

  /// No description provided for @currentLocationRadius.
  ///
  /// In en, this message translates to:
  /// **'Current location · {distance} km radius'**
  String currentLocationRadius(Object distance);

  /// No description provided for @searchRadius.
  ///
  /// In en, this message translates to:
  /// **'Search radius: {distance} km'**
  String searchRadius(Object distance);

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @noOpenMatches.
  ///
  /// In en, this message translates to:
  /// **'No open matches yet'**
  String get noOpenMatches;

  /// No description provided for @noMatchesFilters.
  ///
  /// In en, this message translates to:
  /// **'No matches match your filters'**
  String get noMatchesFilters;

  /// No description provided for @noMatchesRadius.
  ///
  /// In en, this message translates to:
  /// **'No matches within {distance} km'**
  String noMatchesRadius(Object distance);

  /// No description provided for @organizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get organizer;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get full;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @profileDetailsSafe.
  ///
  /// In en, this message translates to:
  /// **'Your profile details are safe. Check your connection and try again.'**
  String get profileDetailsSafe;

  /// No description provided for @visibleDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Visible in Players discovery'**
  String get visibleDiscovery;

  /// No description provided for @hiddenDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Hidden from Players discovery'**
  String get hiddenDiscovery;

  /// No description provided for @setCityPlayers.
  ///
  /// In en, this message translates to:
  /// **'Set your city to find players'**
  String get setCityPlayers;

  /// No description provided for @addCoarseCity.
  ///
  /// In en, this message translates to:
  /// **'Add a coarse city in your profile. Your precise location is never shared.'**
  String get addCoarseCity;

  /// No description provided for @playersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Players are unavailable right now'**
  String get playersUnavailable;

  /// No description provided for @morePlayersMayMatch.
  ///
  /// In en, this message translates to:
  /// **'More players may match'**
  String get morePlayersMayMatch;

  /// No description provided for @noPlayersFilters.
  ///
  /// In en, this message translates to:
  /// **'No players match these filters'**
  String get noPlayersFilters;

  /// No description provided for @continueSearchingPlayers.
  ///
  /// In en, this message translates to:
  /// **'Continue searching the remaining players.'**
  String get continueSearchingPlayers;

  /// No description provided for @broadenPlayerFilters.
  ///
  /// In en, this message translates to:
  /// **'Try a broader area, level, side, or relationship filter.'**
  String get broadenPlayerFilters;

  /// No description provided for @anyLevel.
  ///
  /// In en, this message translates to:
  /// **'Any level'**
  String get anyLevel;

  /// No description provided for @anySide.
  ///
  /// In en, this message translates to:
  /// **'Any side'**
  String get anySide;

  /// No description provided for @eitherOnly.
  ///
  /// In en, this message translates to:
  /// **'Either only'**
  String get eitherOnly;

  /// No description provided for @unfriendQuestion.
  ///
  /// In en, this message translates to:
  /// **'Unfriend this player?'**
  String get unfriendQuestion;

  /// No description provided for @unfriendExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your friendship and direct social connection will end.'**
  String get unfriendExplanation;

  /// No description provided for @incomingRequests.
  ///
  /// In en, this message translates to:
  /// **'Incoming Requests'**
  String get incomingRequests;

  /// No description provided for @outgoingRequests.
  ///
  /// In en, this message translates to:
  /// **'Outgoing Requests'**
  String get outgoingRequests;

  /// No description provided for @acceptedFriends.
  ///
  /// In en, this message translates to:
  /// **'Accepted Friends'**
  String get acceptedFriends;

  /// No description provided for @noFriendsYet.
  ///
  /// In en, this message translates to:
  /// **'No friends yet.'**
  String get noFriendsYet;

  /// No description provided for @noRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests.'**
  String get noRequests;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @accountDeletionInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Deletion'**
  String get accountDeletionInfo;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @matchMessages.
  ///
  /// In en, this message translates to:
  /// **'Match messages'**
  String get matchMessages;

  /// No description provided for @joinRequestsCategory.
  ///
  /// In en, this message translates to:
  /// **'Join requests'**
  String get joinRequestsCategory;

  /// No description provided for @friendRequestsCategory.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get friendRequestsCategory;

  /// No description provided for @friendAcceptedCategory.
  ///
  /// In en, this message translates to:
  /// **'Friend accepted'**
  String get friendAcceptedCategory;

  /// No description provided for @matchUpdatesCategory.
  ///
  /// In en, this message translates to:
  /// **'Match updates'**
  String get matchUpdatesCategory;

  /// No description provided for @accountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account management'**
  String get accountManagement;

  /// No description provided for @pushOn.
  ///
  /// In en, this message translates to:
  /// **'Push notifications on'**
  String get pushOn;

  /// No description provided for @pushOff.
  ///
  /// In en, this message translates to:
  /// **'Push notifications off'**
  String get pushOff;

  /// No description provided for @notificationsBlockedSettings.
  ///
  /// In en, this message translates to:
  /// **'Notifications blocked in device settings'**
  String get notificationsBlockedSettings;

  /// No description provided for @pushUnavailableBuild.
  ///
  /// In en, this message translates to:
  /// **'Unavailable in this build'**
  String get pushUnavailableBuild;

  /// No description provided for @checkingDevicePermission.
  ///
  /// In en, this message translates to:
  /// **'Checking device permission…'**
  String get checkingDevicePermission;

  /// No description provided for @deletionExplanation.
  ///
  /// In en, this message translates to:
  /// **'Deletion is permanent. Future matches you organize will be cancelled, and you will leave future matches you joined. Historical participation will be anonymized. Ratings involving your account will be removed.'**
  String get deletionExplanation;

  /// No description provided for @deletionPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password for this deletion attempt.'**
  String get deletionPasswordRequired;

  /// No description provided for @deletionRequested.
  ///
  /// In en, this message translates to:
  /// **'Account deletion requested. You are signed out. Cleanup continues securely in the background.'**
  String get deletionRequested;

  /// No description provided for @signedOutNotice.
  ///
  /// In en, this message translates to:
  /// **'You are signed out.'**
  String get signedOutNotice;

  /// No description provided for @requestingDeletion.
  ///
  /// In en, this message translates to:
  /// **'Requesting deletion…'**
  String get requestingDeletion;

  /// No description provided for @permanentlyDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete my account'**
  String get permanentlyDeleteAccount;

  /// No description provided for @eligibilityConfirmFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm eligibility. Check your connection and try again.'**
  String get eligibilityConfirmFailed;

  /// No description provided for @confirmingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Confirming...'**
  String get confirmingEllipsis;

  /// No description provided for @legalRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not record your acknowledgement. Try again.'**
  String get legalRecordFailed;

  /// No description provided for @legalRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Your acknowledgement was recorded, but its status could not be refreshed. Try again.'**
  String get legalRefreshFailed;

  /// No description provided for @savingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingEllipsis;

  /// No description provided for @guidelineAdultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Adults only'**
  String get guidelineAdultsTitle;

  /// No description provided for @guidelineAdultsBody.
  ///
  /// In en, this message translates to:
  /// **'PadelX is for users 18 and older.'**
  String get guidelineAdultsBody;

  /// No description provided for @guidelineRespectTitle.
  ///
  /// In en, this message translates to:
  /// **'Respect other players'**
  String get guidelineRespectTitle;

  /// No description provided for @guidelineRespectBody.
  ///
  /// In en, this message translates to:
  /// **'Treat players respectfully. Harassment, bullying, intimidation, and targeted abuse are not allowed.'**
  String get guidelineRespectBody;

  /// No description provided for @guidelineHateTitle.
  ///
  /// In en, this message translates to:
  /// **'Hate and discrimination'**
  String get guidelineHateTitle;

  /// No description provided for @guidelineHateBody.
  ///
  /// In en, this message translates to:
  /// **'Hateful or discriminatory content and conduct are not allowed.'**
  String get guidelineHateBody;

  /// No description provided for @guidelineSexualTitle.
  ///
  /// In en, this message translates to:
  /// **'Sexual or inappropriate conduct'**
  String get guidelineSexualTitle;

  /// No description provided for @guidelineSexualBody.
  ///
  /// In en, this message translates to:
  /// **'Do not send unwanted sexual content or engage in sexual harassment or other inappropriate behavior.'**
  String get guidelineSexualBody;

  /// No description provided for @guidelineThreatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Threats and unsafe behavior'**
  String get guidelineThreatsTitle;

  /// No description provided for @guidelineThreatsBody.
  ///
  /// In en, this message translates to:
  /// **'Threats, violence, intimidation, and deliberately unsafe conduct are not allowed.'**
  String get guidelineThreatsBody;

  /// No description provided for @guidelineSpamTitle.
  ///
  /// In en, this message translates to:
  /// **'Spam, scams, and deception'**
  String get guidelineSpamTitle;

  /// No description provided for @guidelineSpamBody.
  ///
  /// In en, this message translates to:
  /// **'Do not post scams, spam, deceptive listings, fraudulent payment requests, or intentionally misleading match information.'**
  String get guidelineSpamBody;

  /// No description provided for @guidelineImpersonationBody.
  ///
  /// In en, this message translates to:
  /// **'Do not impersonate another player, venue, organization, or person.'**
  String get guidelineImpersonationBody;

  /// No description provided for @guidelinePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get guidelinePrivacyTitle;

  /// No description provided for @guidelinePrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Do not share another person’s private information without permission or improperly expose private or residential locations.'**
  String get guidelinePrivacyBody;

  /// No description provided for @guidelineProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles and content'**
  String get guidelineProfilesTitle;

  /// No description provided for @guidelineProfilesBody.
  ///
  /// In en, this message translates to:
  /// **'Display names, avatars, biographies, match information, and messages must follow these guidelines.'**
  String get guidelineProfilesBody;

  /// No description provided for @guidelineMessagingTitle.
  ///
  /// In en, this message translates to:
  /// **'Messaging'**
  String get guidelineMessagingTitle;

  /// No description provided for @guidelineMessagingBody.
  ///
  /// In en, this message translates to:
  /// **'Do not use Direct Messages or Match Chat for harassment, threats, scams, spam, or unwanted inappropriate content.'**
  String get guidelineMessagingBody;

  /// No description provided for @guidelineMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get guidelineMatchesTitle;

  /// No description provided for @guidelineMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'Create honest match listings. Do not intentionally misrepresent location, time, cost, level, availability, or organizer information.'**
  String get guidelineMatchesBody;

  /// No description provided for @guidelineBlockingTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocking and reporting'**
  String get guidelineBlockingTitle;

  /// No description provided for @guidelineBlockingBody.
  ///
  /// In en, this message translates to:
  /// **'Respect another player’s decision to block or stop communicating. Do not retaliate against someone for blocking or reporting, or knowingly submit malicious or fabricated reports.'**
  String get guidelineBlockingBody;

  /// No description provided for @guidelineRealWorldTitle.
  ///
  /// In en, this message translates to:
  /// **'Real-world safety'**
  String get guidelineRealWorldTitle;

  /// No description provided for @guidelineRealWorldBody.
  ///
  /// In en, this message translates to:
  /// **'Exercise reasonable judgment when meeting people in person. Treat private and residential locations carefully.'**
  String get guidelineRealWorldBody;

  /// No description provided for @guidelineReliabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Future reliability'**
  String get guidelineReliabilityTitle;

  /// No description provided for @guidelineReliabilityBody.
  ///
  /// In en, this message translates to:
  /// **'PadelX may later use objective participation behavior, such as cancellations and no-shows, to help improve matchmaking.'**
  String get guidelineReliabilityBody;

  /// No description provided for @guidelineEnforcementTitle.
  ///
  /// In en, this message translates to:
  /// **'Enforcement'**
  String get guidelineEnforcementTitle;

  /// No description provided for @guidelineEnforcementBody.
  ///
  /// In en, this message translates to:
  /// **'PadelX may review reported conduct and restrict access when appropriate.'**
  String get guidelineEnforcementBody;

  /// No description provided for @immediateDangerBody.
  ///
  /// In en, this message translates to:
  /// **'If you or someone else is in immediate danger, contact local emergency services.'**
  String get immediateDangerBody;

  /// No description provided for @notEmergencyService.
  ///
  /// In en, this message translates to:
  /// **'PadelX reporting and support are not emergency services.'**
  String get notEmergencyService;

  /// No description provided for @emergencySafetyGuidanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Emergency safety guidance'**
  String get emergencySafetyGuidanceLabel;

  /// No description provided for @where.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get where;

  /// No description provided for @when.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get when;

  /// No description provided for @hideLocationDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide location details'**
  String get hideLocationDetails;

  /// No description provided for @editLocationDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit location details'**
  String get editLocationDetails;

  /// No description provided for @matchDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Match details'**
  String get matchDetailsSection;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @completeYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeYourProfile;

  /// No description provided for @profileRequiredIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell other players who they will be sharing the court with.'**
  String get profileRequiredIntro;

  /// No description provided for @profileEditIntro.
  ///
  /// In en, this message translates to:
  /// **'Keep your player details accurate so matches are a better fit.'**
  String get profileEditIntro;

  /// No description provided for @chooseCity.
  ///
  /// In en, this message translates to:
  /// **'Choose city'**
  String get chooseCity;

  /// No description provided for @optionalNeighborhoodCity.
  ///
  /// In en, this message translates to:
  /// **'Optional neighborhood within your city'**
  String get optionalNeighborhoodCity;

  /// No description provided for @legacyAreaHelp.
  ///
  /// In en, this message translates to:
  /// **'Current area; clear or replace it with a search result'**
  String get legacyAreaHelp;

  /// No description provided for @displayNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Please enter a display name with at least 2 characters.'**
  String get displayNameTooShort;

  /// No description provided for @displayNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Display name must be 40 characters or fewer.'**
  String get displayNameTooLong;

  /// No description provided for @chooseLevelRange.
  ///
  /// In en, this message translates to:
  /// **'Choose a level from 1 to 7.'**
  String get chooseLevelRange;

  /// No description provided for @bioTooLong.
  ///
  /// In en, this message translates to:
  /// **'Bio must be 160 characters or fewer.'**
  String get bioTooLong;

  /// No description provided for @discoveryLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a country, 2-letter country code, and city for discovery.'**
  String get discoveryLocationRequired;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. Please try again.'**
  String get profileSaveFailed;

  /// No description provided for @selectPadelClub.
  ///
  /// In en, this message translates to:
  /// **'Select a padel club.'**
  String get selectPadelClub;

  /// No description provided for @chooseDateTimePeriod.
  ///
  /// In en, this message translates to:
  /// **'Choose a date and time.'**
  String get chooseDateTimePeriod;

  /// No description provided for @choosePlayerLevel.
  ///
  /// In en, this message translates to:
  /// **'Choose a player level.'**
  String get choosePlayerLevel;

  /// No description provided for @matchCreatedInvited.
  ///
  /// In en, this message translates to:
  /// **'Match created and invitation sent.'**
  String get matchCreatedInvited;

  /// No description provided for @matchCreatedInviteFailed.
  ///
  /// In en, this message translates to:
  /// **'Match created, but the invitation could not be sent.'**
  String get matchCreatedInviteFailed;

  /// No description provided for @matchCreated.
  ///
  /// In en, this message translates to:
  /// **'Match created successfully.'**
  String get matchCreated;

  /// No description provided for @legacyLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'Legacy location — search above to choose a structured location.'**
  String get legacyLocationHelp;

  /// No description provided for @saveMatchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save match changes. Please try again.'**
  String get saveMatchFailed;

  /// No description provided for @confirmedPlayersCapacity.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 player currently confirmed · maximum 4} other{{count} players currently confirmed · maximum 4}}'**
  String confirmedPlayersCapacity(num count);

  /// No description provided for @matchChatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Match chat is unavailable.'**
  String get matchChatUnavailable;

  /// No description provided for @completedMatchNoChanges.
  ///
  /// In en, this message translates to:
  /// **'This match has already been completed.'**
  String get completedMatchNoChanges;

  /// No description provided for @loginJoinMatch.
  ///
  /// In en, this message translates to:
  /// **'Please log in to request to join a match.'**
  String get loginJoinMatch;

  /// No description provided for @joinRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Join request sent.'**
  String get joinRequestSent;

  /// No description provided for @joinRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your join request. Please try again.'**
  String get joinRequestFailed;

  /// No description provided for @completedMatchesNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Completed matches cannot be changed.'**
  String get completedMatchesNoChanges;

  /// No description provided for @joinRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Join request approved.'**
  String get joinRequestApproved;

  /// No description provided for @joinRequestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Join request declined.'**
  String get joinRequestDeclined;

  /// No description provided for @approveRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not approve request. Please try again.'**
  String get approveRequestFailed;

  /// No description provided for @declineRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not decline request. Please try again.'**
  String get declineRequestFailed;

  /// No description provided for @loginLeaveMatch.
  ///
  /// In en, this message translates to:
  /// **'Please log in to leave a match.'**
  String get loginLeaveMatch;

  /// No description provided for @leftMatch.
  ///
  /// In en, this message translates to:
  /// **'You left the match.'**
  String get leftMatch;

  /// No description provided for @leaveMatchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not leave the match. Please try again.'**
  String get leaveMatchFailed;

  /// No description provided for @loginCancelMatch.
  ///
  /// In en, this message translates to:
  /// **'Please log in to cancel a match.'**
  String get loginCancelMatch;

  /// No description provided for @cancelMatchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel the match. Please try again.'**
  String get cancelMatchFailed;

  /// No description provided for @playersFromMatch.
  ///
  /// In en, this message translates to:
  /// **'Players from this match'**
  String get playersFromMatch;

  /// No description provided for @confirmedRole.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmedRole;

  /// No description provided for @cancellingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Cancelling...'**
  String get cancellingEllipsis;

  /// No description provided for @leavingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Leaving...'**
  String get leavingEllipsis;

  /// No description provided for @requestStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load request status'**
  String get requestStatusFailed;

  /// No description provided for @loadingRequestStatus.
  ///
  /// In en, this message translates to:
  /// **'Loading request status…'**
  String get loadingRequestStatus;

  /// No description provided for @matchFull.
  ///
  /// In en, this message translates to:
  /// **'Match Full'**
  String get matchFull;

  /// No description provided for @requestingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Requesting...'**
  String get requestingEllipsis;

  /// No description provided for @loadingRequest.
  ///
  /// In en, this message translates to:
  /// **'Loading request...'**
  String get loadingRequest;

  /// No description provided for @loadRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load request'**
  String get loadRequestFailed;

  /// No description provided for @dateTimeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Date and time unavailable'**
  String get dateTimeUnavailable;

  /// No description provided for @ratingSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} of 5'**
  String ratingSelected(Object count);

  /// No description provided for @selectRating.
  ///
  /// In en, this message translates to:
  /// **'Select a rating'**
  String get selectRating;

  /// No description provided for @ratingSubmittedStars.
  ///
  /// In en, this message translates to:
  /// **'Rating submitted · {count, plural, =1{1 star} other{{count} stars}}'**
  String ratingSubmittedStars(num count);

  /// No description provided for @submittedStars.
  ///
  /// In en, this message translates to:
  /// **'Submitted · {count, plural, =1{1 star} other{{count} stars}}'**
  String submittedStars(num count);

  /// No description provided for @startupLoadingSemantics.
  ///
  /// In en, this message translates to:
  /// **'PadelX loading'**
  String get startupLoadingSemantics;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'es':
      {
        switch (locale.countryCode) {
          case 'MX':
            return AppLocalizationsEsMx();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
