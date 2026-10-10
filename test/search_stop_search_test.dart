import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/account_sync_service.dart';
import 'package:taiwanbus_flutter/core/app_analytics.dart';
import 'package:taiwanbus_flutter/core/app_build_info.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/screens/search_screen.dart';

StopRouteSearchResult result(
  String name, {
  BusProvider provider = BusProvider.tpe,
}) => StopRouteSearchResult(
  route: RouteSummary(
    sourceProvider: provider.name,
    hashMd5: '',
    routeKey: 307,
    routeId: '${provider.prefix}307',
    routeName: '307',
    officialRouteName: '307',
    description: '返程',
    category: provider.label,
    sequence: 1,
    rtrip: 1,
  ),
  matchedStop: StopInfo(
    routeKey: 307,
    pathId: 1,
    stopId: 123,
    rawStopId: '0123',
    stopName: name,
    stopNameEn: 'Terminal 1',
    sequence: 4,
    lon: 121.5,
    lat: 25,
  ),
);

class _SearchController extends AppController {
  _SearchController({
    required super.repository,
    required super.storage,
    required super.analytics,
    required super.buildInfo,
    required super.appUpdateService,
    required super.appUpdateInstaller,
    required super.authService,
    required super.accountSyncService,
  });

  final localProviders = <BusProvider>{};
  final discoveredProviders = <BusProvider>{};
  final routeQueries = <String>[];
  final remoteQueries = <String>[];
  final remoteScopes = <List<BusProvider>?>[];
  int stopListLoads = 0;
  Future<List<RouteSummary>> Function(String) routes = (_) async => [];
  Future<List<StopRouteSearchResult>> Function(String) remote = (_) async => [
    result('第1航廈'),
  ];
  Future<List<StopRouteSearchResult>> Function(String) local = (_) async => [
    result('市政府（台北）'),
  ];

  @override
  AppSettings get settings => super.settings.copyWith(
    enableRouteBackgroundMonitor: true,
    desktopDiscordPresenceEnabled: false,
  );
  @override
  List<BusProvider> get searchProviders => [
    BusProvider.tpe,
    BusProvider.nwt,
    BusProvider.inter,
  ];
  @override
  bool isDatabaseReady(BusProvider provider) =>
      localProviders.contains(provider);

  @override
  Future<void> ensureProviderDatabaseState(
    BusProvider provider, {
    bool force = false,
  }) async {
    if (discoveredProviders.contains(provider)) localProviders.add(provider);
  }

  @override
  Future<List<RouteSummary>> searchRoutesAcrossSelected(String query) {
    routeQueries.add(query);
    return routes(query);
  }

  @override
  Future<List<StopRouteSearchResult>> searchRoutesByStopFromApi(
    String query, {
    Iterable<BusProvider>? providers,
  }) {
    remoteQueries.add(query);
    remoteScopes.add(providers?.toList());
    return remote(query);
  }

  @override
  Future<List<StopRouteSearchResult>> searchRoutesByStop(
    String query, {
    required BusProvider provider,
  }) => local(query);
  @override
  Future<List<StopInfo>> getStopsByRoute(
    int routeKey, {
    required BusProvider provider,
    String? routeIdHint,
  }) async {
    stopListLoads++;
    return [];
  }
}

class _Observer extends NavigatorObserver {
  Route<dynamic>? lastPushed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
  }
}

Future<_SearchController> _createController() async {
  const info = AppBuildInfo(
    version: '1.0.0',
    buildNumber: '1',
    gitSha: 'test',
    defaultUpdateChannel: AppUpdateChannel.release,
  );
  final client = MockClient((_) async => http.Response('{}', 200));
  return _SearchController(
    repository: BusRepository(client: client),
    storage: StorageService(),
    analytics: await AppAnalytics.initialize(),
    buildInfo: info,
    appUpdateService: AppUpdateService(buildInfo: info, client: client),
    appUpdateInstaller: createAppUpdateInstaller(),
    authService: AuthService(),
    accountSyncService: AccountSyncService(client: client),
  );
}

Future<void> _pumpSearch(
  WidgetTester tester,
  _SearchController controller, {
  _Observer? observer,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [?observer],
      builder: (context, child) =>
          AppControllerScope(controller: controller, child: child!),
      home: const SearchScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> typeQuery(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

class _NoLocation extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.deniedForever;
}

void searchTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    final previousLocation = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _NoLocation();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      GeolocatorPlatform.instance = previousLocation;
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  searchTest(
    'unified search finds routes by stop name without downloads and opens the stop',
    (tester) async {
      final controller = await _createController();
      final observer = _Observer();
      addTearDown(controller.dispose);
      await _pumpSearch(tester, controller, observer: observer);
      await typeQuery(tester, 'Terminal 1');
      await tester.pumpAndSettle();
      expect(find.text('第1航廈'), findsOneWidget);
      expect(controller.routeQueries, ['Terminal 1']);
      expect(controller.remoteQueries, ['Terminal 1']);
      expect(
        controller.remoteScopes.single,
        kIsWeb ? isNull : unorderedEquals(controller.searchProviders),
      );
      expect(controller.stopListLoads, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('第1航廈'));
      await tester.pump();
      final uri = Uri.parse(observer.lastPushed!.settings.name!);
      expect(uri.queryParameters['pathId'], '1');
      expect(uri.queryParameters['stopId'], '123');
      expect(uri.queryParameters['destinationStopId'], isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  searchTest('one query searches routes and English stop names together', (
    tester,
  ) async {
    final controller = await _createController();
    controller.remote = (_) async => [result('市政府')];
    addTearDown(controller.dispose);
    await _pumpSearch(tester, controller);
    await typeQuery(tester, 'City Hall');
    await tester.pumpAndSettle();
    expect(find.text('市政府'), findsOneWidget);
    expect(controller.routeQueries, ['City Hall']);
    expect(controller.remoteQueries, ['City Hall']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  searchTest(
    'old failures cannot replace a new query during its debounce window',
    (tester) async {
      final old = Completer<List<StopRouteSearchResult>>();
      final controller = await _createController();
      controller.remote = (query) =>
          query == 'Airport' ? old.future : Future.value([result('新站牌')]);
      addTearDown(controller.dispose);
      await _pumpSearch(tester, controller);
      await typeQuery(tester, 'Airport');
      expect(controller.remoteQueries, ['Airport']);
      await tester.enterText(find.byType(TextField), 'City Hall');
      old.completeError(StateError('old failed request'));
      await tester.pump();
      expect(find.text('Search hit a snag'), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('新站牌'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  searchTest(
    'partial failure keeps local matches and a retry fills the missing region',
    (tester) async {
      final controller = await _createController();
      // A cold search must discover an existing download before choosing API
      // fallback; the remote outage must not hide this offline result.
      controller.discoveredProviders.add(BusProvider.tpe);
      controller.remote = (_) async => throw StateError('offline');
      addTearDown(controller.dispose);
      await _pumpSearch(tester, controller);
      await typeQuery(tester, '市政府');
      await tester.pumpAndSettle();
      expect(find.text('市政府（台北）'), findsOneWidget);
      expect(
        find.text(
          'Some searches could not be completed. Available results are shown.',
        ),
        findsOneWidget,
      );
      controller.remote = (_) async => [
        result('市政府（新北）', provider: BusProvider.nwt),
      ];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('市政府（新北）'), findsOneWidget);
      expect(
        find.text(
          'Some searches could not be completed. Available results are shown.',
        ),
        findsNothing,
      );
      expect(controller.remoteQueries, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  searchTest('total failure shows retry instead of a false empty result', (
    tester,
  ) async {
    final controller = await _createController();
    controller.remote = (_) async => throw StateError('offline');
    addTearDown(controller.dispose);
    await _pumpSearch(tester, controller);
    await typeQuery(tester, 'Airport');
    await tester.pumpAndSettle();
    expect(find.text('Search hit a snag'), findsOneWidget);
    expect(find.text('No matching bus found'), findsNothing);
    controller.remote = (_) async => [result('第1航廈')];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('第1航廈'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
