import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:taiwanbus_flutter/widgets/route_search_keypad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mobile defaults to the route keypad and can switch input modes',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final controller = await _createController();
      addTearDown(controller.dispose);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pumpSearchScreen(tester, controller, const Size(320, 568));

        expect(find.byType(RouteSearchKeypad), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).readOnly,
          isTrue,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('route-keypad-text')));
        await tester.pump();

        expect(find.byType(RouteSearchKeypad), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).readOnly,
          isFalse,
        );
        expect(find.byKey(const ValueKey('show-route-keypad')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('show-route-keypad')));
        await tester.pump();

        expect(find.byType(RouteSearchKeypad), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).readOnly,
          isTrue,
        );

        await tester.tap(find.byKey(const ValueKey('route-keypad-collapse')));
        await tester.pump();

        expect(find.byType(RouteSearchKeypad), findsNothing);
        expect(find.byKey(const ValueKey('show-route-keypad')), findsOneWidget);

        await tester.tap(find.byType(TextField));
        await tester.pump();

        expect(find.byType(RouteSearchKeypad), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('desktop keeps the normal editable search field', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final controller = await _createController();
    addTearDown(controller.dispose);
    try {
      await _pumpSearchScreen(tester, controller, const Size(800, 600));

      expect(find.byType(RouteSearchKeypad), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
      expect(find.byKey(const ValueKey('show-route-keypad')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('history tap restores boarding and destination request', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final controller = await _createController();
    await controller.updateDesktopDiscordPresenceEnabled(false);
    await controller.addHistoryEntry(
      const RouteSummary(
        sourceProvider: 'nwt',
        hashMd5: '',
        routeKey: 12,
        routeId: 'NWT12',
        routeName: 'History Route',
        officialRouteName: 'History Route',
        description: '',
        category: '',
        sequence: 0,
        rtrip: 3,
      ),
      provider: BusProvider.nwt,
      pathId: 3,
      boardingStopId: 101,
      destinationPathId: 3,
      destinationStopId: 109,
    );
    final observer = _RecordingNavigatorObserver();
    addTearDown(controller.dispose);
    try {
      await _pumpSearchScreen(
        tester,
        controller,
        const Size(800, 600),
        observer: observer,
      );
      await tester.tap(find.text('History Route'));
      await tester.pump();

      final location = observer.lastPushed?.settings.name;
      expect(location, isNotNull);
      final uri = Uri.parse(location!);
      expect(uri.queryParameters['pathId'], '3');
      expect(uri.queryParameters['stopId'], '101');
      expect(uri.queryParameters['destinationPathId'], '3');
      expect(uri.queryParameters['destinationStopId'], '109');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'shortcuts stay visible until the current provider names load successfully',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final controller = await _createRouteNameController();
      addTearDown(controller.dispose);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pumpSearchScreen(tester, controller, const Size(390, 844));

        expect(
          find.byKey(const ValueKey('route-keypad-prefix-紅')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('route-keypad-prefix-藍')),
          findsOneWidget,
        );

        controller.useProviders(const [BusProvider.txg]);
        await tester.pump();
        controller.loadFor('nwt').complete(const <String>{'紅1'});
        await tester.pump();

        expect(
          find.byKey(const ValueKey('route-keypad-prefix-紅')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('route-keypad-prefix-藍')),
          findsOneWidget,
        );

        controller.loadFor('txg').complete(const <String>{'藍1'});
        await tester.pump();

        expect(
          find.byKey(const ValueKey('route-keypad-prefix-紅')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('route-keypad-prefix-藍')),
          findsOneWidget,
        );

        controller.useProviders(const [BusProvider.tpe]);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('route-keypad-prefix-紅')),
          findsOneWidget,
        );
        controller.loadFor('tpe').completeError(StateError('database failed'));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('route-keypad-prefix-紅')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('route-keypad-prefix-藍')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

class _RouteNameController extends AppController {
  _RouteNameController({
    required super.repository,
    required super.storage,
    required super.analytics,
    required super.buildInfo,
    required super.appUpdateService,
    required super.appUpdateInstaller,
    required super.authService,
    required super.accountSyncService,
  });

  List<BusProvider> _providers = const [BusProvider.nwt];
  final Map<String, Completer<Set<String>>> _loads = {};

  @override
  List<BusProvider> get downloadedProviders => _providers;

  @override
  Future<Set<String>> routeNamesForDownloadedProviders() {
    return loadFor(_providerKey).future;
  }

  Completer<Set<String>> loadFor(String key) {
    return _loads.putIfAbsent(key, Completer<Set<String>>.new);
  }

  void useProviders(List<BusProvider> providers) {
    _providers = providers;
    notifyListeners();
  }

  String get _providerKey =>
      _providers.map((provider) => provider.name).join('|');
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}

Future<AppController> _createController() async {
  const buildInfo = AppBuildInfo(
    version: '1.0.0',
    buildNumber: '1',
    gitSha: 'test',
    defaultUpdateChannel: AppUpdateChannel.release,
  );
  final client = MockClient((_) async => http.Response('{}', 200));
  return AppController(
    repository: BusRepository(client: client),
    storage: StorageService(),
    analytics: await AppAnalytics.initialize(),
    buildInfo: buildInfo,
    appUpdateService: AppUpdateService(buildInfo: buildInfo, client: client),
    appUpdateInstaller: createAppUpdateInstaller(),
    authService: AuthService(),
    accountSyncService: AccountSyncService(client: client),
  );
}

Future<_RouteNameController> _createRouteNameController() async {
  const buildInfo = AppBuildInfo(
    version: '1.0.0',
    buildNumber: '1',
    gitSha: 'test',
    defaultUpdateChannel: AppUpdateChannel.release,
  );
  final client = MockClient((_) async => http.Response('{}', 200));
  return _RouteNameController(
    repository: BusRepository(client: client),
    storage: StorageService(),
    analytics: await AppAnalytics.initialize(),
    buildInfo: buildInfo,
    appUpdateService: AppUpdateService(buildInfo: buildInfo, client: client),
    appUpdateInstaller: createAppUpdateInstaller(),
    authService: AuthService(),
    accountSyncService: AccountSyncService(client: client),
  );
}

Future<void> _pumpSearchScreen(
  WidgetTester tester,
  AppController controller,
  Size size, {
  NavigatorObserver? observer,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(
    AppControllerScope(
      controller: controller,
      child: MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [?observer],
        home: const SearchScreen(),
      ),
    ),
  );
}
