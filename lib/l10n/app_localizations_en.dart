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

  @override
  String get tryAgain => 'Try Again';

  @override
  String get tryAgainLower => 'Try again';

  @override
  String get signOut => 'Sign Out';

  @override
  String get logOut => 'Log out';

  @override
  String get continueLabel => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get remove => 'Remove';

  @override
  String get saveProfile => 'Save Profile';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get sendResetEmail => 'Send reset email';

  @override
  String get signInOrCreate => 'Sign in or create your account.';

  @override
  String get verifyEmail => 'Verify your email';

  @override
  String get openVerificationLink =>
      'Open the link in that message, then return here to continue.';

  @override
  String get beforeContinuing => 'Before continuing';

  @override
  String get ageConfirmation => 'I confirm that I am 18 years of age or older.';

  @override
  String get ageRequired =>
      'To continue, confirm that you are at least 18 years old.';

  @override
  String get ageEligibility => '18+ eligibility';

  @override
  String get ageCheckFailed => 'Could not check age eligibility.';

  @override
  String get adultOnly => 'PadelX is for adults 18 and older.';

  @override
  String get legalAcknowledgement => 'Legal acknowledgement';

  @override
  String get legalReviewIntro =>
      'Review the Terms of Use and Privacy Policy for the PadelX closed beta.';

  @override
  String get legalLoadFailed => 'Acceptance status could not be loaded.';

  @override
  String get matches => 'Matches';

  @override
  String get discover => 'Discover';

  @override
  String get myMatches => 'My Matches';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get create => 'Create';

  @override
  String get createMatch => 'Create Match';

  @override
  String get createAMatch => 'Create Match';

  @override
  String get editMatch => 'Edit Match';

  @override
  String get matchDetails => 'Match Details';

  @override
  String get findMatch => 'Find Matches';

  @override
  String get findMatchesHomeDescription => 'Browse available matches yourself.';

  @override
  String get quickMatchHomeDescription => 'PadelX finds the game for you.';

  @override
  String get createMatchHomeDescription => 'Organize your own game.';

  @override
  String get reliabilityNewPlayer => 'Reliability: New player';

  @override
  String reliabilityPercent(int percent) {
    return 'Reliability: $percent%';
  }

  @override
  String get findPlayers => 'Find Players';

  @override
  String get players => 'Players';

  @override
  String get messages => 'Messages';

  @override
  String get notifications => 'Notifications';

  @override
  String get profile => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get playerProfile => 'Player Profile';

  @override
  String get friends => 'Friends';

  @override
  String get friend => 'Friend';

  @override
  String get addFriend => 'Add Friend';

  @override
  String get requested => 'Requested';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get unfriend => 'Unfriend';

  @override
  String get block => 'Block';

  @override
  String get unblock => 'Unblock';

  @override
  String get reportPlayer => 'Report player';

  @override
  String get reportMessage => 'Report message';

  @override
  String get reportMatch => 'Report match';

  @override
  String get reportSubmitted => 'Report submitted';

  @override
  String get matchChat => 'Match Chat';

  @override
  String get message => 'Message';

  @override
  String get sendMessage => 'Send message';

  @override
  String get refreshMessages => 'Refresh messages';

  @override
  String get noMessages => 'No messages yet. Say hello!';

  @override
  String get noConversations => 'No conversations yet.';

  @override
  String get messagesUnavailable => 'Messages are unavailable right now.';

  @override
  String get couldNotSendMessage => 'Could not send this message.';

  @override
  String get loadOlder => 'Load older';

  @override
  String get loadingEllipsis => 'Loading…';

  @override
  String get markRead => 'Mark read';

  @override
  String get markAsRead => 'Mark as read';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get viewMatch => 'View Match';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get level => 'Level';

  @override
  String get playerLevel => 'Player level';

  @override
  String get chooseLevel => 'Choose a level';

  @override
  String get preferredSide => 'Preferred side';

  @override
  String get areaOptional => 'Area / Neighborhood (optional)';

  @override
  String get anyArea => 'Any area';

  @override
  String get searchAreas => 'Search areas';

  @override
  String get city => 'City';

  @override
  String get country => 'Country';

  @override
  String get countryCode => 'Country code';

  @override
  String get changeCity => 'Change city';

  @override
  String get searchCitiesOnly => 'Search cities only';

  @override
  String get displayName => 'Display name';

  @override
  String get shortBio => 'Short bio (optional)';

  @override
  String get discoverability => 'Let other players find me';

  @override
  String get preferredLocation => 'Preferred discovery location';

  @override
  String get profileUpdated => 'Profile updated.';

  @override
  String get helpSafety => 'Help & Safety';

  @override
  String get supportSafety => 'Support & Safety';

  @override
  String get communityGuidelines => 'Community Guidelines';

  @override
  String get blockedPlayers => 'Blocked Players';

  @override
  String get contactSupport => 'Contact PadelX Support';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountLower => 'Delete account';

  @override
  String get account => 'Account';

  @override
  String get safety => 'Safety';

  @override
  String get reportingBlockingAge => 'Reporting, blocking, and age eligibility';

  @override
  String get emergency => 'Emergency';

  @override
  String get ratingSubmitted => 'Rating submitted.';

  @override
  String get ratePlayer => 'Rate player';

  @override
  String get ratePlayers => 'Rate players';

  @override
  String get submitRating => 'Submit rating';

  @override
  String get playAgain => 'Play Again';

  @override
  String get cancelMatch => 'Cancel Match';

  @override
  String get leaveMatch => 'Leave Match';

  @override
  String get matchUnavailable => 'Match unavailable';

  @override
  String get noMatchesNearby => 'No matches nearby yet.';

  @override
  String get matchesUnavailable => 'Matches are unavailable right now.';

  @override
  String get findingMatches => 'Finding nearby matches…';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get filterMatches => 'Filter matches';

  @override
  String get club => 'Club';

  @override
  String get dateTime => 'Date and time';

  @override
  String get chooseDateTime => 'Choose date and time';

  @override
  String get totalPlayers => 'Total players';

  @override
  String get spots => 'Spots';

  @override
  String get submit => 'Submit';

  @override
  String get whyReporting => 'Why are you reporting this?';

  @override
  String get additionalDetails => 'Additional details (optional)';

  @override
  String couldNotOpenPage(String email) {
    return 'Could not open this page. Contact $email.';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get player => 'Player';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String unreadMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String get unread => 'Unread';

  @override
  String get read => 'Read';

  @override
  String get unreadNotification => 'Unread notification';

  @override
  String get timeUnavailable => 'Time unavailable';

  @override
  String get newJoinRequest => 'New join request';

  @override
  String joinRequestBody(String name, String club) {
    return '$name requested to join your match at $club.';
  }

  @override
  String get requestApproved => 'Request approved';

  @override
  String get requestDeclined => 'Request declined';

  @override
  String requestApprovedBody(String club) {
    return 'Your request to join the match at $club was approved.';
  }

  @override
  String requestDeclinedBody(String club) {
    return 'Your request to join the match at $club was declined.';
  }

  @override
  String get newDirectMessage => 'New message';

  @override
  String get newDirectMessageBody => 'You have an unread direct message.';

  @override
  String get newMatchMessage => 'New match message';

  @override
  String get newMatchMessageBody => 'You have an unread message in Match Chat.';

  @override
  String get newFriendRequest => 'New friend request';

  @override
  String friendRequestBody(String name) {
    return '$name sent you a friend request.';
  }

  @override
  String get friendRequestAccepted => 'Friend request accepted';

  @override
  String friendAcceptedBody(String name) {
    return '$name accepted your friend request.';
  }

  @override
  String get playAgainInvite => 'Play again';

  @override
  String playAgainBody(String name) {
    return '$name invited you to play again.';
  }

  @override
  String get harassmentBullying => 'Harassment or bullying';

  @override
  String get hateAbuse => 'Hate or abusive content';

  @override
  String get sexualInappropriate => 'Sexual or inappropriate content';

  @override
  String get threatsUnsafe => 'Threats or unsafe behavior';

  @override
  String get spamScam => 'Spam or scam';

  @override
  String get impersonation => 'Impersonation';

  @override
  String get other => 'Other';

  @override
  String reportSubject(String subject) {
    return 'Report $subject';
  }

  @override
  String get reportAlreadySubmitted => 'You already reported this.';

  @override
  String get reportRateLimited =>
      'You’ve submitted several reports recently. Please try again later.';

  @override
  String get reportFailed => 'Report could not be submitted. Please try again.';

  @override
  String get thanksForSafety => 'Thanks for helping keep PadelX safe.';

  @override
  String get blockPlayer => 'Block player';

  @override
  String get blockThisPlayer => 'Block this player?';

  @override
  String get playerBlocked => 'Player blocked.';

  @override
  String get playerBlockFailed => 'Player could not be blocked.';

  @override
  String get sharedMatchBlockExplanation =>
      'Blocking prevents normal social discovery and contact. Shared-match access still follows match membership.';

  @override
  String get friendBlockExplanation =>
      'Your friendship will be removed and normal social discovery and contact will be prevented. Shared-match access still follows match membership.';

  @override
  String get nonFriendBlockExplanation =>
      'Normal social discovery and contact with this player will be prevented. Shared-match access still follows match membership.';

  @override
  String get approve => 'Approve';

  @override
  String get allPlayersRated => 'All players rated.';

  @override
  String get areaSuggestionsUnavailable =>
      'Area suggestions are unavailable. You can choose Any area.';

  @override
  String get beFirstMatch => 'Be the first to get a game started.';

  @override
  String get cancelMatchQuestion => 'Cancel match?';

  @override
  String get checkAccessAgain => 'Check access again';

  @override
  String get connectionRetry => 'Check your connection and try again.';

  @override
  String get chooseClubTimePlayers =>
      'Choose a club, time, and who the game is for.';

  @override
  String get cityOrArea => 'City or area';

  @override
  String get citySuggestionsUnavailable =>
      'City suggestions are unavailable. Enter your city details below; Area can remain blank.';

  @override
  String get clearLocation => 'Clear location';

  @override
  String get closeAreaSelector => 'Close area selector';

  @override
  String get closeLevelSelector => 'Close level selector';

  @override
  String get clubName => 'Club name';

  @override
  String get clubNameAddress => 'Club name or address';

  @override
  String get completed => 'Completed';

  @override
  String get confirmPassword => 'Confirm your password';

  @override
  String get preservePlayersRequests =>
      'Confirmed players and join requests will be preserved.';

  @override
  String get createMatchFailed => 'Could not create the match.';

  @override
  String get dismissInviteFailed => 'Could not dismiss this invitation.';

  @override
  String get loadLocationFailed => 'Could not load that location.';

  @override
  String get loadProfileFailed => 'Could not load your profile.';

  @override
  String get markReadFailed => 'Could not mark notification as read.';

  @override
  String get markAllReadFailed => 'Could not mark notifications as read.';

  @override
  String get ratingSubmitFailed => 'Could not submit rating.';

  @override
  String get accessCheckFailed => 'Could not verify account access.';

  @override
  String get editProfileLocation => 'Edit profile location';

  @override
  String get enablePushQuestion => 'Enable push notifications?';

  @override
  String get endFriendship =>
      'End this friendship and direct social connection';

  @override
  String get expand100 => 'Expand to 100 km';

  @override
  String get findMatchesNear => 'Find matches near';

  @override
  String get findPadelMatches => 'Find padel matches near you.';

  @override
  String get findPadelPlayers =>
      'Find padel players you may want to play with.';

  @override
  String get playFrequency => 'How often do you play?';

  @override
  String get howReportMatch => 'How to report a match';

  @override
  String get howReportMessage => 'How to report a message';

  @override
  String get howReportPlayer => 'How to report a player';

  @override
  String get isoCountryCode => 'ISO country code';

  @override
  String get immediateDanger => 'Immediate danger';

  @override
  String get joinRequests => 'Join Requests';

  @override
  String get joinGames => 'Join games that need players.';

  @override
  String get keepMatch => 'Keep Match';

  @override
  String get loadingPadelX => 'LOADING PADELX';

  @override
  String get leaveMatchQuestion => 'Leave match?';

  @override
  String get loadMore => 'Load more';

  @override
  String get loadMoreNearby => 'Load more nearby matches';

  @override
  String get loadOlderMatches => 'Load older matches';

  @override
  String get loadOlderNotifications => 'Load older notifications';

  @override
  String get loadingJoinRequests => 'Loading join requests...';

  @override
  String get matchCancelled => 'Match cancelled.';

  @override
  String get matchDiscovery => 'Match discovery';

  @override
  String get matchUpdated => 'Match updated successfully.';

  @override
  String get notificationEmptyBody =>
      'Match, message, and social updates will appear here.';

  @override
  String get organizedJoinedMatches => 'Matches you organize or have joined.';

  @override
  String get acceptedFriendsMessaging =>
      'Messaging is available to accepted friends.';

  @override
  String get moreActions => 'More actions';

  @override
  String get moreSafetyActions => 'More safety actions';

  @override
  String get needHelp => 'Need help or want to report a safety concern?';

  @override
  String get neighborhoodArea => 'Neighborhood or area';

  @override
  String get noOtherPlayersRate => 'No other players from this match to rate.';

  @override
  String get noPendingRequests => 'No pending requests';

  @override
  String get noRatings => 'No ratings yet';

  @override
  String get notNow => 'Not now';

  @override
  String get notificationPreferencesFailed =>
      'Notification preferences could not be saved.';

  @override
  String get notificationsUnavailable =>
      'Notifications are unavailable right now.';

  @override
  String get openReportMatchHelp =>
      'Open Match Details, then choose Report match from the safety actions.';

  @override
  String get openMatches => 'Open matches';

  @override
  String get openReportPlayerHelp =>
      'Open the player’s profile, tap More actions, then Report player.';

  @override
  String get pendingRequests => 'Pending Requests';

  @override
  String get playedWith => 'People you\'ve played with';

  @override
  String get permanentlyDelete => 'Permanently delete your PadelX account';

  @override
  String get photoCropHelp =>
      'Photos are center-cropped and saved as a 512×512 JPEG.';

  @override
  String get unblockedNotice =>
      'Player unblocked. Friendship is not restored automatically.';

  @override
  String get chooseFutureDate => 'Please choose a future date and time.';

  @override
  String get policyCategory => 'Policy category';

  @override
  String get pressHoldReport =>
      'Press and hold a message from another player, then choose Report message.';

  @override
  String get preventSocialContact =>
      'Prevent normal social discovery and contact';

  @override
  String get pushUpdateFailed =>
      'Push notification settings could not be updated.';

  @override
  String get pushNotifications => 'Push notifications';

  @override
  String get pushPermissionCategories =>
      'Push permission and notification categories';

  @override
  String get questionsSafety => 'Questions or safety concerns';

  @override
  String get rateInDetails => 'Rate in match details';

  @override
  String get refreshMatches => 'Refresh matches';

  @override
  String get regionOptional => 'Region / State / Province (optional)';

  @override
  String get relationshipActions => 'Relationship actions';

  @override
  String get restrictionEnds => 'Restriction ends';

  @override
  String get reviewUnblock => 'Review and unblock players';

  @override
  String get safetyExpectations => 'Safety expectations for the PadelX beta';

  @override
  String get searchClubLocation => 'Search club or location';

  @override
  String get searchCityArea => 'Search for a city or area';

  @override
  String get searchPadelClub => 'Search for a padel club';

  @override
  String get seeAll => 'See all';

  @override
  String get sendPrivateReport => 'Send a private safety report';

  @override
  String get setUpGame => 'Set up your game';

  @override
  String get sharedMatchRatings => 'Shared match ratings';

  @override
  String get stay => 'Stay';

  @override
  String get tellPlayersGame => 'Tell players a little about your game';

  @override
  String get thisMatchUnavailable => 'This match is no longer available.';

  @override
  String get matchMayRemoved =>
      'This match may have been cancelled or removed.';

  @override
  String get notificationUnavailable => 'This notification is unavailable.';

  @override
  String get socialUnavailable => 'This social action is unavailable.';

  @override
  String get cancelMatchWarning =>
      'This will remove the match for everyone and cannot be undone.';

  @override
  String get totalCapacity => 'Total player capacity';

  @override
  String get widerRadius => 'Try a wider radius or change location.';

  @override
  String get loadMoreRetry => 'Try loading more again';

  @override
  String get upcomingMatches => 'Upcoming matches';

  @override
  String get updateMatchDetails => 'Update match details';

  @override
  String get matchUpdates => 'Updates about your matches and requests.';

  @override
  String get usePhoto => 'Use photo';

  @override
  String get viewAll => 'View All';

  @override
  String get profileVisibilityHelp =>
      'When off, your profile will not appear in Find Players. Players may still see it through matches, friendships, messages, invitations, or shared history.';

  @override
  String get capacityHelp => 'You count as one player · maximum 4';

  @override
  String get noBlockedPlayers => 'You have not blocked any players.';

  @override
  String get spotAvailable => 'Your confirmed spot will become available.';

  @override
  String get padelProfile => 'Your padel profile';

  @override
  String get couldNotOpenEmail =>
      'Could not open email. Contact support.padelx@gmail.com.';

  @override
  String get blockedPlayersUnavailable =>
      'Blocked players are unavailable right now.';

  @override
  String get startupFailed => 'PadelX could not start.';

  @override
  String get verificationSent => 'We sent a verification link to';

  @override
  String get legalAgreement =>
      'I agree to the Terms of Use and acknowledge the Privacy Policy.';

  @override
  String get resetEmailHelp =>
      'Enter your email and we’ll send you a link to reset your password.';

  @override
  String get signInDiscoverPlayers => 'Sign in to discover players.';

  @override
  String get locationNoCoordinates => 'That location has no coordinates.';

  @override
  String levelValue(String level) {
    return 'Level $level';
  }

  @override
  String radiusKm(String distance) {
    return '$distance km';
  }

  @override
  String playerCountChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count players',
      one: '1 player',
    );
    return '$_temp0';
  }

  @override
  String playersIn(String city) {
    return 'Players in\n$city';
  }

  @override
  String chooseAreaIn(String city) {
    return 'Choose an area in $city';
  }

  @override
  String chooseAreaInCountry(String city, String countryCode) {
    return 'Choose an area in $city, $countryCode.';
  }

  @override
  String currentArea(String area) {
    return 'Current area: $area';
  }

  @override
  String preferredSideDisplay(String side) {
    return '$side side';
  }

  @override
  String get leftSide => 'Left';

  @override
  String get rightSide => 'Right';

  @override
  String get eitherSide => 'Either';

  @override
  String playedTogetherCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: '1 time',
    );
    return 'Played together $_temp0';
  }

  @override
  String lastPlayed(String date) {
    return 'Last played $date';
  }

  @override
  String ratingAverage(String average) {
    return '$average stars';
  }

  @override
  String rateNamedPlayer(String name) {
    return 'Rate $name';
  }

  @override
  String howWasPlaying(String name) {
    return 'How was playing with $name?';
  }

  @override
  String get everyone => 'Everyone';

  @override
  String get playedWithFilter => 'Played With';

  @override
  String get noAreasFound => 'No areas found.';

  @override
  String playerLevelSide(String level, String side) {
    return 'Level $level · $side side';
  }

  @override
  String playerNoRatingsMatches(int matches) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches completed matches',
      one: '1 completed match',
    );
    return 'No ratings yet · $_temp0';
  }

  @override
  String playerRatingMatches(String rating, int ratings, int matches) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches completed matches',
      one: '1 completed match',
    );
    return '$rating stars ($ratings) · $_temp0';
  }

  @override
  String emailAppFailed(String email) {
    return 'Could not open your email app. You can contact us at $email.';
  }

  @override
  String get pushPermissionExplanation =>
      'PadelX will ask iOS for permission and register this device. You can change individual categories at any time.';

  @override
  String get pushBlockedHelp =>
      'Notifications are blocked in device settings. Enable them there to receive PadelX push notifications.';

  @override
  String get pushBuildUnavailable =>
      'Push notifications are not configured for this build. Notification categories can still be prepared below.';

  @override
  String get pushSettingsHelp =>
      'Open your device Settings, select PadelX, then enable Notifications before trying again.';

  @override
  String get pushCategoriesFuture =>
      'These categories are saved now and will control push delivery as notification types are enabled in later phases.';

  @override
  String inviteAfterCreate(String name) {
    return 'Invite $name after creating';
  }

  @override
  String ratingSummary(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
      one: '1 rating',
    );
    return '$average stars ($_temp0)';
  }

  @override
  String get home => 'Home';

  @override
  String get browseMatches => 'Browse Matches';

  @override
  String get loadingNotifications => 'Loading notifications';

  @override
  String get loadingYourMatches => 'Loading your matches…';

  @override
  String get yourMatchesUnavailable =>
      'Your matches are unavailable right now.';

  @override
  String get noUpcomingMatches => 'No upcoming matches.';

  @override
  String get findOpenOrOrganize =>
      'Find an open match or organize your next game.';

  @override
  String get noPastMatches => 'No past matches yet.';

  @override
  String get completedAppearHere => 'Completed matches will appear here.';

  @override
  String get profileNeedsInfo => 'Your profile needs a little more information';

  @override
  String get addNameLevel =>
      'Add your display name and level to finish setting it up.';

  @override
  String get profileStatsFailed => 'Could not load your profile stats';

  @override
  String get rating => 'Rating';

  @override
  String get ratings => 'Ratings';

  @override
  String get completedMatches => 'Completed matches';

  @override
  String get repeatPlayers => 'Repeat players';

  @override
  String get sharedMatches => 'Shared matches';

  @override
  String get playerProfileFailed => 'Could not load this player profile';

  @override
  String get loadingSubmittedRatings => 'Loading submitted ratings';

  @override
  String get submittedRatingsFailed => 'Could not load submitted ratings.';

  @override
  String get playerUnavailable => 'Player unavailable';

  @override
  String get dateUnavailable => 'Date unavailable';

  @override
  String get occasional => 'Occasionally';

  @override
  String get weekly => 'Weekly';

  @override
  String get severalPerWeek => 'Several times a week';

  @override
  String get legalAgreePrefix => 'I agree to the ';

  @override
  String get legalAgreeMiddle => ' and acknowledge the ';

  @override
  String get period => '.';

  @override
  String matchesTogether(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches together',
      one: '1 match together',
    );
    return '$_temp0';
  }

  @override
  String get completeProfile => 'Complete Profile';

  @override
  String get requestPending => 'Request Pending';

  @override
  String get organizing => 'Organizing';

  @override
  String get joined => 'Joined';

  @override
  String get ratingNotEligible =>
      'This rating was already submitted or is not eligible.';

  @override
  String get match => 'Match';

  @override
  String get findingOpenMatches => 'Finding open matches…';

  @override
  String get deletedPlayer => 'Deleted player';

  @override
  String get signOutLower => 'Sign out';

  @override
  String get createMatchGetStarted => 'Create a match and get a game started.';

  @override
  String get creatingMatch => 'Creating...';

  @override
  String get emailAddressFallback => 'your email address';

  @override
  String get checkingEllipsis => 'Checking...';

  @override
  String get verifiedMyEmail => 'I\'ve verified my email';

  @override
  String get sendingEllipsis => 'Sending...';

  @override
  String resendAvailableIn(Object seconds) {
    return 'Resend available in ${seconds}s';
  }

  @override
  String get resendVerificationEmail => 'Resend verification email';

  @override
  String get signingOutEllipsis => 'Signing out...';

  @override
  String get emailNotVerified =>
      'Your email is not verified yet. Open the link in your email, then try again.';

  @override
  String get emailCheckFailed =>
      'Could not check your email yet. Please try again.';

  @override
  String get verificationEmailSent => 'A new verification email was sent.';

  @override
  String get verificationResendFailed =>
      'Could not resend the email. Please try again.';

  @override
  String get signOutFailed => 'Could not sign out. Please try again.';

  @override
  String get tooManyAttemptsWait =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get networkRetry => 'Check your internet connection and try again.';

  @override
  String get accountUnavailableSupport =>
      'This account is unavailable. Contact PadelX support.';

  @override
  String get recentLoginRequired => 'Please sign out, log in again, and retry.';

  @override
  String get requestFailedGeneric =>
      'Could not complete that request. Please try again.';

  @override
  String get ageConfirmContinue =>
      'Confirm that you are 18 years of age or older to continue.';

  @override
  String get legalAgreeContinue =>
      'Agree to the Terms of Use and acknowledge the Privacy Policy to continue.';

  @override
  String get enterEmailPeriod => 'Enter your email.';

  @override
  String get validEmailRequired => 'Enter a valid email address.';

  @override
  String get enterPasswordPeriod => 'Enter your password.';

  @override
  String get ageRecordAfterCreateFailed =>
      'Your account was created, but age eligibility could not be confirmed. Try again to continue.';

  @override
  String get legalRecordAfterCreateFailed =>
      'Your account was created, but legal acknowledgement could not be recorded. Try again to continue.';

  @override
  String get accountNotFound => 'No account was found with that email.';

  @override
  String get incorrectCredentials => 'Incorrect email or password.';

  @override
  String get createAccountFailed =>
      'Could not create your account. Please try again.';

  @override
  String get emailAlreadyUsed =>
      'An account already uses that email. Try logging in.';

  @override
  String get weakPassword => 'Your password must be at least 6 characters.';

  @override
  String get tooManyAttemptsLater =>
      'Too many attempts. Please try again later.';

  @override
  String get loginFailed => 'Could not log in. Please try again.';

  @override
  String get genericCreateAccountFailed =>
      'Could not create your account. Please try again.';

  @override
  String get somethingWrongRetry => 'Something went wrong. Please try again.';

  @override
  String get passwordResetSent =>
      'Password reset email sent. Check your inbox.';

  @override
  String get logIn => 'Log In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get welcomeBackAuth => 'Welcome back. Your next match is waiting.';

  @override
  String get createVerifyAuth =>
      'Create your account, then verify your email to get started.';

  @override
  String get createPassword => 'Create a password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get loggingIn => 'Logging in...';

  @override
  String get creatingAccount => 'Creating account...';

  @override
  String get retryAgeConfirmation => 'Retry age confirmation';

  @override
  String get createAccount => 'Create Account';

  @override
  String get switchToSignUp => 'Don’t have an account? Sign Up';

  @override
  String get switchToLogin => 'Already have an account? Log in';

  @override
  String get resetEmailFailed =>
      'Could not send the reset email. Please try again.';

  @override
  String get tooManyRequestsLater =>
      'Too many requests. Please try again later.';

  @override
  String get notSelected => 'Not selected';

  @override
  String legacyLevelHelp(Object value) {
    return 'Current value \"$value\" is legacy. Choose a numeric level.';
  }

  @override
  String get choosePhoto => 'Choose photo';

  @override
  String get chooseAnotherPhoto => 'Choose another';

  @override
  String get unblockingEllipsis => 'Unblocking…';

  @override
  String get profileUnavailable => 'Profile unavailable';

  @override
  String get levelNotSet => 'Level not set';

  @override
  String get couldNotLoadPlayers => 'Could not load players.';

  @override
  String get playedWithEmpty =>
      'People you play with will appear here after completed matches.';

  @override
  String get notRated => 'Not rated';

  @override
  String get locationSuggestionsUnavailable =>
      'Location suggestions are temporarily unavailable.';

  @override
  String get conversationUnavailable => 'Conversation unavailable';

  @override
  String get conversationReadOnly => 'This conversation is read-only.';

  @override
  String get loadOlderMessages => 'Load older messages';

  @override
  String messageFrom(Object name) {
    return 'Message from $name';
  }

  @override
  String get you => 'You';

  @override
  String get enterPasswordHint => 'Enter your password';

  @override
  String get reasonHarassmentAbuse => 'Harassment or abusive conduct';

  @override
  String get reasonHateDiscrimination => 'Hate or discriminatory conduct';

  @override
  String get reasonSexualMisconduct => 'Sexual or inappropriate conduct';

  @override
  String get reasonThreatsUnsafe => 'Threats or unsafe behavior';

  @override
  String get reasonSpamScams => 'Spam or scams';

  @override
  String get reasonPrivacyViolation => 'Privacy violation';

  @override
  String get reasonFraudDeception => 'Fraud or deception';

  @override
  String get reasonMaliciousReporting => 'Misuse of reporting';

  @override
  String get accountTemporarilySuspended => 'Account temporarily suspended';

  @override
  String get accountRestricted => 'Account restricted';

  @override
  String get accessTemporarilyRestricted =>
      'Your access to PadelX has been temporarily restricted.';

  @override
  String get accessRestricted => 'Your access to PadelX has been restricted.';

  @override
  String get currentLocation => 'Current location';

  @override
  String get findingYourLocation => 'Finding your location…';

  @override
  String get useCurrentLocation => 'Use my current location';

  @override
  String currentLocationRadius(Object distance) {
    return 'Current location · $distance km radius';
  }

  @override
  String searchRadius(Object distance) {
    return 'Search radius: $distance km';
  }

  @override
  String get all => 'All';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get thisWeek => 'This Week';

  @override
  String get noOpenMatches => 'No open matches yet';

  @override
  String get noMatchesFilters => 'No matches match your filters';

  @override
  String noMatchesRadius(Object distance) {
    return 'No matches within $distance km';
  }

  @override
  String get organizer => 'Organizer';

  @override
  String get pending => 'Pending';

  @override
  String get full => 'Full';

  @override
  String get open => 'Open';

  @override
  String get profileDetailsSafe =>
      'Your profile details are safe. Check your connection and try again.';

  @override
  String get visibleDiscovery => 'Visible in Players discovery';

  @override
  String get hiddenDiscovery => 'Hidden from Players discovery';

  @override
  String get setCityPlayers => 'Set your city to find players';

  @override
  String get addCoarseCity =>
      'Add a coarse city in your profile. Your precise location is never shared.';

  @override
  String get playersUnavailable => 'Players are unavailable right now';

  @override
  String get morePlayersMayMatch => 'More players may match';

  @override
  String get noPlayersFilters => 'No players match these filters';

  @override
  String get continueSearchingPlayers =>
      'Continue searching the remaining players.';

  @override
  String get broadenPlayerFilters =>
      'Try a broader area, level, side, or relationship filter.';

  @override
  String get anyLevel => 'Any level';

  @override
  String get anySide => 'Any side';

  @override
  String get eitherOnly => 'Either only';

  @override
  String get unfriendQuestion => 'Unfriend this player?';

  @override
  String get unfriendExplanation =>
      'Your friendship and direct social connection will end.';

  @override
  String get incomingRequests => 'Incoming Requests';

  @override
  String get outgoingRequests => 'Outgoing Requests';

  @override
  String get acceptedFriends => 'Accepted Friends';

  @override
  String get noFriendsYet => 'No friends yet.';

  @override
  String get noRequests => 'No requests.';

  @override
  String get privacy => 'Privacy';

  @override
  String get legal => 'Legal';

  @override
  String get accountDeletionInfo => 'Account Deletion';

  @override
  String get categories => 'Categories';

  @override
  String get matchMessages => 'Match messages';

  @override
  String get joinRequestsCategory => 'Join requests';

  @override
  String get friendRequestsCategory => 'Friend requests';

  @override
  String get friendAcceptedCategory => 'Friend accepted';

  @override
  String get matchUpdatesCategory => 'Match updates';

  @override
  String get accountManagement => 'Account management';

  @override
  String get pushOn => 'Push notifications on';

  @override
  String get pushOff => 'Push notifications off';

  @override
  String get notificationsBlockedSettings =>
      'Notifications blocked in device settings';

  @override
  String get pushUnavailableBuild => 'Unavailable in this build';

  @override
  String get checkingDevicePermission => 'Checking device permission…';

  @override
  String get deletionExplanation =>
      'Deletion is permanent. Future matches you organize will be cancelled, and you will leave future matches you joined. Historical participation will be anonymized. Ratings involving your account will be removed.';

  @override
  String get deletionPasswordRequired =>
      'Enter your password for this deletion attempt.';

  @override
  String get deletionRequested =>
      'Account deletion requested. You are signed out. Cleanup continues securely in the background.';

  @override
  String get signedOutNotice => 'You are signed out.';

  @override
  String get requestingDeletion => 'Requesting deletion…';

  @override
  String get permanentlyDeleteAccount => 'Permanently delete my account';

  @override
  String get eligibilityConfirmFailed =>
      'Could not confirm eligibility. Check your connection and try again.';

  @override
  String get confirmingEllipsis => 'Confirming...';

  @override
  String get legalRecordFailed =>
      'Could not record your acknowledgement. Try again.';

  @override
  String get legalRefreshFailed =>
      'Your acknowledgement was recorded, but its status could not be refreshed. Try again.';

  @override
  String get savingEllipsis => 'Saving...';

  @override
  String get guidelineAdultsTitle => 'Adults only';

  @override
  String get guidelineAdultsBody => 'PadelX is for users 18 and older.';

  @override
  String get guidelineRespectTitle => 'Respect other players';

  @override
  String get guidelineRespectBody =>
      'Treat players respectfully. Harassment, bullying, intimidation, and targeted abuse are not allowed.';

  @override
  String get guidelineHateTitle => 'Hate and discrimination';

  @override
  String get guidelineHateBody =>
      'Hateful or discriminatory content and conduct are not allowed.';

  @override
  String get guidelineSexualTitle => 'Sexual or inappropriate conduct';

  @override
  String get guidelineSexualBody =>
      'Do not send unwanted sexual content or engage in sexual harassment or other inappropriate behavior.';

  @override
  String get guidelineThreatsTitle => 'Threats and unsafe behavior';

  @override
  String get guidelineThreatsBody =>
      'Threats, violence, intimidation, and deliberately unsafe conduct are not allowed.';

  @override
  String get guidelineSpamTitle => 'Spam, scams, and deception';

  @override
  String get guidelineSpamBody =>
      'Do not post scams, spam, deceptive listings, fraudulent payment requests, or intentionally misleading match information.';

  @override
  String get guidelineImpersonationBody =>
      'Do not impersonate another player, venue, organization, or person.';

  @override
  String get guidelinePrivacyTitle => 'Privacy';

  @override
  String get guidelinePrivacyBody =>
      'Do not share another person’s private information without permission or improperly expose private or residential locations.';

  @override
  String get guidelineProfilesTitle => 'Profiles and content';

  @override
  String get guidelineProfilesBody =>
      'Display names, avatars, biographies, match information, and messages must follow these guidelines.';

  @override
  String get guidelineMessagingTitle => 'Messaging';

  @override
  String get guidelineMessagingBody =>
      'Do not use Direct Messages or Match Chat for harassment, threats, scams, spam, or unwanted inappropriate content.';

  @override
  String get guidelineMatchesTitle => 'Matches';

  @override
  String get guidelineMatchesBody =>
      'Create honest match listings. Do not intentionally misrepresent location, time, cost, level, availability, or organizer information.';

  @override
  String get guidelineBlockingTitle => 'Blocking and reporting';

  @override
  String get guidelineBlockingBody =>
      'Respect another player’s decision to block or stop communicating. Do not retaliate against someone for blocking or reporting, or knowingly submit malicious or fabricated reports.';

  @override
  String get guidelineRealWorldTitle => 'Real-world safety';

  @override
  String get guidelineRealWorldBody =>
      'Exercise reasonable judgment when meeting people in person. Treat private and residential locations carefully.';

  @override
  String get guidelineReliabilityTitle => 'Future reliability';

  @override
  String get guidelineReliabilityBody =>
      'PadelX may later use objective participation behavior, such as cancellations and no-shows, to help improve matchmaking.';

  @override
  String get guidelineEnforcementTitle => 'Enforcement';

  @override
  String get guidelineEnforcementBody =>
      'PadelX may review reported conduct and restrict access when appropriate.';

  @override
  String get immediateDangerBody =>
      'If you or someone else is in immediate danger, contact local emergency services.';

  @override
  String get notEmergencyService =>
      'PadelX reporting and support are not emergency services.';

  @override
  String get emergencySafetyGuidanceLabel => 'Emergency safety guidance';

  @override
  String get where => 'Where';

  @override
  String get when => 'When';

  @override
  String get hideLocationDetails => 'Hide location details';

  @override
  String get editLocationDetails => 'Edit location details';

  @override
  String get matchDetailsSection => 'Match details';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get completeYourProfile => 'Complete Your Profile';

  @override
  String get profileRequiredIntro =>
      'Tell other players who they will be sharing the court with.';

  @override
  String get profileEditIntro =>
      'Keep your player details accurate so matches are a better fit.';

  @override
  String get chooseCity => 'Choose city';

  @override
  String get optionalNeighborhoodCity =>
      'Optional neighborhood within your city';

  @override
  String get legacyAreaHelp =>
      'Current area; clear or replace it with a search result';

  @override
  String get displayNameTooShort =>
      'Please enter a display name with at least 2 characters.';

  @override
  String get displayNameTooLong =>
      'Display name must be 40 characters or fewer.';

  @override
  String get chooseLevelRange => 'Choose a level from 1 to 7.';

  @override
  String get bioTooLong => 'Bio must be 160 characters or fewer.';

  @override
  String get discoveryLocationRequired =>
      'Enter a country, 2-letter country code, and city for discovery.';

  @override
  String get profileSaveFailed =>
      'Could not save your profile. Please try again.';

  @override
  String get selectPadelClub => 'Select a padel club.';

  @override
  String get chooseDateTimePeriod => 'Choose a date and time.';

  @override
  String get choosePlayerLevel => 'Choose a player level.';

  @override
  String get matchCreatedInvited => 'Match created and invitation sent.';

  @override
  String get matchCreatedInviteFailed =>
      'Match created, but the invitation could not be sent.';

  @override
  String get matchCreated => 'Match created successfully.';

  @override
  String get legacyLocationHelp =>
      'Legacy location — search above to choose a structured location.';

  @override
  String get saveMatchFailed =>
      'Could not save match changes. Please try again.';

  @override
  String confirmedPlayersCapacity(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count players currently confirmed · maximum 4',
      one: '1 player currently confirmed · maximum 4',
    );
    return '$_temp0';
  }

  @override
  String get matchChatUnavailable => 'Match chat is unavailable.';

  @override
  String get completedMatchNoChanges =>
      'This match has already been completed.';

  @override
  String get loginJoinMatch => 'Please log in to request to join a match.';

  @override
  String get joinRequestSent => 'Join request sent.';

  @override
  String get joinRequestFailed =>
      'Could not send your join request. Please try again.';

  @override
  String get completedMatchesNoChanges =>
      'Completed matches cannot be changed.';

  @override
  String get joinRequestApproved => 'Join request approved.';

  @override
  String get joinRequestDeclined => 'Join request declined.';

  @override
  String get approveRequestFailed =>
      'Could not approve request. Please try again.';

  @override
  String get declineRequestFailed =>
      'Could not decline request. Please try again.';

  @override
  String get loginLeaveMatch => 'Please log in to leave a match.';

  @override
  String get leftMatch => 'You left the match.';

  @override
  String get leaveMatchFailed => 'Could not leave the match. Please try again.';

  @override
  String get loginCancelMatch => 'Please log in to cancel a match.';

  @override
  String get cancelMatchFailed =>
      'Could not cancel the match. Please try again.';

  @override
  String get playersFromMatch => 'Players from this match';

  @override
  String get confirmedRole => 'Confirmed';

  @override
  String get cancellingEllipsis => 'Cancelling...';

  @override
  String get leavingEllipsis => 'Leaving...';

  @override
  String get requestStatusFailed => 'Could not load request status';

  @override
  String get loadingRequestStatus => 'Loading request status…';

  @override
  String get matchFull => 'Match Full';

  @override
  String get requestingEllipsis => 'Requesting...';

  @override
  String get loadingRequest => 'Loading request...';

  @override
  String get loadRequestFailed => 'Could not load request';

  @override
  String get dateTimeUnavailable => 'Date and time unavailable';

  @override
  String ratingSelected(Object count) {
    return '$count of 5';
  }

  @override
  String get selectRating => 'Select a rating';

  @override
  String ratingSubmittedStars(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return 'Rating submitted · $_temp0';
  }

  @override
  String submittedStars(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return 'Submitted · $_temp0';
  }

  @override
  String get startupLoadingSemantics => 'PadelX loading';

  @override
  String privateVenueExactLocation(String address) {
    return 'Exact location: $address';
  }

  @override
  String get findMeAMatch => 'Quick Match';

  @override
  String get matchmakingActionFailed =>
      'That matchmaking action could not be completed. Try again.';

  @override
  String get completeMatchmakingRequest =>
      'Choose a valid availability window and partner when applicable.';

  @override
  String get matchmakingIntro =>
      'Tell PadelX when you want to play. We’ll assemble the game for you.';

  @override
  String get solo => 'Solo';

  @override
  String get withPartner => 'With a Partner';

  @override
  String get choosePartner => 'Choose a partner';

  @override
  String get availableFrom => 'Available from';

  @override
  String get availableUntil => 'Available until';

  @override
  String searchLocationSummary(String city, String area) {
    String _temp0 = intl.Intl.selectLogic(area, {
      'other': '$area, $city',
      'empty': '$city',
    });
    return '$_temp0';
  }

  @override
  String get travelRadius => 'Travel radius';

  @override
  String get startSearching => 'Start Searching';

  @override
  String get startQuickMatch => 'Start Quick Match';

  @override
  String get partnerInvitation => 'Partner invitation';

  @override
  String get findingYourMatch => 'Finding your match…';

  @override
  String invitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String get cancelSearch => 'Cancel Search';

  @override
  String get matchFound => 'Match Found';

  @override
  String get playersReady => 'Players Ready';

  @override
  String get confirmMySpot => 'Confirm my spot';

  @override
  String get courtNotSelected => 'Court not selected yet';

  @override
  String offerExpiresMinutes(String minutes) {
    return 'Offer expires in about $minutes min';
  }

  @override
  String get confirmed => 'Confirmed';

  @override
  String get waiting => 'Waiting';

  @override
  String teamNumber(String number) {
    return 'Team $number';
  }

  @override
  String get matchmakingSpotFound => 'Match spot found';

  @override
  String get matchmakingMatchConfirmed => 'Match confirmed';

  @override
  String get matchmakingPartnerInviteBody =>
      'You have a matchmaking partner invitation.';

  @override
  String get matchmakingMatchFoundBody =>
      'A matchmaking offer is ready for your confirmation.';

  @override
  String get matchmakingSpotFoundBody =>
      'A spot is ready for your confirmation.';

  @override
  String get matchmakingMatchConfirmedBody => 'Your match is confirmed.';

  @override
  String get acceptMatch => 'Accept Match';

  @override
  String get chooseVenueToFinish =>
      'Everyone accepted. Choose a court to finish creating the match.';

  @override
  String get waitingForVenue =>
      'Everyone accepted. Waiting for the coordinator to choose the court.';

  @override
  String get chooseVenue => 'Choose Venue';

  @override
  String get openMatchDetails => 'Open Match Details';

  @override
  String get privateCourt => 'Private court';

  @override
  String get clubPublicCourt => 'Club / public court';

  @override
  String get privateCourtLocation => 'Private court location';

  @override
  String get searchVenue => 'Search for the court location';

  @override
  String get courtBookingSeparate => 'Court booking is handled separately.';

  @override
  String get confirmVenue => 'Confirm Venue';

  @override
  String get matchmakingUnavailable => 'Matchmaking is unavailable right now.';

  @override
  String get findAPlayer => 'Find a Player';

  @override
  String get autoFillExplanation =>
      'Let PadelX find a compatible player for this spot.';

  @override
  String get stopAutoFill => 'Stop AutoFill';

  @override
  String get findingAnotherPlayer => 'Finding another player…';

  @override
  String get padelVenueSearchLabel => 'Padel club or court';

  @override
  String get padelVenueSearchHint => 'Search nearby padel venues';

  @override
  String padelVenueRadiusExplanation(String distance) {
    return 'Showing padel venues within the agreed $distance km search area.';
  }

  @override
  String get noPadelVenuesInArea =>
      'No padel courts found within your search area.';

  @override
  String get padelVenueOutsideArea =>
      'That venue is outside the agreed search area.';

  @override
  String get padelVenueSearchUnavailable =>
      'Padel venue search is unavailable right now.';

  @override
  String get privateCourtAddressHelp =>
      'Can’t find your private court? Search for its street address.';

  @override
  String get yourSpotConfirmed => 'Your spot is confirmed';

  @override
  String get findingRemainingPlayers => 'We’re finding the remaining players.';

  @override
  String playersConfirmedCount(String confirmed) {
    return '$confirmed of 4 confirmed';
  }

  @override
  String get versus => 'VS';

  @override
  String get quickMatchPushWarning =>
      'Turn on notifications so you do not miss time-sensitive match offers. You can still use Quick Match.';

  @override
  String get confirmAttendance => 'Confirm attendance';

  @override
  String get didMatchHappen => 'Did this match happen?';

  @override
  String get yesMatchHappened => 'Yes';

  @override
  String get matchDidNotHappen => 'No, the match did not happen';

  @override
  String get whoPlayed => 'Who played?';

  @override
  String get attendanceSubmissionFinal =>
      'Your attendance confirmation is final and kept private.';

  @override
  String get attendanceSubmitted => 'Attendance submitted';

  @override
  String get attendanceSubmitFailed =>
      'Attendance could not be submitted. Try again.';
}
