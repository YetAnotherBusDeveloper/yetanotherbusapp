import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/ad_service.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';
import 'package:taiwanbus_flutter/widgets/ad_density_setting.dart';

import 'support/ad_test_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy and malformed density preserve other settings', () {
    expect(AppSettings.defaults().adDensity, 1);
    for (final value in [null, '4', 2.5, true, [], {}]) {
      final restored = AppSettings.fromJson({
        'enableAds': false,
        'adDensity': value,
      });
      expect(restored.adDensity, 1);
      expect(restored.enableAds, isFalse);
    }
    expect(AppSettings.fromJson({'adDensity': -5}).adDensity, 1);
    expect(AppSettings.fromJson({'adDensity': 9}).adDensity, 4);
    for (var density = 1; density <= 4; density++) {
      final settings = AppSettings.defaults().copyWith(adDensity: density);
      expect(AppSettings.fromJson(settings.toJson()).adDensity, density);
    }
  });

  test(
    'density persists through ad toggles without locking the toggle',
    () async {
      final controller = await createAdTestController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);
      for (var index = 0; index < 8; index++) {
        await controller.updateAdDensity(index % 4 + 1);
      }
      expect(notifications, 8);
      await controller.updateEnableAds(false);
      var restored = await StorageService().loadSettings();
      expect(restored.enableAds, isFalse);
      expect(restored.adDensity, 4);
      await controller.updateEnableAds(true);
      restored = await StorageService().loadSettings();
      expect(restored.enableAds, isTrue);
      expect(restored.adDensity, 4);
      expect(await AdService.instance.isAdToggleLocked(), isFalse);
      await controller.updateAdDensity(99);
      expect(controller.settings.adDensity, 4);
    },
  );

  for (final width in [320.0, 780.0]) {
    testWidgets('selector images and text fit at width $width', (tester) async {
      final controller = await createAdTestController();
      addTearDown(controller.dispose);
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: AppControllerScope(
            controller: controller,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: AdDensitySetting(),
                ),
              ),
            ),
          ),
        ),
      );
      const assets = ['unshock', 'shock', 'cringe', 'scared'];
      const messages = [
        '感謝支持',
        '哇 感謝你的支持<3',
        '謝謝謝謝謝謝謝謝謝謝',
        '哥們你真的很愛看廣告嗎 那很謝謝你了',
      ];
      for (var level = 1; level <= 4; level++) {
        await tester.tap(find.text('$level'));
        await tester.pumpAndSettle();
        expect(controller.settings.adDensity, level);
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as AssetImage).assetName,
          'assets/cat_${assets[level - 1]}.jpg',
        );
        expect(tester.getSize(find.byType(Image)), const Size(20, 20));
        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expect(tile.subtitle, isA<Text>());
        expect((tile.subtitle as Text).textSpan, isA<TextSpan>());
        expect(find.textContaining(messages[level - 1]), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await controller.updateEnableAds(false);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .onSelectionChanged,
        isNull,
      );
      expect(controller.settings.adDensity, 4);
    });
  }
}
