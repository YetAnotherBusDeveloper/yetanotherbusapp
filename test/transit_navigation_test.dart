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
import 'package:taiwanbus_flutter/widgets/background_image_wrapper.dart';
import 'package:taiwanbus_flutter/screens/home_screen.dart';
import 'package:taiwanbus_flutter/screens/main_transit_shell.dart';
import 'package:taiwanbus_flutter/widgets/transit_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = await _buildController();
  });
  tearDown(() => controller.dispose());

  test('transit destinations use the canonical navigation order', () {
    expect(
      kTransitModeDestinations.map((destination) => destination.mode),
      orderedEquals(const [
        TransitMode.bus,
        TransitMode.metro,
        TransitMode.thsr,
        TransitMode.tra,
        TransitMode.youbike,
      ]),
    );
  });

  testWidgets('mobile navigation stays below the scrollable page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 500),
            padding: EdgeInsets.only(top: 32, bottom: 24),
            viewPadding: EdgeInsets.only(top: 32, bottom: 24),
          ),
          child: AppControllerScope(
            controller: controller,
            child: const MainTransitShell(),
          ),
        ),
      ),
    );
    await tester.pump();

    final navigation = find.byType(NavigationBar);
    final navigationSafeArea = find.ancestor(
      of: navigation,
      matching: find.byType(SafeArea),
    );
    expect(navigation, findsOneWidget);
    expect(navigationSafeArea, findsOneWidget);
    expect(tester.getSize(navigation).height, 64);
    expect(tester.getBottomLeft(navigation).dy, 476);
    expect(tester.getBottomLeft(navigationSafeArea).dy, 500);
    expect(
      find.ancestor(
        of: navigation,
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );

    final navigationTop = tester.getTopLeft(navigation);
    final pageScrollView = find.byType(SingleChildScrollView).first;
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: pageScrollView, matching: find.byType(Scrollable)),
    );
    final initialScrollOffset = scrollable.position.pixels;
    await tester.drag(pageScrollView, const Offset(0, -300));
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(initialScrollOffset));
    expect(tester.getTopLeft(navigation), navigationTop);

    await tester.tap(find.text('捷運'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.getTopLeft(find.byType(NavigationBar)), navigationTop);
  });

  testWidgets('mode pages fade in place without sliding', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppControllerScope(
          controller: controller,
          child: const MainTransitShell(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('高鐵'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(_modeOpacity(tester, TransitMode.thsr), inExclusiveRange(0, 1));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(TransitMode.thsr))),
      Offset.zero,
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('捷運'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(_modeOpacity(tester, TransitMode.metro), inExclusiveRange(0, 1));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(TransitMode.metro))),
      Offset.zero,
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(_modeOpacity(tester, TransitMode.metro), 1);
  });

  testWidgets('mobile home feature cards use one vertical spacing rule', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.updateEnableSmartRecommendations(false);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppControllerScope(
          controller: controller,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final cards = [
      for (final title in ['搜尋路線', '我的最愛', '附近站牌', '全公車地圖'])
        find.ancestor(of: find.text(title), matching: find.byType(Card)).first,
    ];
    for (var index = 1; index < cards.length; index++) {
      expect(
        tester.getTopLeft(cards[index]).dy -
            tester.getBottomLeft(cards[index - 1]).dy,
        8,
      );
    }
    for (final card in cards) {
      expect(tester.widget<Card>(card).margin, EdgeInsets.zero);
    }
    final scrollView = find.byType(SingleChildScrollView);
    expect(
      tester.widget<SingleChildScrollView>(scrollView).padding,
      const EdgeInsets.fromLTRB(16, 8, 16, 8),
    );
    final cardGroupCenter =
        (tester.getTopLeft(cards.first).dy +
            tester.getBottomLeft(cards.last).dy) /
        2;
    expect(cardGroupCenter, closeTo(tester.getCenter(scrollView).dy, 0.01));
  });

  for (final layout in [
    (
      name: 'no system insets',
      size: const Size(390, 600),
      padding: EdgeInsets.zero,
    ),
    (
      name: 'Android status and gesture bars',
      size: const Size(390, 600),
      padding: const EdgeInsets.only(top: 32, bottom: 24),
    ),
    (
      name: 'portrait display cutout',
      size: const Size(390, 600),
      padding: const EdgeInsets.only(top: 59, bottom: 34),
    ),
    (
      name: 'landscape display cutout',
      size: const Size(844, 390),
      padding: const EdgeInsets.fromLTRB(44, 0, 24, 21),
    ),
  ]) {
    testWidgets('all transit modes keep a 64dp bar with ${layout.name}', (
      tester,
    ) async {
      tester.view.physicalSize = layout.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'TW'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: layout.size,
              padding: layout.padding,
              viewPadding: layout.padding,
            ),
            child: AppControllerScope(
              controller: controller,
              child: const MainTransitShell(),
            ),
          ),
        ),
      );
      await tester.pump();

      final navigation = find.byType(NavigationBar);
      const labels = ['公車', '捷運', '高鐵', '台鐵', 'YouBike'];
      for (var index = 0; index < kTransitModeDestinations.length; index++) {
        await tester.tap(
          find.descendant(of: navigation, matching: find.text(labels[index])),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(navigation, findsOneWidget);
        expect(tester.widget<NavigationBar>(navigation).selectedIndex, index);
        expect(
          tester.getRect(navigation),
          Rect.fromLTWH(
            layout.padding.left,
            layout.size.height - layout.padding.bottom - 64,
            layout.size.width - layout.padding.horizontal,
            64,
          ),
        );
        final page = find.byType(Scaffold);
        expect(page, findsOneWidget);
        expect(tester.getBottomLeft(page).dy, tester.getTopLeft(navigation).dy);
        expect(
          MediaQuery.paddingOf(tester.element(page)).top,
          layout.padding.top,
        );
        expect(MediaQuery.paddingOf(tester.element(page)).bottom, 0);

        // The navigation surface covers the full width and gesture inset,
        // independently of each page's cards, tint and background image.
        final surface = find
            .ancestor(of: navigation, matching: find.byType(Material))
            .first;
        expect(
          tester.getRect(surface),
          Rect.fromLTWH(
            0,
            layout.size.height - layout.padding.bottom - 64,
            layout.size.width,
            64 + layout.padding.bottom,
          ),
        );
        final material = tester.widget<Material>(surface);
        final colors = Theme.of(tester.element(navigation)).colorScheme;
        expect(material.color, colors.surfaceContainerHigh);
        expect(
          material.shape,
          Border(top: BorderSide(color: colors.outlineVariant)),
        );
        for (final type in [ListView, Card, BackgroundImageWrapper]) {
          expect(
            find.ancestor(of: navigation, matching: find.byType(type)),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

double _modeOpacity(WidgetTester tester, TransitMode mode) {
  final layer = find.descendant(
    of: find.byKey(ValueKey<TransitMode>(mode)),
    matching: find.byType(Opacity),
  );
  return tester.widget<Opacity>(layer.first).opacity;
}

Future<AppController> _buildController() async {
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
