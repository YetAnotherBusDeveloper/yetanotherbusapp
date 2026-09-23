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
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/interface_scale_text_scaler.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DynamicColorTestingUtils.setMockDynamicColors();
  });

  testWidgets(
    'locale and interface scale update at runtime',
    (tester) async {
      final controller = (await tester.runAsync(_buildController))!;
      addTearDown(controller.dispose);
      await tester.runAsync(
        () => controller.updateLanguage(AppLanguage.english),
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
        () => controller.updateLanguage(AppLanguage.traditionalChinese),
      );
      await tester.runAsync(() => controller.updateInterfaceScale(0.8));
      await tester.pump();

      appContext = tester.element(find.byType(Navigator).first);
      expect(Localizations.localeOf(appContext), const Locale('zh', 'TW'));
      expect(MediaQuery.textScalerOf(appContext).scale(10), closeTo(8, 0.0001));

      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
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
