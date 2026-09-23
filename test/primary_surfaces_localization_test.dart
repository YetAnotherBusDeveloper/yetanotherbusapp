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
import 'package:taiwanbus_flutter/screens/main_transit_shell.dart';
import 'package:taiwanbus_flutter/screens/search_screen.dart';
import 'package:taiwanbus_flutter/screens/settings_screen.dart';
import 'package:taiwanbus_flutter/widgets/route_search_keypad.dart';
import 'package:taiwanbus_flutter/widgets/stop_transfer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final language in const [
    (
      locale: Locale('zh', 'TW'),
      bus: '公車',
      metro: '捷運',
      search: '搜尋路線',
      searchScreen: '搜尋路線或站牌',
      searchHint: '搜尋公車路線或站牌名稱',
      keypad: '路線字首與號碼',
      settings: '設定',
      appearance: '外觀',
      usage: '使用與更新',
      transferMissing: '這個站牌沒有座標資料，無法尋找附近轉乘。',
    ),
    (
      locale: Locale('en'),
      bus: 'Bus',
      metro: 'Metro',
      search: 'Search routes',
      searchScreen: 'Search routes or stops',
      searchHint: 'Search by bus route or stop name',
      keypad: 'Route prefixes and numbers',
      settings: 'Settings',
      appearance: 'Appearance',
      usage: 'Usage and updates',
      transferMissing:
          'This stop has no coordinates, so nearby transfers cannot be found.',
    ),
  ]) {
    testWidgets(
      'navigation and home localize at narrow width in ${language.locale}',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final controller = await _createController();
        addTearDown(controller.dispose);
        await controller.updateEnableSmartRecommendations(false);
        try {
          await _pumpSurface(
            tester,
            controller: controller,
            locale: language.locale,
            child: const MainTransitShell(),
          );

          expect(find.text(language.bus), findsOneWidget);
          expect(find.text(language.metro), findsOneWidget);
          expect(find.text(language.search), findsOneWidget);
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'search and keypad localize at narrow width in ${language.locale}',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final controller = await _createController();
        addTearDown(controller.dispose);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await _pumpSurface(
            tester,
            controller: controller,
            locale: language.locale,
            child: const SearchScreen(),
          );

          expect(find.text(language.searchScreen), findsOneWidget);
          expect(find.text(language.searchHint), findsOneWidget);
          expect(find.text(language.keypad), findsOneWidget);
          expect(find.byType(RouteSearchKeypad), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'settings localize and scroll at narrow width in ${language.locale}',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final controller = await _createController();
        addTearDown(controller.dispose);
        try {
          await _pumpSurface(
            tester,
            controller: controller,
            locale: language.locale,
            child: const SettingsScreen(),
          );

          expect(find.text(language.settings), findsOneWidget);
          expect(find.text(language.appearance), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text(language.usage),
            400,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(language.usage), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'transfer errors localize at narrow width in ${language.locale}',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final controller = await _createController();
        addTearDown(controller.dispose);
        try {
          await _pumpSurface(
            tester,
            controller: controller,
            locale: language.locale,
            child: StopTransferSheet(
              controller: controller,
              provider: BusProvider.tpe,
              currentRouteId: 'TPE1',
              stop: const StopInfo(
                routeKey: 1,
                pathId: 0,
                stopId: 1,
                stopName: '測試站',
                stopNameEn: 'Test Stop',
                sequence: 1,
                lat: 0,
                lon: 0,
              ),
            ),
          );
          await tester.pump();

          expect(find.text(language.transferMissing), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required AppController controller,
  required Locale locale,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 568);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppControllerScope(controller: controller, child: child),
    ),
  );
  await tester.pump();
}

Future<AppController> _createController() async {
  const buildInfo = AppBuildInfo(
    version: '1.0.0',
    buildNumber: '1',
    gitSha: 'test',
    defaultUpdateChannel: AppUpdateChannel.release,
  );
  final client = MockClient((_) async => http.Response('{}', 200));
  final controller = AppController(
    repository: BusRepository(client: client),
    storage: StorageService(),
    analytics: await AppAnalytics.initialize(),
    buildInfo: buildInfo,
    appUpdateService: AppUpdateService(buildInfo: buildInfo, client: client),
    appUpdateInstaller: createAppUpdateInstaller(),
    authService: AuthService(),
    accountSyncService: AccountSyncService(client: client),
  );
  await controller.updateDesktopDiscordPresenceEnabled(false);
  return controller;
}
