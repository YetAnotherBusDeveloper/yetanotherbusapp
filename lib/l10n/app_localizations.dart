import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'YetAnotherBusApp'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appearanceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSectionTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @languageTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get languageTraditionalChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @interfaceScaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Interface scale'**
  String get interfaceScaleLabel;

  /// No description provided for @interfaceScaleDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust the size of text and interface elements.'**
  String get interfaceScaleDescription;

  /// No description provided for @interfaceScaleValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String interfaceScaleValue(int percent);

  /// No description provided for @themeModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeModeLabel;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @compactModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Compact mode'**
  String get compactModeTitle;

  /// No description provided for @compactModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Show less descriptive text on the home screen and some cards; desktop always uses compact mode.'**
  String get compactModeDescription;

  /// No description provided for @showWeatherTitle.
  ///
  /// In en, this message translates to:
  /// **'Show weather'**
  String get showWeatherTitle;

  /// No description provided for @showWeatherDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the current temperature beside the home title. Tap it to open the full forecast.'**
  String get showWeatherDescription;

  /// No description provided for @mapProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Map provider'**
  String get mapProviderLabel;

  /// No description provided for @personalizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get personalizationTitle;

  /// No description provided for @personalizationDescription.
  ///
  /// In en, this message translates to:
  /// **'Colors and background opacity'**
  String get personalizationDescription;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get commonOpenSettings;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get commonDownload;

  /// No description provided for @commonDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get commonDownloading;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get commonLater;

  /// No description provided for @commonNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// No description provided for @commonUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get commonUpdate;

  /// No description provided for @commonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// No description provided for @commonReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get commonReload;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get commonCenter;

  /// No description provided for @commonPercentage.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String commonPercentage(int value);

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again later.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'There is a network problem. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The connection timed out. Please try again later.'**
  String get errorTimeout;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get errorRateLimited;

  /// No description provided for @transitBus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get transitBus;

  /// No description provided for @transitMetro.
  ///
  /// In en, this message translates to:
  /// **'Metro'**
  String get transitMetro;

  /// No description provided for @transitThsr.
  ///
  /// In en, this message translates to:
  /// **'HSR'**
  String get transitThsr;

  /// No description provided for @transitTra.
  ///
  /// In en, this message translates to:
  /// **'TRA'**
  String get transitTra;

  /// No description provided for @transitYouBike.
  ///
  /// In en, this message translates to:
  /// **'YouBike'**
  String get transitYouBike;

  /// No description provided for @transitBusHomePresence.
  ///
  /// In en, this message translates to:
  /// **'Bus home'**
  String get transitBusHomePresence;

  /// No description provided for @homeSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search routes'**
  String get homeSearchTitle;

  /// No description provided for @homeSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a bus number, route name, or intercity route to see live arrivals.'**
  String get homeSearchDescription;

  /// No description provided for @homeFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get homeFavoritesTitle;

  /// No description provided for @homeFavoritesDescription.
  ///
  /// In en, this message translates to:
  /// **'Organize frequently used stops and groups for quick access.'**
  String get homeFavoritesDescription;

  /// No description provided for @homeNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby stops'**
  String get homeNearbyTitle;

  /// No description provided for @homeNearbyDescription.
  ///
  /// In en, this message translates to:
  /// **'Find bus stops near your current location.'**
  String get homeNearbyDescription;

  /// No description provided for @homeBusMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Live bus map'**
  String get homeBusMapTitle;

  /// No description provided for @homeBusMapDescription.
  ///
  /// In en, this message translates to:
  /// **'See buses across the region and open a vehicle to view its route and stops.'**
  String get homeBusMapDescription;

  /// No description provided for @homeOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get homeOverviewTitle;

  /// No description provided for @homeSelectedRegions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 region selected} other {{count} regions selected}}'**
  String homeSelectedRegions(int count);

  /// No description provided for @homeOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get homeOpenSettings;

  /// No description provided for @databaseDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Databases and downloads'**
  String get databaseDownloadsTitle;

  /// No description provided for @announcementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcementsTitle;

  /// No description provided for @installAppTooltip.
  ///
  /// In en, this message translates to:
  /// **'Install app'**
  String get installAppTooltip;

  /// No description provided for @installAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Install this app?'**
  String get installAppTitle;

  /// No description provided for @installAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Install YABus so you can open it like any other app.'**
  String get installAppDescription;

  /// No description provided for @installAppLimitation.
  ///
  /// In en, this message translates to:
  /// **'Some features from the full app are not available.'**
  String get installAppLimitation;

  /// No description provided for @installAppConfirm.
  ///
  /// In en, this message translates to:
  /// **'Install it! \\(^o^)/'**
  String get installAppConfirm;

  /// No description provided for @installRequestSent.
  ///
  /// In en, this message translates to:
  /// **'The install request was sent.'**
  String get installRequestSent;

  /// No description provided for @installCancelled.
  ///
  /// In en, this message translates to:
  /// **'Installation was cancelled.'**
  String get installCancelled;

  /// No description provided for @installUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device cannot show an installation prompt right now.'**
  String get installUnavailable;

  /// No description provided for @smartRecommendationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart recommendations'**
  String get smartRecommendationsTitle;

  /// No description provided for @smartRecommendationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Routes suggested from your usage patterns'**
  String get smartRecommendationsSubtitle;

  /// No description provided for @smartRecommendationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'This feature is off. When enabled, YABus learns which routes you open at different times and suggests them on the home screen.'**
  String get smartRecommendationsDisabled;

  /// No description provided for @smartRecommendationsGoToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to settings'**
  String get smartRecommendationsGoToSettings;

  /// No description provided for @smartRecommendationsNeedDatabase.
  ///
  /// In en, this message translates to:
  /// **'Download a local database first. This card will then learn your usage patterns and show arrivals at nearby stops.'**
  String get smartRecommendationsNeedDatabase;

  /// No description provided for @destinationStopId.
  ///
  /// In en, this message translates to:
  /// **'Destination stop {stopId}'**
  String destinationStopId(int stopId);

  /// No description provided for @directionValue.
  ///
  /// In en, this message translates to:
  /// **'Direction: {direction}'**
  String directionValue(String direction);

  /// No description provided for @destinationValue.
  ///
  /// In en, this message translates to:
  /// **'Destination: {destination}'**
  String destinationValue(String destination);

  /// No description provided for @approximateDistance.
  ///
  /// In en, this message translates to:
  /// **'About {distance} away'**
  String approximateDistance(String distance);

  /// No description provided for @tryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again later.'**
  String get tryAgainLater;

  /// No description provided for @nearbyMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby map'**
  String get nearbyMapTitle;

  /// No description provided for @nearbyMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you taking the bus today?'**
  String get nearbyMapSubtitle;

  /// No description provided for @refreshNearbyStops.
  ///
  /// In en, this message translates to:
  /// **'Refresh nearby stops'**
  String get refreshNearbyStops;

  /// No description provided for @nearbyNoStopsToDisplay.
  ///
  /// In en, this message translates to:
  /// **'There are no nearby stops to display right now.'**
  String get nearbyNoStopsToDisplay;

  /// No description provided for @mapNoLocations.
  ///
  /// In en, this message translates to:
  /// **'There are no stop locations to display.'**
  String get mapNoLocations;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off.'**
  String get locationServicesDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was not granted.'**
  String get locationPermissionDenied;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search routes or stops'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by bus route or stop name'**
  String get searchHint;

  /// No description provided for @searchClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClearTooltip;

  /// No description provided for @searchShowKeypadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open route keypad'**
  String get searchShowKeypadTooltip;

  /// No description provided for @searchErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Search hit a snag'**
  String get searchErrorTitle;

  /// No description provided for @searchResolvingTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking nearby stops'**
  String get searchResolvingTitle;

  /// No description provided for @searchResolvingMessage.
  ///
  /// In en, this message translates to:
  /// **'Searching for stops you can board nearby...'**
  String get searchResolvingMessage;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching bus found'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a shorter query or search by stop name.'**
  String get searchEmptyMessage;

  /// No description provided for @searchEmptyNeedsDatabase.
  ///
  /// In en, this message translates to:
  /// **'Some stop searches need a local database. Update the database and try again.'**
  String get searchEmptyNeedsDatabase;

  /// No description provided for @searchHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No search history yet.'**
  String get searchHistoryEmpty;

  /// No description provided for @searchRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecentTitle;

  /// No description provided for @searchNearestStop.
  ///
  /// In en, this message translates to:
  /// **'Nearest to you: {stopName} ({distance})'**
  String searchNearestStop(String stopName, String distance);

  /// No description provided for @searchKeypadTitle.
  ///
  /// In en, this message translates to:
  /// **'Route prefixes and numbers'**
  String get searchKeypadTitle;

  /// No description provided for @searchKeypadCollapseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Collapse route keypad'**
  String get searchKeypadCollapseTooltip;

  /// No description provided for @searchKeypadTextTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to text keyboard'**
  String get searchKeypadTextTooltip;

  /// No description provided for @searchKeypadBackspaceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Backspace'**
  String get searchKeypadBackspaceTooltip;

  /// No description provided for @searchKeypadOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get searchKeypadOther;

  /// No description provided for @nearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby stops'**
  String get nearbyTitle;

  /// No description provided for @nearbyLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Location settings'**
  String get nearbyLocationSettings;

  /// No description provided for @nearbyPermissionSettings.
  ///
  /// In en, this message translates to:
  /// **'Permission settings'**
  String get nearbyPermissionSettings;

  /// No description provided for @nearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No nearby stops were found.'**
  String get nearbyEmpty;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get favoritesUpdating;

  /// No description provided for @favoritesRealtimeUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Live information could not be updated'**
  String get favoritesRealtimeUpdateFailed;

  /// No description provided for @favoritesNoRealtime.
  ///
  /// In en, this message translates to:
  /// **'No live information is available right now'**
  String get favoritesNoRealtime;

  /// No description provided for @favoritesPartialUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Some live information could not be updated'**
  String get favoritesPartialUpdateFailed;

  /// No description provided for @favoritesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load favorites'**
  String get favoritesLoadFailed;

  /// No description provided for @favoritesUpdateFailedKeepingData.
  ///
  /// In en, this message translates to:
  /// **'Update failed; showing the previous data'**
  String get favoritesUpdateFailedKeepingData;

  /// No description provided for @favoriteRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {item} from {group}'**
  String favoriteRemoved(String item, String group);

  /// No description provided for @favoriteTypeRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get favoriteTypeRoute;

  /// No description provided for @favoriteTypeStation.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get favoriteTypeStation;

  /// No description provided for @favoriteTypeBoarding.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get favoriteTypeBoarding;

  /// No description provided for @favoriteGroupKindMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get favoriteGroupKindMixed;

  /// No description provided for @favoriteNoUpcomingArrivals.
  ///
  /// In en, this message translates to:
  /// **'No upcoming arrivals'**
  String get favoriteNoUpcomingArrivals;

  /// No description provided for @favoriteStationSide.
  ///
  /// In en, this message translates to:
  /// **'Side {side}'**
  String favoriteStationSide(String side);

  /// No description provided for @routeIdFallback.
  ///
  /// In en, this message translates to:
  /// **'Route {routeId}'**
  String routeIdFallback(int routeId);

  /// No description provided for @stopIdFallback.
  ///
  /// In en, this message translates to:
  /// **'Stop {stopId}'**
  String stopIdFallback(int stopId);

  /// No description provided for @favoriteFetchingRealtime.
  ///
  /// In en, this message translates to:
  /// **'Getting live information'**
  String get favoriteFetchingRealtime;

  /// No description provided for @favoriteNoSelectableStops.
  ///
  /// In en, this message translates to:
  /// **'This route has no stops to select right now.'**
  String get favoriteNoSelectableStops;

  /// No description provided for @stopSequence.
  ///
  /// In en, this message translates to:
  /// **'Stop {number}'**
  String stopSequence(int number);

  /// No description provided for @favoriteDestinationSet.
  ///
  /// In en, this message translates to:
  /// **'Destination set to {stopName}'**
  String favoriteDestinationSet(String stopName);

  /// No description provided for @favoriteDestinationCleared.
  ///
  /// In en, this message translates to:
  /// **'The destination was cleared for this favorite.'**
  String get favoriteDestinationCleared;

  /// No description provided for @favoritesFinishSorting.
  ///
  /// In en, this message translates to:
  /// **'Finish sorting'**
  String get favoritesFinishSorting;

  /// No description provided for @favoritesAdjustSorting.
  ///
  /// In en, this message translates to:
  /// **'Reorder favorites'**
  String get favoritesAdjustSorting;

  /// No description provided for @favoritesManageGroupsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage favorite groups'**
  String get favoritesManageGroupsTooltip;

  /// No description provided for @favoritesUpdateCountdown.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1 {Updates in 1 second} other {Updates in {seconds} seconds}}'**
  String favoritesUpdateCountdown(int seconds);

  /// No description provided for @favoritesErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites got stuck'**
  String get favoritesErrorTitle;

  /// No description provided for @favoritesTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get favoritesTryAgain;

  /// No description provided for @favoritesGroupEmpty.
  ///
  /// In en, this message translates to:
  /// **'This group has no favorites.'**
  String get favoritesGroupEmpty;

  /// No description provided for @routeKeyFallback.
  ///
  /// In en, this message translates to:
  /// **'routeKey {routeKey}'**
  String routeKeyFallback(int routeKey);

  /// No description provided for @favoriteDestinationSettings.
  ///
  /// In en, this message translates to:
  /// **'Destination settings'**
  String get favoriteDestinationSettings;

  /// No description provided for @favoriteSetDestination.
  ///
  /// In en, this message translates to:
  /// **'Set destination'**
  String get favoriteSetDestination;

  /// No description provided for @favoriteClearDestination.
  ///
  /// In en, this message translates to:
  /// **'Clear destination'**
  String get favoriteClearDestination;

  /// No description provided for @favoritesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'You have not saved any stops yet :('**
  String get favoritesEmptyMessage;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No regular stop yet'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoriteGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorite groups'**
  String get favoriteGroupsTitle;

  /// No description provided for @favoriteGroupAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get favoriteGroupAddTitle;

  /// No description provided for @favoriteGroupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get favoriteGroupNameLabel;

  /// No description provided for @favoriteGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Home'**
  String get favoriteGroupNameHint;

  /// No description provided for @favoriteGroupCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite type'**
  String get favoriteGroupCategoryLabel;

  /// No description provided for @favoriteGroupAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get favoriteGroupAddAction;

  /// No description provided for @favoriteGroupDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A favorite group with this name already exists.'**
  String get favoriteGroupDuplicate;

  /// No description provided for @favoriteGroupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No groups yet.'**
  String get favoriteGroupsEmpty;

  /// No description provided for @favoriteGroupDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get favoriteGroupDeleteTitle;

  /// No description provided for @favoriteGroupDeletePrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete “{group}”?'**
  String favoriteGroupDeletePrompt(String group);

  /// No description provided for @favoriteGroupSummary.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {count, plural, =0 {No favorites} =1 {1 favorite} other {{count} favorites}}'**
  String favoriteGroupSummary(String kind, int count);

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Not signed in.'**
  String get accountSignedOut;

  /// No description provided for @accountSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String accountSignedInAs(String name);

  /// No description provided for @wearConnectedWatch.
  ///
  /// In en, this message translates to:
  /// **'Connected watch: {names}'**
  String wearConnectedWatch(String names);

  /// No description provided for @wearConnectedWatches.
  ///
  /// In en, this message translates to:
  /// **'Connected watches: {names} ({count} total)'**
  String wearConnectedWatches(String names, int count);

  /// No description provided for @wearSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Wear OS sync'**
  String get wearSyncTitle;

  /// No description provided for @wearSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync favorite stops to your watch'**
  String get wearSyncDescription;

  /// No description provided for @wearNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'There are no favorite stops yet. Add a favorite before syncing.'**
  String get wearNoFavorites;

  /// No description provided for @wearSyncCategory.
  ///
  /// In en, this message translates to:
  /// **'Sync group'**
  String get wearSyncCategory;

  /// No description provided for @wearAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All groups'**
  String get wearAllCategories;

  /// No description provided for @databaseCurrentRegion.
  ///
  /// In en, this message translates to:
  /// **'Current region: {region}'**
  String databaseCurrentRegion(String region);

  /// No description provided for @databaseStartupUpdate.
  ///
  /// In en, this message translates to:
  /// **'On launch: {mode}'**
  String databaseStartupUpdate(String mode);

  /// No description provided for @databasePendingRegions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 region has an update} other {{count} regions have updates}}'**
  String databasePendingRegions(int count);

  /// No description provided for @databaseOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Open database page'**
  String get databaseOpenPage;

  /// No description provided for @usageAndUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage and updates'**
  String get usageAndUpdatesTitle;

  /// No description provided for @alwaysShowSecondsTitle.
  ///
  /// In en, this message translates to:
  /// **'Always show seconds'**
  String get alwaysShowSecondsTitle;

  /// No description provided for @alwaysShowSecondsDescription.
  ///
  /// In en, this message translates to:
  /// **'They are usually not very accurate'**
  String get alwaysShowSecondsDescription;

  /// No description provided for @hapticFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get hapticFeedbackTitle;

  /// No description provided for @hapticFeedbackDescription.
  ///
  /// In en, this message translates to:
  /// **'Provide haptic feedback for taps and actions'**
  String get hapticFeedbackDescription;

  /// No description provided for @showAdsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show ads'**
  String get showAdsTitle;

  /// No description provided for @adsLockedMessage.
  ///
  /// In en, this message translates to:
  /// **' Keep trying, haha'**
  String get adsLockedMessage;

  /// No description provided for @adsEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Take away the developer\'s lunch money.'**
  String get adsEnabledDescription;

  /// No description provided for @adsPleaOne.
  ///
  /// In en, this message translates to:
  /// **'Please don\'t'**
  String get adsPleaOne;

  /// No description provided for @adsPleaTwo.
  ///
  /// In en, this message translates to:
  /// **'Would begging help?'**
  String get adsPleaTwo;

  /// No description provided for @adsPleaThree.
  ///
  /// In en, this message translates to:
  /// **'You can\'t do this to me'**
  String get adsPleaThree;

  /// No description provided for @adsPleaFour.
  ///
  /// In en, this message translates to:
  /// **'QAQ'**
  String get adsPleaFour;

  /// No description provided for @adsDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get adsDisableTitle;

  /// No description provided for @adsDisableDescription.
  ///
  /// In en, this message translates to:
  /// **'I have no money :('**
  String get adsDisableDescription;

  /// No description provided for @adsKeepEnabled.
  ///
  /// In en, this message translates to:
  /// **'Keep them on'**
  String get adsKeepEnabled;

  /// No description provided for @adsDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get adsDisableConfirm;

  /// No description provided for @smartRecommendationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show suggestions on the home screen based on routes you open and when you use them.'**
  String get smartRecommendationsDescription;

  /// No description provided for @autoFavoriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-add frequent favorites'**
  String get autoFavoriteTitle;

  /// No description provided for @autoFavoriteDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically add a stop to the “Frequent” group after several trips in a short period.'**
  String get autoFavoriteDescription;

  /// No description provided for @smartNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart recommendation notifications'**
  String get smartNotificationTitle;

  /// No description provided for @smartNotificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Suggest routes in the background around times you often travel.'**
  String get smartNotificationDescription;

  /// No description provided for @smartNotificationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is required for smart recommendation notifications.'**
  String get smartNotificationPermissionRequired;

  /// No description provided for @keepScreenAwakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on for bus routes'**
  String get keepScreenAwakeTitle;

  /// No description provided for @keepScreenAwakeDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen awake on route detail pages.'**
  String get keepScreenAwakeDescription;

  /// No description provided for @backgroundTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Background trip alerts'**
  String get backgroundTripTitle;

  /// No description provided for @backgroundTripDescription.
  ///
  /// In en, this message translates to:
  /// **'Notification and location permissions are required for trip alerts in the background.'**
  String get backgroundTripDescription;

  /// No description provided for @backgroundTripIosDescription.
  ///
  /// In en, this message translates to:
  /// **'Notification and background location permissions are required for trip alerts in the background.'**
  String get backgroundTripIosDescription;

  /// No description provided for @favoriteWidgetRefreshLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite widget background refresh'**
  String get favoriteWidgetRefreshLabel;

  /// No description provided for @favoriteWidgetRefreshHelper.
  ///
  /// In en, this message translates to:
  /// **'Android widgets have a minimum refresh interval of 15 minutes.'**
  String get favoriteWidgetRefreshHelper;

  /// No description provided for @minutesValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1 {1 minute} other {{minutes} minutes}}'**
  String minutesValue(int minutes);

  /// No description provided for @normalUpdateInterval.
  ///
  /// In en, this message translates to:
  /// **'Normal refresh interval: {seconds, plural, =1 {1 second} other {{seconds} seconds}}'**
  String normalUpdateInterval(int seconds);

  /// No description provided for @retryInterval.
  ///
  /// In en, this message translates to:
  /// **'Retry interval after errors: {seconds, plural, =1 {1 second} other {{seconds} seconds}}'**
  String retryInterval(int seconds);

  /// No description provided for @secondsValue.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1 {1 second} other {{seconds} seconds}}'**
  String secondsValue(int seconds);

  /// No description provided for @appUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'App updates'**
  String get appUpdatesTitle;

  /// No description provided for @updateChannelLabel.
  ///
  /// In en, this message translates to:
  /// **'Update channel'**
  String get updateChannelLabel;

  /// No description provided for @updateCheckOnLaunchLabel.
  ///
  /// In en, this message translates to:
  /// **'Check on launch'**
  String get updateCheckOnLaunchLabel;

  /// No description provided for @updateChannelDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get updateChannelDeveloper;

  /// No description provided for @updateChannelNightly.
  ///
  /// In en, this message translates to:
  /// **'Nightly'**
  String get updateChannelNightly;

  /// No description provided for @updateChannelRelease.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get updateChannelRelease;

  /// No description provided for @updateChannelDeveloperDescription.
  ///
  /// In en, this message translates to:
  /// **'Do not check for app updates'**
  String get updateChannelDeveloperDescription;

  /// No description provided for @updateChannelNightlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Compare against the latest successful build commit'**
  String get updateChannelNightlyDescription;

  /// No description provided for @updateChannelReleaseDescription.
  ///
  /// In en, this message translates to:
  /// **'Compare against the latest GitHub release'**
  String get updateChannelReleaseDescription;

  /// No description provided for @updateCheckOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get updateCheckOff;

  /// No description provided for @updateCheckNotify.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get updateCheckNotify;

  /// No description provided for @updateCheckPopup.
  ///
  /// In en, this message translates to:
  /// **'Pop-up'**
  String get updateCheckPopup;

  /// No description provided for @updateCheckOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Only show results for manual checks'**
  String get updateCheckOffDescription;

  /// No description provided for @updateCheckNotifyDescription.
  ///
  /// In en, this message translates to:
  /// **'Show a notification after launch'**
  String get updateCheckNotifyDescription;

  /// No description provided for @updateCheckPopupDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the update window after launch'**
  String get updateCheckPopupDescription;

  /// No description provided for @appUpdateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get appUpdateChecking;

  /// No description provided for @appUpdateCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check for app updates'**
  String get appUpdateCheckNow;

  /// No description provided for @appUpdateRecentResult.
  ///
  /// In en, this message translates to:
  /// **'Latest result: {result}'**
  String appUpdateRecentResult(String result);

  /// No description provided for @appUpdateAvailableResult.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available.'**
  String appUpdateAvailableResult(String version);

  /// No description provided for @appUpdateUpToDateResult.
  ///
  /// In en, this message translates to:
  /// **'The app is up to date.'**
  String get appUpdateUpToDateResult;

  /// No description provided for @appUpdateUnavailableResult.
  ///
  /// In en, this message translates to:
  /// **'Update information is unavailable right now.'**
  String get appUpdateUnavailableResult;

  /// No description provided for @appUpdateNightlyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Nightly update'**
  String get appUpdateNightlyDialogTitle;

  /// No description provided for @appUpdateReleaseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Release update: {version}'**
  String appUpdateReleaseDialogTitle(String version);

  /// No description provided for @appUpdateNightlySummary.
  ///
  /// In en, this message translates to:
  /// **'Nightly build {commit} is ready to download.'**
  String appUpdateNightlySummary(String commit);

  /// No description provided for @appUpdateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version: {version}'**
  String appUpdateCurrentVersion(String version);

  /// No description provided for @appUpdateLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest version: {version}'**
  String appUpdateLatestVersion(String version);

  /// No description provided for @appUpdateFullChangesMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Full changes: [{range}]({url})'**
  String appUpdateFullChangesMarkdown(String range, String url);

  /// No description provided for @appUpdateCommitMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Commit: [`{commit}`]({url})'**
  String appUpdateCommitMarkdown(String commit, String url);

  /// No description provided for @appUpdateContentsTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get appUpdateContentsTitle;

  /// No description provided for @appUpdateDownloadLink.
  ///
  /// In en, this message translates to:
  /// **'Download link'**
  String get appUpdateDownloadLink;

  /// No description provided for @appUpdateCopyDownloadLink.
  ///
  /// In en, this message translates to:
  /// **'Copy download link'**
  String get appUpdateCopyDownloadLink;

  /// No description provided for @appUpdateDownloadLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Download link copied to the clipboard.'**
  String get appUpdateDownloadLinkCopied;

  /// No description provided for @appUpdateDownloadAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get appUpdateDownloadAndInstall;

  /// No description provided for @appUpdatePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing update...'**
  String get appUpdatePreparing;

  /// No description provided for @appUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get appUpdateDownloading;

  /// No description provided for @appUpdatePreparingInstaller.
  ///
  /// In en, this message translates to:
  /// **'Preparing installer...'**
  String get appUpdatePreparingInstaller;

  /// No description provided for @appUpdateLaunchingInstaller.
  ///
  /// In en, this message translates to:
  /// **'Launching installer...'**
  String get appUpdateLaunchingInstaller;

  /// No description provided for @appUpdatePreparingDesktopInstaller.
  ///
  /// In en, this message translates to:
  /// **'Preparing to close the app and launch the installer...'**
  String get appUpdatePreparingDesktopInstaller;

  /// No description provided for @appUpdateInstallUnsupported.
  ///
  /// In en, this message translates to:
  /// **'In-app update installation is not supported on this platform.'**
  String get appUpdateInstallUnsupported;

  /// No description provided for @appUpdateInstallPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Allow this app to install unknown apps, then select update again.'**
  String get appUpdateInstallPermissionRequired;

  /// No description provided for @appUpdateInstallerLaunched.
  ///
  /// In en, this message translates to:
  /// **'The installer has been launched.'**
  String get appUpdateInstallerLaunched;

  /// No description provided for @appUpdateDesktopInstallerScheduled.
  ///
  /// In en, this message translates to:
  /// **'The app will close and launch the installer.'**
  String get appUpdateDesktopInstallerScheduled;

  /// No description provided for @appUpdateInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download or install the update: {error}'**
  String appUpdateInstallFailed(String error);

  /// No description provided for @historyPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'History and privacy'**
  String get historyPrivacyTitle;

  /// No description provided for @searchHistoryLimit.
  ///
  /// In en, this message translates to:
  /// **'Search history limit: {count, plural, =1 {1 item} other {{count} items}}'**
  String searchHistoryLimit(int count);

  /// No description provided for @itemsValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 item} other {{count} items}}'**
  String itemsValue(int count);

  /// No description provided for @smartRoutesCount.
  ///
  /// In en, this message translates to:
  /// **'Smart recommendation routes: {count}'**
  String smartRoutesCount(int count);

  /// No description provided for @routeSelectionsCount.
  ///
  /// In en, this message translates to:
  /// **'Route selections: {count}'**
  String routeSelectionsCount(int count);

  /// No description provided for @clearSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get clearSearchHistory;

  /// No description provided for @clearSmartHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear smart recommendation history'**
  String get clearSmartHistory;

  /// No description provided for @clearRouteSelectionHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear route selection history'**
  String get clearRouteSelectionHistory;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @onboardingSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get onboardingSettingsTitle;

  /// No description provided for @restartOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Run setup again'**
  String get restartOnboarding;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @contributorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contributors'**
  String get contributorsTitle;

  /// No description provided for @communityTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the frog community'**
  String get communityTitle;

  /// No description provided for @communityDescription.
  ///
  /// In en, this message translates to:
  /// **'My Discord server uwu'**
  String get communityDescription;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackTitle;

  /// No description provided for @feedbackDescription.
  ///
  /// In en, this message translates to:
  /// **'Report a problem, request a feature, or tell us anything'**
  String get feedbackDescription;

  /// No description provided for @discordOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Discord community link.'**
  String get discordOpenFailed;

  /// No description provided for @instagramOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Instagram page.'**
  String get instagramOpenFailed;

  /// No description provided for @githubOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {name}\'s GitHub page.'**
  String githubOpenFailed(String name);

  /// No description provided for @databaseAutoUpdateOff.
  ///
  /// In en, this message translates to:
  /// **'Do not check'**
  String get databaseAutoUpdateOff;

  /// No description provided for @databaseAutoUpdatePopup.
  ///
  /// In en, this message translates to:
  /// **'Check and show a pop-up'**
  String get databaseAutoUpdatePopup;

  /// No description provided for @databaseAutoUpdateNotify.
  ///
  /// In en, this message translates to:
  /// **'Check and notify'**
  String get databaseAutoUpdateNotify;

  /// No description provided for @databaseAutoUpdateAlways.
  ///
  /// In en, this message translates to:
  /// **'Always update automatically'**
  String get databaseAutoUpdateAlways;

  /// No description provided for @databaseAutoUpdateWifi.
  ///
  /// In en, this message translates to:
  /// **'Auto-update on Wi-Fi only'**
  String get databaseAutoUpdateWifi;

  /// No description provided for @databaseAutoUpdateCellular.
  ///
  /// In en, this message translates to:
  /// **'Auto-update on mobile data only'**
  String get databaseAutoUpdateCellular;

  /// No description provided for @onboardingLocationServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. You can still select databases manually.'**
  String get onboardingLocationServiceDisabled;

  /// No description provided for @onboardingLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was not granted. Select databases manually instead.'**
  String get onboardingLocationPermissionDenied;

  /// No description provided for @onboardingLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location permission was granted, but your location is temporarily unavailable. Select databases manually instead.'**
  String get onboardingLocationUnavailable;

  /// No description provided for @onboardingProviderSelected.
  ///
  /// In en, this message translates to:
  /// **'Nearest database selected automatically: {provider}.'**
  String onboardingProviderSelected(String provider);

  /// No description provided for @onboardingLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Location setup failed ({error}). Select databases manually instead.'**
  String onboardingLocationFailed(String error);

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to YABus'**
  String get onboardingWelcome;

  /// No description provided for @onboardingSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a bus name or number to open live stop information.'**
  String get onboardingSearchDescription;

  /// No description provided for @onboardingFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save stops'**
  String get onboardingFavoritesTitle;

  /// No description provided for @onboardingFavoritesDescription.
  ///
  /// In en, this message translates to:
  /// **'Organize regular stops into groups and return with one tap.'**
  String get onboardingFavoritesDescription;

  /// No description provided for @onboardingNearbyDescription.
  ///
  /// In en, this message translates to:
  /// **'Use location access to quickly find nearby stops.'**
  String get onboardingNearbyDescription;

  /// No description provided for @onboardingLegalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get onboardingLegalPrefix;

  /// No description provided for @onboardingLegalAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get onboardingLegalAnd;

  /// No description provided for @onboardingLegalSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get onboardingLegalSuffix;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start setup'**
  String get onboardingStart;

  /// No description provided for @onboardingLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location access'**
  String get onboardingLocationTitle;

  /// No description provided for @onboardingLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Location access helps us find the nearest bus stops.'**
  String get onboardingLocationDescription;

  /// No description provided for @onboardingLocationConsent.
  ///
  /// In en, this message translates to:
  /// **'Allowing access means you agree to let the app process your location to find nearby stops.'**
  String get onboardingLocationConsent;

  /// No description provided for @onboardingLocationServerUse.
  ///
  /// In en, this message translates to:
  /// **'Your location is sent to the server only when no local database is available.'**
  String get onboardingLocationServerUse;

  /// No description provided for @onboardingProcessing.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get onboardingProcessing;

  /// No description provided for @onboardingAllowContinue.
  ///
  /// In en, this message translates to:
  /// **'Allow and continue'**
  String get onboardingAllowContinue;

  /// No description provided for @onboardingChooseManually.
  ///
  /// In en, this message translates to:
  /// **'Select databases manually'**
  String get onboardingChooseManually;

  /// No description provided for @onboardingDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download databases'**
  String get onboardingDownloadTitle;

  /// No description provided for @onboardingDownloadDescription.
  ///
  /// In en, this message translates to:
  /// **'Select one or more regional databases to use on this device.'**
  String get onboardingDownloadDescription;

  /// No description provided for @onboardingRegionList.
  ///
  /// In en, this message translates to:
  /// **'Regions'**
  String get onboardingRegionList;

  /// No description provided for @onboardingNearestSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Nearest suggestion: {provider}'**
  String onboardingNearestSuggestion(String provider);

  /// No description provided for @onboardingDefaultSource.
  ///
  /// In en, this message translates to:
  /// **'Default data source: {provider}'**
  String onboardingDefaultSource(String provider);

  /// No description provided for @onboardingSelectedDatabases.
  ///
  /// In en, this message translates to:
  /// **'Selected databases: {providers}'**
  String onboardingSelectedDatabases(String providers);

  /// No description provided for @onboardingDatabaseProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {downloaded} of {total} databases'**
  String onboardingDatabaseProgress(int downloaded, int total);

  /// No description provided for @onboardingDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String onboardingDownloadFailed(String error);

  /// No description provided for @shellWebUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version is available ({version}+{buildNumber})'**
  String shellWebUpdateAvailable(String version, String buildNumber);

  /// No description provided for @shellEnableSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable cloud sync?'**
  String get shellEnableSyncTitle;

  /// No description provided for @shellEnableSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'After signing in, favorite stops and preferences can sync automatically. They update when you open the app and shortly after changes.'**
  String get shellEnableSyncDescription;

  /// No description provided for @shellEnableSyncAction.
  ///
  /// In en, this message translates to:
  /// **'Enable sync'**
  String get shellEnableSyncAction;

  /// No description provided for @shellSyncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync is enabled.'**
  String get shellSyncEnabled;

  /// No description provided for @shellSyncSkipped.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync was skipped. You can still sync manually later.'**
  String get shellSyncSkipped;

  /// No description provided for @shellSyncPreferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the sync preference: {error}'**
  String shellSyncPreferenceFailed(String error);

  /// No description provided for @shellSignInSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Signed in.'**
  String get shellSignInSucceeded;

  /// No description provided for @shellSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String shellSignInFailed(String error);

  /// No description provided for @shellAccountLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked the {provider} account.'**
  String shellAccountLinked(String provider);

  /// No description provided for @shellAccountAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'{provider} is already linked to this account.'**
  String shellAccountAlreadyLinked(String provider);

  /// No description provided for @shellLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Linking failed: {error}'**
  String shellLinkFailed(String error);

  /// No description provided for @shellMergeAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge accounts?'**
  String get shellMergeAccountsTitle;

  /// No description provided for @shellMergeAccountsDescription.
  ///
  /// In en, this message translates to:
  /// **'{provider} belongs to another account. The identities and data below will move to this account, and the source account will be deleted:'**
  String shellMergeAccountsDescription(String provider);

  /// No description provided for @shellActiveDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {The source account has 1 active device.} other {The source account has {count} active devices.}}'**
  String shellActiveDevices(int count);

  /// No description provided for @shellMergeAccountsAction.
  ///
  /// In en, this message translates to:
  /// **'Merge accounts'**
  String get shellMergeAccountsAction;

  /// No description provided for @shellAccountsMerged.
  ///
  /// In en, this message translates to:
  /// **'Accounts merged. {provider} is now linked to this account.'**
  String shellAccountsMerged(String provider);

  /// No description provided for @shellMergeFailed.
  ///
  /// In en, this message translates to:
  /// **'Merge failed: {error}'**
  String shellMergeFailed(String error);

  /// No description provided for @shellDatabaseUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating databases...'**
  String get shellDatabaseUpdating;

  /// No description provided for @shellDatabaseUpdated.
  ///
  /// In en, this message translates to:
  /// **'Databases updated: {providers}'**
  String shellDatabaseUpdated(String providers);

  /// No description provided for @shellDatabaseAutoUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Automatic database update failed: {error}'**
  String shellDatabaseAutoUpdateFailed(String error);

  /// No description provided for @shellDatabaseUpdateComplete.
  ///
  /// In en, this message translates to:
  /// **'Database update complete.'**
  String get shellDatabaseUpdateComplete;

  /// No description provided for @shellDatabaseUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Database update failed: {error}'**
  String shellDatabaseUpdateFailed(String error);

  /// No description provided for @shellDatabaseUpdatesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Database updates are available for: {providers}'**
  String shellDatabaseUpdatesAvailable(String providers);

  /// No description provided for @shellDatabaseCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for database updates: {error}'**
  String shellDatabaseCheckFailed(String error);

  /// No description provided for @shellDatabaseUpdateDeferred.
  ///
  /// In en, this message translates to:
  /// **'The database update was deferred.'**
  String get shellDatabaseUpdateDeferred;

  /// No description provided for @etaLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get etaLoading;

  /// No description provided for @etaArriving.
  ///
  /// In en, this message translates to:
  /// **'Arriving'**
  String get etaArriving;

  /// No description provided for @etaSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String etaSeconds(int seconds);

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String etaMinutes(int minutes);

  /// No description provided for @etaMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m\n{seconds}s'**
  String etaMinutesSeconds(int minutes, int seconds);

  /// No description provided for @autoFavoriteFallback.
  ///
  /// In en, this message translates to:
  /// **'this stop'**
  String get autoFavoriteFallback;

  /// No description provided for @autoFavoriteAdded.
  ///
  /// In en, this message translates to:
  /// **'Ride this often? “{label}” was added to Frequent favorites.'**
  String autoFavoriteAdded(String label);

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonOkay.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOkay;

  /// No description provided for @commonEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get commonEnable;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonAddToHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Add to Home screen'**
  String get commonAddToHomeScreen;

  /// No description provided for @commonChooseStop.
  ///
  /// In en, this message translates to:
  /// **'Choose a stop'**
  String get commonChooseStop;

  /// No description provided for @commonAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonAcknowledge;

  /// No description provided for @directionOutbound.
  ///
  /// In en, this message translates to:
  /// **'Outbound'**
  String get directionOutbound;

  /// No description provided for @directionInbound.
  ///
  /// In en, this message translates to:
  /// **'Inbound'**
  String get directionInbound;

  /// No description provided for @directionNumber.
  ///
  /// In en, this message translates to:
  /// **'Direction {direction}'**
  String directionNumber(int direction);

  /// No description provided for @directionTo.
  ///
  /// In en, this message translates to:
  /// **'To {destination}'**
  String directionTo(String destination);

  /// No description provided for @relativeSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 second ago} other {{count} seconds ago}}'**
  String relativeSecondsAgo(int count);

  /// No description provided for @relativeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 minute ago} other {{count} minutes ago}}'**
  String relativeMinutesAgo(int count);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 hour ago} other {{count} hours ago}}'**
  String relativeHoursAgo(int count);

  /// No description provided for @relativeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 day ago} other {{count} days ago}}'**
  String relativeDaysAgo(int count);

  /// No description provided for @distanceMetersValue.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String distanceMetersValue(int meters);

  /// No description provided for @distanceKilometersValue.
  ///
  /// In en, this message translates to:
  /// **'{kilometers} km'**
  String distanceKilometersValue(String kilometers);

  /// No description provided for @speedKilometersPerHour.
  ///
  /// In en, this message translates to:
  /// **'{speed} km/h'**
  String speedKilometersPerHour(int speed);

  /// No description provided for @busStatusNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get busStatusNormal;

  /// No description provided for @busStatusAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get busStatusAccident;

  /// No description provided for @busStatusBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get busStatusBreakdown;

  /// No description provided for @busStatusTraffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get busStatusTraffic;

  /// No description provided for @busStatusEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get busStatusEmergency;

  /// No description provided for @busStatusRefueling.
  ///
  /// In en, this message translates to:
  /// **'Refueling'**
  String get busStatusRefueling;

  /// No description provided for @busStatusUnclear.
  ///
  /// In en, this message translates to:
  /// **'Unclear'**
  String get busStatusUnclear;

  /// No description provided for @busStatusDirectionUnclear.
  ///
  /// In en, this message translates to:
  /// **'Direction unclear'**
  String get busStatusDirectionUnclear;

  /// No description provided for @busStatusOffRoute.
  ///
  /// In en, this message translates to:
  /// **'Off route'**
  String get busStatusOffRoute;

  /// No description provided for @busStatusNotInService.
  ///
  /// In en, this message translates to:
  /// **'Not in service'**
  String get busStatusNotInService;

  /// No description provided for @busStatusFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get busStatusFull;

  /// No description provided for @busStatusChartered.
  ///
  /// In en, this message translates to:
  /// **'Chartered'**
  String get busStatusChartered;

  /// No description provided for @busStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get busStatusUnknown;

  /// No description provided for @busStatusUnknownCode.
  ///
  /// In en, this message translates to:
  /// **'Unknown ({code})'**
  String busStatusUnknownCode(int code);

  /// No description provided for @stationFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get stationFallbackTitle;

  /// No description provided for @stationShortcutRequested.
  ///
  /// In en, this message translates to:
  /// **'The station shortcut request was sent.'**
  String get stationShortcutRequested;

  /// No description provided for @shortcutUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This device does not support Home screen shortcuts.'**
  String get shortcutUnsupported;

  /// No description provided for @stationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Could not find information for this station.'**
  String get stationNotFound;

  /// No description provided for @stationPinTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add station to Home screen'**
  String get stationPinTooltip;

  /// No description provided for @stationNoSides.
  ///
  /// In en, this message translates to:
  /// **'There are no stops to display at this station right now.'**
  String get stationNoSides;

  /// No description provided for @stationSideLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop {side}'**
  String stationSideLabel(String side);

  /// No description provided for @stationSideDirection.
  ///
  /// In en, this message translates to:
  /// **'{side} · {direction}'**
  String stationSideDirection(String side, String direction);

  /// No description provided for @stationSideNoRoutes.
  ///
  /// In en, this message translates to:
  /// **'No routes serve stop {side} right now.'**
  String stationSideNoRoutes(String side);

  /// No description provided for @busMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Live bus map · {region}'**
  String busMapTitle(String region);

  /// No description provided for @busMapRouteDataLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load route data: {error}'**
  String busMapRouteDataLoadFailed(String error);

  /// No description provided for @busMapRouteDetailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Details are not available for this route right now.'**
  String get busMapRouteDetailUnavailable;

  /// No description provided for @busMapSwitchedRegion.
  ///
  /// In en, this message translates to:
  /// **'Switched to {region}'**
  String busMapSwitchedRegion(String region);

  /// No description provided for @busMapCloseFilter.
  ///
  /// In en, this message translates to:
  /// **'Close filter'**
  String get busMapCloseFilter;

  /// No description provided for @busMapFilterRoutes.
  ///
  /// In en, this message translates to:
  /// **'Filter routes'**
  String get busMapFilterRoutes;

  /// No description provided for @busMapFavoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Show favorite routes only'**
  String get busMapFavoritesOnly;

  /// No description provided for @busMapLocate.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get busMapLocate;

  /// No description provided for @busMapSwitchRegion.
  ///
  /// In en, this message translates to:
  /// **'Switch region'**
  String get busMapSwitchRegion;

  /// No description provided for @busMapFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter by route name or license plate'**
  String get busMapFilterHint;

  /// No description provided for @busMapNoData.
  ///
  /// In en, this message translates to:
  /// **'No bus data is available right now'**
  String get busMapNoData;

  /// No description provided for @busMapLoadingPositions.
  ///
  /// In en, this message translates to:
  /// **'Loading bus locations...'**
  String get busMapLoadingPositions;

  /// No description provided for @busMapBusCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 bus} other {{count} buses}}'**
  String busMapBusCount(int count);

  /// No description provided for @busMapBusCountUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 bus · {updated}} other {{count} buses · {updated}}}'**
  String busMapBusCountUpdated(int count, String updated);

  /// No description provided for @busMapZoomForBuses.
  ///
  /// In en, this message translates to:
  /// **'Zoom in or tap a circle to see individual buses'**
  String get busMapZoomForBuses;

  /// No description provided for @busMapShownCount.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total} buses; zoom in to see more'**
  String busMapShownCount(int shown, int total);

  /// No description provided for @busMapNoFavoriteRoutes.
  ///
  /// In en, this message translates to:
  /// **'No favorite routes are available in this region'**
  String get busMapNoFavoriteRoutes;

  /// No description provided for @busMapNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching buses found'**
  String get busMapNoMatches;

  /// No description provided for @busMapDataStale.
  ///
  /// In en, this message translates to:
  /// **'Data may be out of date'**
  String get busMapDataStale;

  /// No description provided for @busMapDataIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Data may be incomplete'**
  String get busMapDataIncomplete;

  /// No description provided for @busMapUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'The live bus map is not available in this region'**
  String get busMapUnsupportedTitle;

  /// No description provided for @busMapUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Use the menu in the upper-right corner to switch regions.'**
  String get busMapUnsupportedMessage;

  /// No description provided for @busMapRouteStops.
  ///
  /// In en, this message translates to:
  /// **'Stops along the route'**
  String get busMapRouteStops;

  /// No description provided for @busMapSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a bus to see its route, direction, and stops.'**
  String get busMapSelectionHint;

  /// No description provided for @busMapClusterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 bus} other {{count} buses}}'**
  String busMapClusterCount(int count);

  /// No description provided for @busMapClusterSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 bus here. Tap to zoom in.} other {{count} buses here. Tap to zoom in.}}'**
  String busMapClusterSemantics(int count);

  /// No description provided for @busMapYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get busMapYourLocation;

  /// No description provided for @busMapClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get busMapClearSelection;

  /// No description provided for @busMapSameRouteRunning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 bus running on this route} other {{count} buses running on this route}}'**
  String busMapSameRouteRunning(int count);

  /// No description provided for @busMapBareRouteCode.
  ///
  /// In en, this message translates to:
  /// **'This bus has route code {code}, but no route name is available.'**
  String busMapBareRouteCode(String code);

  /// No description provided for @busMapAmbiguousFamily.
  ///
  /// In en, this message translates to:
  /// **'This bus belongs to the “{family}” route family, but its exact service cannot be determined.'**
  String busMapAmbiguousFamily(String family);

  /// No description provided for @busMapRouteDetails.
  ///
  /// In en, this message translates to:
  /// **'Route details'**
  String get busMapRouteDetails;

  /// No description provided for @busMapShowWholeRoute.
  ///
  /// In en, this message translates to:
  /// **'Show full route'**
  String get busMapShowWholeRoute;

  /// No description provided for @routeMapRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get routeMapRefreshing;

  /// No description provided for @routeMapRefreshCountdown.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1 {Updates in 1 second} other {Updates in {seconds} seconds}}'**
  String routeMapRefreshCountdown(int seconds);

  /// No description provided for @routeMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Bus map'**
  String get routeMapTitle;

  /// No description provided for @routeMapToggleBuses.
  ///
  /// In en, this message translates to:
  /// **'Buses'**
  String get routeMapToggleBuses;

  /// No description provided for @routeMapToggleStops.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get routeMapToggleStops;

  /// No description provided for @routeMapRecenter.
  ///
  /// In en, this message translates to:
  /// **'Recenter on your location'**
  String get routeMapRecenter;

  /// No description provided for @routeMapNoData.
  ///
  /// In en, this message translates to:
  /// **'No route map data is available right now'**
  String get routeMapNoData;

  /// No description provided for @routeMapSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get routeMapSpeed;

  /// No description provided for @routeMapBearing.
  ///
  /// In en, this message translates to:
  /// **'Dir.'**
  String get routeMapBearing;

  /// No description provided for @routeMapUpdated.
  ///
  /// In en, this message translates to:
  /// **'Upd.'**
  String get routeMapUpdated;

  /// No description provided for @routeMapPosition.
  ///
  /// In en, this message translates to:
  /// **'Pos.'**
  String get routeMapPosition;

  /// No description provided for @routeMapStopSequence.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get routeMapStopSequence;

  /// No description provided for @routeMapArrival.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get routeMapArrival;

  /// No description provided for @routeMapAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get routeMapAngle;

  /// No description provided for @routeMapStatus.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get routeMapStatus;

  /// No description provided for @routeMapOnRoute.
  ///
  /// In en, this message translates to:
  /// **'On route'**
  String get routeMapOnRoute;

  /// No description provided for @routeMapSnappedToRoute.
  ///
  /// In en, this message translates to:
  /// **'On line'**
  String get routeMapSnappedToRoute;

  /// No description provided for @routeMapOffRoute.
  ///
  /// In en, this message translates to:
  /// **'{meters} m off route'**
  String routeMapOffRoute(int meters);

  /// No description provided for @routeMapOffLine.
  ///
  /// In en, this message translates to:
  /// **'{meters} m off line'**
  String routeMapOffLine(int meters);

  /// No description provided for @transferMissingCoordinates.
  ///
  /// In en, this message translates to:
  /// **'This stop has no coordinates, so nearby transfers cannot be found.'**
  String get transferMissingCoordinates;

  /// No description provided for @transferEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no nearby transfer options to display right now.'**
  String get transferEmpty;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby transfers'**
  String get transferTitle;

  /// No description provided for @transferWalkingRanges.
  ///
  /// In en, this message translates to:
  /// **'{stopName}\nBuses within a 250 m walk and YouBike stations within 300 m'**
  String transferWalkingRanges(String stopName);

  /// No description provided for @transferRouteCount.
  ///
  /// In en, this message translates to:
  /// **'{distance} · {count, plural, =1 {1 route} other {{count} routes}}'**
  String transferRouteCount(String distance, int count);

  /// No description provided for @transferBikeAvailability.
  ///
  /// In en, this message translates to:
  /// **'Rent {rent} · Return {returns}'**
  String transferBikeAvailability(int rent, int returns);

  /// No description provided for @transferBikeAvailabilityDistance.
  ///
  /// In en, this message translates to:
  /// **'{distance} · Rent {rent} · Return {returns}'**
  String transferBikeAvailabilityDistance(
    String distance,
    int rent,
    int returns,
  );

  /// No description provided for @routeDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Bus information'**
  String get routeDetailTitle;

  /// No description provided for @routeDetailStatusRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get routeDetailStatusRefreshing;

  /// No description provided for @routeDetailStatusLoadingRoute.
  ///
  /// In en, this message translates to:
  /// **'Loading route data'**
  String get routeDetailStatusLoadingRoute;

  /// No description provided for @routeDetailStatusLoadingRealtime.
  ///
  /// In en, this message translates to:
  /// **'Loading live arrivals'**
  String get routeDetailStatusLoadingRealtime;

  /// No description provided for @routeDetailStatusRealtimeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live information is temporarily unavailable'**
  String get routeDetailStatusRealtimeUnavailable;

  /// No description provided for @routeDetailStatusLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load'**
  String get routeDetailStatusLoadFailed;

  /// No description provided for @routeDetailStatusLoadingFamily.
  ///
  /// In en, this message translates to:
  /// **'Loading related services'**
  String get routeDetailStatusLoadingFamily;

  /// No description provided for @routeDetailCancelledToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s canceled departures'**
  String get routeDetailCancelledToday;

  /// No description provided for @routeDetailDirectionHeading.
  ///
  /// In en, this message translates to:
  /// **'{direction}:'**
  String routeDetailDirectionHeading(String direction);

  /// No description provided for @routeDetailOperationsNotice.
  ///
  /// In en, this message translates to:
  /// **'Service notice'**
  String get routeDetailOperationsNotice;

  /// No description provided for @routeDetailViewRoutePresence.
  ///
  /// In en, this message translates to:
  /// **'Viewing route'**
  String get routeDetailViewRoutePresence;

  /// No description provided for @routeDetailBackgroundPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable background trip alerts?'**
  String get routeDetailBackgroundPromptTitle;

  /// No description provided for @routeDetailBackgroundPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'YABus can keep tracking this route in the background and alert you as you approach your destination.'**
  String get routeDetailBackgroundPromptMessage;

  /// No description provided for @routeDetailBackgroundNotificationPermission.
  ///
  /// In en, this message translates to:
  /// **'Background trip alerts need notification permission to appear.'**
  String get routeDetailBackgroundNotificationPermission;

  /// No description provided for @routeDetailOppoPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get routeDetailOppoPromptTitle;

  /// No description provided for @routeDetailOppoPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'Your device may support live alerts. Enable them in YABus notification settings.'**
  String get routeDetailOppoPromptMessage;

  /// No description provided for @routeDetailSamsungPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Samsung Now Bar settings'**
  String get routeDetailSamsungPromptTitle;

  /// No description provided for @routeDetailSamsungPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'If trip information does not appear in Now Bar, enable Samsung\'s live notification test option.'**
  String get routeDetailSamsungPromptMessage;

  /// No description provided for @routeDetailSamsungDeveloperSteps.
  ///
  /// In en, this message translates to:
  /// **'If Developer options are not enabled:\nSettings → About phone → Software information → tap Build number 7 times'**
  String get routeDetailSamsungDeveloperSteps;

  /// No description provided for @routeDetailSamsungLiveSteps.
  ///
  /// In en, this message translates to:
  /// **'Then go to:\nSettings → Developer options → scroll to the bottom → More settings → Live notifications for all apps'**
  String get routeDetailSamsungLiveSteps;

  /// No description provided for @routeDetailOpenSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open system settings. Follow the path shown in the instructions instead.'**
  String get routeDetailOpenSettingsFailed;

  /// No description provided for @routeDetailTripPaused.
  ///
  /// In en, this message translates to:
  /// **'Background trip alerts paused'**
  String get routeDetailTripPaused;

  /// No description provided for @routeDetailTripResumed.
  ///
  /// In en, this message translates to:
  /// **'Background trip alerts resumed'**
  String get routeDetailTripResumed;

  /// No description provided for @routeDetailLocationServiceRequired.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to use background trip alerts.'**
  String get routeDetailLocationServiceRequired;

  /// No description provided for @routeDetailLocationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Allow location access to use background trip alerts.'**
  String get routeDetailLocationPermissionRequired;

  /// No description provided for @routeDetailNotificationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications to use arrival alerts.'**
  String get routeDetailNotificationPermissionRequired;

  /// No description provided for @routeDetailBackgroundLocationFallback.
  ///
  /// In en, this message translates to:
  /// **'Always-on location was not enabled. Background trip alerts will continue using the last location and bus arrival data.'**
  String get routeDetailBackgroundLocationFallback;

  /// No description provided for @routeDetailBackgroundLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow background location'**
  String get routeDetailBackgroundLocationTitle;

  /// No description provided for @routeDetailBackgroundLocationIos.
  ///
  /// In en, this message translates to:
  /// **'To keep destination alerts and Live Activities updated in the background, set iPhone location access to Always.'**
  String get routeDetailBackgroundLocationIos;

  /// No description provided for @routeDetailBackgroundLocationAndroid.
  ///
  /// In en, this message translates to:
  /// **'To keep alerts working in the background, set Android location access to Allow all the time.'**
  String get routeDetailBackgroundLocationAndroid;

  /// No description provided for @routeDetailAlwaysLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow location all the time?'**
  String get routeDetailAlwaysLocationTitle;

  /// No description provided for @routeDetailAlwaysLocationMessage.
  ///
  /// In en, this message translates to:
  /// **'YABus needs all-the-time location access to detect whether you have boarded or reached your stop in the background.'**
  String get routeDetailAlwaysLocationMessage;

  /// No description provided for @routeDetailEnableAction.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get routeDetailEnableAction;

  /// No description provided for @routeDetailDestinationPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a destination alert?'**
  String get routeDetailDestinationPromptTitle;

  /// No description provided for @routeDetailDestinationPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose where you plan to get off and YABus will alert you as you approach.'**
  String get routeDetailDestinationPromptMessage;

  /// No description provided for @routeDetailSetBoardingStop.
  ///
  /// In en, this message translates to:
  /// **'Board here'**
  String get routeDetailSetBoardingStop;

  /// No description provided for @routeDetailChangeBoardingStop.
  ///
  /// In en, this message translates to:
  /// **'Change boarding'**
  String get routeDetailChangeBoardingStop;

  /// No description provided for @routeDetailSetDestinationAlert.
  ///
  /// In en, this message translates to:
  /// **'Set destination'**
  String get routeDetailSetDestinationAlert;

  /// No description provided for @routeDetailBlockedDestination.
  ///
  /// In en, this message translates to:
  /// **'Already set as the destination'**
  String get routeDetailBlockedDestination;

  /// No description provided for @routeDetailBlockedBoarding.
  ///
  /// In en, this message translates to:
  /// **'Already set as the boarding stop'**
  String get routeDetailBlockedBoarding;

  /// No description provided for @routeDetailSameBoardingDestination.
  ///
  /// In en, this message translates to:
  /// **'The boarding stop cannot also be the destination.'**
  String get routeDetailSameBoardingDestination;

  /// No description provided for @routeDetailBoardingStopSet.
  ///
  /// In en, this message translates to:
  /// **'Boarding stop set to {stopName}.'**
  String routeDetailBoardingStopSet(String stopName);

  /// No description provided for @routeDetailDestinationSet.
  ///
  /// In en, this message translates to:
  /// **'Destination alert set to {stopName}.'**
  String routeDetailDestinationSet(String stopName);

  /// No description provided for @routeDetailManualBoardingCleared.
  ///
  /// In en, this message translates to:
  /// **'Manual boarding stop cleared. It will be detected automatically when location becomes available.'**
  String get routeDetailManualBoardingCleared;

  /// No description provided for @routeDetailUsingCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'The boarding stop will now follow your current location.'**
  String get routeDetailUsingCurrentLocation;

  /// No description provided for @routeDetailTripActive.
  ///
  /// In en, this message translates to:
  /// **'Background trip alerts active'**
  String get routeDetailTripActive;

  /// No description provided for @routeDetailBusApproaching.
  ///
  /// In en, this message translates to:
  /// **'Bus approaching'**
  String get routeDetailBusApproaching;

  /// No description provided for @routeDetailBusStopsAway.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {Bus is 1 stop away} other {Bus is {count} stops away}}'**
  String routeDetailBusStopsAway(int count);

  /// No description provided for @routeDetailNearestStopValue.
  ///
  /// In en, this message translates to:
  /// **'Nearest stop: {stopName}'**
  String routeDetailNearestStopValue(String stopName);

  /// No description provided for @routeDetailNotBoarded.
  ///
  /// In en, this message translates to:
  /// **'Not boarded'**
  String get routeDetailNotBoarded;

  /// No description provided for @routeDetailBoardingStopValue.
  ///
  /// In en, this message translates to:
  /// **'Boarding stop: {stopName}'**
  String routeDetailBoardingStopValue(String stopName);

  /// No description provided for @routeDetailDestinationValue.
  ///
  /// In en, this message translates to:
  /// **'Destination: {stopName}'**
  String routeDetailDestinationValue(String stopName);

  /// No description provided for @routeDetailWaitingForLocation.
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get routeDetailWaitingForLocation;

  /// No description provided for @routeDetailLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating'**
  String get routeDetailLocating;

  /// No description provided for @routeDetailWaitingToBoard.
  ///
  /// In en, this message translates to:
  /// **'Waiting to board'**
  String get routeDetailWaitingToBoard;

  /// No description provided for @routeDetailNearestStop.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get routeDetailNearestStop;

  /// No description provided for @routeDetailDestinationNotSet.
  ///
  /// In en, this message translates to:
  /// **'No destination set'**
  String get routeDetailDestinationNotSet;

  /// No description provided for @routeDetailBoarded.
  ///
  /// In en, this message translates to:
  /// **'Boarded'**
  String get routeDetailBoarded;

  /// No description provided for @routeDetailEtaNotDeparted.
  ///
  /// In en, this message translates to:
  /// **'Not departed'**
  String get routeDetailEtaNotDeparted;

  /// No description provided for @routeDetailEtaLastBusPassed.
  ///
  /// In en, this message translates to:
  /// **'Last bus departed'**
  String get routeDetailEtaLastBusPassed;

  /// No description provided for @routeDetailEtaApproxMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'About {minutes}m {seconds}s'**
  String routeDetailEtaApproxMinutesSeconds(int minutes, int seconds);

  /// No description provided for @routeDetailEtaApproxMinutes.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min'**
  String routeDetailEtaApproxMinutes(int minutes);

  /// No description provided for @routeDetailFavoriteStop.
  ///
  /// In en, this message translates to:
  /// **'Favorite stop'**
  String get routeDetailFavoriteStop;

  /// No description provided for @routeDetailFavoriteStation.
  ///
  /// In en, this message translates to:
  /// **'Favorite station'**
  String get routeDetailFavoriteStation;

  /// No description provided for @routeDetailFavoriteGroupDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A favorite group with this name already exists.'**
  String get routeDetailFavoriteGroupDuplicate;

  /// No description provided for @routeDetailFavoriteLimit.
  ///
  /// In en, this message translates to:
  /// **'Favorites are limited to {count} items. This item could not be added.'**
  String routeDetailFavoriteLimit(int count);

  /// No description provided for @routeDetailRouteAdded.
  ///
  /// In en, this message translates to:
  /// **'Route added to {group}'**
  String routeDetailRouteAdded(String group);

  /// No description provided for @routeDetailStationIdMissing.
  ///
  /// In en, this message translates to:
  /// **'This stop cannot be matched to a station because its identifier is missing.'**
  String get routeDetailStationIdMissing;

  /// No description provided for @routeDetailStationNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Station information for this stop has not been synced yet.'**
  String get routeDetailStationNotSynced;

  /// No description provided for @routeDetailStationAdded.
  ///
  /// In en, this message translates to:
  /// **'{station} added to {group}'**
  String routeDetailStationAdded(String station, String group);

  /// No description provided for @routeDetailFavoriteAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to {group}'**
  String routeDetailFavoriteAdded(String group);

  /// No description provided for @routeDetailFavoriteAddedWithDestination.
  ///
  /// In en, this message translates to:
  /// **'Added to {group}; destination: {destination}'**
  String routeDetailFavoriteAddedWithDestination(
    String group,
    String destination,
  );

  /// No description provided for @routeDetailFavoriteDestinationTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a destination for this favorite?'**
  String get routeDetailFavoriteDestinationTitle;

  /// No description provided for @routeDetailFavoriteDestinationMessage.
  ///
  /// In en, this message translates to:
  /// **'When you open it from Favorites or a widget, its destination alert will be applied automatically.'**
  String get routeDetailFavoriteDestinationMessage;

  /// No description provided for @routeDetailNoSelectableStops.
  ///
  /// In en, this message translates to:
  /// **'There are no stops to select in this direction right now.'**
  String get routeDetailNoSelectableStops;

  /// No description provided for @routeDetailShortcutRequested.
  ///
  /// In en, this message translates to:
  /// **'The Home screen shortcut request was sent.'**
  String get routeDetailShortcutRequested;

  /// No description provided for @routeDetailRouteShortcutRequested.
  ///
  /// In en, this message translates to:
  /// **'The route shortcut request was sent.'**
  String get routeDetailRouteShortcutRequested;

  /// No description provided for @routeDetailDestinationCleared.
  ///
  /// In en, this message translates to:
  /// **'Destination alert cleared.'**
  String get routeDetailDestinationCleared;

  /// No description provided for @routeDetailGoogleMapsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Google Maps.'**
  String get routeDetailGoogleMapsFailed;

  /// No description provided for @routeDetailRealtimeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading live data...'**
  String get routeDetailRealtimeLoading;

  /// No description provided for @routeDetailNoRealtime.
  ///
  /// In en, this message translates to:
  /// **'No live data'**
  String get routeDetailNoRealtime;

  /// No description provided for @routeDetailSelectFavoriteGroup.
  ///
  /// In en, this message translates to:
  /// **'Choose a favorite group'**
  String get routeDetailSelectFavoriteGroup;

  /// No description provided for @routeDetailNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get routeDetailNewGroup;

  /// No description provided for @routeDetailForumFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open TWBusforum.'**
  String get routeDetailForumFailed;

  /// No description provided for @routeDetailBackgroundDrawerTitle.
  ///
  /// In en, this message translates to:
  /// **'Background trip alerts'**
  String get routeDetailBackgroundDrawerTitle;

  /// No description provided for @routeDetailBackgroundDrawerMessage.
  ///
  /// In en, this message translates to:
  /// **'Manage background tracking and destination alerts here.'**
  String get routeDetailBackgroundDrawerMessage;

  /// No description provided for @routeDetailPauseBackground.
  ///
  /// In en, this message translates to:
  /// **'Pause background trip alerts'**
  String get routeDetailPauseBackground;

  /// No description provided for @routeDetailResumeBackground.
  ///
  /// In en, this message translates to:
  /// **'Resume background trip alerts'**
  String get routeDetailResumeBackground;

  /// No description provided for @routeDetailPauseBackgroundMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep your settings, but pause background tracking and alerts.'**
  String get routeDetailPauseBackgroundMessage;

  /// No description provided for @routeDetailResumeBackgroundMessage.
  ///
  /// In en, this message translates to:
  /// **'Resume background tracking and alerts.'**
  String get routeDetailResumeBackgroundMessage;

  /// No description provided for @routeDetailCurrentStop.
  ///
  /// In en, this message translates to:
  /// **'Current stop: {stopName}'**
  String routeDetailCurrentStop(String stopName);

  /// No description provided for @routeDetailBoardingStopHint.
  ///
  /// In en, this message translates to:
  /// **'If location is unavailable, you can choose a boarding stop manually.'**
  String get routeDetailBoardingStopHint;

  /// No description provided for @routeDetailDestinationHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a stop for the destination alert.'**
  String get routeDetailDestinationHint;

  /// No description provided for @routeDetailClearManualBoarding.
  ///
  /// In en, this message translates to:
  /// **'Clear manual boarding stop'**
  String get routeDetailClearManualBoarding;

  /// No description provided for @routeDetailReturnToCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location again'**
  String get routeDetailReturnToCurrentLocation;

  /// No description provided for @routeDetailClearManualBoardingHint.
  ///
  /// In en, this message translates to:
  /// **'Keep alerts enabled and detect the boarding stop when location becomes available.'**
  String get routeDetailClearManualBoardingHint;

  /// No description provided for @routeDetailCurrentLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Automatically follow the nearest stop to your current location.'**
  String get routeDetailCurrentLocationHint;

  /// No description provided for @routeDetailClearDestinationAlert.
  ///
  /// In en, this message translates to:
  /// **'Clear destination alert'**
  String get routeDetailClearDestinationAlert;

  /// No description provided for @routeDetailVehicleBackfill.
  ///
  /// In en, this message translates to:
  /// **'Backfilled location'**
  String get routeDetailVehicleBackfill;

  /// No description provided for @routeDetailVehicleRealtime.
  ///
  /// In en, this message translates to:
  /// **'Live location'**
  String get routeDetailVehicleRealtime;

  /// No description provided for @routeDetailVehicleSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get routeDetailVehicleSource;

  /// No description provided for @routeDetailVehicleEta.
  ///
  /// In en, this message translates to:
  /// **'ETA at this stop'**
  String get routeDetailVehicleEta;

  /// No description provided for @routeDetailVehicleNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get routeDetailVehicleNotes;

  /// No description provided for @routeDetailVehicleCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get routeDetailVehicleCondition;

  /// No description provided for @routeDetailVehicleFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get routeDetailVehicleFull;

  /// No description provided for @routeDetailVehicleAtStop.
  ///
  /// In en, this message translates to:
  /// **'At stop'**
  String get routeDetailVehicleAtStop;

  /// No description provided for @routeDetailVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get routeDetailVehicleType;

  /// No description provided for @routeDetailVehicleElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric bus'**
  String get routeDetailVehicleElectric;

  /// No description provided for @routeDetailVehicleEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get routeDetailVehicleEquipment;

  /// No description provided for @routeDetailVehicleAccessible.
  ///
  /// In en, this message translates to:
  /// **'Low-floor / accessible'**
  String get routeDetailVehicleAccessible;

  /// No description provided for @routeDetailViewOnMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get routeDetailViewOnMap;

  /// No description provided for @routeDetailSearchForum.
  ///
  /// In en, this message translates to:
  /// **'TWBusforum'**
  String get routeDetailSearchForum;

  /// No description provided for @routeDetailVehicleElectricShort.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get routeDetailVehicleElectricShort;

  /// No description provided for @routeDetailVehicleAccessibleShort.
  ///
  /// In en, this message translates to:
  /// **'Accessible'**
  String get routeDetailVehicleAccessibleShort;

  /// No description provided for @routeDetailVehicleFullShort.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get routeDetailVehicleFullShort;

  /// No description provided for @routeDetailDestinationStop.
  ///
  /// In en, this message translates to:
  /// **'Dest.'**
  String get routeDetailDestinationStop;

  /// No description provided for @routeDetailNoDirectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'This route has no direction data'**
  String get routeDetailNoDirectionsTitle;

  /// No description provided for @routeDetailNoDirectionsMessage.
  ///
  /// In en, this message translates to:
  /// **'No outbound or inbound service could be found. Try again later.'**
  String get routeDetailNoDirectionsMessage;

  /// No description provided for @routeDetailNoStopsTitle.
  ///
  /// In en, this message translates to:
  /// **'This direction has no stops'**
  String get routeDetailNoStopsTitle;

  /// No description provided for @routeDetailNoStopsMessage.
  ///
  /// In en, this message translates to:
  /// **'The data may still be syncing. Refresh again shortly.'**
  String get routeDetailNoStopsMessage;

  /// No description provided for @routeDetailNoMapData.
  ///
  /// In en, this message translates to:
  /// **'No map data is available right now'**
  String get routeDetailNoMapData;

  /// No description provided for @routeDetailRouteNotice.
  ///
  /// In en, this message translates to:
  /// **'Route notice'**
  String get routeDetailRouteNotice;

  /// No description provided for @routeDetailNoticeUpdate.
  ///
  /// In en, this message translates to:
  /// **'Service information has been updated'**
  String get routeDetailNoticeUpdate;

  /// No description provided for @routeDetailCancelledDepartures.
  ///
  /// In en, this message translates to:
  /// **'Canceled departures today'**
  String get routeDetailCancelledDepartures;

  /// No description provided for @routeDetailAdditionalNotices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {{message} (1 more)} other {{message} ({count} more)}}'**
  String routeDetailAdditionalNotices(String message, int count);

  /// No description provided for @routeDetailErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Bus information is stuck'**
  String get routeDetailErrorTitle;

  /// No description provided for @routeDetailErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Bus information cannot be loaded right now. Try refreshing again later.'**
  String get routeDetailErrorMessage;

  /// No description provided for @routeDetailHideMap.
  ///
  /// In en, this message translates to:
  /// **'Hide map'**
  String get routeDetailHideMap;

  /// No description provided for @routeDetailShowMap.
  ///
  /// In en, this message translates to:
  /// **'Show map'**
  String get routeDetailShowMap;

  /// No description provided for @routeDetailJumpToNearestStop.
  ///
  /// In en, this message translates to:
  /// **'Nearest stop'**
  String get routeDetailJumpToNearestStop;

  /// No description provided for @routeDetailScheduleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Route schedule'**
  String get routeDetailScheduleTooltip;

  /// No description provided for @routeInfoActions.
  ///
  /// In en, this message translates to:
  /// **'Route actions'**
  String get routeInfoActions;

  /// No description provided for @routeInfoFavoriteRoute.
  ///
  /// In en, this message translates to:
  /// **'Favorite route'**
  String get routeInfoFavoriteRoute;

  /// No description provided for @routeInfoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load: {error}'**
  String routeInfoLoadFailed(String error);

  /// No description provided for @routeInfoOperators.
  ///
  /// In en, this message translates to:
  /// **'Operators'**
  String get routeInfoOperators;

  /// No description provided for @routeInfoFamilySchedule.
  ///
  /// In en, this message translates to:
  /// **'Related route schedule'**
  String get routeInfoFamilySchedule;

  /// No description provided for @routeInfoRelatedRoutes.
  ///
  /// In en, this message translates to:
  /// **'Related routes'**
  String get routeInfoRelatedRoutes;

  /// No description provided for @routeInfoShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get routeInfoShareLink;

  /// No description provided for @routeInfoLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get routeInfoLinkCopied;

  /// No description provided for @routeInfoPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String routeInfoPhone(String phone);

  /// No description provided for @routeInfoWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website: {url}'**
  String routeInfoWebsite(String url);

  /// No description provided for @scheduleWeekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get scheduleWeekdayMon;

  /// No description provided for @scheduleWeekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get scheduleWeekdayTue;

  /// No description provided for @scheduleWeekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get scheduleWeekdayWed;

  /// No description provided for @scheduleWeekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get scheduleWeekdayThu;

  /// No description provided for @scheduleWeekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get scheduleWeekdayFri;

  /// No description provided for @scheduleWeekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get scheduleWeekdaySat;

  /// No description provided for @scheduleWeekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get scheduleWeekdaySun;

  /// No description provided for @scheduleDateLabel.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day} ({weekday})'**
  String scheduleDateLabel(int month, int day, String weekday);

  /// No description provided for @scheduleHolidayDateLabel.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day} ({weekday} · holiday)'**
  String scheduleHolidayDateLabel(int month, int day, String weekday);

  /// No description provided for @scheduleChooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get scheduleChooseDate;

  /// No description provided for @scheduleNoServiceDay.
  ///
  /// In en, this message translates to:
  /// **'No departures are scheduled for this day'**
  String get scheduleNoServiceDay;

  /// No description provided for @scheduleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No schedule data is available right now'**
  String get scheduleUnavailable;

  /// No description provided for @scheduleNoDepartureTimes.
  ///
  /// In en, this message translates to:
  /// **'No departure times available'**
  String get scheduleNoDepartureTimes;

  /// No description provided for @stopScheduleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{routeName} · Estimated times'**
  String stopScheduleSubtitle(String routeName);

  /// No description provided for @stopScheduleDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Estimated from the timetable; actual service may vary'**
  String get stopScheduleDisclaimer;

  /// No description provided for @stopScheduleNoTimetable.
  ///
  /// In en, this message translates to:
  /// **'This route has no timetable data'**
  String get stopScheduleNoTimetable;

  /// No description provided for @stopScheduleNoStopTimes.
  ///
  /// In en, this message translates to:
  /// **'No matching departure times are available at this stop on this day'**
  String get stopScheduleNoStopTimes;

  /// No description provided for @stopScheduleFrequency.
  ///
  /// In en, this message translates to:
  /// **'Service frequency'**
  String get stopScheduleFrequency;

  /// No description provided for @stopScheduleEstimatedArrival.
  ///
  /// In en, this message translates to:
  /// **'Estimated arrival times'**
  String get stopScheduleEstimatedArrival;

  /// No description provided for @stopScheduleIncludesEstimates.
  ///
  /// In en, this message translates to:
  /// **'Includes estimates'**
  String get stopScheduleIncludesEstimates;

  /// No description provided for @stopScheduleEstimateFootnote.
  ///
  /// In en, this message translates to:
  /// **'Times marked “Includes estimates” are calculated from service frequency and travel time and are for reference only.'**
  String get stopScheduleEstimateFootnote;

  /// No description provided for @relatedRoutesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load routes serving this stop'**
  String get relatedRoutesLoadFailed;

  /// No description provided for @relatedRoutesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No routes found for “{stopName}”'**
  String relatedRoutesEmpty(String stopName);

  /// No description provided for @relatedRoutesTitle.
  ///
  /// In en, this message translates to:
  /// **'Routes serving this stop'**
  String get relatedRoutesTitle;

  /// No description provided for @stopActionSetDestination.
  ///
  /// In en, this message translates to:
  /// **'Set as destination alert'**
  String get stopActionSetDestination;

  /// No description provided for @stopActionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Departures / arrivals at this stop'**
  String get stopActionSchedule;

  /// No description provided for @stopActionRelatedRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes serving this stop'**
  String get stopActionRelatedRoutes;

  /// No description provided for @stopActionTransfers.
  ///
  /// In en, this message translates to:
  /// **'Nearby transfers'**
  String get stopActionTransfers;

  /// No description provided for @stopActionOpenGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get stopActionOpenGoogleMaps;

  /// No description provided for @linkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get linkOpenFailed;

  /// No description provided for @announcementsSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sync announcements'**
  String get announcementsSyncFailed;

  /// No description provided for @announcementsEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no announcements right now.'**
  String get announcementsEmpty;

  /// No description provided for @announcementNotFound.
  ///
  /// In en, this message translates to:
  /// **'This announcement could not be found.'**
  String get announcementNotFound;

  /// No description provided for @announcementResync.
  ///
  /// In en, this message translates to:
  /// **'Sync announcements again'**
  String get announcementResync;

  /// No description provided for @announcementEmbeddedContent.
  ///
  /// In en, this message translates to:
  /// **'Embedded content'**
  String get announcementEmbeddedContent;

  /// No description provided for @announcementSound.
  ///
  /// In en, this message translates to:
  /// **'Notification sound'**
  String get announcementSound;

  /// No description provided for @announcementReaction.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get announcementReaction;

  /// No description provided for @announcementAddReaction.
  ///
  /// In en, this message translates to:
  /// **'Add an emoji reaction'**
  String get announcementAddReaction;

  /// No description provided for @announcementFirstReaction.
  ///
  /// In en, this message translates to:
  /// **'Be the first to react'**
  String get announcementFirstReaction;

  /// No description provided for @announcementReactionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update your reaction. Please try again later.'**
  String get announcementReactionUpdateFailed;

  /// No description provided for @announcementReactionSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to add a reaction'**
  String get announcementReactionSignInRequired;

  /// No description provided for @legalDocumentUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the document'**
  String get legalDocumentUpdateFailed;

  /// No description provided for @legalDocumentReload.
  ///
  /// In en, this message translates to:
  /// **'Reload document'**
  String get legalDocumentReload;

  /// No description provided for @accountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountSignIn;

  /// No description provided for @accountSignInDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to back up your favorite stops and settings.'**
  String get accountSignInDescription;

  /// No description provided for @accountLoginPageOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the sign-in page.'**
  String get accountLoginPageOpenFailed;

  /// No description provided for @accountLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String accountLoginFailed(String error);

  /// No description provided for @accountLinkPageOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the account-linking page.'**
  String get accountLinkPageOpenFailed;

  /// No description provided for @accountLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Linking failed: {error}'**
  String accountLinkFailed(String error);

  /// No description provided for @accountRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh the account: {error}'**
  String accountRefreshFailed(String error);

  /// No description provided for @accountAutoSyncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync is on.'**
  String get accountAutoSyncEnabled;

  /// No description provided for @accountAutoSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync is off.'**
  String get accountAutoSyncDisabled;

  /// No description provided for @accountSyncSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update sync settings: {error}'**
  String accountSyncSettingsFailed(String error);

  /// No description provided for @accountRouteHistoryPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync route history?'**
  String get accountRouteHistoryPromptTitle;

  /// No description provided for @accountRouteHistoryPromptDescription.
  ///
  /// In en, this message translates to:
  /// **'Your recent route searches and smart recommendation activity will be uploaded to your account so they are available on your other devices. Location data is not included. You can turn this off at any time and remove history uploaded from this device.'**
  String get accountRouteHistoryPromptDescription;

  /// No description provided for @accountEnableSync.
  ///
  /// In en, this message translates to:
  /// **'Enable sync'**
  String get accountEnableSync;

  /// No description provided for @accountRouteHistoryEnabled.
  ///
  /// In en, this message translates to:
  /// **'Route history sync is on.'**
  String get accountRouteHistoryEnabled;

  /// No description provided for @accountRouteHistoryDisabled.
  ///
  /// In en, this message translates to:
  /// **'Route history sync is off.'**
  String get accountRouteHistoryDisabled;

  /// No description provided for @accountRouteHistoryUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update route history sync: {error}'**
  String accountRouteHistoryUpdateFailed(String error);

  /// No description provided for @accountSyncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete.'**
  String get accountSyncComplete;

  /// No description provided for @accountSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String accountSyncFailed(String error);

  /// No description provided for @accountSyncConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync conflict'**
  String get accountSyncConflictTitle;

  /// No description provided for @accountSyncConflictFallback.
  ///
  /// In en, this message translates to:
  /// **'A conflict occurred while syncing {namespace}.'**
  String accountSyncConflictFallback(String namespace);

  /// No description provided for @accountSyncNamespaceFavorites.
  ///
  /// In en, this message translates to:
  /// **'favorite stops and groups'**
  String get accountSyncNamespaceFavorites;

  /// No description provided for @accountSyncNamespacePreferences.
  ///
  /// In en, this message translates to:
  /// **'preferences'**
  String get accountSyncNamespacePreferences;

  /// No description provided for @accountUseCloud.
  ///
  /// In en, this message translates to:
  /// **'Use cloud copy'**
  String get accountUseCloud;

  /// No description provided for @accountTryMerge.
  ///
  /// In en, this message translates to:
  /// **'Try to merge'**
  String get accountTryMerge;

  /// No description provided for @accountOverwriteCloud.
  ///
  /// In en, this message translates to:
  /// **'Overwrite cloud copy'**
  String get accountOverwriteCloud;

  /// No description provided for @accountSyncConflictFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resolve the sync conflict: {error}'**
  String accountSyncConflictFailed(String error);

  /// No description provided for @accountLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get accountLoggedOut;

  /// No description provided for @accountLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountLogout;

  /// No description provided for @accountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedIn;

  /// No description provided for @accountDefaultDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Ciallo~(∠・ω< )⌒☆'**
  String get accountDefaultDisplayName;

  /// No description provided for @accountContinueDescription.
  ///
  /// In en, this message translates to:
  /// **'Continue with Discord or Google to create or link your account.'**
  String get accountContinueDescription;

  /// No description provided for @accountLoadedFromCurrentToken.
  ///
  /// In en, this message translates to:
  /// **'Loaded from the current sign-in token'**
  String get accountLoadedFromCurrentToken;

  /// No description provided for @accountNoLinkedProviders.
  ///
  /// In en, this message translates to:
  /// **'No linked account details have been loaded yet.'**
  String get accountNoLinkedProviders;

  /// No description provided for @accountLinkProvider.
  ///
  /// In en, this message translates to:
  /// **'Link {provider}'**
  String accountLinkProvider(String provider);

  /// No description provided for @accountCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get accountCloudSync;

  /// No description provided for @accountEnableCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Enable cloud sync'**
  String get accountEnableCloudSync;

  /// No description provided for @accountLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {date}'**
  String accountLastSync(String date);

  /// No description provided for @accountSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sync is off.'**
  String get accountSyncDisabled;

  /// No description provided for @accountSyncRouteHistory.
  ///
  /// In en, this message translates to:
  /// **'Sync route history'**
  String get accountSyncRouteHistory;

  /// No description provided for @accountRouteHistoryDeletionPending.
  ///
  /// In en, this message translates to:
  /// **'Off. Removing this device\'s route history from the cloud.'**
  String get accountRouteHistoryDeletionPending;

  /// No description provided for @accountRouteHistorySyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Recent searches and smart recommendation activity will sync. Location data is not included.'**
  String get accountRouteHistorySyncDescription;

  /// No description provided for @accountRouteHistoryWaitingForCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Allowed. History will upload after cloud sync is enabled.'**
  String get accountRouteHistoryWaitingForCloudSync;

  /// No description provided for @accountRouteHistoryOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional and off by default.'**
  String get accountRouteHistoryOptional;

  /// No description provided for @accountSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get accountSyncNow;

  /// No description provided for @accountContinueWithProvider.
  ///
  /// In en, this message translates to:
  /// **'Continue with {provider}'**
  String accountContinueWithProvider(String provider);

  /// No description provided for @accountNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get accountNeverSynced;

  /// No description provided for @feedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent. Thank you for helping us improve.'**
  String get feedbackSubmitted;

  /// No description provided for @feedbackSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Sign in again before sending feedback.'**
  String get feedbackSessionExpired;

  /// No description provided for @feedbackSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in first'**
  String get feedbackSignInRequired;

  /// No description provided for @feedbackGoToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get feedbackGoToSignIn;

  /// No description provided for @feedbackSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get feedbackSubjectLabel;

  /// No description provided for @feedbackSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Favorite stop sync failed'**
  String get feedbackSubjectHint;

  /// No description provided for @feedbackSubjectRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a subject'**
  String get feedbackSubjectRequired;

  /// No description provided for @feedbackSubjectTooLong.
  ///
  /// In en, this message translates to:
  /// **'The subject can be at most {max} characters.'**
  String feedbackSubjectTooLong(int max);

  /// No description provided for @feedbackContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get feedbackContentLabel;

  /// No description provided for @feedbackContentHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened, what you expected, and how to reproduce it.'**
  String get feedbackContentHint;

  /// No description provided for @feedbackContentRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter some details'**
  String get feedbackContentRequired;

  /// No description provided for @feedbackContentTooLong.
  ///
  /// In en, this message translates to:
  /// **'The details can be at most {max} characters.'**
  String feedbackContentTooLong(int max);

  /// No description provided for @feedbackSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get feedbackSubmitting;

  /// No description provided for @feedbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get feedbackSubmit;

  /// No description provided for @feedbackInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'The feedback format is invalid.'**
  String get feedbackInvalidFormat;

  /// No description provided for @feedbackSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send feedback. Please try again later.'**
  String get feedbackSubmitFailed;

  /// No description provided for @databaseUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Your databases are up to date.'**
  String get databaseUpToDate;

  /// No description provided for @databaseUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'{provider} has a new version: {version}'**
  String databaseUpdateAvailable(String provider, int version);

  /// No description provided for @databaseCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for database updates: {error}'**
  String databaseCheckFailed(String error);

  /// No description provided for @databaseNoUpdatesAvailable.
  ///
  /// In en, this message translates to:
  /// **'There are no databases to update.'**
  String get databaseNoUpdatesAvailable;

  /// No description provided for @databaseDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download the database: {error}'**
  String databaseDownloadFailed(String error);

  /// No description provided for @databaseStartupUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates on launch'**
  String get databaseStartupUpdateTitle;

  /// No description provided for @databaseAutoUpdateModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Automatic update mode'**
  String get databaseAutoUpdateModeLabel;

  /// No description provided for @databaseAutoUpdateOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Do not automatically check for database updates on launch.'**
  String get databaseAutoUpdateOffDescription;

  /// No description provided for @databaseAutoUpdatePopupDescription.
  ///
  /// In en, this message translates to:
  /// **'Check on launch and show a pop-up when updates are available.'**
  String get databaseAutoUpdatePopupDescription;

  /// No description provided for @databaseAutoUpdateNotifyDescription.
  ///
  /// In en, this message translates to:
  /// **'Check on launch and show a notification when updates are available.'**
  String get databaseAutoUpdateNotifyDescription;

  /// No description provided for @databaseAutoUpdateAlwaysDescription.
  ///
  /// In en, this message translates to:
  /// **'Download and install available updates automatically on launch.'**
  String get databaseAutoUpdateAlwaysDescription;

  /// No description provided for @databaseAutoUpdateWifiDescription.
  ///
  /// In en, this message translates to:
  /// **'Update automatically on Wi-Fi. On other networks, only notify you.'**
  String get databaseAutoUpdateWifiDescription;

  /// No description provided for @databaseAutoUpdateCellularDescription.
  ///
  /// In en, this message translates to:
  /// **'Update automatically on mobile data. On other networks, only notify you.'**
  String get databaseAutoUpdateCellularDescription;

  /// No description provided for @databaseRegionVersion.
  ///
  /// In en, this message translates to:
  /// **'{provider} v{version}'**
  String databaseRegionVersion(String provider, int version);

  /// No description provided for @databaseCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get databaseCheckNow;

  /// No description provided for @databaseAllUpdatesDownloaded.
  ///
  /// In en, this message translates to:
  /// **'All available database updates were installed.'**
  String get databaseAllUpdatesDownloaded;

  /// No description provided for @databaseDownloadUpdates.
  ///
  /// In en, this message translates to:
  /// **'Install available updates'**
  String get databaseDownloadUpdates;

  /// No description provided for @databaseRouteDatabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Route database'**
  String get databaseRouteDatabaseTitle;

  /// No description provided for @databaseDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get databaseDownloaded;

  /// No description provided for @databaseNotDownloadedYet.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded yet'**
  String get databaseNotDownloadedYet;

  /// No description provided for @databaseDataSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Data source'**
  String get databaseDataSourceTitle;

  /// No description provided for @databaseDefaultRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Default region'**
  String get databaseDefaultRegionLabel;

  /// No description provided for @databaseSelectLocalRegions.
  ///
  /// In en, this message translates to:
  /// **'Select the regional databases to keep on this device.'**
  String get databaseSelectLocalRegions;

  /// No description provided for @databaseSelectedRegionsDownloaded.
  ///
  /// In en, this message translates to:
  /// **'The selected regional databases were downloaded.'**
  String get databaseSelectedRegionsDownloaded;

  /// No description provided for @databaseDownloadSelectedRegions.
  ///
  /// In en, this message translates to:
  /// **'Download selected regions'**
  String get databaseDownloadSelectedRegions;

  /// No description provided for @databaseDiscordPresenceSection.
  ///
  /// In en, this message translates to:
  /// **'Discord Rich Presence'**
  String get databaseDiscordPresenceSection;

  /// No description provided for @databaseDiscordPresenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Discord Rich Presence'**
  String get databaseDiscordPresenceTitle;

  /// No description provided for @databaseDiscordPresenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Share the bus you are viewing with friends (⁠ ⁠/⁠^⁠ω⁠^⁠)⁠/⁠⁠'**
  String get databaseDiscordPresenceDescription;

  /// No description provided for @databasePresenceCurrentPage.
  ///
  /// In en, this message translates to:
  /// **'Current page'**
  String get databasePresenceCurrentPage;

  /// No description provided for @databasePresenceRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get databasePresenceRegion;

  /// No description provided for @databasePresenceRouteName.
  ///
  /// In en, this message translates to:
  /// **'Route name'**
  String get databasePresenceRouteName;

  /// No description provided for @databaseVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: v{version}'**
  String databaseVersionAvailable(int version);

  /// No description provided for @databaseNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get databaseNotDownloaded;

  /// No description provided for @databaseLocalVersionNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Local version: not downloaded'**
  String get databaseLocalVersionNotDownloaded;

  /// No description provided for @databaseLocalVersion.
  ///
  /// In en, this message translates to:
  /// **'Local version: {version}'**
  String databaseLocalVersion(int version);

  /// No description provided for @databaseRegionUpdated.
  ///
  /// In en, this message translates to:
  /// **'The {provider} database was updated.'**
  String databaseRegionUpdated(String provider);

  /// No description provided for @databaseRedownload.
  ///
  /// In en, this message translates to:
  /// **'Download again'**
  String get databaseRedownload;

  /// No description provided for @databaseRegionDeleted.
  ///
  /// In en, this message translates to:
  /// **'The {provider} database was deleted.'**
  String databaseRegionDeleted(String provider);

  /// No description provided for @databaseDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the database: {error}'**
  String databaseDeleteFailed(String error);

  /// No description provided for @regionKeelung.
  ///
  /// In en, this message translates to:
  /// **'Keelung City'**
  String get regionKeelung;

  /// No description provided for @regionTaipei.
  ///
  /// In en, this message translates to:
  /// **'Taipei City'**
  String get regionTaipei;

  /// No description provided for @regionNewTaipei.
  ///
  /// In en, this message translates to:
  /// **'New Taipei City'**
  String get regionNewTaipei;

  /// No description provided for @regionIntercity.
  ///
  /// In en, this message translates to:
  /// **'Intercity buses'**
  String get regionIntercity;

  /// No description provided for @regionTaoyuan.
  ///
  /// In en, this message translates to:
  /// **'Taoyuan City'**
  String get regionTaoyuan;

  /// No description provided for @regionHsinchuCity.
  ///
  /// In en, this message translates to:
  /// **'Hsinchu City'**
  String get regionHsinchuCity;

  /// No description provided for @regionHsinchuCounty.
  ///
  /// In en, this message translates to:
  /// **'Hsinchu County'**
  String get regionHsinchuCounty;

  /// No description provided for @regionMiaoli.
  ///
  /// In en, this message translates to:
  /// **'Miaoli County'**
  String get regionMiaoli;

  /// No description provided for @regionTaichung.
  ///
  /// In en, this message translates to:
  /// **'Taichung City'**
  String get regionTaichung;

  /// No description provided for @regionChanghua.
  ///
  /// In en, this message translates to:
  /// **'Changhua County'**
  String get regionChanghua;

  /// No description provided for @regionNantou.
  ///
  /// In en, this message translates to:
  /// **'Nantou County'**
  String get regionNantou;

  /// No description provided for @regionYunlin.
  ///
  /// In en, this message translates to:
  /// **'Yunlin County'**
  String get regionYunlin;

  /// No description provided for @regionChiayiCity.
  ///
  /// In en, this message translates to:
  /// **'Chiayi City'**
  String get regionChiayiCity;

  /// No description provided for @regionChiayiCounty.
  ///
  /// In en, this message translates to:
  /// **'Chiayi County'**
  String get regionChiayiCounty;

  /// No description provided for @regionTainan.
  ///
  /// In en, this message translates to:
  /// **'Tainan City'**
  String get regionTainan;

  /// No description provided for @regionKaohsiung.
  ///
  /// In en, this message translates to:
  /// **'Kaohsiung City'**
  String get regionKaohsiung;

  /// No description provided for @regionPingtung.
  ///
  /// In en, this message translates to:
  /// **'Pingtung County'**
  String get regionPingtung;

  /// No description provided for @regionYilan.
  ///
  /// In en, this message translates to:
  /// **'Yilan County'**
  String get regionYilan;

  /// No description provided for @regionHualien.
  ///
  /// In en, this message translates to:
  /// **'Hualien County'**
  String get regionHualien;

  /// No description provided for @regionTaitung.
  ///
  /// In en, this message translates to:
  /// **'Taitung County'**
  String get regionTaitung;

  /// No description provided for @regionPenghu.
  ///
  /// In en, this message translates to:
  /// **'Penghu County'**
  String get regionPenghu;

  /// No description provided for @regionKinmen.
  ///
  /// In en, this message translates to:
  /// **'Kinmen County'**
  String get regionKinmen;

  /// No description provided for @regionLienchiang.
  ///
  /// In en, this message translates to:
  /// **'Lienchiang County'**
  String get regionLienchiang;

  /// No description provided for @personalizationColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get personalizationColorScheme;

  /// No description provided for @personalizationDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get personalizationDarkMode;

  /// No description provided for @personalizationAmoledTitle.
  ///
  /// In en, this message translates to:
  /// **'Pure black (AMOLED) dark theme'**
  String get personalizationAmoledTitle;

  /// No description provided for @personalizationAmoledDescription.
  ///
  /// In en, this message translates to:
  /// **'Use a pure black background in dark mode to save power and improve contrast.'**
  String get personalizationAmoledDescription;

  /// No description provided for @personalizationHomeGradient.
  ///
  /// In en, this message translates to:
  /// **'Home gradient'**
  String get personalizationHomeGradient;

  /// No description provided for @personalizationHomeGradientDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust the opacity of the gradient on the home screen.'**
  String get personalizationHomeGradientDescription;

  /// No description provided for @personalizationGradientOpacity.
  ///
  /// In en, this message translates to:
  /// **'Gradient opacity'**
  String get personalizationGradientOpacity;

  /// No description provided for @personalizationBackgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Background image'**
  String get personalizationBackgroundImage;

  /// No description provided for @personalizationBackgroundImageDescription.
  ///
  /// In en, this message translates to:
  /// **'Set background images for individual pages. The home background also applies to the Bus, Metro, HSR, TRA, and YouBike home tabs.'**
  String get personalizationBackgroundImageDescription;

  /// No description provided for @personalizationChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get personalizationChooseImage;

  /// No description provided for @personalizationBackgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background opacity'**
  String get personalizationBackgroundOpacity;

  /// No description provided for @personalizationPerPageSettings.
  ///
  /// In en, this message translates to:
  /// **'Per-page settings'**
  String get personalizationPerPageSettings;

  /// No description provided for @personalizationPerPageDescription.
  ///
  /// In en, this message translates to:
  /// **'Set a separate background image for each page.'**
  String get personalizationPerPageDescription;

  /// No description provided for @personalizationOverlayOpacityTitle.
  ///
  /// In en, this message translates to:
  /// **'Overlay opacity'**
  String get personalizationOverlayOpacityTitle;

  /// No description provided for @personalizationOverlay.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get personalizationOverlay;

  /// No description provided for @personalizationColorSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get personalizationColorSystem;

  /// No description provided for @personalizationColorAutomaticBackground.
  ///
  /// In en, this message translates to:
  /// **'Automatic (background image)'**
  String get personalizationColorAutomaticBackground;

  /// No description provided for @personalizationColorSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatic picks colors from the background image. System uses your device\'s dynamic colors.'**
  String get personalizationColorSourceDescription;

  /// No description provided for @personalizationColorAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get personalizationColorAutomatic;

  /// No description provided for @personalizationColorCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get personalizationColorCustom;

  /// No description provided for @personalizationChooseColor.
  ///
  /// In en, this message translates to:
  /// **'Choose a color'**
  String get personalizationChooseColor;

  /// No description provided for @personalizationHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get personalizationHue;

  /// No description provided for @personalizationSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get personalizationSaturation;

  /// No description provided for @personalizationBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get personalizationBrightness;

  /// No description provided for @personalizationPerPageBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page backgrounds'**
  String get personalizationPerPageBackgroundTitle;

  /// No description provided for @personalizationGlobalHomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Also applies to the Bus, Metro, HSR, TRA, and YouBike home tabs.'**
  String get personalizationGlobalHomeDescription;

  /// No description provided for @personalizationPageGlobalHome.
  ///
  /// In en, this message translates to:
  /// **'All home tabs'**
  String get personalizationPageGlobalHome;

  /// No description provided for @personalizationPageSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get personalizationPageSearch;

  /// No description provided for @personalizationPageNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get personalizationPageNearby;

  /// No description provided for @personalizationPreviewAmoled.
  ///
  /// In en, this message translates to:
  /// **'AMOLED black'**
  String get personalizationPreviewAmoled;

  /// No description provided for @personalizationAppearancePreview.
  ///
  /// In en, this message translates to:
  /// **'Appearance preview'**
  String get personalizationAppearancePreview;

  /// No description provided for @personalizationPreviewSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Quickly check live arrival information'**
  String get personalizationPreviewSearchDescription;

  /// No description provided for @personalizationPreviewFavoritesDescription.
  ///
  /// In en, this message translates to:
  /// **'Regular stops and groups'**
  String get personalizationPreviewFavoritesDescription;

  /// No description provided for @personalizationReplaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get personalizationReplaceImage;

  /// No description provided for @personalizationRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get personalizationRemoveImage;

  /// No description provided for @announcementDismissForever.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get announcementDismissForever;

  /// No description provided for @announcementViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View announcement'**
  String get announcementViewDetails;

  /// No description provided for @databaseUpdatesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Database updates available'**
  String get databaseUpdatesDialogTitle;

  /// No description provided for @databaseUpdatesDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Updates are available for these regions:'**
  String get databaseUpdatesDialogDescription;

  /// No description provided for @databaseVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String databaseVersion(int version);

  /// No description provided for @databaseUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get databaseUpdateNow;

  /// No description provided for @accountProviderDiscord.
  ///
  /// In en, this message translates to:
  /// **'Discord'**
  String get accountProviderDiscord;

  /// No description provided for @accountProviderGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get accountProviderGoogle;

  /// No description provided for @accountProviderOAuth.
  ///
  /// In en, this message translates to:
  /// **'OAuth'**
  String get accountProviderOAuth;

  /// No description provided for @personalizationPreviewAppName.
  ///
  /// In en, this message translates to:
  /// **'YABus'**
  String get personalizationPreviewAppName;

  /// No description provided for @personalizationGifBadge.
  ///
  /// In en, this message translates to:
  /// **'GIF'**
  String get personalizationGifBadge;

  /// No description provided for @announcementReactionCount.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {count}'**
  String announcementReactionCount(String emoji, int count);

  /// No description provided for @weatherTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weatherTitle;

  /// No description provided for @temperatureCelsius.
  ///
  /// In en, this message translates to:
  /// **'{temperature}°C'**
  String temperatureCelsius(int temperature);

  /// No description provided for @temperatureDegrees.
  ///
  /// In en, this message translates to:
  /// **'{temperature}°'**
  String temperatureDegrees(int temperature);

  /// No description provided for @weatherHourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get weatherHourly;

  /// No description provided for @weatherWeekly.
  ///
  /// In en, this message translates to:
  /// **'7-day forecast'**
  String get weatherWeekly;

  /// No description provided for @weatherHighLow.
  ///
  /// In en, this message translates to:
  /// **'High {high}° · Low {low}°'**
  String weatherHighLow(int high, int low);

  /// No description provided for @weatherFeelsLike.
  ///
  /// In en, this message translates to:
  /// **'Feels like'**
  String get weatherFeelsLike;

  /// No description provided for @weatherHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get weatherHumidity;

  /// No description provided for @weatherWindSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get weatherWindSpeed;

  /// No description provided for @weatherPrecipitation.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherPrecipitation;

  /// No description provided for @weatherNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get weatherNow;

  /// No description provided for @weatherHour.
  ///
  /// In en, this message translates to:
  /// **'{hour}:00'**
  String weatherHour(int hour);

  /// No description provided for @weatherSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get weatherSunrise;

  /// No description provided for @weatherSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get weatherSunset;

  /// No description provided for @weatherSourceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Source: Central Weather Administration · Updated {time}'**
  String weatherSourceUpdated(String time);

  /// No description provided for @weatherLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your location is unavailable, so the weather cannot be shown. Check that location services and permission are enabled.'**
  String get weatherLocationUnavailable;

  /// No description provided for @weatherLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load weather data. Please try again later.'**
  String get weatherLoadFailed;

  /// No description provided for @weatherToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get weatherToday;

  /// No description provided for @weatherTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get weatherTomorrow;

  /// No description provided for @weatherWeekday.
  ///
  /// In en, this message translates to:
  /// **'{weekday}'**
  String weatherWeekday(String weekday);

  /// No description provided for @weatherCurrentSemantics.
  ///
  /// In en, this message translates to:
  /// **'Current weather: {condition}, {temperature} degrees'**
  String weatherCurrentSemantics(String condition, int temperature);

  /// No description provided for @weatherViewTooltip.
  ///
  /// In en, this message translates to:
  /// **'{condition} · View weather'**
  String weatherViewTooltip(String condition);

  /// No description provided for @youBikeLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your location is unavailable right now. Please try again later.'**
  String get youBikeLocationUnavailable;

  /// No description provided for @youBikeUsingDefaultArea.
  ///
  /// In en, this message translates to:
  /// **'{message} Showing the default area instead.'**
  String youBikeUsingDefaultArea(String message);

  /// No description provided for @youBikeNearbyStations.
  ///
  /// In en, this message translates to:
  /// **'Nearby stations'**
  String get youBikeNearbyStations;

  /// No description provided for @youBikeStationCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 station} other {{count} stations}}'**
  String youBikeStationCount(int count);

  /// No description provided for @youBikeNoNearbyStations.
  ///
  /// In en, this message translates to:
  /// **'No stations were found nearby.'**
  String get youBikeNoNearbyStations;

  /// No description provided for @youBikeGeneralBike.
  ///
  /// In en, this message translates to:
  /// **'Standard bikes'**
  String get youBikeGeneralBike;

  /// No description provided for @youBikeElectricBike.
  ///
  /// In en, this message translates to:
  /// **'2.0E e-bikes'**
  String get youBikeElectricBike;

  /// No description provided for @youBikeReturnSlots.
  ///
  /// In en, this message translates to:
  /// **'Open docks'**
  String get youBikeReturnSlots;

  /// No description provided for @youBikeDistance.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String youBikeDistance(String distance);

  /// No description provided for @youBikeStationInfo.
  ///
  /// In en, this message translates to:
  /// **'Station details'**
  String get youBikeStationInfo;

  /// No description provided for @youBikeSelectStationHint.
  ///
  /// In en, this message translates to:
  /// **'Select a station in the list or a marker on the map to see available bikes, return spaces, and distance.'**
  String get youBikeSelectStationHint;

  /// No description provided for @youBikeLocationAcquired.
  ///
  /// In en, this message translates to:
  /// **'Current location found'**
  String get youBikeLocationAcquired;

  /// No description provided for @youBikeRelocate.
  ///
  /// In en, this message translates to:
  /// **'Find my location again'**
  String get youBikeRelocate;

  /// No description provided for @youBikeBackToLocation.
  ///
  /// In en, this message translates to:
  /// **'Back to my location'**
  String get youBikeBackToLocation;

  /// No description provided for @youBikeAvailability.
  ///
  /// In en, this message translates to:
  /// **'Standard {general} · 2.0E {electric} · Docks {returns}'**
  String youBikeAvailability(int general, int electric, int returns);

  /// No description provided for @metroSystem.
  ///
  /// In en, this message translates to:
  /// **'Metro system'**
  String get metroSystem;

  /// No description provided for @metroNoLineSelected.
  ///
  /// In en, this message translates to:
  /// **'No line selected'**
  String get metroNoLineSelected;

  /// No description provided for @metroUpdateEta.
  ///
  /// In en, this message translates to:
  /// **'Update ETA'**
  String get metroUpdateEta;

  /// No description provided for @metroNoLines.
  ///
  /// In en, this message translates to:
  /// **'No lines are currently available for this metro system.'**
  String get metroNoLines;

  /// No description provided for @metroTimetableEstimate.
  ///
  /// In en, this message translates to:
  /// **'Arrival times are currently estimated from the timetable.'**
  String get metroTimetableEstimate;

  /// No description provided for @metroFrequencyOnly.
  ///
  /// In en, this message translates to:
  /// **'Only service frequency is currently available.'**
  String get metroFrequencyOnly;

  /// No description provided for @metroFrequencyEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated from service frequency: about {min}-{max} minutes.'**
  String metroFrequencyEstimate(int min, int max);

  /// No description provided for @metroEtaUnknown.
  ///
  /// In en, this message translates to:
  /// **'The ETA source is not identified.'**
  String get metroEtaUnknown;

  /// No description provided for @metroLiveArrivals.
  ///
  /// In en, this message translates to:
  /// **'Live arrivals'**
  String get metroLiveArrivals;

  /// No description provided for @metroStationMap.
  ///
  /// In en, this message translates to:
  /// **'Station map'**
  String get metroStationMap;

  /// No description provided for @metroChooseLine.
  ///
  /// In en, this message translates to:
  /// **'Select a metro line first.'**
  String get metroChooseLine;

  /// No description provided for @metroNoStationSequence.
  ///
  /// In en, this message translates to:
  /// **'No station sequence is currently available for this line.'**
  String get metroNoStationSequence;

  /// No description provided for @metroRouteMap.
  ///
  /// In en, this message translates to:
  /// **'Line map'**
  String get metroRouteMap;

  /// No description provided for @metroViewEta.
  ///
  /// In en, this message translates to:
  /// **'View ETA'**
  String get metroViewEta;

  /// No description provided for @metroNoCoordinates.
  ///
  /// In en, this message translates to:
  /// **'No station coordinates are currently available for this metro line.'**
  String get metroNoCoordinates;

  /// No description provided for @metroTravelDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction of travel'**
  String get metroTravelDirection;

  /// No description provided for @metroDirectionHeading.
  ///
  /// In en, this message translates to:
  /// **'Toward {destination}'**
  String metroDirectionHeading(String destination);

  /// No description provided for @metroHeadway.
  ///
  /// In en, this message translates to:
  /// **'Every {min}-{max} min'**
  String metroHeadway(int min, int max);

  /// No description provided for @metroNoLiveArrivals.
  ///
  /// In en, this message translates to:
  /// **'No live arrivals are available for this station right now.'**
  String get metroNoLiveArrivals;

  /// No description provided for @metroFrequencyOnlyEstimate.
  ///
  /// In en, this message translates to:
  /// **'Only a frequency estimate is available: about {min}-{max} minutes.'**
  String metroFrequencyOnlyEstimate(int min, int max);

  /// No description provided for @metroDestination.
  ///
  /// In en, this message translates to:
  /// **'Toward {destination}'**
  String metroDestination(String destination);

  /// No description provided for @railOperatingNotices.
  ///
  /// In en, this message translates to:
  /// **'Service notices'**
  String get railOperatingNotices;

  /// No description provided for @railAllStations.
  ///
  /// In en, this message translates to:
  /// **'All stations'**
  String get railAllStations;

  /// No description provided for @railOtherStations.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get railOtherStations;

  /// No description provided for @railShowDeparted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {Show 1 departed train} other {Show {count} departed trains}}'**
  String railShowDeparted(int count);

  /// No description provided for @railHideDeparted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {Hide 1 departed train} other {Hide {count} departed trains}}'**
  String railHideDeparted(int count);

  /// No description provided for @railPickerNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching station found'**
  String get railPickerNoMatches;

  /// No description provided for @railPickerNoNearby.
  ///
  /// In en, this message translates to:
  /// **'No nearby station found.'**
  String get railPickerNoNearby;

  /// No description provided for @railPickerNearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest station: {station} (about {distance})'**
  String railPickerNearest(String station, String distance);

  /// No description provided for @railLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your location is unavailable right now. Please try again later.'**
  String get railLocationUnavailable;

  /// No description provided for @railPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by station name or code'**
  String get railPickerSearchHint;

  /// No description provided for @railUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get railUseCurrentLocation;

  /// No description provided for @railChooseStation.
  ///
  /// In en, this message translates to:
  /// **'Choose station'**
  String get railChooseStation;

  /// No description provided for @railChooseNamedStation.
  ///
  /// In en, this message translates to:
  /// **'Choose {station}'**
  String railChooseNamedStation(String station);

  /// No description provided for @railSameStationExcluded.
  ///
  /// In en, this message translates to:
  /// **'This station is already selected at the other end'**
  String get railSameStationExcluded;

  /// No description provided for @railOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get railOrigin;

  /// No description provided for @railDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get railDestination;

  /// No description provided for @railChooseOrigin.
  ///
  /// In en, this message translates to:
  /// **'Choose origin'**
  String get railChooseOrigin;

  /// No description provided for @railChooseDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose destination'**
  String get railChooseDestination;

  /// No description provided for @railSwapStations.
  ///
  /// In en, this message translates to:
  /// **'Swap origin and destination'**
  String get railSwapStations;

  /// No description provided for @railDeparted.
  ///
  /// In en, this message translates to:
  /// **'Departed'**
  String get railDeparted;

  /// No description provided for @railDelayedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1 {1 min late} other {{minutes} min late}}'**
  String railDelayedMinutes(int minutes);

  /// No description provided for @railOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get railOnTime;

  /// No description provided for @railDepartsAt.
  ///
  /// In en, this message translates to:
  /// **'Departs {time}'**
  String railDepartsAt(String time);

  /// No description provided for @railMinutesUntilDeparture.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1 {In 1 min} other {In {minutes} min}}'**
  String railMinutesUntilDeparture(int minutes);

  /// No description provided for @railDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1 {1 hr} other {{hours} hrs}} {minutes, plural, =1 {1 min} other {{minutes} min}}'**
  String railDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @railDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1 {1 min} other {{minutes} min}}'**
  String railDurationMinutes(int minutes);

  /// No description provided for @railTrainSemantics.
  ///
  /// In en, this message translates to:
  /// **'Train {trainNo}, {trainType}, {headline}'**
  String railTrainSemantics(String trainNo, String trainType, String headline);

  /// No description provided for @railTrainSemanticsWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Train {trainNo}, {trainType}, {headline}, {status}'**
  String railTrainSemanticsWithStatus(
    String trainNo,
    String trainType,
    String headline,
    String status,
  );

  /// No description provided for @railRouteWithTimes.
  ///
  /// In en, this message translates to:
  /// **'{origin} {departure} → {destination} {arrival}'**
  String railRouteWithTimes(
    String origin,
    String departure,
    String destination,
    String arrival,
  );

  /// No description provided for @railStationRange.
  ///
  /// In en, this message translates to:
  /// **'{origin} → {destination}'**
  String railStationRange(String origin, String destination);

  /// No description provided for @railTimeRange.
  ///
  /// In en, this message translates to:
  /// **'{departure} → {arrival}'**
  String railTimeRange(String departure, String arrival);

  /// No description provided for @traServices.
  ///
  /// In en, this message translates to:
  /// **'Trains'**
  String get traServices;

  /// No description provided for @traStationMap.
  ///
  /// In en, this message translates to:
  /// **'Station map'**
  String get traStationMap;

  /// No description provided for @traSelectDifferentStations.
  ///
  /// In en, this message translates to:
  /// **'Origin and destination must be different.'**
  String get traSelectDifferentStations;

  /// No description provided for @traUseLocationOrigin.
  ///
  /// In en, this message translates to:
  /// **'Use my location for the origin'**
  String get traUseLocationOrigin;

  /// No description provided for @traSelectionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose an origin and destination to see trains you can still catch today.'**
  String get traSelectionPrompt;

  /// No description provided for @traSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get traSearching;

  /// No description provided for @traNoDirectServices.
  ///
  /// In en, this message translates to:
  /// **'There are no direct trains between these stations today. A transfer may be required.'**
  String get traNoDirectServices;

  /// No description provided for @traRemainingServices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 train left} other {{count} trains left}}'**
  String traRemainingServices(int count);

  /// No description provided for @traAllServicesDeparted.
  ///
  /// In en, this message translates to:
  /// **'All trains from {origin} to {destination} have departed today.'**
  String traAllServicesDeparted(String origin, String destination);

  /// No description provided for @traViewTomorrow.
  ///
  /// In en, this message translates to:
  /// **'View tomorrow\'s trains'**
  String get traViewTomorrow;

  /// No description provided for @traViewServices.
  ///
  /// In en, this message translates to:
  /// **'View trains'**
  String get traViewServices;

  /// No description provided for @traMapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a station to set it as the origin or destination. Tap a red train marker to view its estimated position.'**
  String get traMapHint;

  /// No description provided for @traMapNoCoordinates.
  ///
  /// In en, this message translates to:
  /// **'No TRA station coordinates are currently available.'**
  String get traMapNoCoordinates;

  /// No description provided for @traSetOrigin.
  ///
  /// In en, this message translates to:
  /// **'Set as origin'**
  String get traSetOrigin;

  /// No description provided for @traSetDestination.
  ///
  /// In en, this message translates to:
  /// **'Set as destination'**
  String get traSetDestination;

  /// No description provided for @traPositionArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived at {station}'**
  String traPositionArrived(String station);

  /// No description provided for @traPositionStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped at {station}'**
  String traPositionStopped(String station);

  /// No description provided for @traTrainPositionEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated train position'**
  String get traTrainPositionEstimate;

  /// No description provided for @traEstimatedBetween.
  ///
  /// In en, this message translates to:
  /// **'Estimated between {current} and {next}'**
  String traEstimatedBetween(String current, String next);

  /// No description provided for @traEstimatedArrived.
  ///
  /// In en, this message translates to:
  /// **'Estimated to have arrived at {station}'**
  String traEstimatedArrived(String station);

  /// No description provided for @traEstimatedStopped.
  ///
  /// In en, this message translates to:
  /// **'Estimated to be stopped at {station}'**
  String traEstimatedStopped(String station);

  /// No description provided for @traSegmentProgress.
  ///
  /// In en, this message translates to:
  /// **'Segment progress: {percent}%'**
  String traSegmentProgress(int percent);

  /// No description provided for @traDataUpdated.
  ///
  /// In en, this message translates to:
  /// **'Data updated {time}'**
  String traDataUpdated(String time);

  /// No description provided for @thsrSeatOverview.
  ///
  /// In en, this message translates to:
  /// **'Live seat overview'**
  String get thsrSeatOverview;

  /// No description provided for @thsrObservedStation.
  ///
  /// In en, this message translates to:
  /// **'Station to watch'**
  String get thsrObservedStation;

  /// No description provided for @thsrChooseStation.
  ///
  /// In en, this message translates to:
  /// **'Choose station'**
  String get thsrChooseStation;

  /// No description provided for @thsrSelectStationForSeats.
  ///
  /// In en, this message translates to:
  /// **'Choose a station to view seat availability for upcoming HSR trains.'**
  String get thsrSelectStationForSeats;

  /// No description provided for @thsrNoStationSeats.
  ///
  /// In en, this message translates to:
  /// **'No live seat information is available for {station} right now.'**
  String thsrNoStationSeats(String station);

  /// No description provided for @thsrSearchServices.
  ///
  /// In en, this message translates to:
  /// **'Search trains'**
  String get thsrSearchServices;

  /// No description provided for @thsrNotSearched.
  ///
  /// In en, this message translates to:
  /// **'No train search yet'**
  String get thsrNotSearched;

  /// No description provided for @thsrServicesSummary.
  ///
  /// In en, this message translates to:
  /// **'{upcoming, plural, =1 {1 train left} other {{upcoming} trains left}} ({total, plural, =1 {1 total} other {{total} total}})'**
  String thsrServicesSummary(int upcoming, int total);

  /// No description provided for @thsrQueryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose origin, destination, and date to view HSR trains.'**
  String get thsrQueryPrompt;

  /// No description provided for @thsrDayDeparted.
  ///
  /// In en, this message translates to:
  /// **'All trains for this day have departed.'**
  String get thsrDayDeparted;

  /// No description provided for @thsrSeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Non-reserved and business class seats'**
  String get thsrSeatTitle;

  /// No description provided for @thsrQueryStation.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get thsrQueryStation;

  /// No description provided for @thsrSelectStationSeats.
  ///
  /// In en, this message translates to:
  /// **'Choose a station to view seat availability by train.'**
  String get thsrSelectStationSeats;

  /// No description provided for @thsrNoSeatData.
  ///
  /// In en, this message translates to:
  /// **'No seat information is currently available.'**
  String get thsrNoSeatData;

  /// No description provided for @thsrMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Station map'**
  String get thsrMapTitle;

  /// No description provided for @thsrViewSeats.
  ///
  /// In en, this message translates to:
  /// **'View seats'**
  String get thsrViewSeats;

  /// No description provided for @thsrMapNoCoordinates.
  ///
  /// In en, this message translates to:
  /// **'No HSR station coordinates are currently available.'**
  String get thsrMapNoCoordinates;

  /// No description provided for @thsrTimetable.
  ///
  /// In en, this message translates to:
  /// **'Train search'**
  String get thsrTimetable;

  /// No description provided for @thsrSeats.
  ///
  /// In en, this message translates to:
  /// **'Seat information'**
  String get thsrSeats;

  /// No description provided for @thsrTrainLabel.
  ///
  /// In en, this message translates to:
  /// **'HSR'**
  String get thsrTrainLabel;

  /// No description provided for @thsrNoSeatField.
  ///
  /// In en, this message translates to:
  /// **'This train has no seat information for {station}.'**
  String thsrNoSeatField(String station);

  /// No description provided for @thsrStandardCar.
  ///
  /// In en, this message translates to:
  /// **'Standard class'**
  String get thsrStandardCar;

  /// No description provided for @thsrBusinessCar.
  ///
  /// In en, this message translates to:
  /// **'Business class'**
  String get thsrBusinessCar;

  /// No description provided for @thsrNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get thsrNotProvided;

  /// No description provided for @thsrStationNoSeats.
  ///
  /// In en, this message translates to:
  /// **'No seat information is available for this station right now.'**
  String get thsrStationNoSeats;

  /// No description provided for @thsrDepartureTime.
  ///
  /// In en, this message translates to:
  /// **'Departs {time}'**
  String thsrDepartureTime(String time);
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
