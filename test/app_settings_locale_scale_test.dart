import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';

void main() {
  test('language and interface scale have device defaults and round trip', () {
    final defaults = AppSettings.defaults();
    expect(defaults.language, isNull);
    expect(defaults.toJson()['language'], isNull);
    expect(defaults.interfaceScale, AppSettings.defaultInterfaceScale);

    final restored = AppSettings.fromJson(
      defaults
          .copyWith(language: const Locale('zh', 'TW'), interfaceScale: 1.2)
          .toJson(),
    );

    expect(restored.language, const Locale('zh', 'TW'));
    expect(restored.toJson()['language'], 'zh-TW');
    expect(restored.interfaceScale, 1.2);
  });

  test('supported locales round trip and copyWith clears to system', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final settings = AppSettings.defaults().copyWith(language: locale);
      expect(settings.toJson()['language'], locale.toLanguageTag());
      expect(AppSettings.fromJson(settings.toJson()).language, locale);
      expect(settings.copyWith().language, locale);
      final system = settings.copyWith(language: null);
      expect(system.language, isNull);
      expect(AppSettings.fromJson(system.toJson()).language, isNull);
    }
  });

  test('invalid language and scale JSON safely normalize', () {
    expect(
      AppSettings.fromJson(const {'language': 'unknown'}).language,
      isNull,
    );
    expect(AppSettings.fromJson(const {'language': ''}).language, isNull);
    expect(
      AppSettings.fromJson(const {'language': 'traditionalChinese'}).language,
      isNull,
    );
    expect(
      AppSettings.fromJson(const {'interfaceScale': 0.2}).interfaceScale,
      AppSettings.minInterfaceScale,
    );
    expect(
      AppSettings.fromJson(const {'interfaceScale': 5.0}).interfaceScale,
      AppSettings.maxInterfaceScale,
    );
    expect(
      AppSettings.fromJson({'interfaceScale': double.nan}).interfaceScale,
      AppSettings.defaultInterfaceScale,
    );
    expect(
      AppSettings.fromJson({'interfaceScale': double.infinity}).interfaceScale,
      AppSettings.defaultInterfaceScale,
    );
    expect(
      AppSettings.fromJson(const {'interfaceScale': 'large'}).interfaceScale,
      AppSettings.defaultInterfaceScale,
    );
  });

  test('copyWith normalizes interface scale through the constructor', () {
    final defaults = AppSettings.defaults();

    expect(
      defaults.copyWith(interfaceScale: -1).interfaceScale,
      AppSettings.minInterfaceScale,
    );
    expect(
      defaults.copyWith(interfaceScale: double.nan).interfaceScale,
      AppSettings.defaultInterfaceScale,
    );
  });
}
