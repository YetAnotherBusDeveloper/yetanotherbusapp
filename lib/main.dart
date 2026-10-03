import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app/bus_app.dart';
import 'core/announcement_push_service.dart';
import 'core/account_sync_service.dart';
import 'core/app_controller.dart';
import 'core/app_analytics.dart';
import 'core/app_build_info.dart';
import 'core/app_launch_service.dart';
import 'core/app_update_installer.dart';
import 'core/app_update_service.dart';
import 'core/api_user_agent.dart';
import 'core/auth_service.dart';
import 'core/bus_repository.dart';
import 'core/database_factory.dart';
import 'core/friendly_error.dart';
import 'core/storage_service.dart';
import 'core/ad_service.dart';

Future<void> main(List<String> args) async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  try {
    final (_, _, buildInfo) = await (
      configureDatabaseFactory(),
      AppLaunchService.instance.initialize(initialArguments: args),
      AppBuildInfo.load(),
    ).wait;
    final analytics = AppAnalytics.deferred();
    ApiUserAgent.configure(buildInfo);

    final controller = AppController(
      repository: BusRepository(),
      storage: StorageService(),
      analytics: analytics,
      buildInfo: buildInfo,
      appUpdateService: AppUpdateService(buildInfo: buildInfo),
      appUpdateInstaller: createAppUpdateInstaller(),
      authService: AuthService(),
      accountSyncService: AccountSyncService(),
    );
    await controller.initializeForFirstFrame();
    final automaticSeedPath = automaticBackgroundColorPath(controller.settings);
    final cachedSeed = await controller.storage.loadBackgroundColorCache(
      automaticSeedPath,
    );
    AdService.instance.deferUntil(widgetsBinding.waitUntilFirstFrameRasterized);
    runApp(
      BusApp(
        controller: controller,
        analytics: analytics,
        automaticSeedPath: automaticSeedPath,
        automaticSeedColor: cachedSeed == null ? null : Color(cachedSeed),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(controller.initializeAfterFirstFrame());
      unawaited(
        widgetsBinding.waitUntilFirstFrameRasterized.then((_) async {
          await Future<void>.delayed(Duration.zero);
          unawaited(analytics.start());
          unawaited(
            AnnouncementPushService.instance.initialize().catchError(
              (Object _) {},
            ),
          );
        }),
      );
    });
  } catch (error) {
    runApp(
      _StartupErrorApp(
        message: friendlyErrorMessage(error, fallback: '啓動時發生未預期的錯誤，請稍後再試。'),
        detail: '$error',
      ),
    );
  } finally {
    FlutterNativeSplash.remove();
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message, required this.detail});

  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '啓動失敗',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  if (detail != message) ...[
                    const SizedBox(height: 16),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
