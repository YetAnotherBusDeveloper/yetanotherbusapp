import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/account_sync_service.dart';
import 'package:taiwanbus_flutter/core/app_analytics.dart';
import 'package:taiwanbus_flutter/core/app_build_info.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/app_launch_service.dart';
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';
import 'package:taiwanbus_flutter/screens/account_screen.dart';

class _FakeAuthService extends AuthService {
  AuthSession? _session;

  @override
  AuthSession? get session => _session;

  @override
  Future<void> completeCallback({
    required String token,
    required String accountId,
    required String deviceId,
    required String role,
    required String provider,
    required String displayName,
  }) async {
    _session = AuthSession(
      token: token,
      accountId: accountId,
      deviceId: deviceId,
      role: role,
      provider: provider,
      displayName: displayName,
    );
  }

  @override
  Future<AuthAccount> fetchAccount() async => const AuthAccount(
    accountId: 'test-account',
    deviceId: 'test-device',
    role: 'user',
    device: null,
    identities: [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('route history requires explicit confirmation and starts off', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final buildInfo = AppBuildInfo(
      version: '1.0.0',
      buildNumber: '1',
      gitSha: 'test',
      defaultUpdateChannel: AppUpdateChannel.release,
    );
    final controller = AppController(
      repository: BusRepository(),
      storage: StorageService(),
      analytics: await AppAnalytics.initialize(),
      buildInfo: buildInfo,
      appUpdateService: AppUpdateService(buildInfo: buildInfo),
      appUpdateInstaller: createAppUpdateInstaller(),
      authService: _FakeAuthService(),
      accountSyncService: AccountSyncService(),
    );
    await controller.completeAuthCallback(
      const AppLaunchAction(
        target: AppLaunchTarget.authCallback,
        authToken: 'test-token',
        authAccountId: 'test-account',
        authDeviceId: 'test-device',
        authRole: 'user',
        authProvider: 'test',
        authDisplayName: 'Test User',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppControllerScope(
          controller: controller,
          child: const AccountScreen(),
        ),
      ),
    );
    await tester.pump();

    final routeHistorySwitch = find.widgetWithText(SwitchListTile, '同步路線紀錄');
    expect(routeHistorySwitch, findsOneWidget);
    expect(controller.routeHistorySyncEnabled, isFalse);
    expect(find.text('選擇性功能，預設關閉。'), findsOneWidget);

    await tester.tap(routeHistorySwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('同步路線紀錄？'), findsOneWidget);
    expect(find.textContaining('這不包含定位資料'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.routeHistorySyncEnabled, isFalse);

    await tester.tap(routeHistorySwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('開啓同步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.routeHistorySyncEnabled, isTrue);
    expect(find.text('已允許同步，開啓雲端同步後才會上傳。'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
