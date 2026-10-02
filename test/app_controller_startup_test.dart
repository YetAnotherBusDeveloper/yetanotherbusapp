import 'dart:async';

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
import 'package:taiwanbus_flutter/core/background_image_store.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final failCleanup in [false, true]) {
    test(
      'startup cleanup is deferred and serialized (failure=$failCleanup)',
      () async {
        final store = _DeferredCleanupStore();
        final storage = StorageService();
        await storage.saveSettings(
          AppSettings.defaults().copyWith(desktopDiscordPresenceEnabled: false),
        );
        const buildInfo = AppBuildInfo(
          version: '1.0.0',
          buildNumber: '1',
          gitSha: 'test',
          defaultUpdateChannel: AppUpdateChannel.release,
        );
        final controller = AppController(
          repository: _NoDatabaseRepository(),
          storage: storage,
          analytics: AppAnalytics.deferred(),
          buildInfo: buildInfo,
          appUpdateService: AppUpdateService(buildInfo: buildInfo),
          appUpdateInstaller: createAppUpdateInstaller(),
          authService: AuthService(),
          accountSyncService: AccountSyncService(),
          backgroundImageStore: store,
        );
        addTearDown(controller.dispose);

        await controller.initialize();
        expect(controller.initialized, isTrue);
        expect(store.cleanups, 0);
        expect(store.normalizations, [false]);

        final startup = controller.initializeAfterFirstFrame();
        await store.cleanupStarted.future;
        await controller.initializeAfterFirstFrame();
        expect(store.cleanups, 1);

        final update = controller.updatePageBackgroundImagePath('bus', 'new.png');
        await Future<void>.delayed(Duration.zero);
        // The new file cannot be imported until cleanup has finished.
        expect(store.normalizations, [false]);
        if (failCleanup) {
          store.cleanupFinished.completeError(StateError('cleanup failed'));
        } else {
          store.cleanupFinished.complete();
        }
        await update;
        await startup;
        expect(controller.settings.pageBackgroundImagePaths, {
          'bus': 'new.png',
        });
        expect((await storage.loadSettings()).pageBackgroundImagePaths, {
          'bus': 'new.png',
        });
        expect(store.normalizations, [false, true]);
      },
    );
  }
}

class _DeferredCleanupStore extends BackgroundImageStore {
  final cleanupStarted = Completer<void>();
  final cleanupFinished = Completer<void>();
  final normalizations = <bool>[];
  var cleanups = 0;

  @override
  Future<Map<String, String>> normalizeSettingsPaths(
    Map<String, String> paths, {
    bool cleanup = true,
  }) async {
    normalizations.add(cleanup);
    return Map.of(paths);
  }

  @override
  Future<void> cleanupUnusedImages(Iterable<String> referencedPaths) {
    cleanups++;
    cleanupStarted.complete();
    return cleanupFinished.future;
  }
}

class _NoDatabaseRepository extends BusRepository {
  @override
  Future<bool> databaseExists(BusProvider provider) async => false;
}
