import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/interface_scale_text_scaler.dart';

void main() {
  test('composes accessibility and interface scaling', () {
    const scaler = InterfaceScaleTextScaler(
      systemTextScaler: TextScaler.linear(1.5),
      interfaceScale: 1.2,
    );

    expect(scaler.scale(10), closeTo(18, 0.0001));
  });

  test('has value semantics', () {
    const first = InterfaceScaleTextScaler(
      systemTextScaler: TextScaler.linear(1.5),
      interfaceScale: 1.2,
    );
    const same = InterfaceScaleTextScaler(
      systemTextScaler: TextScaler.linear(1.5),
      interfaceScale: 1.2,
    );
    const different = InterfaceScaleTextScaler(
      systemTextScaler: TextScaler.linear(1.5),
      interfaceScale: 1.1,
    );

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(different));
  });
}
