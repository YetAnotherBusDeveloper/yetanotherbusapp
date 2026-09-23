// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'YetAnotherBusApp';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearanceSectionTitle => 'Appearance';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageTraditionalChinese => 'Traditional Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get interfaceScaleLabel => 'Interface scale';

  @override
  String get interfaceScaleDescription =>
      'Adjust the size of text and interface elements.';

  @override
  String interfaceScaleValue(int percent) {
    return '$percent%';
  }

  @override
  String get themeModeLabel => 'Theme mode';

  @override
  String get themeModeSystem => 'Follow system';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get compactModeTitle => 'Compact mode';

  @override
  String get compactModeDescription =>
      'Show less descriptive text on the home screen and some cards; desktop always uses compact mode.';

  @override
  String get showWeatherTitle => 'Show weather';

  @override
  String get showWeatherDescription =>
      'Show the current temperature beside the home title. Tap it to open the full forecast.';

  @override
  String get mapProviderLabel => 'Map provider';

  @override
  String get personalizationTitle => 'Personalization';

  @override
  String get personalizationDescription => 'Colors and background opacity';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonOpenSettings => 'Open settings';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonBack => 'Back';

  @override
  String get commonDownload => 'Download';

  @override
  String get commonDownloading => 'Downloading...';

  @override
  String get commonDone => 'Done';

  @override
  String get commonLater => 'Maybe later';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonUpdate => 'Update';

  @override
  String get commonView => 'View';

  @override
  String get commonReload => 'Reload';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonCenter => 'Center';

  @override
  String commonPercentage(int value) {
    return '$value%';
  }

  @override
  String get errorGeneric => 'Something went wrong. Please try again later.';

  @override
  String get errorNetwork =>
      'There is a network problem. Check your connection and try again.';

  @override
  String get errorTimeout =>
      'The connection timed out. Please try again later.';

  @override
  String get errorRateLimited => 'Too many requests. Please try again later.';

  @override
  String get transitBus => 'Bus';

  @override
  String get transitMetro => 'Metro';

  @override
  String get transitThsr => 'HSR';

  @override
  String get transitTra => 'TRA';

  @override
  String get transitYouBike => 'YouBike';

  @override
  String get transitBusHomePresence => 'Bus home';

  @override
  String get homeSearchTitle => 'Search routes';

  @override
  String get homeSearchDescription =>
      'Enter a bus number, route name, or intercity route to see live arrivals.';

  @override
  String get homeFavoritesTitle => 'Favorites';

  @override
  String get homeFavoritesDescription =>
      'Organize frequently used stops and groups for quick access.';

  @override
  String get homeNearbyTitle => 'Nearby stops';

  @override
  String get homeNearbyDescription =>
      'Find bus stops near your current location.';

  @override
  String get homeBusMapTitle => 'Live bus map';

  @override
  String get homeBusMapDescription =>
      'See buses across the region and open a vehicle to view its route and stops.';

  @override
  String get homeOverviewTitle => 'Overview';

  @override
  String homeSelectedRegions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regions selected',
      one: '1 region selected',
    );
    return '$_temp0';
  }

  @override
  String get homeOpenSettings => 'Open settings';

  @override
  String get databaseDownloadsTitle => 'Databases and downloads';

  @override
  String get announcementsTitle => 'Announcements';

  @override
  String get installAppTooltip => 'Install app';

  @override
  String get installAppTitle => 'Install this app?';

  @override
  String get installAppDescription =>
      'Install YABus so you can open it like any other app.';

  @override
  String get installAppLimitation =>
      'Some features from the full app are not available.';

  @override
  String get installAppConfirm => 'Install it! \\(^o^)/';

  @override
  String get installRequestSent => 'The install request was sent.';

  @override
  String get installCancelled => 'Installation was cancelled.';

  @override
  String get installUnavailable =>
      'This device cannot show an installation prompt right now.';

  @override
  String get smartRecommendationsTitle => 'Smart recommendations';

  @override
  String get smartRecommendationsSubtitle =>
      'Routes suggested from your usage patterns';

  @override
  String get smartRecommendationsDisabled =>
      'This feature is off. When enabled, YABus learns which routes you open at different times and suggests them on the home screen.';

  @override
  String get smartRecommendationsGoToSettings => 'Go to settings';

  @override
  String get smartRecommendationsNeedDatabase =>
      'Download a local database first. This card will then learn your usage patterns and show arrivals at nearby stops.';

  @override
  String destinationStopId(int stopId) {
    return 'Destination stop $stopId';
  }

  @override
  String directionValue(String direction) {
    return 'Direction: $direction';
  }

  @override
  String destinationValue(String destination) {
    return 'Destination: $destination';
  }

  @override
  String approximateDistance(String distance) {
    return 'About $distance away';
  }

  @override
  String get tryAgainLater => 'Please try again later.';

  @override
  String get nearbyMapTitle => 'Nearby map';

  @override
  String get nearbyMapSubtitle => 'Where are you taking the bus today?';

  @override
  String get refreshNearbyStops => 'Refresh nearby stops';

  @override
  String get nearbyNoStopsToDisplay =>
      'There are no nearby stops to display right now.';

  @override
  String get mapNoLocations => 'There are no stop locations to display.';

  @override
  String get locationServicesDisabled => 'Location services are turned off.';

  @override
  String get locationPermissionDenied => 'Location permission was not granted.';

  @override
  String get searchTitle => 'Search routes or stops';

  @override
  String get searchHint => 'Search by bus route or stop name';

  @override
  String get searchClearTooltip => 'Clear search';

  @override
  String get searchShowKeypadTooltip => 'Open route keypad';

  @override
  String get searchErrorTitle => 'Search hit a snag';

  @override
  String get searchResolvingTitle => 'Checking nearby stops';

  @override
  String get searchResolvingMessage =>
      'Searching for stops you can board nearby...';

  @override
  String get searchEmptyTitle => 'No matching bus found';

  @override
  String get searchEmptyMessage =>
      'Try a shorter query or search by stop name.';

  @override
  String get searchEmptyNeedsDatabase =>
      'Some stop searches need a local database. Update the database and try again.';

  @override
  String get searchHistoryEmpty => 'No search history yet.';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String searchNearestStop(String stopName, String distance) {
    return 'Nearest to you: $stopName ($distance)';
  }

  @override
  String get searchKeypadTitle => 'Route prefixes and numbers';

  @override
  String get searchKeypadCollapseTooltip => 'Collapse route keypad';

  @override
  String get searchKeypadTextTooltip => 'Switch to text keyboard';

  @override
  String get searchKeypadBackspaceTooltip => 'Backspace';

  @override
  String get searchKeypadOther => 'Other';

  @override
  String get nearbyTitle => 'Nearby stops';

  @override
  String get nearbyLocationSettings => 'Location settings';

  @override
  String get nearbyPermissionSettings => 'Permission settings';

  @override
  String get nearbyEmpty => 'No nearby stops were found.';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesUpdating => 'Updating';

  @override
  String get favoritesRealtimeUpdateFailed =>
      'Live information could not be updated';

  @override
  String get favoritesNoRealtime =>
      'No live information is available right now';

  @override
  String get favoritesPartialUpdateFailed =>
      'Some live information could not be updated';

  @override
  String get favoritesLoadFailed => 'Could not load favorites';

  @override
  String get favoritesUpdateFailedKeepingData =>
      'Update failed; showing the previous data';

  @override
  String favoriteRemoved(String item, String group) {
    return 'Removed $item from $group';
  }

  @override
  String get favoriteTypeRoute => 'Route';

  @override
  String get favoriteTypeStation => 'Station';

  @override
  String get favoriteTypeBoarding => 'Stop';

  @override
  String get favoriteGroupKindMixed => 'Mixed';

  @override
  String get favoriteNoUpcomingArrivals => 'No upcoming arrivals';

  @override
  String favoriteStationSide(String side) {
    return 'Side $side';
  }

  @override
  String routeIdFallback(int routeId) {
    return 'Route $routeId';
  }

  @override
  String stopIdFallback(int stopId) {
    return 'Stop $stopId';
  }

  @override
  String get favoriteFetchingRealtime => 'Getting live information';

  @override
  String get favoriteNoSelectableStops =>
      'This route has no stops to select right now.';

  @override
  String stopSequence(int number) {
    return 'Stop $number';
  }

  @override
  String favoriteDestinationSet(String stopName) {
    return 'Destination set to $stopName';
  }

  @override
  String get favoriteDestinationCleared =>
      'The destination was cleared for this favorite.';

  @override
  String get favoritesFinishSorting => 'Finish sorting';

  @override
  String get favoritesAdjustSorting => 'Reorder favorites';

  @override
  String get favoritesManageGroupsTooltip => 'Manage favorite groups';

  @override
  String favoritesUpdateCountdown(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Updates in $seconds seconds',
      one: 'Updates in 1 second',
    );
    return '$_temp0';
  }

  @override
  String get favoritesErrorTitle => 'Favorites got stuck';

  @override
  String get favoritesTryAgain => 'Try again';

  @override
  String get favoritesGroupEmpty => 'This group has no favorites.';

  @override
  String routeKeyFallback(int routeKey) {
    return 'routeKey $routeKey';
  }

  @override
  String get favoriteDestinationSettings => 'Destination settings';

  @override
  String get favoriteSetDestination => 'Set destination';

  @override
  String get favoriteClearDestination => 'Clear destination';

  @override
  String get favoritesEmptyMessage => 'You have not saved any stops yet :(';

  @override
  String get favoritesEmptyTitle => 'No regular stop yet';

  @override
  String get favoriteGroupsTitle => 'Favorite groups';

  @override
  String get favoriteGroupAddTitle => 'New group';

  @override
  String get favoriteGroupNameLabel => 'Group name';

  @override
  String get favoriteGroupNameHint => 'For example: Home';

  @override
  String get favoriteGroupCategoryLabel => 'Favorite type';

  @override
  String get favoriteGroupAddAction => 'Add';

  @override
  String get favoriteGroupDuplicate =>
      'A favorite group with this name already exists.';

  @override
  String get favoriteGroupsEmpty => 'No groups yet.';

  @override
  String get favoriteGroupDeleteTitle => 'Delete group';

  @override
  String favoriteGroupDeletePrompt(String group) {
    return 'Delete “$group”?';
  }

  @override
  String favoriteGroupSummary(String kind, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favorites',
      one: '1 favorite',
      zero: 'No favorites',
    );
    return '$kind · $_temp0';
  }

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSignedOut => 'Not signed in.';

  @override
  String accountSignedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String wearConnectedWatch(String names) {
    return 'Connected watch: $names';
  }

  @override
  String wearConnectedWatches(String names, int count) {
    return 'Connected watches: $names ($count total)';
  }

  @override
  String get wearSyncTitle => 'Enable Wear OS sync';

  @override
  String get wearSyncDescription => 'Sync favorite stops to your watch';

  @override
  String get wearNoFavorites =>
      'There are no favorite stops yet. Add a favorite before syncing.';

  @override
  String get wearSyncCategory => 'Sync group';

  @override
  String get wearAllCategories => 'All groups';

  @override
  String databaseCurrentRegion(String region) {
    return 'Current region: $region';
  }

  @override
  String databaseStartupUpdate(String mode) {
    return 'On launch: $mode';
  }

  @override
  String databasePendingRegions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regions have updates',
      one: '1 region has an update',
    );
    return '$_temp0';
  }

  @override
  String get databaseOpenPage => 'Open database page';

  @override
  String get usageAndUpdatesTitle => 'Usage and updates';

  @override
  String get alwaysShowSecondsTitle => 'Always show seconds';

  @override
  String get alwaysShowSecondsDescription =>
      'They are usually not very accurate';

  @override
  String get hapticFeedbackTitle => 'Haptic feedback';

  @override
  String get hapticFeedbackDescription =>
      'Provide haptic feedback for taps and actions';

  @override
  String get showAdsTitle => 'Show ads';

  @override
  String get adsLockedMessage => ' Keep trying, haha';

  @override
  String get adsEnabledDescription => 'Take away the developer\'s lunch money.';

  @override
  String get adsPleaOne => 'Please don\'t';

  @override
  String get adsPleaTwo => 'Would begging help?';

  @override
  String get adsPleaThree => 'You can\'t do this to me';

  @override
  String get adsPleaFour => 'QAQ';

  @override
  String get adsDisableTitle => 'Are you sure?';

  @override
  String get adsDisableDescription => 'I have no money :(';

  @override
  String get adsKeepEnabled => 'Keep them on';

  @override
  String get adsDisableConfirm => 'Turn off';

  @override
  String get smartRecommendationsDescription =>
      'Show suggestions on the home screen based on routes you open and when you use them.';

  @override
  String get autoFavoriteTitle => 'Auto-add frequent favorites';

  @override
  String get autoFavoriteDescription =>
      'Automatically add a stop to the “Frequent” group after several trips in a short period.';

  @override
  String get smartNotificationTitle => 'Smart recommendation notifications';

  @override
  String get smartNotificationDescription =>
      'Suggest routes in the background around times you often travel.';

  @override
  String get smartNotificationPermissionRequired =>
      'Notification permission is required for smart recommendation notifications.';

  @override
  String get keepScreenAwakeTitle => 'Keep screen on for bus routes';

  @override
  String get keepScreenAwakeDescription =>
      'Keep the screen awake on route detail pages.';

  @override
  String get backgroundTripTitle => 'Background trip alerts';

  @override
  String get backgroundTripDescription =>
      'Notification and location permissions are required for trip alerts in the background.';

  @override
  String get backgroundTripIosDescription =>
      'Notification and background location permissions are required for trip alerts in the background.';

  @override
  String get favoriteWidgetRefreshLabel => 'Favorite widget background refresh';

  @override
  String get favoriteWidgetRefreshHelper =>
      'Android widgets have a minimum refresh interval of 15 minutes.';

  @override
  String minutesValue(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String normalUpdateInterval(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Normal refresh interval: $_temp0';
  }

  @override
  String retryInterval(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Retry interval after errors: $_temp0';
  }

  @override
  String secondsValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get appUpdatesTitle => 'App updates';

  @override
  String get updateChannelLabel => 'Update channel';

  @override
  String get updateCheckOnLaunchLabel => 'Check on launch';

  @override
  String get updateChannelDeveloper => 'Developer';

  @override
  String get updateChannelNightly => 'Nightly';

  @override
  String get updateChannelRelease => 'Release';

  @override
  String get updateChannelDeveloperDescription =>
      'Do not check for app updates';

  @override
  String get updateChannelNightlyDescription =>
      'Compare against the latest successful build commit';

  @override
  String get updateChannelReleaseDescription =>
      'Compare against the latest GitHub release';

  @override
  String get updateCheckOff => 'Off';

  @override
  String get updateCheckNotify => 'Notification';

  @override
  String get updateCheckPopup => 'Pop-up';

  @override
  String get updateCheckOffDescription => 'Only show results for manual checks';

  @override
  String get updateCheckNotifyDescription => 'Show a notification after launch';

  @override
  String get updateCheckPopupDescription =>
      'Open the update window after launch';

  @override
  String get appUpdateChecking => 'Checking...';

  @override
  String get appUpdateCheckNow => 'Check for app updates';

  @override
  String appUpdateRecentResult(String result) {
    return 'Latest result: $result';
  }

  @override
  String appUpdateAvailableResult(String version) {
    return 'Version $version is available.';
  }

  @override
  String get appUpdateUpToDateResult => 'The app is up to date.';

  @override
  String get appUpdateUnavailableResult =>
      'Update information is unavailable right now.';

  @override
  String get appUpdateNightlyDialogTitle => 'Nightly update';

  @override
  String appUpdateReleaseDialogTitle(String version) {
    return 'Release update: $version';
  }

  @override
  String appUpdateNightlySummary(String commit) {
    return 'Nightly build $commit is ready to download.';
  }

  @override
  String appUpdateCurrentVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String appUpdateLatestVersion(String version) {
    return 'Latest version: $version';
  }

  @override
  String appUpdateFullChangesMarkdown(String range, String url) {
    return 'Full changes: [$range]($url)';
  }

  @override
  String appUpdateCommitMarkdown(String commit, String url) {
    return 'Commit: [`$commit`]($url)';
  }

  @override
  String get appUpdateContentsTitle => 'What\'s new';

  @override
  String get appUpdateDownloadLink => 'Download link';

  @override
  String get appUpdateCopyDownloadLink => 'Copy download link';

  @override
  String get appUpdateDownloadLinkCopied =>
      'Download link copied to the clipboard.';

  @override
  String get appUpdateDownloadAndInstall => 'Download and install';

  @override
  String get appUpdatePreparing => 'Preparing update...';

  @override
  String get appUpdateDownloading => 'Downloading update...';

  @override
  String get appUpdatePreparingInstaller => 'Preparing installer...';

  @override
  String get appUpdateLaunchingInstaller => 'Launching installer...';

  @override
  String get appUpdatePreparingDesktopInstaller =>
      'Preparing to close the app and launch the installer...';

  @override
  String get appUpdateInstallUnsupported =>
      'In-app update installation is not supported on this platform.';

  @override
  String get appUpdateInstallPermissionRequired =>
      'Allow this app to install unknown apps, then select update again.';

  @override
  String get appUpdateInstallerLaunched => 'The installer has been launched.';

  @override
  String get appUpdateDesktopInstallerScheduled =>
      'The app will close and launch the installer.';

  @override
  String appUpdateInstallFailed(String error) {
    return 'Could not download or install the update: $error';
  }

  @override
  String get historyPrivacyTitle => 'History and privacy';

  @override
  String searchHistoryLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Search history limit: $_temp0';
  }

  @override
  String itemsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String smartRoutesCount(int count) {
    return 'Smart recommendation routes: $count';
  }

  @override
  String routeSelectionsCount(int count) {
    return 'Route selections: $count';
  }

  @override
  String get clearSearchHistory => 'Clear search history';

  @override
  String get clearSmartHistory => 'Clear smart recommendation history';

  @override
  String get clearRouteSelectionHistory => 'Clear route selection history';

  @override
  String get termsOfService => 'Terms of service';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get onboardingSettingsTitle => 'Getting started';

  @override
  String get restartOnboarding => 'Run setup again';

  @override
  String get aboutTitle => 'About';

  @override
  String get contributorsTitle => 'Contributors';

  @override
  String get communityTitle => 'Join the frog community';

  @override
  String get communityDescription => 'My Discord server uwu';

  @override
  String get feedbackTitle => 'Feedback';

  @override
  String get feedbackDescription =>
      'Report a problem, request a feature, or tell us anything';

  @override
  String get discordOpenFailed => 'Could not open the Discord community link.';

  @override
  String get instagramOpenFailed => 'Could not open the Instagram page.';

  @override
  String githubOpenFailed(String name) {
    return 'Could not open $name\'s GitHub page.';
  }

  @override
  String get databaseAutoUpdateOff => 'Do not check';

  @override
  String get databaseAutoUpdatePopup => 'Check and show a pop-up';

  @override
  String get databaseAutoUpdateNotify => 'Check and notify';

  @override
  String get databaseAutoUpdateAlways => 'Always update automatically';

  @override
  String get databaseAutoUpdateWifi => 'Auto-update on Wi-Fi only';

  @override
  String get databaseAutoUpdateCellular => 'Auto-update on mobile data only';

  @override
  String get onboardingLocationServiceDisabled =>
      'Location services are off. You can still select databases manually.';

  @override
  String get onboardingLocationPermissionDenied =>
      'Location permission was not granted. Select databases manually instead.';

  @override
  String get onboardingLocationUnavailable =>
      'Location permission was granted, but your location is temporarily unavailable. Select databases manually instead.';

  @override
  String onboardingProviderSelected(String provider) {
    return 'Nearest database selected automatically: $provider.';
  }

  @override
  String onboardingLocationFailed(String error) {
    return 'Location setup failed ($error). Select databases manually instead.';
  }

  @override
  String get onboardingWelcome => 'Welcome to YABus';

  @override
  String get onboardingSearchDescription =>
      'Enter a bus name or number to open live stop information.';

  @override
  String get onboardingFavoritesTitle => 'Save stops';

  @override
  String get onboardingFavoritesDescription =>
      'Organize regular stops into groups and return with one tap.';

  @override
  String get onboardingNearbyDescription =>
      'Use location access to quickly find nearby stops.';

  @override
  String get onboardingLegalPrefix => 'By continuing, you agree to our ';

  @override
  String get onboardingLegalAnd => ' and ';

  @override
  String get onboardingLegalSuffix => '.';

  @override
  String get onboardingStart => 'Start setup';

  @override
  String get onboardingLocationTitle => 'Location access';

  @override
  String get onboardingLocationDescription =>
      'Location access helps us find the nearest bus stops.';

  @override
  String get onboardingLocationConsent =>
      'Allowing access means you agree to let the app process your location to find nearby stops.';

  @override
  String get onboardingLocationServerUse =>
      'Your location is sent to the server only when no local database is available.';

  @override
  String get onboardingProcessing => 'Working...';

  @override
  String get onboardingAllowContinue => 'Allow and continue';

  @override
  String get onboardingChooseManually => 'Select databases manually';

  @override
  String get onboardingDownloadTitle => 'Download databases';

  @override
  String get onboardingDownloadDescription =>
      'Select one or more regional databases to use on this device.';

  @override
  String get onboardingRegionList => 'Regions';

  @override
  String onboardingNearestSuggestion(String provider) {
    return 'Nearest suggestion: $provider';
  }

  @override
  String onboardingDefaultSource(String provider) {
    return 'Default data source: $provider';
  }

  @override
  String onboardingSelectedDatabases(String providers) {
    return 'Selected databases: $providers';
  }

  @override
  String onboardingDatabaseProgress(int downloaded, int total) {
    return 'Downloaded $downloaded of $total databases';
  }

  @override
  String onboardingDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String shellWebUpdateAvailable(String version, String buildNumber) {
    return 'A new version is available ($version+$buildNumber)';
  }

  @override
  String get shellEnableSyncTitle => 'Enable cloud sync?';

  @override
  String get shellEnableSyncDescription =>
      'After signing in, favorite stops and preferences can sync automatically. They update when you open the app and shortly after changes.';

  @override
  String get shellEnableSyncAction => 'Enable sync';

  @override
  String get shellSyncEnabled => 'Cloud sync is enabled.';

  @override
  String get shellSyncSkipped =>
      'Automatic sync was skipped. You can still sync manually later.';

  @override
  String shellSyncPreferenceFailed(String error) {
    return 'Could not save the sync preference: $error';
  }

  @override
  String get shellSignInSucceeded => 'Signed in.';

  @override
  String shellSignInFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String shellAccountLinked(String provider) {
    return 'Linked the $provider account.';
  }

  @override
  String shellAccountAlreadyLinked(String provider) {
    return '$provider is already linked to this account.';
  }

  @override
  String shellLinkFailed(String error) {
    return 'Linking failed: $error';
  }

  @override
  String get shellMergeAccountsTitle => 'Merge accounts?';

  @override
  String shellMergeAccountsDescription(String provider) {
    return '$provider belongs to another account. The identities and data below will move to this account, and the source account will be deleted:';
  }

  @override
  String shellActiveDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The source account has $count active devices.',
      one: 'The source account has 1 active device.',
    );
    return '$_temp0';
  }

  @override
  String get shellMergeAccountsAction => 'Merge accounts';

  @override
  String shellAccountsMerged(String provider) {
    return 'Accounts merged. $provider is now linked to this account.';
  }

  @override
  String shellMergeFailed(String error) {
    return 'Merge failed: $error';
  }

  @override
  String get shellDatabaseUpdating => 'Updating databases...';

  @override
  String shellDatabaseUpdated(String providers) {
    return 'Databases updated: $providers';
  }

  @override
  String shellDatabaseAutoUpdateFailed(String error) {
    return 'Automatic database update failed: $error';
  }

  @override
  String get shellDatabaseUpdateComplete => 'Database update complete.';

  @override
  String shellDatabaseUpdateFailed(String error) {
    return 'Database update failed: $error';
  }

  @override
  String shellDatabaseUpdatesAvailable(String providers) {
    return 'Database updates are available for: $providers';
  }

  @override
  String shellDatabaseCheckFailed(String error) {
    return 'Could not check for database updates: $error';
  }

  @override
  String get shellDatabaseUpdateDeferred => 'The database update was deferred.';

  @override
  String get etaLoading => 'Loading';

  @override
  String get etaArriving => 'Arriving';

  @override
  String etaSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String etaMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String etaMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m\n${seconds}s';
  }

  @override
  String get autoFavoriteFallback => 'this stop';

  @override
  String autoFavoriteAdded(String label) {
    return 'Ride this often? “$label” was added to Frequent favorites.';
  }

  @override
  String get commonClose => 'Close';

  @override
  String get commonOkay => 'OK';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonAll => 'All';

  @override
  String get commonAddToHomeScreen => 'Add to Home screen';

  @override
  String get commonChooseStop => 'Choose a stop';

  @override
  String get commonAcknowledge => 'Got it';

  @override
  String get directionOutbound => 'Outbound';

  @override
  String get directionInbound => 'Inbound';

  @override
  String directionNumber(int direction) {
    return 'Direction $direction';
  }

  @override
  String directionTo(String destination) {
    return 'To $destination';
  }

  @override
  String relativeSecondsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds ago',
      one: '1 second ago',
    );
    return '$_temp0';
  }

  @override
  String relativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String distanceMetersValue(int meters) {
    return '$meters m';
  }

  @override
  String distanceKilometersValue(String kilometers) {
    return '$kilometers km';
  }

  @override
  String speedKilometersPerHour(int speed) {
    return '$speed km/h';
  }

  @override
  String get busStatusNormal => 'Normal';

  @override
  String get busStatusAccident => 'Accident';

  @override
  String get busStatusBreakdown => 'Breakdown';

  @override
  String get busStatusTraffic => 'Traffic';

  @override
  String get busStatusEmergency => 'Emergency';

  @override
  String get busStatusRefueling => 'Refueling';

  @override
  String get busStatusUnclear => 'Unclear';

  @override
  String get busStatusDirectionUnclear => 'Direction unclear';

  @override
  String get busStatusOffRoute => 'Off route';

  @override
  String get busStatusNotInService => 'Not in service';

  @override
  String get busStatusFull => 'Full';

  @override
  String get busStatusChartered => 'Chartered';

  @override
  String get busStatusUnknown => 'Unknown';

  @override
  String busStatusUnknownCode(int code) {
    return 'Unknown ($code)';
  }

  @override
  String get stationFallbackTitle => 'Station';

  @override
  String get stationShortcutRequested =>
      'The station shortcut request was sent.';

  @override
  String get shortcutUnsupported =>
      'This device does not support Home screen shortcuts.';

  @override
  String get stationNotFound => 'Could not find information for this station.';

  @override
  String get stationPinTooltip => 'Add station to Home screen';

  @override
  String get stationNoSides =>
      'There are no stops to display at this station right now.';

  @override
  String stationSideLabel(String side) {
    return 'Stop $side';
  }

  @override
  String stationSideDirection(String side, String direction) {
    return '$side · $direction';
  }

  @override
  String stationSideNoRoutes(String side) {
    return 'No routes serve stop $side right now.';
  }

  @override
  String busMapTitle(String region) {
    return 'Live bus map · $region';
  }

  @override
  String busMapRouteDataLoadFailed(String error) {
    return 'Could not load route data: $error';
  }

  @override
  String get busMapRouteDetailUnavailable =>
      'Details are not available for this route right now.';

  @override
  String busMapSwitchedRegion(String region) {
    return 'Switched to $region';
  }

  @override
  String get busMapCloseFilter => 'Close filter';

  @override
  String get busMapFilterRoutes => 'Filter routes';

  @override
  String get busMapFavoritesOnly => 'Show favorite routes only';

  @override
  String get busMapLocate => 'My location';

  @override
  String get busMapSwitchRegion => 'Switch region';

  @override
  String get busMapFilterHint => 'Filter by route name or license plate';

  @override
  String get busMapNoData => 'No bus data is available right now';

  @override
  String get busMapLoadingPositions => 'Loading bus locations...';

  @override
  String busMapBusCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses',
      one: '1 bus',
    );
    return '$_temp0';
  }

  @override
  String busMapBusCountUpdated(int count, String updated) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses · $updated',
      one: '1 bus · $updated',
    );
    return '$_temp0';
  }

  @override
  String get busMapZoomForBuses =>
      'Zoom in or tap a circle to see individual buses';

  @override
  String busMapShownCount(int shown, int total) {
    return 'Showing $shown of $total buses; zoom in to see more';
  }

  @override
  String get busMapNoFavoriteRoutes =>
      'No favorite routes are available in this region';

  @override
  String get busMapNoMatches => 'No matching buses found';

  @override
  String get busMapDataStale => 'Data may be out of date';

  @override
  String get busMapDataIncomplete => 'Data may be incomplete';

  @override
  String get busMapUnsupportedTitle =>
      'The live bus map is not available in this region';

  @override
  String get busMapUnsupportedMessage =>
      'Use the menu in the upper-right corner to switch regions.';

  @override
  String get busMapRouteStops => 'Stops along the route';

  @override
  String get busMapSelectionHint =>
      'Tap a bus to see its route, direction, and stops.';

  @override
  String busMapClusterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses',
      one: '1 bus',
    );
    return '$_temp0';
  }

  @override
  String busMapClusterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses here. Tap to zoom in.',
      one: '1 bus here. Tap to zoom in.',
    );
    return '$_temp0';
  }

  @override
  String get busMapYourLocation => 'Your location';

  @override
  String get busMapClearSelection => 'Clear selection';

  @override
  String busMapSameRouteRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses running on this route',
      one: '1 bus running on this route',
    );
    return '$_temp0';
  }

  @override
  String busMapBareRouteCode(String code) {
    return 'This bus has route code $code, but no route name is available.';
  }

  @override
  String busMapAmbiguousFamily(String family) {
    return 'This bus belongs to the “$family” route family, but its exact service cannot be determined.';
  }

  @override
  String get busMapRouteDetails => 'Route details';

  @override
  String get busMapShowWholeRoute => 'Show full route';

  @override
  String get routeMapRefreshing => 'Updating';

  @override
  String routeMapRefreshCountdown(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Updates in $seconds seconds',
      one: 'Updates in 1 second',
    );
    return '$_temp0';
  }

  @override
  String get routeMapTitle => 'Bus map';

  @override
  String get routeMapToggleBuses => 'Buses';

  @override
  String get routeMapToggleStops => 'Stops';

  @override
  String get routeMapRecenter => 'Recenter on your location';

  @override
  String get routeMapNoData => 'No route map data is available right now';

  @override
  String get routeMapSpeed => 'Speed';

  @override
  String get routeMapBearing => 'Dir.';

  @override
  String get routeMapUpdated => 'Upd.';

  @override
  String get routeMapPosition => 'Pos.';

  @override
  String get routeMapStopSequence => 'Order';

  @override
  String get routeMapArrival => 'ETA';

  @override
  String get routeMapAngle => 'Angle';

  @override
  String get routeMapStatus => 'State';

  @override
  String get routeMapOnRoute => 'On route';

  @override
  String get routeMapSnappedToRoute => 'On line';

  @override
  String routeMapOffRoute(int meters) {
    return '$meters m off route';
  }

  @override
  String routeMapOffLine(int meters) {
    return '$meters m off line';
  }

  @override
  String get transferMissingCoordinates =>
      'This stop has no coordinates, so nearby transfers cannot be found.';

  @override
  String get transferEmpty =>
      'There are no nearby transfer options to display right now.';

  @override
  String get transferTitle => 'Nearby transfers';

  @override
  String transferWalkingRanges(String stopName) {
    return '$stopName\nBuses within a 250 m walk and YouBike stations within 300 m';
  }

  @override
  String transferRouteCount(String distance, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count routes',
      one: '1 route',
    );
    return '$distance · $_temp0';
  }

  @override
  String transferBikeAvailability(int rent, int returns) {
    return 'Rent $rent · Return $returns';
  }

  @override
  String transferBikeAvailabilityDistance(
    String distance,
    int rent,
    int returns,
  ) {
    return '$distance · Rent $rent · Return $returns';
  }

  @override
  String get routeDetailTitle => 'Bus information';

  @override
  String get routeDetailStatusRefreshing => 'Updating';

  @override
  String get routeDetailStatusLoadingRoute => 'Loading route data';

  @override
  String get routeDetailStatusLoadingRealtime => 'Loading live arrivals';

  @override
  String get routeDetailStatusRealtimeUnavailable =>
      'Live information is temporarily unavailable';

  @override
  String get routeDetailStatusLoadFailed => 'Could not load';

  @override
  String get routeDetailStatusLoadingFamily => 'Loading related services';

  @override
  String get routeDetailCancelledToday => 'Today\'s canceled departures';

  @override
  String routeDetailDirectionHeading(String direction) {
    return '$direction:';
  }

  @override
  String get routeDetailOperationsNotice => 'Service notice';

  @override
  String get routeDetailViewRoutePresence => 'Viewing route';

  @override
  String get routeDetailBackgroundPromptTitle =>
      'Enable background trip alerts?';

  @override
  String get routeDetailBackgroundPromptMessage =>
      'YABus can keep tracking this route in the background and alert you as you approach your destination.';

  @override
  String get routeDetailBackgroundNotificationPermission =>
      'Background trip alerts need notification permission to appear.';

  @override
  String get routeDetailOppoPromptTitle => 'Notice';

  @override
  String get routeDetailOppoPromptMessage =>
      'Your device may support live alerts. Enable them in YABus notification settings.';

  @override
  String get routeDetailSamsungPromptTitle => 'Samsung Now Bar settings';

  @override
  String get routeDetailSamsungPromptMessage =>
      'If trip information does not appear in Now Bar, enable Samsung\'s live notification test option.';

  @override
  String get routeDetailSamsungDeveloperSteps =>
      'If Developer options are not enabled:\nSettings → About phone → Software information → tap Build number 7 times';

  @override
  String get routeDetailSamsungLiveSteps =>
      'Then go to:\nSettings → Developer options → scroll to the bottom → More settings → Live notifications for all apps';

  @override
  String get routeDetailOpenSettingsFailed =>
      'Could not open system settings. Follow the path shown in the instructions instead.';

  @override
  String get routeDetailTripPaused => 'Background trip alerts paused';

  @override
  String get routeDetailTripResumed => 'Background trip alerts resumed';

  @override
  String get routeDetailLocationServiceRequired =>
      'Turn on location services to use background trip alerts.';

  @override
  String get routeDetailLocationPermissionRequired =>
      'Allow location access to use background trip alerts.';

  @override
  String get routeDetailNotificationPermissionRequired =>
      'Allow notifications to use arrival alerts.';

  @override
  String get routeDetailBackgroundLocationFallback =>
      'Always-on location was not enabled. Background trip alerts will continue using the last location and bus arrival data.';

  @override
  String get routeDetailBackgroundLocationTitle => 'Allow background location';

  @override
  String get routeDetailBackgroundLocationIos =>
      'To keep destination alerts and Live Activities updated in the background, set iPhone location access to Always.';

  @override
  String get routeDetailBackgroundLocationAndroid =>
      'To keep alerts working in the background, set Android location access to Allow all the time.';

  @override
  String get routeDetailAlwaysLocationTitle => 'Allow location all the time?';

  @override
  String get routeDetailAlwaysLocationMessage =>
      'YABus needs all-the-time location access to detect whether you have boarded or reached your stop in the background.';

  @override
  String get routeDetailEnableAction => 'Turn on';

  @override
  String get routeDetailDestinationPromptTitle => 'Set a destination alert?';

  @override
  String get routeDetailDestinationPromptMessage =>
      'Choose where you plan to get off and YABus will alert you as you approach.';

  @override
  String get routeDetailSetBoardingStop => 'Board here';

  @override
  String get routeDetailChangeBoardingStop => 'Change boarding';

  @override
  String get routeDetailSetDestinationAlert => 'Set destination';

  @override
  String get routeDetailBlockedDestination => 'Already set as the destination';

  @override
  String get routeDetailBlockedBoarding => 'Already set as the boarding stop';

  @override
  String get routeDetailSameBoardingDestination =>
      'The boarding stop cannot also be the destination.';

  @override
  String routeDetailBoardingStopSet(String stopName) {
    return 'Boarding stop set to $stopName.';
  }

  @override
  String routeDetailDestinationSet(String stopName) {
    return 'Destination alert set to $stopName.';
  }

  @override
  String get routeDetailManualBoardingCleared =>
      'Manual boarding stop cleared. It will be detected automatically when location becomes available.';

  @override
  String get routeDetailUsingCurrentLocation =>
      'The boarding stop will now follow your current location.';

  @override
  String get routeDetailTripActive => 'Background trip alerts active';

  @override
  String get routeDetailBusApproaching => 'Bus approaching';

  @override
  String routeDetailBusStopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bus is $count stops away',
      one: 'Bus is 1 stop away',
    );
    return '$_temp0';
  }

  @override
  String routeDetailNearestStopValue(String stopName) {
    return 'Nearest stop: $stopName';
  }

  @override
  String get routeDetailNotBoarded => 'Not boarded';

  @override
  String routeDetailBoardingStopValue(String stopName) {
    return 'Boarding stop: $stopName';
  }

  @override
  String routeDetailDestinationValue(String stopName) {
    return 'Destination: $stopName';
  }

  @override
  String get routeDetailWaitingForLocation => 'Locating...';

  @override
  String get routeDetailLocating => 'Locating';

  @override
  String get routeDetailWaitingToBoard => 'Waiting to board';

  @override
  String get routeDetailNearestStop => 'Nearest';

  @override
  String get routeDetailDestinationNotSet => 'No destination set';

  @override
  String get routeDetailBoarded => 'Boarded';

  @override
  String get routeDetailEtaNotDeparted => 'Not departed';

  @override
  String get routeDetailEtaLastBusPassed => 'Last bus departed';

  @override
  String routeDetailEtaApproxMinutesSeconds(int minutes, int seconds) {
    return 'About ${minutes}m ${seconds}s';
  }

  @override
  String routeDetailEtaApproxMinutes(int minutes) {
    return 'About $minutes min';
  }

  @override
  String get routeDetailFavoriteStop => 'Favorite stop';

  @override
  String get routeDetailFavoriteStation => 'Favorite station';

  @override
  String get routeDetailFavoriteGroupDuplicate =>
      'A favorite group with this name already exists.';

  @override
  String routeDetailFavoriteLimit(int count) {
    return 'Favorites are limited to $count items. This item could not be added.';
  }

  @override
  String routeDetailRouteAdded(String group) {
    return 'Route added to $group';
  }

  @override
  String get routeDetailStationIdMissing =>
      'This stop cannot be matched to a station because its identifier is missing.';

  @override
  String get routeDetailStationNotSynced =>
      'Station information for this stop has not been synced yet.';

  @override
  String routeDetailStationAdded(String station, String group) {
    return '$station added to $group';
  }

  @override
  String routeDetailFavoriteAdded(String group) {
    return 'Added to $group';
  }

  @override
  String routeDetailFavoriteAddedWithDestination(
    String group,
    String destination,
  ) {
    return 'Added to $group; destination: $destination';
  }

  @override
  String get routeDetailFavoriteDestinationTitle =>
      'Set a destination for this favorite?';

  @override
  String get routeDetailFavoriteDestinationMessage =>
      'When you open it from Favorites or a widget, its destination alert will be applied automatically.';

  @override
  String get routeDetailNoSelectableStops =>
      'There are no stops to select in this direction right now.';

  @override
  String get routeDetailShortcutRequested =>
      'The Home screen shortcut request was sent.';

  @override
  String get routeDetailRouteShortcutRequested =>
      'The route shortcut request was sent.';

  @override
  String get routeDetailDestinationCleared => 'Destination alert cleared.';

  @override
  String get routeDetailGoogleMapsFailed => 'Could not open Google Maps.';

  @override
  String get routeDetailRealtimeLoading => 'Loading live data...';

  @override
  String get routeDetailNoRealtime => 'No live data';

  @override
  String get routeDetailSelectFavoriteGroup => 'Choose a favorite group';

  @override
  String get routeDetailNewGroup => 'New group';

  @override
  String get routeDetailForumFailed => 'Could not open TWBusforum.';

  @override
  String get routeDetailBackgroundDrawerTitle => 'Background trip alerts';

  @override
  String get routeDetailBackgroundDrawerMessage =>
      'Manage background tracking and destination alerts here.';

  @override
  String get routeDetailPauseBackground => 'Pause background trip alerts';

  @override
  String get routeDetailResumeBackground => 'Resume background trip alerts';

  @override
  String get routeDetailPauseBackgroundMessage =>
      'Keep your settings, but pause background tracking and alerts.';

  @override
  String get routeDetailResumeBackgroundMessage =>
      'Resume background tracking and alerts.';

  @override
  String routeDetailCurrentStop(String stopName) {
    return 'Current stop: $stopName';
  }

  @override
  String get routeDetailBoardingStopHint =>
      'If location is unavailable, you can choose a boarding stop manually.';

  @override
  String get routeDetailDestinationHint =>
      'Choose a stop for the destination alert.';

  @override
  String get routeDetailClearManualBoarding => 'Clear manual boarding stop';

  @override
  String get routeDetailReturnToCurrentLocation => 'Use current location again';

  @override
  String get routeDetailClearManualBoardingHint =>
      'Keep alerts enabled and detect the boarding stop when location becomes available.';

  @override
  String get routeDetailCurrentLocationHint =>
      'Automatically follow the nearest stop to your current location.';

  @override
  String get routeDetailClearDestinationAlert => 'Clear destination alert';

  @override
  String get routeDetailVehicleBackfill => 'Backfilled location';

  @override
  String get routeDetailVehicleRealtime => 'Live location';

  @override
  String get routeDetailVehicleSource => 'Source';

  @override
  String get routeDetailVehicleEta => 'ETA at this stop';

  @override
  String get routeDetailVehicleNotes => 'Notes';

  @override
  String get routeDetailVehicleCondition => 'Condition';

  @override
  String get routeDetailVehicleFull => 'Full';

  @override
  String get routeDetailVehicleAtStop => 'At stop';

  @override
  String get routeDetailVehicleType => 'Vehicle';

  @override
  String get routeDetailVehicleElectric => 'Electric bus';

  @override
  String get routeDetailVehicleEquipment => 'Equipment';

  @override
  String get routeDetailVehicleAccessible => 'Low-floor / accessible';

  @override
  String get routeDetailViewOnMap => 'Map';

  @override
  String get routeDetailSearchForum => 'TWBusforum';

  @override
  String get routeDetailVehicleElectricShort => 'Electric';

  @override
  String get routeDetailVehicleAccessibleShort => 'Accessible';

  @override
  String get routeDetailVehicleFullShort => 'Full';

  @override
  String get routeDetailDestinationStop => 'Dest.';

  @override
  String get routeDetailNoDirectionsTitle => 'This route has no direction data';

  @override
  String get routeDetailNoDirectionsMessage =>
      'No outbound or inbound service could be found. Try again later.';

  @override
  String get routeDetailNoStopsTitle => 'This direction has no stops';

  @override
  String get routeDetailNoStopsMessage =>
      'The data may still be syncing. Refresh again shortly.';

  @override
  String get routeDetailNoMapData => 'No map data is available right now';

  @override
  String get routeDetailRouteNotice => 'Route notice';

  @override
  String get routeDetailNoticeUpdate => 'Service information has been updated';

  @override
  String get routeDetailCancelledDepartures => 'Canceled departures today';

  @override
  String routeDetailAdditionalNotices(String message, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$message ($count more)',
      one: '$message (1 more)',
    );
    return '$_temp0';
  }

  @override
  String get routeDetailErrorTitle => 'Bus information is stuck';

  @override
  String get routeDetailErrorMessage =>
      'Bus information cannot be loaded right now. Try refreshing again later.';

  @override
  String get routeDetailHideMap => 'Hide map';

  @override
  String get routeDetailShowMap => 'Show map';

  @override
  String get routeDetailJumpToNearestStop => 'Nearest stop';

  @override
  String get routeDetailScheduleTooltip => 'Route schedule';

  @override
  String get routeInfoActions => 'Route actions';

  @override
  String get routeInfoFavoriteRoute => 'Favorite route';

  @override
  String routeInfoLoadFailed(String error) {
    return 'Could not load: $error';
  }

  @override
  String get routeInfoOperators => 'Operators';

  @override
  String get routeInfoFamilySchedule => 'Related route schedule';

  @override
  String get routeInfoRelatedRoutes => 'Related routes';

  @override
  String get routeInfoShareLink => 'Share link';

  @override
  String get routeInfoLinkCopied => 'Link copied';

  @override
  String routeInfoPhone(String phone) {
    return 'Phone: $phone';
  }

  @override
  String routeInfoWebsite(String url) {
    return 'Website: $url';
  }

  @override
  String get scheduleWeekdayMon => 'Mon';

  @override
  String get scheduleWeekdayTue => 'Tue';

  @override
  String get scheduleWeekdayWed => 'Wed';

  @override
  String get scheduleWeekdayThu => 'Thu';

  @override
  String get scheduleWeekdayFri => 'Fri';

  @override
  String get scheduleWeekdaySat => 'Sat';

  @override
  String get scheduleWeekdaySun => 'Sun';

  @override
  String scheduleDateLabel(int month, int day, String weekday) {
    return '$month/$day ($weekday)';
  }

  @override
  String scheduleHolidayDateLabel(int month, int day, String weekday) {
    return '$month/$day ($weekday · holiday)';
  }

  @override
  String get scheduleChooseDate => 'Choose date';

  @override
  String get scheduleNoServiceDay => 'No departures are scheduled for this day';

  @override
  String get scheduleUnavailable => 'No schedule data is available right now';

  @override
  String get scheduleNoDepartureTimes => 'No departure times available';

  @override
  String stopScheduleSubtitle(String routeName) {
    return '$routeName · Estimated times';
  }

  @override
  String get stopScheduleDisclaimer =>
      'Estimated from the timetable; actual service may vary';

  @override
  String get stopScheduleNoTimetable => 'This route has no timetable data';

  @override
  String get stopScheduleNoStopTimes =>
      'No matching departure times are available at this stop on this day';

  @override
  String get stopScheduleFrequency => 'Service frequency';

  @override
  String get stopScheduleEstimatedArrival => 'Estimated arrival times';

  @override
  String get stopScheduleIncludesEstimates => 'Includes estimates';

  @override
  String get stopScheduleEstimateFootnote =>
      'Times marked “Includes estimates” are calculated from service frequency and travel time and are for reference only.';

  @override
  String get relatedRoutesLoadFailed =>
      'Could not load routes serving this stop';

  @override
  String relatedRoutesEmpty(String stopName) {
    return 'No routes found for “$stopName”';
  }

  @override
  String get relatedRoutesTitle => 'Routes serving this stop';

  @override
  String get stopActionSetDestination => 'Set as destination alert';

  @override
  String get stopActionSchedule => 'Departures / arrivals at this stop';

  @override
  String get stopActionRelatedRoutes => 'Routes serving this stop';

  @override
  String get stopActionTransfers => 'Nearby transfers';

  @override
  String get stopActionOpenGoogleMaps => 'Open in Google Maps';

  @override
  String get linkOpenFailed => 'Could not open the link.';

  @override
  String get announcementsSyncFailed => 'Could not sync announcements';

  @override
  String get announcementsEmpty => 'There are no announcements right now.';

  @override
  String get announcementNotFound => 'This announcement could not be found.';

  @override
  String get announcementResync => 'Sync announcements again';

  @override
  String get announcementEmbeddedContent => 'Embedded content';

  @override
  String get announcementSound => 'Notification sound';

  @override
  String get announcementReaction => 'React';

  @override
  String get announcementAddReaction => 'Add an emoji reaction';

  @override
  String get announcementFirstReaction => 'Be the first to react';

  @override
  String get announcementReactionUpdateFailed =>
      'Could not update your reaction. Please try again later.';

  @override
  String get announcementReactionSignInRequired => 'Sign in to add a reaction';

  @override
  String get legalDocumentUpdateFailed => 'Could not update the document';

  @override
  String get legalDocumentReload => 'Reload document';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountSignInDescription =>
      'Sign in to back up your favorite stops and settings.';

  @override
  String get accountLoginPageOpenFailed => 'Could not open the sign-in page.';

  @override
  String accountLoginFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get accountLinkPageOpenFailed =>
      'Could not open the account-linking page.';

  @override
  String accountLinkFailed(String error) {
    return 'Linking failed: $error';
  }

  @override
  String accountRefreshFailed(String error) {
    return 'Could not refresh the account: $error';
  }

  @override
  String get accountAutoSyncEnabled => 'Automatic sync is on.';

  @override
  String get accountAutoSyncDisabled => 'Automatic sync is off.';

  @override
  String accountSyncSettingsFailed(String error) {
    return 'Could not update sync settings: $error';
  }

  @override
  String get accountRouteHistoryPromptTitle => 'Sync route history?';

  @override
  String get accountRouteHistoryPromptDescription =>
      'Your recent route searches and smart recommendation activity will be uploaded to your account so they are available on your other devices. Location data is not included. You can turn this off at any time and remove history uploaded from this device.';

  @override
  String get accountEnableSync => 'Enable sync';

  @override
  String get accountRouteHistoryEnabled => 'Route history sync is on.';

  @override
  String get accountRouteHistoryDisabled => 'Route history sync is off.';

  @override
  String accountRouteHistoryUpdateFailed(String error) {
    return 'Could not update route history sync: $error';
  }

  @override
  String get accountSyncComplete => 'Sync complete.';

  @override
  String accountSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get accountSyncConflictTitle => 'Sync conflict';

  @override
  String accountSyncConflictFallback(String namespace) {
    return 'A conflict occurred while syncing $namespace.';
  }

  @override
  String get accountSyncNamespaceFavorites => 'favorite stops and groups';

  @override
  String get accountSyncNamespacePreferences => 'preferences';

  @override
  String get accountUseCloud => 'Use cloud copy';

  @override
  String get accountTryMerge => 'Try to merge';

  @override
  String get accountOverwriteCloud => 'Overwrite cloud copy';

  @override
  String accountSyncConflictFailed(String error) {
    return 'Could not resolve the sync conflict: $error';
  }

  @override
  String get accountLoggedOut => 'Signed out.';

  @override
  String get accountLogout => 'Sign out';

  @override
  String get accountSignedIn => 'Signed in';

  @override
  String get accountDefaultDisplayName => 'Ciallo~(∠・ω< )⌒☆';

  @override
  String get accountContinueDescription =>
      'Continue with Discord or Google to create or link your account.';

  @override
  String get accountLoadedFromCurrentToken =>
      'Loaded from the current sign-in token';

  @override
  String get accountNoLinkedProviders =>
      'No linked account details have been loaded yet.';

  @override
  String accountLinkProvider(String provider) {
    return 'Link $provider';
  }

  @override
  String get accountCloudSync => 'Cloud sync';

  @override
  String get accountEnableCloudSync => 'Enable cloud sync';

  @override
  String accountLastSync(String date) {
    return 'Last synced: $date';
  }

  @override
  String get accountSyncDisabled => 'Sync is off.';

  @override
  String get accountSyncRouteHistory => 'Sync route history';

  @override
  String get accountRouteHistoryDeletionPending =>
      'Off. Removing this device\'s route history from the cloud.';

  @override
  String get accountRouteHistorySyncDescription =>
      'Recent searches and smart recommendation activity will sync. Location data is not included.';

  @override
  String get accountRouteHistoryWaitingForCloudSync =>
      'Allowed. History will upload after cloud sync is enabled.';

  @override
  String get accountRouteHistoryOptional => 'Optional and off by default.';

  @override
  String get accountSyncNow => 'Sync now';

  @override
  String accountContinueWithProvider(String provider) {
    return 'Continue with $provider';
  }

  @override
  String get accountNeverSynced => 'Never synced';

  @override
  String get feedbackSubmitted =>
      'Feedback sent. Thank you for helping us improve.';

  @override
  String get feedbackSessionExpired =>
      'Your session has expired. Sign in again before sending feedback.';

  @override
  String get feedbackSignInRequired => 'Sign in first';

  @override
  String get feedbackGoToSignIn => 'Go to sign in';

  @override
  String get feedbackSubjectLabel => 'Subject';

  @override
  String get feedbackSubjectHint => 'For example: Favorite stop sync failed';

  @override
  String get feedbackSubjectRequired => 'Enter a subject';

  @override
  String feedbackSubjectTooLong(int max) {
    return 'The subject can be at most $max characters.';
  }

  @override
  String get feedbackContentLabel => 'Details';

  @override
  String get feedbackContentHint =>
      'Describe what happened, what you expected, and how to reproduce it.';

  @override
  String get feedbackContentRequired => 'Enter some details';

  @override
  String feedbackContentTooLong(int max) {
    return 'The details can be at most $max characters.';
  }

  @override
  String get feedbackSubmitting => 'Sending...';

  @override
  String get feedbackSubmit => 'Send feedback';

  @override
  String get feedbackInvalidFormat => 'The feedback format is invalid.';

  @override
  String get feedbackSubmitFailed =>
      'Could not send feedback. Please try again later.';

  @override
  String get databaseUpToDate => 'Your databases are up to date.';

  @override
  String databaseUpdateAvailable(String provider, int version) {
    return '$provider has a new version: $version';
  }

  @override
  String databaseCheckFailed(String error) {
    return 'Could not check for database updates: $error';
  }

  @override
  String get databaseNoUpdatesAvailable => 'There are no databases to update.';

  @override
  String databaseDownloadFailed(String error) {
    return 'Could not download the database: $error';
  }

  @override
  String get databaseStartupUpdateTitle => 'Updates on launch';

  @override
  String get databaseAutoUpdateModeLabel => 'Automatic update mode';

  @override
  String get databaseAutoUpdateOffDescription =>
      'Do not automatically check for database updates on launch.';

  @override
  String get databaseAutoUpdatePopupDescription =>
      'Check on launch and show a pop-up when updates are available.';

  @override
  String get databaseAutoUpdateNotifyDescription =>
      'Check on launch and show a notification when updates are available.';

  @override
  String get databaseAutoUpdateAlwaysDescription =>
      'Download and install available updates automatically on launch.';

  @override
  String get databaseAutoUpdateWifiDescription =>
      'Update automatically on Wi-Fi. On other networks, only notify you.';

  @override
  String get databaseAutoUpdateCellularDescription =>
      'Update automatically on mobile data. On other networks, only notify you.';

  @override
  String databaseRegionVersion(String provider, int version) {
    return '$provider v$version';
  }

  @override
  String get databaseCheckNow => 'Check for updates';

  @override
  String get databaseAllUpdatesDownloaded =>
      'All available database updates were installed.';

  @override
  String get databaseDownloadUpdates => 'Install available updates';

  @override
  String get databaseRouteDatabaseTitle => 'Route database';

  @override
  String get databaseDownloaded => 'Downloaded';

  @override
  String get databaseNotDownloadedYet => 'Not downloaded yet';

  @override
  String get databaseDataSourceTitle => 'Data source';

  @override
  String get databaseDefaultRegionLabel => 'Default region';

  @override
  String get databaseSelectLocalRegions =>
      'Select the regional databases to keep on this device.';

  @override
  String get databaseSelectedRegionsDownloaded =>
      'The selected regional databases were downloaded.';

  @override
  String get databaseDownloadSelectedRegions => 'Download selected regions';

  @override
  String get databaseDiscordPresenceSection => 'Discord Rich Presence';

  @override
  String get databaseDiscordPresenceTitle => 'Enable Discord Rich Presence';

  @override
  String get databaseDiscordPresenceDescription =>
      'Share the bus you are viewing with friends (⁠ ⁠/⁠^⁠ω⁠^⁠)⁠/⁠⁠';

  @override
  String get databasePresenceCurrentPage => 'Current page';

  @override
  String get databasePresenceRegion => 'Region';

  @override
  String get databasePresenceRouteName => 'Route name';

  @override
  String databaseVersionAvailable(int version) {
    return 'Update available: v$version';
  }

  @override
  String get databaseNotDownloaded => 'Not downloaded';

  @override
  String get databaseLocalVersionNotDownloaded =>
      'Local version: not downloaded';

  @override
  String databaseLocalVersion(int version) {
    return 'Local version: $version';
  }

  @override
  String databaseRegionUpdated(String provider) {
    return 'The $provider database was updated.';
  }

  @override
  String get databaseRedownload => 'Download again';

  @override
  String databaseRegionDeleted(String provider) {
    return 'The $provider database was deleted.';
  }

  @override
  String databaseDeleteFailed(String error) {
    return 'Could not delete the database: $error';
  }

  @override
  String get regionKeelung => 'Keelung City';

  @override
  String get regionTaipei => 'Taipei City';

  @override
  String get regionNewTaipei => 'New Taipei City';

  @override
  String get regionIntercity => 'Intercity buses';

  @override
  String get regionTaoyuan => 'Taoyuan City';

  @override
  String get regionHsinchuCity => 'Hsinchu City';

  @override
  String get regionHsinchuCounty => 'Hsinchu County';

  @override
  String get regionMiaoli => 'Miaoli County';

  @override
  String get regionTaichung => 'Taichung City';

  @override
  String get regionChanghua => 'Changhua County';

  @override
  String get regionNantou => 'Nantou County';

  @override
  String get regionYunlin => 'Yunlin County';

  @override
  String get regionChiayiCity => 'Chiayi City';

  @override
  String get regionChiayiCounty => 'Chiayi County';

  @override
  String get regionTainan => 'Tainan City';

  @override
  String get regionKaohsiung => 'Kaohsiung City';

  @override
  String get regionPingtung => 'Pingtung County';

  @override
  String get regionYilan => 'Yilan County';

  @override
  String get regionHualien => 'Hualien County';

  @override
  String get regionTaitung => 'Taitung County';

  @override
  String get regionPenghu => 'Penghu County';

  @override
  String get regionKinmen => 'Kinmen County';

  @override
  String get regionLienchiang => 'Lienchiang County';

  @override
  String get personalizationColorScheme => 'Colors';

  @override
  String get personalizationDarkMode => 'Dark mode';

  @override
  String get personalizationAmoledTitle => 'Pure black (AMOLED) dark theme';

  @override
  String get personalizationAmoledDescription =>
      'Use a pure black background in dark mode to save power and improve contrast.';

  @override
  String get personalizationHomeGradient => 'Home gradient';

  @override
  String get personalizationHomeGradientDescription =>
      'Adjust the opacity of the gradient on the home screen.';

  @override
  String get personalizationGradientOpacity => 'Gradient opacity';

  @override
  String get personalizationBackgroundImage => 'Background image';

  @override
  String get personalizationBackgroundImageDescription =>
      'Set background images for individual pages. The home background also applies to the Bus, Metro, HSR, TRA, and YouBike home tabs.';

  @override
  String get personalizationChooseImage => 'Choose image';

  @override
  String get personalizationBackgroundOpacity => 'Background opacity';

  @override
  String get personalizationPerPageSettings => 'Per-page settings';

  @override
  String get personalizationPerPageDescription =>
      'Set a separate background image for each page.';

  @override
  String get personalizationOverlayOpacityTitle => 'Overlay opacity';

  @override
  String get personalizationOverlay => 'Overlay';

  @override
  String get personalizationColorSystem => 'System';

  @override
  String get personalizationColorAutomaticBackground =>
      'Automatic (background image)';

  @override
  String get personalizationColorSourceDescription =>
      'Automatic picks colors from the background image. System uses your device\'s dynamic colors.';

  @override
  String get personalizationColorAutomatic => 'Automatic';

  @override
  String get personalizationColorCustom => 'Custom';

  @override
  String get personalizationChooseColor => 'Choose a color';

  @override
  String get personalizationHue => 'Hue';

  @override
  String get personalizationSaturation => 'Saturation';

  @override
  String get personalizationBrightness => 'Brightness';

  @override
  String get personalizationPerPageBackgroundTitle => 'Page backgrounds';

  @override
  String get personalizationGlobalHomeDescription =>
      'Also applies to the Bus, Metro, HSR, TRA, and YouBike home tabs.';

  @override
  String get personalizationPageGlobalHome => 'All home tabs';

  @override
  String get personalizationPageSearch => 'Search';

  @override
  String get personalizationPageNearby => 'Nearby';

  @override
  String get personalizationPreviewAmoled => 'AMOLED black';

  @override
  String get personalizationAppearancePreview => 'Appearance preview';

  @override
  String get personalizationPreviewSearchDescription =>
      'Quickly check live arrival information';

  @override
  String get personalizationPreviewFavoritesDescription =>
      'Regular stops and groups';

  @override
  String get personalizationReplaceImage => 'Replace';

  @override
  String get personalizationRemoveImage => 'Remove';

  @override
  String get announcementDismissForever => 'Don\'t show again';

  @override
  String get announcementViewDetails => 'View announcement';

  @override
  String get databaseUpdatesDialogTitle => 'Database updates available';

  @override
  String get databaseUpdatesDialogDescription =>
      'Updates are available for these regions:';

  @override
  String databaseVersion(int version) {
    return 'Version $version';
  }

  @override
  String get databaseUpdateNow => 'Update now';

  @override
  String get accountProviderDiscord => 'Discord';

  @override
  String get accountProviderGoogle => 'Google';

  @override
  String get accountProviderOAuth => 'OAuth';

  @override
  String get personalizationPreviewAppName => 'YABus';

  @override
  String get personalizationGifBadge => 'GIF';

  @override
  String announcementReactionCount(String emoji, int count) {
    return '$emoji $count';
  }

  @override
  String get weatherTitle => 'Weather';

  @override
  String temperatureCelsius(int temperature) {
    return '$temperature°C';
  }

  @override
  String temperatureDegrees(int temperature) {
    return '$temperature°';
  }

  @override
  String get weatherHourly => 'Hourly';

  @override
  String get weatherWeekly => '7-day forecast';

  @override
  String weatherHighLow(int high, int low) {
    return 'High $high° · Low $low°';
  }

  @override
  String get weatherFeelsLike => 'Feels like';

  @override
  String get weatherHumidity => 'Humidity';

  @override
  String get weatherWindSpeed => 'Wind';

  @override
  String get weatherPrecipitation => 'Rain';

  @override
  String get weatherNow => 'Now';

  @override
  String weatherHour(int hour) {
    return '$hour:00';
  }

  @override
  String get weatherSunrise => 'Sunrise';

  @override
  String get weatherSunset => 'Sunset';

  @override
  String weatherSourceUpdated(String time) {
    return 'Source: Central Weather Administration · Updated $time';
  }

  @override
  String get weatherLocationUnavailable =>
      'Your location is unavailable, so the weather cannot be shown. Check that location services and permission are enabled.';

  @override
  String get weatherLoadFailed =>
      'Could not load weather data. Please try again later.';

  @override
  String get weatherToday => 'Today';

  @override
  String get weatherTomorrow => 'Tomorrow';

  @override
  String weatherWeekday(String weekday) {
    return '$weekday';
  }

  @override
  String weatherCurrentSemantics(String condition, int temperature) {
    return 'Current weather: $condition, $temperature degrees';
  }

  @override
  String weatherViewTooltip(String condition) {
    return '$condition · View weather';
  }

  @override
  String get youBikeLocationUnavailable =>
      'Your location is unavailable right now. Please try again later.';

  @override
  String youBikeUsingDefaultArea(String message) {
    return '$message Showing the default area instead.';
  }

  @override
  String get youBikeNearbyStations => 'Nearby stations';

  @override
  String youBikeStationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stations',
      one: '1 station',
    );
    return '$_temp0';
  }

  @override
  String get youBikeNoNearbyStations => 'No stations were found nearby.';

  @override
  String get youBikeGeneralBike => 'Standard bikes';

  @override
  String get youBikeElectricBike => '2.0E e-bikes';

  @override
  String get youBikeReturnSlots => 'Open docks';

  @override
  String youBikeDistance(String distance) {
    return '$distance away';
  }

  @override
  String get youBikeStationInfo => 'Station details';

  @override
  String get youBikeSelectStationHint =>
      'Select a station in the list or a marker on the map to see available bikes, return spaces, and distance.';

  @override
  String get youBikeLocationAcquired => 'Current location found';

  @override
  String get youBikeRelocate => 'Find my location again';

  @override
  String get youBikeBackToLocation => 'Back to my location';

  @override
  String youBikeAvailability(int general, int electric, int returns) {
    return 'Standard $general · 2.0E $electric · Docks $returns';
  }

  @override
  String get metroSystem => 'Metro system';

  @override
  String get metroNoLineSelected => 'No line selected';

  @override
  String get metroUpdateEta => 'Update ETA';

  @override
  String get metroNoLines =>
      'No lines are currently available for this metro system.';

  @override
  String get metroTimetableEstimate =>
      'Arrival times are currently estimated from the timetable.';

  @override
  String get metroFrequencyOnly =>
      'Only service frequency is currently available.';

  @override
  String metroFrequencyEstimate(int min, int max) {
    return 'Estimated from service frequency: about $min-$max minutes.';
  }

  @override
  String get metroEtaUnknown => 'The ETA source is not identified.';

  @override
  String get metroLiveArrivals => 'Live arrivals';

  @override
  String get metroStationMap => 'Station map';

  @override
  String get metroChooseLine => 'Select a metro line first.';

  @override
  String get metroNoStationSequence =>
      'No station sequence is currently available for this line.';

  @override
  String get metroRouteMap => 'Line map';

  @override
  String get metroViewEta => 'View ETA';

  @override
  String get metroNoCoordinates =>
      'No station coordinates are currently available for this metro line.';

  @override
  String get metroTravelDirection => 'Direction of travel';

  @override
  String metroDirectionHeading(String destination) {
    return 'Toward $destination';
  }

  @override
  String metroHeadway(int min, int max) {
    return 'Every $min-$max min';
  }

  @override
  String get metroNoLiveArrivals =>
      'No live arrivals are available for this station right now.';

  @override
  String metroFrequencyOnlyEstimate(int min, int max) {
    return 'Only a frequency estimate is available: about $min-$max minutes.';
  }

  @override
  String metroDestination(String destination) {
    return 'Toward $destination';
  }

  @override
  String get railOperatingNotices => 'Service notices';

  @override
  String get railAllStations => 'All stations';

  @override
  String get railOtherStations => 'Other';

  @override
  String railShowDeparted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count departed trains',
      one: 'Show 1 departed train',
    );
    return '$_temp0';
  }

  @override
  String railHideDeparted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hide $count departed trains',
      one: 'Hide 1 departed train',
    );
    return '$_temp0';
  }

  @override
  String get railPickerNoMatches => 'No matching station found';

  @override
  String get railPickerNoNearby => 'No nearby station found.';

  @override
  String railPickerNearest(String station, String distance) {
    return 'Nearest station: $station (about $distance)';
  }

  @override
  String get railLocationUnavailable =>
      'Your location is unavailable right now. Please try again later.';

  @override
  String get railPickerSearchHint => 'Search by station name or code';

  @override
  String get railUseCurrentLocation => 'Use current location';

  @override
  String get railChooseStation => 'Choose station';

  @override
  String railChooseNamedStation(String station) {
    return 'Choose $station';
  }

  @override
  String get railSameStationExcluded =>
      'This station is already selected at the other end';

  @override
  String get railOrigin => 'Origin';

  @override
  String get railDestination => 'Destination';

  @override
  String get railChooseOrigin => 'Choose origin';

  @override
  String get railChooseDestination => 'Choose destination';

  @override
  String get railSwapStations => 'Swap origin and destination';

  @override
  String get railDeparted => 'Departed';

  @override
  String railDelayedMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min late',
      one: '1 min late',
    );
    return '$_temp0';
  }

  @override
  String get railOnTime => 'On time';

  @override
  String railDepartsAt(String time) {
    return 'Departs $time';
  }

  @override
  String railMinutesUntilDeparture(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'In $minutes min',
      one: 'In 1 min',
    );
    return '$_temp0';
  }

  @override
  String railDurationHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hrs',
      one: '1 hr',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      one: '1 min',
    );
    return '$_temp0 $_temp1';
  }

  @override
  String railDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String railTrainSemantics(String trainNo, String trainType, String headline) {
    return 'Train $trainNo, $trainType, $headline';
  }

  @override
  String railTrainSemanticsWithStatus(
    String trainNo,
    String trainType,
    String headline,
    String status,
  ) {
    return 'Train $trainNo, $trainType, $headline, $status';
  }

  @override
  String railRouteWithTimes(
    String origin,
    String departure,
    String destination,
    String arrival,
  ) {
    return '$origin $departure → $destination $arrival';
  }

  @override
  String railStationRange(String origin, String destination) {
    return '$origin → $destination';
  }

  @override
  String railTimeRange(String departure, String arrival) {
    return '$departure → $arrival';
  }

  @override
  String get traServices => 'Trains';

  @override
  String get traStationMap => 'Station map';

  @override
  String get traSelectDifferentStations =>
      'Origin and destination must be different.';

  @override
  String get traUseLocationOrigin => 'Use my location for the origin';

  @override
  String get traSelectionPrompt =>
      'Choose an origin and destination to see trains you can still catch today.';

  @override
  String get traSearching => 'Searching...';

  @override
  String get traNoDirectServices =>
      'There are no direct trains between these stations today. A transfer may be required.';

  @override
  String traRemainingServices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trains left',
      one: '1 train left',
    );
    return '$_temp0';
  }

  @override
  String traAllServicesDeparted(String origin, String destination) {
    return 'All trains from $origin to $destination have departed today.';
  }

  @override
  String get traViewTomorrow => 'View tomorrow\'s trains';

  @override
  String get traViewServices => 'View trains';

  @override
  String get traMapHint =>
      'Tap a station to set it as the origin or destination. Tap a red train marker to view its estimated position.';

  @override
  String get traMapNoCoordinates =>
      'No TRA station coordinates are currently available.';

  @override
  String get traSetOrigin => 'Set as origin';

  @override
  String get traSetDestination => 'Set as destination';

  @override
  String traPositionArrived(String station) {
    return 'Arrived at $station';
  }

  @override
  String traPositionStopped(String station) {
    return 'Stopped at $station';
  }

  @override
  String get traTrainPositionEstimate => 'Estimated train position';

  @override
  String traEstimatedBetween(String current, String next) {
    return 'Estimated between $current and $next';
  }

  @override
  String traEstimatedArrived(String station) {
    return 'Estimated to have arrived at $station';
  }

  @override
  String traEstimatedStopped(String station) {
    return 'Estimated to be stopped at $station';
  }

  @override
  String traSegmentProgress(int percent) {
    return 'Segment progress: $percent%';
  }

  @override
  String traDataUpdated(String time) {
    return 'Data updated $time';
  }

  @override
  String get thsrSeatOverview => 'Live seat overview';

  @override
  String get thsrObservedStation => 'Station to watch';

  @override
  String get thsrChooseStation => 'Choose station';

  @override
  String get thsrSelectStationForSeats =>
      'Choose a station to view seat availability for upcoming HSR trains.';

  @override
  String thsrNoStationSeats(String station) {
    return 'No live seat information is available for $station right now.';
  }

  @override
  String get thsrSearchServices => 'Search trains';

  @override
  String get thsrNotSearched => 'No train search yet';

  @override
  String thsrServicesSummary(int upcoming, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      upcoming,
      locale: localeName,
      other: '$upcoming trains left',
      one: '1 train left',
    );
    String _temp1 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total total',
      one: '1 total',
    );
    return '$_temp0 ($_temp1)';
  }

  @override
  String get thsrQueryPrompt =>
      'Choose origin, destination, and date to view HSR trains.';

  @override
  String get thsrDayDeparted => 'All trains for this day have departed.';

  @override
  String get thsrSeatTitle => 'Non-reserved and business class seats';

  @override
  String get thsrQueryStation => 'Station';

  @override
  String get thsrSelectStationSeats =>
      'Choose a station to view seat availability by train.';

  @override
  String get thsrNoSeatData => 'No seat information is currently available.';

  @override
  String get thsrMapTitle => 'Station map';

  @override
  String get thsrViewSeats => 'View seats';

  @override
  String get thsrMapNoCoordinates =>
      'No HSR station coordinates are currently available.';

  @override
  String get thsrTimetable => 'Train search';

  @override
  String get thsrSeats => 'Seat information';

  @override
  String get thsrTrainLabel => 'HSR';

  @override
  String thsrNoSeatField(String station) {
    return 'This train has no seat information for $station.';
  }

  @override
  String get thsrStandardCar => 'Standard class';

  @override
  String get thsrBusinessCar => 'Business class';

  @override
  String get thsrNotProvided => 'Not provided';

  @override
  String get thsrStationNoSeats =>
      'No seat information is available for this station right now.';

  @override
  String thsrDepartureTime(String time) {
    return 'Departs $time';
  }
}
