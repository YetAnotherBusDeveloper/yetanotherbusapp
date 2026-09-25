import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/widgets/eta_badge.dart';

void main() {
  const stop = StopInfo(
    routeKey: 1,
    pathId: 0,
    stopId: 1,
    stopName: '測試站',
    sequence: 1,
    lon: 121.5,
    lat: 25,
    sec: 120,
  );

  Widget buildBadge({required bool isLoading}) {
    return MaterialApp(
      locale: const Locale('zh', 'TW'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: EtaBadge(
            stop: stop,
            alwaysShowSeconds: false,
            isLoading: isLoading,
          ),
        ),
      ),
    );
  }

  testWidgets('crossfades from loading to ETA without resizing', (
    tester,
  ) async {
    await tester.pumpWidget(buildBadge(isLoading: true));
    final badge = find.byType(EtaBadge);
    expect(tester.getSize(badge), const Size(58, 58));
    expect(find.text('載入中'), findsOneWidget);

    await tester.pumpWidget(buildBadge(isLoading: false));
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.text('載入中'), findsOneWidget);
    expect(find.text('2分'), findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.byType(ScaleTransition)),
      findsNothing,
    );
    final etaFade = find.ancestor(
      of: find.text('2分'),
      matching: find.byType(FadeTransition),
    );
    expect(
      tester.widget<FadeTransition>(etaFade.first).opacity.value,
      inExclusiveRange(0, 1),
    );
    expect(tester.getSize(badge), const Size(58, 58));

    await tester.pump(const Duration(milliseconds: 420));
    expect(find.text('載入中'), findsNothing);
    expect(find.text('2分'), findsOneWidget);
  });

  testWidgets('rail ETA changes fade without moving or resizing', (
    tester,
  ) async {
    Widget build(int seconds) => MaterialApp(
      locale: const Locale('zh', 'TW'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(child: GenericEtaBadge(seconds: seconds)),
    );
    await tester.pumpWidget(build(120));
    final bounds = tester.getRect(find.byType(GenericEtaBadge));
    await tester.pumpWidget(build(60));
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.text('2分'), findsOneWidget);
    expect(find.text('1分'), findsOneWidget);
    expect(tester.getRect(find.byType(GenericEtaBadge)), bounds);
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('2分'), findsNothing);
    expect(find.text('1分'), findsOneWidget);
  });

  testWidgets('dark generic ETA uses a deep background and white text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: const GenericEtaBadge(seconds: 300, darkBackground: true),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(GenericEtaBadge),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    final text = tester.widget<Text>(find.text('5分'));

    expect(
      HSLColor.fromColor(decoration.color!).lightness,
      lessThanOrEqualTo(0.33),
    );
    expect(text.style?.color, Colors.white);
  });
}
