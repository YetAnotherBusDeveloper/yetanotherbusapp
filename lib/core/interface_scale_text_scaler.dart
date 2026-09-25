import 'package:flutter/widgets.dart';

@immutable
class InterfaceScaleTextScaler implements TextScaler {
  const InterfaceScaleTextScaler({
    required this.systemTextScaler,
    required this.interfaceScale,
  }) : assert(interfaceScale > 0 && interfaceScale < double.infinity);

  final TextScaler systemTextScaler;
  final double interfaceScale;

  @override
  double scale(double fontSize) =>
      systemTextScaler.scale(fontSize) * interfaceScale;

  @override
  double get textScaleFactor => scale(1);

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) {
    assert(maxScaleFactor >= minScaleFactor);
    return InterfaceScaleTextScaler(
      systemTextScaler: systemTextScaler.clamp(
        minScaleFactor: minScaleFactor / interfaceScale,
        maxScaleFactor: maxScaleFactor / interfaceScale,
      ),
      interfaceScale: interfaceScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InterfaceScaleTextScaler &&
      other.systemTextScaler == systemTextScaler &&
      other.interfaceScale == interfaceScale;

  @override
  int get hashCode => Object.hash(systemTextScaler, interfaceScale);
}
