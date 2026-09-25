import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';

void main() {
  test('language and interface scale have device defaults and round trip', () {
    final defaults = AppSettings.defaults();
    expect(defaults.language, AppLanguage.system);
    expect(defaults.interfaceScale, AppSettings.defaultInterfaceScale);

    final restored = AppSettings.fromJson(
      defaults
          .copyWith(
            language: AppLanguage.traditionalChinese,
            interfaceScale: 1.2,
          )
          .toJson(),
    );

    expect(restored.language, AppLanguage.traditionalChinese);
    expect(restored.interfaceScale, 1.2);
  });

  test('invalid language and scale JSON safely normalize', () {
    expect(
      AppSettings.fromJson(const {'language': 'unknown'}).language,
      AppLanguage.system,
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
