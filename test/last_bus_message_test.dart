import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/last_bus_message.dart';

void main() {
  test('recognizes normalized final-bus departure messages', () {
    for (final message in <String>[
      '末班駛離',
      '末班已過',
      '末班車已過',
      ' 末班車：已經駛離。 ',
      '本日最後一班公車，已離站！',
      '末班車已開走',
    ]) {
      expect(isLastBusMessage(message), isTrue, reason: message);
    }
  });

  test('does not treat future or informational final-bus text as departed', () {
    for (final message in <String?>[
      null,
      '',
      '末班車 23:00',
      '末班車尚未駛離',
      '末班車即將進站',
      '一般班次已過站',
    ]) {
      expect(isLastBusMessage(message), isFalse, reason: '$message');
    }
  });
}
