import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/screens/home_screen.dart';

import 'support/ad_test_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform originalGeolocator;
  late _Location location;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalGeolocator = GeolocatorPlatform.instance;
    location = _Location();
    GeolocatorPlatform.instance = location;
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalGeolocator;
    debugDefaultTargetPlatformOverride = null;
  });

  for (final width in [390.0, 1400.0]) {
    _homeTest('missing location and database keep the card at width $width', (
      tester,
    ) async {
      await _pumpHome(tester, _Repository(), width: width);
      final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
      expect(find.text(l10n.smartRecommendationsTitle), findsOneWidget);
      expect(find.text(l10n.smartRecommendationsEmpty), findsOneWidget);
      expect(find.text(l10n.smartRecommendationsNeedDatabase), findsOneWidget);
      expect(find.byTooltip(l10n.commonRefresh), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text(l10n.smartRecommendationsEmpty),
            matching: find.byType(Card),
          ),
          matching: find.widgetWithText(OutlinedButton, l10n.homeNearbyTitle),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  _homeTest('denied location keeps the card with an existing database', (
    tester,
  ) async {
    location.enabled = true;
    final repository = _Repository()..hasDatabase = true;
    await _pumpHome(tester, repository);
    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
    expect(find.text(l10n.smartRecommendationsEmpty), findsOneWidget);
    expect(find.text(l10n.smartRecommendationsNeedDatabase), findsNothing);
    expect(repository.nearbyRequests, 0);
    expect(tester.takeException(), isNull);
  });

  _homeTest('empty nearby results recover to a route after refresh', (
    tester,
  ) async {
    location.enabled = true;
    location.permission = LocationPermission.whileInUse;
    final repository = _Repository()..hasDatabase = true;
    await _pumpHome(tester, repository);
    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
    expect(repository.nearbyRequests, 1);
    expect(find.text(l10n.smartRecommendationsEmpty), findsOneWidget);

    repository.nearby = const [
      NearbyStopResult(route: _route, stop: _stop, distanceMeters: 20),
    ];
    await tester.tap(find.byTooltip(l10n.commonRefresh));
    await tester.pumpAndSettle();
    expect(repository.nearbyRequests, 2);
    expect(find.text(l10n.smartRecommendationsTitle), findsOneWidget);
    expect(find.text(l10n.smartRecommendationsEmpty), findsNothing);
    expect(find.text('307'), findsOneWidget);
    expect(find.text('市政府'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  _homeTest('turning recommendations off hides the card', (tester) async {
    final controller = await _pumpHome(tester, _Repository());
    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
    expect(find.text(l10n.smartRecommendationsTitle), findsOneWidget);
    await controller.updateEnableSmartRecommendations(false);
    await tester.pumpAndSettle();
    expect(find.text(l10n.smartRecommendationsTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _homeTest(String description, WidgetTesterCallback test) {
  testWidgets(description, (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await test(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}

Future<AppController> _pumpHome(
  WidgetTester tester,
  _Repository repository, {
  double width = 390,
}) async {
  final controller = await createAdTestController(repository: repository);
  await controller.initializeForFirstFrame();
  await controller.updateShowWeatherInAppBar(false);
  await controller.updateDesktopDiscordPresenceEnabled(false);
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    AppControllerScope(
      controller: controller,
      child: MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _Location extends GeolocatorPlatform {
  bool enabled = false;
  LocationPermission permission = LocationPermission.denied;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 25.033,
    longitude: 121.5654,
    timestamp: DateTime.now(),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _Repository extends BusRepository {
  bool hasDatabase = false;
  int nearbyRequests = 0;
  List<NearbyStopResult> nearby = const [];

  @override
  Future<bool> databaseExists(BusProvider provider) async => hasDatabase;

  @override
  Future<List<NearbyStopResult>> fetchNearbyStops({
    required BusProvider provider,
    required double latitude,
    required double longitude,
    double radiusMeters = 500,
    int limit = 20,
  }) async {
    nearbyRequests++;
    return nearby;
  }

  @override
  Future<RouteDetailData> getCompleteBusInfo(
    int routeKey, {
    required BusProvider provider,
    String? routeIdHint,
    String? routeNameHint,
  }) async => const RouteDetailData(
    route: _route,
    paths: [],
    stopsByPath: {
      0: [_stop],
    },
    hasLiveData: true,
  );
}

const _route = RouteSummary(
  routeKey: 1,
  routeId: 'TPE307',
  hashMd5: 'test',
  routeName: '307',
  officialRouteName: '307',
  description: '往板橋',
  sourceProvider: 'tpe',
  category: '',
  sequence: 1,
  rtrip: 0,
);

const _stop = StopInfo(
  routeKey: 1,
  pathId: 0,
  stopId: 1,
  stopName: '市政府',
  sequence: 1,
  lat: 25.033,
  lon: 121.5654,
  sec: 180,
);
