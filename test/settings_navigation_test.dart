import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/ad_service.dart';
import 'package:taiwanbus_flutter/core/app_build_info.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/screens/account_screen.dart';
import 'package:taiwanbus_flutter/screens/adaptive_settings_presenter.dart';
import 'package:taiwanbus_flutter/screens/database_settings_screen.dart';
import 'package:taiwanbus_flutter/screens/settings_screen.dart';
import 'package:taiwanbus_flutter/widgets/ad_density_setting.dart';

import 'support/ad_test_controller.dart';

const _wearChannel = MethodChannel('tw.avianjay.taiwanbus.flutter/wear_os');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_wearChannel, null);
  });

  for (final width in [390.0, 1400.0]) {
    _settingsTest('category back and settings dismissal at width $width', (
      tester,
    ) async {
      await _pumpHost(tester, width: width);
      expect(
        find.byType(Dialog),
        width >= 1100 ? findsOneWidget : findsNothing,
      );
      expect(find.text('設定'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(Slider), findsNothing);

      await _openCategory(tester, '外觀');
      expect(find.text('外觀'), findsOneWidget);
      expect(find.text('設定'), findsNothing);
      expect(find.byType(SwitchListTile), findsWidgets);
      expect(find.text('使用與更新'), findsNothing);
      expect(
        find.byType(Dialog),
        width >= 1100 ? findsOneWidget : findsNothing,
      );

      if (width >= 1100) {
        await tester.tap(find.byType(BackButton));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('設定'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Open settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    _settingsTest('restart onboarding closes all settings at width $width', (
      tester,
    ) async {
      final controller = await _pumpHost(tester, width: width);
      expect(controller.needsOnboarding, isFalse);
      await _openCategory(tester, '開始流程');
      await tester.tap(find.text('重新執行開始流程'));
      await tester.pumpAndSettle();
      expect(controller.needsOnboarding, isTrue);
      expect(
        (await StorageService().loadSettings()).hasCompletedOnboarding,
        isFalse,
      );
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dismissWithEscape in [false, true]) {
    for (final openCategory in [false, true]) {
      _settingsTest(
        'desktop dismiss via ${dismissWithEscape ? 'Escape' : 'scrim'} with category=$openCategory',
        (tester) async {
          await _pumpHost(tester, width: 1400);
          if (openCategory) {
            await _openCategory(tester, '外觀');
          }

          if (dismissWithEscape) {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          } else {
            await tester.tapAt(const Offset(10, 10));
          }
          await tester.pumpAndSettle();

          expect(find.byType(SettingsScreen), findsNothing);
          expect(find.byType(Dialog), findsNothing);
          expect(find.text('Open settings'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  _settingsTest('full-page settings preserve category back at desktop width', (
    tester,
  ) async {
    await _pumpHost(tester, width: 1400, adaptive: false);
    expect(find.byType(Dialog), findsNothing);
    await _openCategory(tester, '外觀');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _settingsTest('settings persist when moving between categories', (
    tester,
  ) async {
    final controller = await _pumpHost(tester);
    await _openCategory(tester, '外觀');
    final compact = find.widgetWithText(SwitchListTile, '精簡模式');
    await tester.ensureVisible(compact);
    await tester.tap(compact);
    await tester.pumpAndSettle();
    expect(controller.settings.enableCompactMode, isTrue);
    expect((await StorageService().loadSettings()).enableCompactMode, isTrue);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await _openCategory(tester, '使用與更新');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await _openCategory(tester, '外觀');
    expect(tester.widget<SwitchListTile>(compact).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('zh', 'TW'), const Locale('en')]) {
    _settingsTest('compact descriptions switch with the setting in $locale', (
      tester,
    ) async {
      final controller = await _pumpHost(tester, height: 3000, locale: locale);
      final l10n = lookupAppLocalizations(locale);
      await _openCategory(tester, l10n.appearanceSectionTitle);
      expect(find.text(l10n.languageDescription), findsOneWidget);

      final compact = find.widgetWithText(
        SwitchListTile,
        l10n.compactModeTitle,
      );
      await tester.tap(compact);
      await tester.pumpAndSettle();
      expect(find.text(l10n.languageDescriptionCompact), findsOneWidget);
      expect(find.text(l10n.showWeatherDescriptionCompact), findsOneWidget);
      expect(find.text(l10n.interfaceScaleDescriptionCompact), findsOneWidget);
      expect(find.text(l10n.compactModeDescription), findsOneWidget);
      expect(find.text(l10n.languageDescription), findsNothing);
      expect(find.text(l10n.showWeatherDescription), findsNothing);

      await tester.tap(
        find.widgetWithText(ListTile, l10n.personalizationTitle),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.personalizationAmoledDescriptionCompact),
        findsOneWidget,
      );
      expect(
        find.text(l10n.personalizationHomeGradientDescriptionCompact),
        findsOneWidget,
      );
      expect(
        find.text(l10n.personalizationPerPageDescriptionCompact),
        findsOneWidget,
      );
      expect(
        find.text(l10n.personalizationBackgroundImageDescriptionCompact),
        findsOneWidget,
      );
      expect(find.text(l10n.personalizationAmoledDescription), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await controller.updateDatabaseAutoUpdateMode(
        DatabaseAutoUpdateMode.cellularOnly,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(l10n.databaseAutoUpdateCellular),
        findsOneWidget,
      );
      await _openCategory(tester, l10n.usageAndUpdatesTitle);
      expect(
        find.text(l10n.alwaysShowSecondsDescriptionCompact),
        findsOneWidget,
      );
      expect(
        find.text(l10n.normalUpdateIntervalDescriptionCompact),
        findsOneWidget,
      );
      expect(find.text(l10n.alwaysShowSecondsDescription), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await _openCategory(tester, l10n.appearanceSectionTitle);
      await tester.tap(compact);
      await tester.pumpAndSettle();
      expect(controller.settings.enableCompactMode, isFalse);
      expect(find.text(l10n.languageDescription), findsOneWidget);
      expect(find.text(l10n.showWeatherDescription), findsOneWidget);
      expect(find.text(l10n.languageDescriptionCompact), findsNothing);
      expect(tester.takeException(), isNull);
    });

    _settingsTest(
      'compact ad descriptions follow enabled and locked states in $locale',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final controller = await _pumpHost(
          tester,
          height: 3000,
          locale: locale,
        );
        final l10n = lookupAppLocalizations(locale);
        await controller.updateEnableCompactMode(true);
        await tester.pumpAndSettle();
        await _openCategory(tester, l10n.usageAndUpdatesTitle);
        final ads = find.widgetWithText(SwitchListTile, l10n.showAdsTitle);
        final pleas = RegExp(
          [
            l10n.adsPleaOne,
            l10n.adsPleaTwo,
            l10n.adsPleaThree,
            l10n.adsPleaFour,
          ].map(RegExp.escape).join('|'),
        );
        expect(tester.widget<SwitchListTile>(ads).value, isTrue);
        expect(find.text(l10n.adsEnabledDescription), findsOneWidget);
        expect(find.byType(AdDensitySetting), findsOneWidget);

        await tester.tap(ads);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(l10n.adsDisableDescription), findsOneWidget);
        expect(controller.settings.enableAds, isTrue);
        await tester.tap(find.text(l10n.adsDisableConfirm));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(ads).value, isFalse);
        expect(find.textContaining(l10n.adsDisabledStatus), findsOneWidget);
        expect(
          find.descendant(of: ads, matching: find.textContaining(pleas)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: ads, matching: find.byType(Image)),
          findsOneWidget,
        );
        expect(find.text(l10n.adsEnabledDescription), findsNothing);
        expect(find.byType(AdDensitySetting), findsNothing);

        await tester.tap(ads);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(ads).value, isTrue);
        expect(find.text(l10n.adsEnabledDescription), findsOneWidget);
        expect(find.textContaining(l10n.adsDisabledStatus), findsNothing);

        for (var index = 0; index < 4; index++) {
          await tester.tap(ads);
          await tester.pumpAndSettle();
        }
        expect(controller.settings.enableAds, isTrue);
        expect(tester.widget<SwitchListTile>(ads).onChanged, isNull);
        expect(
          find.textContaining(l10n.adsLockedMessageCompact),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: ads,
            matching: find.textContaining(l10n.adsLockedMessage.trim()),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: ads, matching: find.byType(Image)),
          findsOneWidget,
        );
        expect(find.textContaining(l10n.adsDisabledStatus), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  _settingsTest('catalog and category scroll positions are restored', (
    tester,
  ) async {
    await _pumpHost(tester, width: 320, height: 400);
    final usage = find.widgetWithText(ListTile, '使用與更新');
    await tester.scrollUntilVisible(usage, 200);
    await Scrollable.ensureVisible(tester.element(usage), alignment: 0.5);
    await tester.pumpAndSettle();
    final catalogOffset = _scrollOffset(tester);
    expect(catalogOffset, greaterThan(0));
    await tester.tap(usage);
    await tester.pumpAndSettle();
    expect(_scrollOffset(tester), 0);
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    final usageOffset = _scrollOffset(tester);
    expect(usageOffset, greaterThan(0));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(_scrollOffset(tester), closeTo(catalogOffset, 1));
    await tester.tap(usage);
    await tester.pumpAndSettle();
    expect(_scrollOffset(tester), closeTo(usageOffset, 1));
    expect(tester.takeException(), isNull);
  });

  _settingsTest('account and database categories open existing pages', (
    tester,
  ) async {
    await _pumpHost(tester);
    await _openCategory(tester, '帳戶');
    expect(find.byType(AccountScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
    await _openCategory(tester, '資料庫與下載');
    expect(find.byType(DatabaseSettingsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
  ]) {
    for (final connected in [false, true]) {
      _settingsTest(
        'Wear OS visibility on $platform with connected=$connected',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(_wearChannel, (call) async {
                if (call.method == 'getWearSyncStatus') {
                  return {
                    'connectedNodeCount': connected ? 1 : 0,
                    'connectedNodeNames': connected
                        ? ['Test Watch']
                        : <String>[],
                  };
                }
                return null;
              });
          await _pumpHost(tester);
          final visible = platform == TargetPlatform.android && connected;
          expect(find.text('Wear OS'), visible ? findsOneWidget : findsNothing);
          expect(
            find.text('App 更新'),
            AppBuildInfo.isAabBuild ? findsNothing : findsOneWidget,
          );
          if (visible) {
            await _openCategory(tester, 'Wear OS');
            expect(find.textContaining('Test Watch'), findsOneWidget);
            expect(
              find.widgetWithText(SwitchListTile, '啓用 Wear OS 同步'),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  _settingsTest('ad toggle confirmation and count survive category changes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = await _pumpHost(tester);
    for (var index = 0; index < 6; index++) {
      await _openCategory(tester, '使用與更新');
      final ads = find.widgetWithText(SwitchListTile, '顯示廣告');
      await tester.ensureVisible(ads);
      await tester.tap(ads);
      await tester.pumpAndSettle();
      if (index == 0) {
        expect(find.byType(AlertDialog), findsOneWidget);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AlertDialog)),
        );
        await tester.tap(find.text(l10n.adsDisableConfirm));
        await tester.pumpAndSettle();
      } else {
        expect(find.byType(AlertDialog), findsNothing);
      }
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    expect(controller.settings.enableAds, isTrue);
    expect(await AdService.instance.isAdToggleLocked(), isTrue);
    await _openCategory(tester, '使用與更新');
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '顯示廣告'))
          .onChanged,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('zh', 'TW'), const Locale('en')]) {
    for (final compactMode in [false, true]) {
      _settingsTest(
        'all categories fit narrow screens with large text in $locale with compact=$compactMode',
        (tester) async {
          final controller = await _pumpHost(
            tester,
            width: 320,
            height: 568,
            scale: 1.8,
            locale: locale,
          );
          if (compactMode) {
            await controller.updateEnableCompactMode(true);
            await tester.pumpAndSettle();
          }
          final l10n = lookupAppLocalizations(locale);
          for (final title in [
            l10n.appearanceSectionTitle,
            l10n.usageAndUpdatesTitle,
            if (!AppBuildInfo.isAabBuild) l10n.appUpdatesTitle,
            l10n.historyPrivacyTitle,
            l10n.onboardingSettingsTitle,
            l10n.aboutTitle,
          ]) {
            await _openCategory(tester, title);
            await tester.drag(find.byType(ListView), const Offset(0, -1200));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

double _scrollOffset(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

Future<void> _openCategory(WidgetTester tester, String title) async {
  final tile = find.widgetWithText(ListTile, title);
  await tester.scrollUntilVisible(
    tile,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(tile), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<AppController> _pumpHost(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double scale = 1,
  Locale locale = const Locale('zh', 'TW'),
  bool adaptive = true,
}) async {
  final controller = await createAdTestController(
    repository: _SettingsRepository(),
  );
  await controller.setOnboardingCompleted(true);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AppControllerScope(
      controller: controller,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () {
                  if (adaptive) {
                    openAdaptiveSettingsScreen(context);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  }
                },
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open settings'));
  await tester.pumpAndSettle();
  return controller;
}

void _settingsTest(String description, WidgetTesterCallback test) {
  testWidgets(description, (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await test(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}

class _SettingsRepository extends BusRepository {
  @override
  Future<int?> getLocalVersion(BusProvider provider) async => null;
}
