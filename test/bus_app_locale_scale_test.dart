import 'package:dynamic_color/test_utils.dart';
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
import 'package:taiwanbus_flutter/core/app_routes.dart';
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/interface_scale_text_scaler.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';
import 'package:taiwanbus_flutter/widgets/app_dropdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DynamicColorTestingUtils.setMockDynamicColors();
    TestWidgetsFlutterBinding.instance.platformDispatcher.localeTestValue =
        const Locale('en');
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocaleTestValue();
  });

  testWidgets(
    'locale and interface scale update at runtime',
    (tester) async {
      final controller = (await tester.runAsync(_buildController))!;
      addTearDown(controller.dispose);
      await tester.runAsync(
        () => controller.updateLanguage(const Locale('en')),
      );
      await tester.runAsync(() => controller.updateInterfaceScale(1.2));

      await tester.pumpWidget(
        BusApp(controller: controller, analytics: controller.analytics),
      );
      await tester.pump();

      var appContext = tester.element(find.byType(Navigator).first);
      expect(Localizations.localeOf(appContext), const Locale('en'));
      expect(
        MediaQuery.textScalerOf(appContext),
        isA<InterfaceScaleTextScaler>(),
      );
      expect(
        MediaQuery.textScalerOf(appContext).scale(10),
        closeTo(12, 0.0001),
      );

      await tester.runAsync(
        () => controller.updateLanguage(const Locale('zh', 'TW')),
      );
      await tester.runAsync(() => controller.updateInterfaceScale(0.8));
      await tester.pump();

      appContext = tester.element(find.byType(Navigator).first);
      expect(Localizations.localeOf(appContext), const Locale('zh', 'TW'));
      expect(MediaQuery.textScalerOf(appContext).scale(10), closeTo(8, 0.0001));

      await tester.runAsync(() => controller.updateLanguage(null));
      await tester.pump();

      appContext = tester.element(find.byType(Navigator).first);
      expect(controller.settings.language, isNull);
      expect(Localizations.localeOf(appContext), const Locale('en'));

      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  testWidgets('settings lists selectable locales and can follow system', (
    tester,
  ) async {
    final controller = (await tester.runAsync(_buildController))!;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      BusApp(controller: controller, analytics: controller.analytics),
    );
    await tester.pump();

    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();

    final dropdown = find.byType(AppDropdownFormField<Locale?>);
    expect(dropdown, findsOneWidget);
    expect(
      tester
          .widget<AppDropdownFormField<Locale?>>(dropdown)
          .items
          .map((item) => item.value),
      [null, const Locale('en'), const Locale('zh', 'TW')],
    );
    expect(
      find.descendant(of: dropdown, matching: find.text('Follow system')),
      findsOneWidget,
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.text('English'), findsWidgets);
    expect(find.text('繁體中文'), findsWidgets);
    expect(find.text('中文'), findsNothing);

    await tester.tap(find.text('繁體中文').last);
    await tester.pumpAndSettle();
    expect(controller.settings.language, const Locale('zh', 'TW'));
    expect(controller.rootRevision.value, 1);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('zh', 'TW'),
    );
    expect(
      Localizations.localeOf(tester.element(find.byType(Navigator).first)),
      const Locale('zh', 'TW'),
    );
    expect(
      Localizations.localeOf(tester.element(dropdown)),
      const Locale('zh', 'TW'),
    );
    expect(
      find.descendant(of: dropdown, matching: find.text('繁體中文')),
      findsOneWidget,
    );

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟隨系統').last);
    await tester.pumpAndSettle();
    expect(controller.settings.language, isNull);
    expect(
      find.descendant(of: dropdown, matching: find.text('Follow system')),
      findsOneWidget,
    );
    expect(
      Localizations.localeOf(tester.element(dropdown)),
      const Locale('en'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('existing fallback-locale preference remains changeable', (
    tester,
  ) async {
    final controller = (await tester.runAsync(_buildController))!;
    addTearDown(controller.dispose);
    await tester.runAsync(() => controller.updateLanguage(const Locale('zh')));

    await tester.pumpWidget(
      BusApp(controller: controller, analytics: controller.analytics),
    );
    await tester.pump();
    Navigator.of(
      tester.element(find.byType(Navigator).first),
    ).pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();

    final dropdown = find.byType(AppDropdownFormField<Locale?>);
    expect(
      tester
          .widget<AppDropdownFormField<Locale?>>(dropdown)
          .items
          .map((item) => item.value),
      [null, const Locale('en'), const Locale('zh', 'TW'), const Locale('zh')],
    );

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁體中文').last);
    await tester.pumpAndSettle();
    expect(controller.settings.language, const Locale('zh', 'TW'));
    expect(
      tester
          .widget<AppDropdownFormField<Locale?>>(dropdown)
          .items
          .map((item) => item.value),
      [null, const Locale('en'), const Locale('zh', 'TW')],
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<AppController> _buildController() async {
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
