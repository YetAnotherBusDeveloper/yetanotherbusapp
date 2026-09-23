import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/transit_name.dart';
import 'package:taiwanbus_flutter/widgets/transit_station_name.dart';

void main() {
  const name = TransitName(
    zh: '台北車站',
    en: 'Taipei Main Station',
    stableId: 'STOP-1',
  );

  testWidgets('Chinese locale shows only the Chinese station name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'TW'),
        supportedLocales: [Locale('zh', 'TW'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: TransitStationName(name: name)),
      ),
    );

    expect(find.text('台北車站'), findsOneWidget);
    expect(find.text('Taipei Main Station'), findsNothing);
  });

  testWidgets('foreign station name is smaller on the second line', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(body: TransitStationName(name: name)),
      ),
    );

    final chinese = tester.widget<Text>(find.text('台北車站'));
    final english = tester.widget<Text>(find.text('Taipei Main Station'));
    expect(english.style!.fontSize, lessThan(chinese.style!.fontSize!));
    expect(english.style!.color, isNot(chinese.style!.color));
    expect(
      tester.getTopLeft(find.text('Taipei Main Station')).dy,
      greaterThan(tester.getTopLeft(find.text('台北車站')).dy),
    );
  });
}
