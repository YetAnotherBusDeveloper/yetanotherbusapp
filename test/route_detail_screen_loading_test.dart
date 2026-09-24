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
import 'package:taiwanbus_flutter/core/app_route_observer.dart';
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/screens/route_detail_screen.dart';
import 'package:taiwanbus_flutter/widgets/eta_badge.dart';

class _FamilyRequest {
  _FamilyRequest(this.selected);

  final RouteDetailData selected;
  final completer = Completer<RouteDetailData>();
}

class _Repository extends BusRepository {
  _Repository()
    : super(client: MockClient((_) async => http.Response('{}', 404)));

  final topologyRequests = <Completer<RouteDetailData>>[];
  final primaryRequests = <Completer<RouteDetailData>>[];
  final familyRequests = <_FamilyRequest>[];

  @override
  Future<RouteDetailData> getRouteTopology(
    int routeKey, {
    required BusProvider provider,
    String? routeIdHint,
    String? routeNameHint,
  }) {
    final request = Completer<RouteDetailData>();
    topologyRequests.add(request);
    return request.future;
  }

  @override
  Future<RouteDetailData> getCompleteBusInfo(
    int routeKey, {
    required BusProvider provider,
    String? routeIdHint,
    String? routeNameHint,
  }) {
    final request = Completer<RouteDetailData>();
    primaryRequests.add(request);
    return request.future;
  }

  @override
  Future<RouteDetailData> enrichRouteWithFamily(
    RouteDetailData selected, {
    required BusProvider provider,
  }) {
    final request = _FamilyRequest(selected);
    familyRequests.add(request);
    return request.completer.future;
  }

  void finishPending() {
    for (final request in topologyRequests) {
      if (!request.isCompleted) request.complete(_detail());
    }
    for (final request in primaryRequests) {
      if (!request.isCompleted) request.complete(_detail());
    }
    for (final request in familyRequests) {
      if (!request.completer.isCompleted) {
        request.completer.complete(request.selected);
      }
    }
  }
}

class _NoLocation extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
}

RouteDetailData _detail({
  int? eta,
  String name = '測試路線',
  String? nameEn,
  DateTime? updatedAt,
  List<String> family = const [],
  bool withBus = false,
}) => RouteDetailData(
  route: RouteSummary(
    sourceProvider: 'TPE',
    hashMd5: '',
    routeKey: 500,
    routeId: 'TPE500',
    routeName: name,
    officialRouteName: name,
    description: '',
    category: '',
    sequence: 0,
    rtrip: 0,
    routeNameEn: nameEn,
  ),
  paths: [
    PathInfo(
      routeKey: 500,
      pathId: 0,
      name: '去程',
      nameEn: nameEn == null ? null : 'Outbound',
    ),
    PathInfo(
      routeKey: 500,
      pathId: 1,
      name: '返程',
      nameEn: nameEn == null ? null : 'Inbound',
    ),
  ],
  stopsByPath: {
    for (final path in [0, 1])
      path: [
        for (var i = 1; i <= 15; i++)
          StopInfo(
            routeKey: 500,
            pathId: path,
            stopId: i,
            stopName: '${path == 0 ? '去程' : '返程'}站$i',
            stopNameEn: nameEn == null
                ? null
                : '${path == 0 ? 'Outbound' : 'Inbound'} Stop $i',
            sequence: i,
            lat: 25,
            lon: 121,
            sec: eta,
            t: eta == null
                ? null
                : (updatedAt ?? DateTime.now()).toIso8601String(),
            buses: withBus && path == 1 && i == 1
                ? const [
                    BusVehicle(
                      id: 'TEST-001',
                      type: '0',
                      note: '',
                      full: false,
                      carOnStop: false,
                    ),
                  ]
                : const [],
          ),
      ],
  },
  hasLiveData: eta != null,
  familyRouteIds: family,
);

Future<AppController> _controller(_Repository repository) async {
  const build = AppBuildInfo(
    version: '1.0.0',
    buildNumber: '1',
    gitSha: 'test',
    defaultUpdateChannel: AppUpdateChannel.release,
  );
  final client = MockClient((_) async => http.Response('{}', 404));
  final controller = AppController(
    repository: repository,
    storage: StorageService(),
    analytics: await AppAnalytics.initialize(),
    buildInfo: build,
    appUpdateService: AppUpdateService(buildInfo: build, client: client),
    appUpdateInstaller: createAppUpdateInstaller(),
    authService: AuthService(),
    accountSyncService: AccountSyncService(client: client),
  );
  await controller.updateDesktopDiscordPresenceEnabled(false);
  await controller.updateEnableRouteBackgroundMonitor(false);
  await controller.updateKeepScreenAwakeOnRouteDetail(false);
  await controller.updateEnableAds(false);
  return controller;
}

Future<void> _frames(WidgetTester tester, [int count = 5]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _resumeRoute(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await _frames(tester);
}

void _screenTest(
  String name,
  Future<void> Function(WidgetTester, _Repository) body, {
  Locale locale = const Locale('zh', 'TW'),
  int initialFrameCount = 5,
}) {
  testWidgets(name, (tester) async {
    SharedPreferences.setMockInitialValues({});
    final previousLocation = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _NoLocation();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final repository = _Repository();
    final controller = await _controller(repository);
    try {
      await tester.pumpWidget(
        AppControllerScope(
          controller: controller,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorObservers: [appRouteObserver],
            home: const RouteDetailScreen(
              routeKey: 500,
              provider: BusProvider.tpe,
              routeIdHint: 'TPE500',
              routeNameHint: '標題提示',
              initialPathId: 1,
              suppressAutoDestinationSelection: true,
            ),
          ),
        ),
      );
      await _frames(tester, initialFrameCount);
      await body(tester, repository);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      repository.finishPending();
      await _frames(tester);
      controller.dispose();
      GeolocatorPlatform.instance = previousLocation;
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  test('learned destination requires matching path and a later stop', () {
    final stops = _detail().stopsByPath[0]!;
    final matching = DestinationChoiceProfile(
      provider: BusProvider.tpe,
      routeKey: 500,
      departurePathId: 0,
      boardingStopId: 3,
      destinationPathId: 0,
      destinationStopId: 8,
    );

    expect(
      resolveLearnedDestinationStop(
        pathStops: stops,
        pathId: 0,
        boardingStopId: 3,
        choice: matching,
      )?.stopId,
      8,
    );
    expect(
      resolveLearnedDestinationStop(
        pathStops: stops,
        pathId: 1,
        boardingStopId: 3,
        choice: matching,
      ),
      isNull,
    );
    expect(
      resolveLearnedDestinationStop(
        pathStops: stops,
        pathId: 0,
        boardingStopId: 9,
        choice: matching,
      ),
      isNull,
    );
    final earlier = DestinationChoiceProfile(
      provider: BusProvider.tpe,
      routeKey: 500,
      departurePathId: 0,
      boardingStopId: 8,
      destinationPathId: 0,
      destinationStopId: 3,
    );
    expect(
      resolveLearnedDestinationStop(
        pathStops: stops,
        pathId: 0,
        boardingStopId: 8,
        choice: earlier,
      ),
      isNull,
    );
  });

  test('explicit request and manual clear suppress learned destination', () {
    final stops = _detail().stopsByPath[0]!;
    final choice = DestinationChoiceProfile(
      provider: BusProvider.tpe,
      routeKey: 500,
      departurePathId: 0,
      boardingStopId: 3,
      destinationPathId: 0,
      destinationStopId: 8,
    );

    expect(
      resolveLearnedDestinationStop(
        pathStops: stops,
        pathId: 0,
        boardingStopId: 3,
        choice: choice,
        hasExplicitDestinationRequest: true,
      ),
      isNull,
    );
    expect(
      resolveLearnedDestinationStop(
        pathStops: stops,
        pathId: 0,
        boardingStopId: 3,
        choice: choice,
        manualDestinationClearInSession: true,
      ),
      isNull,
    );
  });

  _screenTest('shows Chinese route, path, and stop names without overflow', (
    tester,
    repository,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    repository.topologyRequests.single.complete(
      _detail(nameEn: 'Test Route With A Long English Name'),
    );
    await _frames(tester);

    expect(find.text('測試路線'), findsOneWidget);
    expect(
      find.text('Test Route With A Long English Name / 測試路線'),
      findsNothing,
    );
    expect(find.text('返程'), findsOneWidget);
    expect(find.text('Inbound / 返程'), findsNothing);
    expect(find.text('返程站1'), findsOneWidget);
    expect(find.text('Inbound Stop 1\n返程站1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _screenTest(
    'localizes route detail in English at narrow width',
    (tester, repository) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      repository.topologyRequests.single.complete(
        _detail(nameEn: 'Test Route With A Long English Name'),
      );
      await _frames(tester);

      expect(
        find.text('Test Route With A Long English Name / 測試路線'),
        findsOneWidget,
      );
      expect(find.text('返程'), findsOneWidget);
      expect(find.text('Inbound'), findsOneWidget);
      expect(find.text('返程站1'), findsOneWidget);
      expect(find.text('Inbound Stop 1'), findsOneWidget);
      expect(find.byTooltip('Bus map'), findsOneWidget);
      final appBarTitle = tester.widget<Text>(
        find.text('Test Route With A Long English Name / 測試路線'),
      );
      expect(appBarTitle.maxLines, 1);
      expect(appBarTitle.softWrap, isFalse);
      expect(appBarTitle.overflow, TextOverflow.ellipsis);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).actionsPadding,
        const EdgeInsetsDirectional.only(end: 12),
      );
      expect(tester.takeException(), isNull);
    },
    locale: const Locale('en'),
  );

  _screenTest('keeps stop status controls aligned to the trailing edge', (
    tester,
    repository,
  ) async {
    tester.view.physicalSize = const Size(466, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    repository.topologyRequests.single.complete(_detail(withBus: true));
    await _frames(tester, 10);

    final tile = find.byKey(const ValueKey('route-detail-stop-1-1'));
    final status = find.byKey(
      const ValueKey('route-detail-trailing-status-1-1'),
    );
    expect(tile, findsOneWidget);
    expect(status, findsOneWidget);
    final tileRect = tester.getRect(tile);
    final statusRect = tester.getRect(status);
    expect(statusRect.right, closeTo(tileRect.right - 8, 0.1));
  });

  _screenTest('waits for realtime ETA before fading in route stops', (
    tester,
    repository,
  ) async {
    expect(repository.primaryRequests, hasLength(1));
    expect(find.byType(ListView), findsNothing);

    repository.topologyRequests.single.complete(_detail());
    await tester.pump();
    await tester.pump();

    final stopsFade = find.byKey(const ValueKey('route-stops-fade'));
    expect(stopsFade, findsOneWidget);
    expect(tester.widget<FadeTransition>(stopsFade).opacity.value, 0);

    await tester.pump(const Duration(milliseconds: 110));
    expect(tester.widget<FadeTransition>(stopsFade).opacity.value, 0);

    repository.primaryRequests.single.complete(_detail(eta: 120));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(
      tester.widget<FadeTransition>(stopsFade).opacity.value,
      greaterThan(0),
    );
    expect(tester.widget<FadeTransition>(stopsFade).opacity.value, lessThan(1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<FadeTransition>(stopsFade).opacity.value, 1);
  }, initialFrameCount: 1);

  _screenTest('caps the initial reveal wait at 500ms', (
    tester,
    repository,
  ) async {
    await tester.pump(const Duration(milliseconds: 500));
    repository.topologyRequests.single.complete(_detail());
    await tester.pump();
    await tester.pump();

    final stopsFade = find.byKey(const ValueKey('route-stops-fade'));
    expect(stopsFade, findsOneWidget);
    expect(tester.widget<FadeTransition>(stopsFade).opacity.value, 1);
  });

  _screenTest(
    'shows topology and loading ETA before realtime, then preserves scroll',
    (tester, repository) async {
      expect(find.text('標題提示'), findsOneWidget);
      expect(find.text('正在準備 標題提示 的站牌資訊'), findsNothing);
      expect(repository.topologyRequests, hasLength(1));
      expect(repository.primaryRequests, hasLength(1));

      repository.topologyRequests.single.complete(_detail());
      await _frames(tester);
      expect(find.text('返程站1'), findsOneWidget);
      expect(find.text('載入中'), findsWidgets);
      expect(find.byTooltip('公車地圖'), findsOneWidget);
      await tester.tap(find.text('去程'));
      await _frames(tester);
      expect(find.text('去程站1'), findsOneWidget);

      repository.primaryRequests.single.complete(_detail(eta: 120));
      await _frames(tester, 8);
      expect(find.text('載入中'), findsNothing);
      expect(find.byTooltip('公車地圖'), findsOneWidget);
      expect(find.text('正在載入同路線班次'), findsOneWidget);
      expect(repository.familyRequests, hasLength(1));

      final list = find.byType(ListView).first;
      await tester.drag(list, const Offset(0, -250));
      await _frames(tester);
      final positions = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .map((state) => state.position.pixels)
          .toList();
      repository.familyRequests.single.completer.complete(
        _detail(eta: 60, family: ['TPE500', 'TPE501']),
      );
      await _frames(tester);
      expect(
        tester
            .stateList<ScrollableState>(find.byType(Scrollable))
            .map((state) => state.position.pixels)
            .toList(),
        positions,
      );
    },
  );

  _screenTest('a new refresh rejects late family results', (
    tester,
    repository,
  ) async {
    repository.topologyRequests.single.complete(_detail());
    repository.primaryRequests.single.complete(_detail(eta: 120));
    await _frames(tester, 8);
    expect(repository.familyRequests, hasLength(1));

    await _resumeRoute(tester);
    expect(repository.primaryRequests, hasLength(2));
    repository.familyRequests.first.completer.complete(
      _detail(eta: 10, name: '過期結果'),
    );
    repository.primaryRequests.last.complete(_detail(eta: 90));
    await _frames(tester, 8);
    expect(repository.familyRequests, hasLength(2));
    repository.familyRequests.last.completer.complete(
      repository.familyRequests.last.selected,
    );
    await _frames(tester);
    expect(find.text('過期結果'), findsNothing);
    expect(find.byTooltip('公車地圖'), findsOneWidget);
  });

  _screenTest(
    'failed realtime keeps recent values but drops values older than 90 seconds',
    (tester, repository) async {
      final recent = DateTime.now().subtract(const Duration(seconds: 30));
      repository.topologyRequests.single.complete(_detail());
      repository.primaryRequests.single.complete(
        _detail(eta: 120, updatedAt: recent),
      );
      await _frames(tester, 8);
      repository.familyRequests.single.completer.complete(
        repository.familyRequests.single.selected,
      );
      await _frames(tester);

      await _resumeRoute(tester);
      repository.primaryRequests.last.complete(_detail());
      await _frames(tester, 8);
      var latestFamily = repository.familyRequests.last;
      latestFamily.completer.complete(latestFamily.selected);
      await _frames(tester);
      var stop = tester.widgetList<EtaBadge>(find.byType(EtaBadge)).first.stop;
      expect(stop.sec, 120);
      expect(stop.t, recent.toIso8601String());

      final stale = DateTime.now().subtract(const Duration(seconds: 91));
      await _resumeRoute(tester);
      repository.primaryRequests.last.complete(
        _detail(eta: 120, updatedAt: stale),
      );
      await _frames(tester, 8);
      latestFamily = repository.familyRequests.last;
      latestFamily.completer.complete(latestFamily.selected);
      await _frames(tester);

      await _resumeRoute(tester);
      repository.primaryRequests.last.complete(_detail());
      await _frames(tester, 8);
      latestFamily = repository.familyRequests.last;
      latestFamily.completer.complete(latestFamily.selected);
      await _frames(tester);
      stop = tester.widgetList<EtaBadge>(find.byType(EtaBadge)).first.stop;
      expect(stop.sec, isNull);
      expect(stop.t, isNull);
    },
  );

  _screenTest('leaving before the first response ignores late updates', (
    tester,
    repository,
  ) async {
    final topology = repository.topologyRequests.single;
    final primary = repository.primaryRequests.single;
    await tester.pumpWidget(const SizedBox.shrink());
    topology.complete(_detail());
    primary.complete(_detail(eta: 60));
    await _frames(tester);
    expect(tester.takeException(), isNull);
    expect(repository.topologyRequests, hasLength(1));
    expect(repository.primaryRequests, hasLength(1));
  });
}
