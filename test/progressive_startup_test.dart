import 'dart:async';

import 'package:dynamic_color/test_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/account_sync_service.dart';
import 'package:taiwanbus_flutter/core/announcement_service.dart';
import 'package:taiwanbus_flutter/core/app_analytics.dart';
import 'package:taiwanbus_flutter/core/app_build_info.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/app_launch_service.dart';
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/auth_token_store.dart';
import 'package:taiwanbus_flutter/core/background_image_store.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/widgets/local_data_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeChannel = MethodChannel(
    'tw.avianjay.taiwanbus.flutter/home_integration',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DynamicColorTestingUtils.setMockDynamicColors();
    // Flutter tests default to Android on both Windows and Linux CI. These
    // controller operations publish native widget/notification updates.
    messenger.setMockMethodCallHandler(homeChannel, (_) async => null);
  });
  tearDown(() => messenger.setMockMethodCallHandler(homeChannel, null));

  test(
    'bootstrap reads appearance only, with no auth, history or file work',
    () async {
      final storage = _ControlledStorage();
      final images = _ControlledImages();
      final auth = _ControlledAuth();
      final controller = _controller(storage, images: images, auth: auth);
      addTearDown(controller.dispose);
      await controller.initializeForFirstFrame();
      expect(controller.initialized, isTrue);
      expect(controller.settings.language, const Locale('en'));
      expect(controller.settings.themeMode, ThemeMode.dark);
      expect(storage.favoriteLoads, 0);
      expect(storage.routeLoads, 0);
      expect(storage.smartLoads, 0);
      expect(auth.initializations, 0);
      expect(images.normalizations, 0);
      expect(controller.favoritesReady, isFalse);
      expect(controller.routeHistoryReady, isFalse);
      expect(controller.accountReady, isFalse);
    },
  );

  testWidgets('home preserves appearance while user data is blocked', (
    tester,
  ) async {
    final storage = _ControlledStorage()
      ..favoriteGate = Completer<Map<String, List<FavoriteItem>>>();
    final controller = _controller(storage);
    await controller.initializeForFirstFrame();
    await tester.pumpWidget(
      BusApp(controller: controller, analytics: controller.analytics),
    );
    await tester.pump();
    expect(find.text('Search routes'), findsWidgets);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('en'),
    );
    expect(
      Theme.of(tester.element(find.byType(Navigator).first)).brightness,
      Brightness.dark,
    );
    expect(controller.favoritesReady, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    storage.favoriteGate!.complete(storage.groups);
    await tester.pump();
  });

  test(
    'early favorite mutation joins one loader and preserves existing groups',
    () async {
      final storage = _ControlledStorage()
        ..favoriteGate = Completer<Map<String, List<FavoriteItem>>>();
      final controller = _controller(storage);
      addTearDown(controller.dispose);
      await controller.initializeForFirstFrame();
      final first = controller.ensureFavoritesReady();
      expect(identical(first, controller.ensureFavoritesReady()), isTrue);
      final edit = controller.addFavoriteGroup(
        'New',
        kind: FavoriteGroupKind.route,
      );
      await Future<void>.value();
      expect(storage.favoriteSaves, 0);
      storage.favoriteGate!.complete(storage.groups);
      await edit;
      expect(storage.favoriteLoads, 1);
      expect(controller.favoriteGroupNames, ['Old', 'New']);
      expect(controller.favoriteGroupKind('Old'), FavoriteGroupKind.mixed);
      expect(controller.favoriteGroupKind('New'), FavoriteGroupKind.route);
      expect(controller.favoritesInGroup('Old'), hasLength(1));
    },
  );

  testWidgets('collection screens show loading, then authoritative contents', (
    tester,
  ) async {
    final storage = _ControlledStorage()
      ..favoriteGate = Completer<Map<String, List<FavoriteItem>>>();
    final controller = _controller(storage);
    await controller.initializeForFirstFrame();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppControllerScope(
          controller: controller,
          child: const LocalDataGate(
            domain: AppLocalData.favorites,
            title: 'Favorites',
            child: Text('Authoritative contents'),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Authoritative contents'), findsNothing);
    storage.favoriteGate!.complete(storage.groups);
    await tester.pump();
    await tester.pump();
    expect(find.text('Authoritative contents'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  test(
    'route visits never load or overwrite unrelated stop/favorite usage',
    () async {
      final storage = _ControlledStorage();
      final controller = _controller(storage);
      addTearDown(controller.dispose);
      await controller.initializeForFirstFrame();
      final revision = controller.rootRevision.value;
      await controller.recordRouteVisit(_route, provider: BusProvider.tpe);
      expect(controller.routeUsageProfiles.single.totalOpens, 5);
      expect(storage.smartLoads, 0);
      expect(storage.favoriteUsageSaves, 0);
      expect(storage.stopVisitSaves, 0);
      expect(controller.rootRevision.value, revision);
      await controller.ensureLocalData(AppLocalData.smartUsage);
      expect(storage.stopVisits.single.selectionTimestampsMs, [1, 2]);
    },
  );

  test(
    'clear during hydration waits and cannot resurrect old history',
    () async {
      final storage = _ControlledStorage()
        ..routeGate = Completer<List<RouteUsageProfile>>();
      final controller = _controller(storage);
      addTearDown(controller.dispose);
      await controller.initializeForFirstFrame();
      final clearing = controller.clearHistory();
      await storage.routeStarted.future;
      expect(storage.historySaves, 0);
      storage.routeGate!.complete(storage.routes);
      await clearing;
      await controller.ensureRouteHistoryReady();
      expect(controller.history, isEmpty);
      expect(storage.savedHistory, isEmpty);
    },
  );

  test('failed hydration forbids writes and can retry safely', () async {
    final storage = _ControlledStorage()..failFavorites = true;
    final controller = _controller(storage);
    addTearDown(controller.dispose);
    await expectLater(controller.addFavoriteGroup('New'), throwsStateError);
    expect(controller.favoritesReady, isFalse);
    expect(storage.favoriteSaves, 0);
    expect(
      controller.localDataError(AppLocalData.favorites),
      isA<StateError>(),
    );
    storage.failFavorites = false;
    await controller.addFavoriteGroup('New');
    expect(controller.favoriteGroupNames, ['Old', 'New']);
    expect(storage.favoriteLoads, 2);
  });

  test(
    'a late hydration result does not notify a disposed controller',
    () async {
      final storage = _ControlledStorage()
        ..routeGate = Completer<List<RouteUsageProfile>>();
      final controller = _controller(storage);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final load = controller.ensureRouteHistoryReady();
      await storage.routeStarted.future;
      controller.dispose();
      final previous = notifications;
      final expectation = expectLater(load, throwsStateError);
      storage.routeGate!.complete(storage.routes);
      await expectation;
      expect(notifications, previous);
    },
  );

  test(
    'an old account validation cannot log out a new callback session',
    () async {
      final auth = _ControlledAuth()..current = _session('old');
      final controller = _controller(_ControlledStorage(), auth: auth);
      addTearDown(controller.dispose);
      await controller.ensureAccountReady();
      final validation = controller.refreshAuthAccount();
      await auth.validationStarted.future;
      await controller.completeAuthCallback(
        const AppLaunchAction(
          target: AppLaunchTarget.authCallback,
          authToken: 'new',
          authAccountId: 'new',
          authDeviceId: 'device',
        ),
      );
      auth.oldValidation.completeError(const AuthTokenExpiredException());
      await validation;
      expect(controller.authSession!.accountId, 'new');
      expect(auth.logouts, 0);
    },
  );

  test(
    'normalization preserves concurrent appearance changes and timestamps',
    () async {
      final storage = _ControlledStorage();
      await storage.saveSettings(
        storage.initialSettings.copyWith(
          pageBackgroundImagePaths: {'bus': 'old.png'},
          pageBackgroundImageOpacities: {'bus': 0.4},
        ),
        modifiedAtMs: 10,
      );
      storage.usePersistedSettings = true;
      final images = _ControlledImages()
        ..normalizeGate = Completer<Map<String, String>>();
      final controller = _controller(storage, images: images);
      addTearDown(controller.dispose);
      await controller.initializeForFirstFrame();
      final startup = controller.initializeAfterFirstFrame();
      await images.normalizationStarted.future;
      await controller.updateThemeMode(ThemeMode.light);
      await controller.updatePageBackgroundImageOpacity('bus', 0.7);
      final modifiedAt = await storage.loadSettingsLastModifiedAtMs();
      images.normalizeGate!.complete({'bus': 'managed.png'});
      await images.cleanupStarted.future;
      await startup;
      final settings = await storage.loadSettings();
      expect(settings.themeMode, ThemeMode.light);
      expect(settings.pageBackgroundImageOpacities, {'bus': 0.7});
      expect(settings.pageBackgroundImagePaths, {'bus': 'managed.png'});
      expect(await storage.loadSettingsLastModifiedAtMs(), modifiedAt);
    },
  );

  test(
    'palette cache is path-specific and does not change settings metadata',
    () async {
      final storage = StorageService();
      await storage.saveSettings(AppSettings.defaults(), modifiedAtMs: 10);
      await storage.saveBackgroundColorCache('a.png', 0xff123456);
      expect(await storage.loadBackgroundColorCache('a.png'), 0xff123456);
      expect(await storage.loadBackgroundColorCache('b.png'), isNull);
      expect(await storage.loadSettingsLastModifiedAtMs(), 10);
    },
  );
}

const _route = RouteSummary(
  sourceProvider: 'tpe',
  hashMd5: '',
  routeKey: 1,
  routeId: 'TPE-1',
  routeName: '1',
  officialRouteName: '1',
  description: '',
  category: '',
  sequence: 0,
  rtrip: 0,
);

AppController _controller(
  _ControlledStorage storage, {
  _ControlledImages? images,
  _ControlledAuth? auth,
}) {
  const build = AppBuildInfo(
    version: '1',
    buildNumber: '1',
    gitSha: 'test',
    defaultUpdateChannel: AppUpdateChannel.release,
  );
  final client = MockClient((_) async => http.Response('[]', 200));
  return AppController(
    repository: _NoDatabaseRepository(),
    storage: storage,
    analytics: AppAnalytics.deferred(),
    buildInfo: build,
    appUpdateService: AppUpdateService(buildInfo: build, client: client),
    appUpdateInstaller: createAppUpdateInstaller(),
    authService: auth ?? _ControlledAuth(),
    accountSyncService: AccountSyncService(client: client),
    announcementService: AnnouncementService(client: client),
    backgroundImageStore: images ?? _ControlledImages(),
  );
}

class _NoDatabaseRepository extends BusRepository {
  @override
  Future<bool> databaseExists(BusProvider provider) async => false;
}

class _ControlledStorage extends StorageService {
  final initialSettings = AppSettings.defaults().copyWith(
    themeMode: ThemeMode.dark,
    language: const Locale('en'),
    hasCompletedOnboarding: true,
    desktopDiscordPresenceEnabled: false,
    enableSmartRecommendations: false,
    enableAds: false,
    appUpdateCheckMode: AppUpdateCheckMode.off,
  );
  bool usePersistedSettings = false;
  bool failFavorites = false;
  Completer<Map<String, List<FavoriteItem>>>? favoriteGate;
  Completer<List<RouteUsageProfile>>? routeGate;
  final routeStarted = Completer<void>();
  var favoriteLoads = 0;
  var routeLoads = 0;
  var smartLoads = 0;
  var favoriteSaves = 0;
  var favoriteUsageSaves = 0;
  var stopVisitSaves = 0;
  var historySaves = 0;
  List<SearchHistoryEntry>? savedHistory;
  final groups = <String, List<FavoriteItem>>{
    'Old': [
      const FavoriteStop(
        provider: BusProvider.tpe,
        routeKey: 1,
        pathId: 0,
        stopId: 1,
      ),
    ],
  };
  final routes = [
    RouteUsageProfile(
      provider: BusProvider.tpe,
      routeKey: 1,
      routeName: '1',
      totalOpens: 4,
      lastOpenedAtMs: 1,
      hourlyOpens: {0: 4},
    ),
  ];
  final stopVisits = [
    FavoriteUsageProfile(
      provider: BusProvider.tpe,
      routeKey: 1,
      pathId: 0,
      stopId: 1,
      selectionTimestampsMs: [1, 2],
    ),
  ];

  @override
  Future<AppSettings> loadSettings() async =>
      usePersistedSettings ? super.loadSettings() : initialSettings;
  @override
  Future<Map<String, List<FavoriteItem>>> loadFavoriteGroups() async {
    favoriteLoads++;
    if (failFavorites) throw StateError('temporarily unreadable');
    return favoriteGate == null ? Map.of(groups) : favoriteGate!.future;
  }

  @override
  Future<Map<String, FavoriteGroupKind>> loadFavoriteGroupKinds(
    Iterable<String> names,
  ) async => {for (final name in names) name: FavoriteGroupKind.mixed};
  @override
  Future<List<SearchHistoryEntry>> loadHistory() async => [
    const SearchHistoryEntry(
      provider: BusProvider.tpe,
      routeKey: 1,
      routeName: 'Old',
      timestampMs: 1,
    ),
  ];
  @override
  Future<List<RouteUsageProfile>> loadRouteUsageProfiles() async {
    routeLoads++;
    if (!routeStarted.isCompleted) routeStarted.complete();
    return routeGate == null ? List.of(routes) : routeGate!.future;
  }

  @override
  Future<List<FavoriteUsageProfile>> loadFavoriteUsageProfiles() async {
    smartLoads++;
    return List.of(stopVisits);
  }

  @override
  Future<List<FavoriteUsageProfile>> loadStopVisitProfiles() async =>
      List.of(stopVisits);
  @override
  Future<void> saveFavoriteGroups(
    Map<String, List<FavoriteItem>> value, {
    int? modifiedAtMs,
  }) async {
    favoriteSaves++;
    await super.saveFavoriteGroups(value, modifiedAtMs: modifiedAtMs);
  }

  @override
  Future<void> saveFavoriteUsageProfiles(
    List<FavoriteUsageProfile> value,
  ) async {
    favoriteUsageSaves++;
    await super.saveFavoriteUsageProfiles(value);
  }

  @override
  Future<void> saveStopVisitProfiles(List<FavoriteUsageProfile> value) async {
    stopVisitSaves++;
    await super.saveStopVisitProfiles(value);
  }

  @override
  Future<void> saveHistory(List<SearchHistoryEntry> value) async {
    historySaves++;
    savedHistory = List.of(value);
    await super.saveHistory(value);
  }
}

class _ControlledImages extends BackgroundImageStore {
  var normalizations = 0;
  Completer<Map<String, String>>? normalizeGate;
  final normalizationStarted = Completer<void>();
  final cleanupStarted = Completer<void>();
  @override
  Future<Map<String, String>> normalizeSettingsPaths(
    Map<String, String> paths, {
    bool cleanup = true,
  }) async {
    normalizations++;
    if (!normalizationStarted.isCompleted) normalizationStarted.complete();
    return normalizeGate == null ? Map.of(paths) : normalizeGate!.future;
  }

  @override
  Future<void> cleanupUnusedImages(Iterable<String> references) async {
    if (!cleanupStarted.isCompleted) cleanupStarted.complete();
  }
}

AuthSession _session(String id) => AuthSession(
  token: id,
  accountId: id,
  deviceId: 'device',
  role: 'user',
  provider: 'test',
  displayName: id,
);

class _ControlledAuth extends AuthService {
  var initializations = 0;
  var logouts = 0;
  AuthSession? current;
  final validationStarted = Completer<void>();
  final oldValidation = Completer<AuthAccount>();
  @override
  AuthSession? get session => current;
  @override
  Future<void> initialize() async {
    initializations++;
  }

  @override
  Future<AuthAccount> fetchAccount() async {
    if (current!.accountId == 'old') {
      if (!validationStarted.isCompleted) validationStarted.complete();
      return oldValidation.future;
    }
    return AuthAccount(
      accountId: current!.accountId,
      deviceId: 'device',
      role: 'user',
      device: null,
      identities: const [],
    );
  }

  @override
  Future<void> completeCallback({
    required String token,
    required String accountId,
    required String deviceId,
    required String role,
    required String provider,
    required String displayName,
  }) async {
    current = _session(accountId);
  }

  @override
  Future<void> logout() async {
    logouts++;
    current = null;
  }
}
