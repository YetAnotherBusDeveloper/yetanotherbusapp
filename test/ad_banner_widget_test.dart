import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Exercise the real SDK lifecycle with fake native replies and callbacks.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/ad_service.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/widgets/ad_banner_widget.dart';

import 'support/ad_test_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppController controller;
  final calls = <MethodCall>[];
  Completer<AdSize?>? pendingSize;
  Completer<int?>? pendingAnchoredSize;

  List<BannerAd> banners() => calls
      .where((call) => call.method == 'loadBannerAd')
      .map((call) => instanceManager.adFor(call.arguments['adId']) as BannerAd?)
      .whereType<BannerAd>()
      .toList();
  int loadCount() =>
      calls.where((call) => call.method == 'loadBannerAd').length;
  int disposeCount() =>
      calls.where((call) => call.method == 'disposeAd').length;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = await createAdTestController();
    calls.clear();
    pendingSize = null;
    pendingAnchoredSize = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'MobileAds#initialize':
          return InitializationStatus({});
        case 'AdSize#getAnchoredAdaptiveBannerAdSize':
          return pendingAnchoredSize?.future ?? Future.value(50);
        case 'getAdSize':
          final ad = instanceManager.adFor(call.arguments['adId']) as BannerAd;
          return pendingSize?.future ??
              Future.value(AdSize(width: ad.size.width, height: 64));
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') return 1;
      if (call.method == 'resize') {
        return {
          'width': call.arguments['width'],
          'height': call.arguments['height'],
        };
      }
      return null;
    });
  });

  tearDown(() {
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Future<void> pumpBanner(
    WidgetTester tester, {
    double width = 300,
    int minimumDensity = 1,
    bool isInline = true,
    bool isActive = true,
    bool tickerEnabled = true,
    Orientation orientation = Orientation.portrait,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppControllerScope(
          controller: controller,
          child: MediaQuery(
            data: MediaQueryData(
              size: orientation == Orientation.portrait
                  ? const Size(400, 800)
                  : const Size(800, 400),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  child: TickerMode(
                    enabled: tickerEnabled,
                    child: AdBannerWidget(
                      minimumDensity: minimumDensity,
                      isInline: isInline,
                      isActive: isActive,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void adTestWidgets(String name, WidgetTesterCallback callback) {
    testWidgets(name, (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await callback(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  adTestWidgets('density, master switch and inactive pages prevent requests', (
    tester,
  ) async {
    await pumpBanner(tester, minimumDensity: 3);
    expect(loadCount(), 0);
    await controller.updateAdDensity(3);
    await tester.pump();
    await tester.pump();
    expect(loadCount(), 1);
    expect(banners().single.adUnitId, AdService.bannerAdUnitId);
    await controller.updateEnableAds(false);
    await tester.pump();
    expect(disposeCount(), 1);
    expect(tester.getSize(find.byType(AdBannerWidget)).height, 0);
    await controller.updateEnableAds(true);
    await pumpBanner(tester, isActive: false);
    expect(loadCount(), 1);
    await pumpBanner(tester, tickerEnabled: false);
    expect(loadCount(), 1);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await pumpBanner(tester);
    expect(loadCount(), 1);
  });

  adTestWidgets(
    'inline uses parent width, native height and no empty padding',
    (tester) async {
      await pumpBanner(tester, width: 280);
      final ad = banners().single;
      expect(ad.size.width, 280);
      expect((ad.size as InlineAdaptiveSize).maxHeight, 100);
      expect(tester.getSize(find.byType(AdBannerWidget)).height, 0);
      ad.listener.onAdLoaded!(ad);
      await tester.pump();
      await tester.pump();
      expect(find.byType(AdWidget), findsOneWidget);
      expect(tester.getSize(find.byType(AdWidget)), const Size(280, 64));
      expect(tester.getSize(find.byType(AdBannerWidget)).height, 88);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(disposeCount(), 1);
    },
  );

  adTestWidgets(
    'late load and failure callbacks cannot resurrect a disabled slot',
    (tester) async {
      await controller.updateAdDensity(4);
      await pumpBanner(tester, minimumDensity: 4);
      final oldAd = banners().single;
      pendingSize = Completer<AdSize?>();
      oldAd.listener.onAdLoaded!(oldAd);
      await tester.pump();
      await controller.updateAdDensity(1);
      await tester.pump();
      pendingSize!.complete(const AdSize(width: 300, height: 64));
      oldAd.listener.onAdFailedToLoad!(
        oldAd,
        LoadAdError(3, 'test', 'no fill', null),
      );
      await tester.pump();
      expect(find.byType(AdWidget), findsNothing);
      expect(disposeCount(), 1);
      expect(tester.takeException(), isNull);
    },
  );

  adTestWidgets('resizing and rotation replace ads and ignore old callbacks', (
    tester,
  ) async {
    await pumpBanner(tester);
    final oldAd = banners().single;
    await pumpBanner(tester, width: 240);
    expect(loadCount(), 2);
    expect(disposeCount(), 1);
    oldAd.listener.onAdLoaded!(oldAd);
    await tester.pump();
    expect(find.byType(AdWidget), findsNothing);
    expect(banners().single.size.width, 240);
    await pumpBanner(tester, width: 240, orientation: Orientation.landscape);
    expect(loadCount(), 3);
    expect(disposeCount(), 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposeCount(), 3);
  });

  adTestWidgets(
    'failed requests collapse and do not retry on unrelated updates',
    (tester) async {
      await pumpBanner(tester);
      final ad = banners().single;
      ad.listener.onAdFailedToLoad!(
        ad,
        LoadAdError(3, 'test', 'no fill', null),
      );
      await tester.pump();
      expect(disposeCount(), 1);
      expect(tester.getSize(find.byType(AdBannerWidget)).height, 0);
      controller.notifyListeners();
      await tester.pump();
      expect(loadCount(), 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(disposeCount(), 1);
    },
  );

  adTestWidgets('disabling during anchored sizing prevents a late request', (
    tester,
  ) async {
    pendingAnchoredSize = Completer<int?>();
    await pumpBanner(tester, isInline: false);
    expect(loadCount(), 0);
    await controller.updateEnableAds(false);
    await tester.pump();
    pendingAnchoredSize!.complete(50);
    await tester.pump();
    expect(loadCount(), 0);
    expect(tester.takeException(), isNull);
  });
}
