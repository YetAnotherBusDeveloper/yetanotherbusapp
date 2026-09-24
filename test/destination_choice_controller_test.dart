import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

Future<AppController> _controller() async {
  const build = AppBuildInfo(
    version: '1.0.0',
    buildNumber: '1',
    gitSha: 'test',
    defaultUpdateChannel: AppUpdateChannel.release,
  );
  final controller = AppController(
    repository: BusRepository(),
    storage: StorageService(),
    analytics: await AppAnalytics.initialize(),
    buildInfo: build,
    appUpdateService: AppUpdateService(buildInfo: build),
    appUpdateInstaller: createAppUpdateInstaller(),
    authService: AuthService(),
    accountSyncService: AccountSyncService(),
  );
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('learns only after three matching choices within seven days', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final now = DateTime.now();

    for (var index = 0; index < 2; index++) {
      await controller.recordDestinationChoice(
        provider: BusProvider.nwt,
        routeKey: 12,
        departurePathId: 1,
        boardingStopId: 100,
        destinationPathId: 1,
        destinationStopId: 200,
        destinationStopName: 'Destination',
        selectedAt: now.subtract(Duration(days: index)),
      );
    }
    expect(
      controller.learnedDestinationChoice(
        provider: BusProvider.nwt,
        routeKey: 12,
        departurePathId: 1,
        boardingStopId: 100,
        now: now,
      ),
      isNull,
    );

    await controller.recordDestinationChoice(
      provider: BusProvider.nwt,
      routeKey: 12,
      departurePathId: 1,
      boardingStopId: 100,
      destinationPathId: 1,
      destinationStopId: 200,
      destinationStopName: 'Destination',
      selectedAt: now,
    );
    expect(
      controller
          .learnedDestinationChoice(
            provider: BusProvider.nwt,
            routeKey: 12,
            departurePathId: 1,
            boardingStopId: 100,
            now: now,
          )
          ?.destinationStopId,
      200,
    );
  });

  test('expired, direction, and boarding choices do not match', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final now = DateTime.now();
    for (var index = 0; index < 3; index++) {
      await controller.recordDestinationChoice(
        provider: BusProvider.tpe,
        routeKey: 500,
        departurePathId: 0,
        boardingStopId: 10,
        destinationPathId: 0,
        destinationStopId: 20,
        destinationStopName: 'Old destination',
        selectedAt: now.subtract(const Duration(days: 8)),
      );
    }

    DestinationChoiceProfile? choice({int path = 0, int stop = 10}) =>
        controller.learnedDestinationChoice(
          provider: BusProvider.tpe,
          routeKey: 500,
          departurePathId: path,
          boardingStopId: stop,
          now: now,
        );

    expect(choice(), isNull);
    expect(choice(path: 1), isNull);
    expect(choice(stop: 11), isNull);
  });

  test('manual destination updates latest matching route history', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    const route = RouteSummary(
      sourceProvider: 'nwt',
      hashMd5: '',
      routeKey: 12,
      routeId: '12',
      routeName: '12',
      officialRouteName: '12',
      description: '',
      category: '',
      sequence: 0,
      rtrip: 1,
    );
    await controller.addHistoryEntry(
      route,
      provider: BusProvider.nwt,
      pathId: 1,
    );

    await controller.updateLatestHistoryDestination(
      provider: BusProvider.nwt,
      routeKey: 12,
      departurePathId: 1,
      boardingStopId: 100,
      boardingStopName: 'Boarding',
      destinationPathId: 1,
      destinationStopId: 200,
      destinationStopName: 'Destination',
    );

    expect(controller.history.single.boardingStopId, 100);
    expect(controller.history.single.destinationStopId, 200);
  });
}
