import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/widgets/route_name_badge.dart';

void main() {
  group('routeBadgeLines', () {
    test('keeps short names whole', () {
      expect(routeBadgeLines('131'), ['131']);
      expect(routeBadgeLines('綠3'), ['綠3']);
      expect(routeBadgeLines('1661'), ['1661']);
    });

    test('breaks where the route number meets its wording', () {
      expect(routeBadgeLines('152區2'), ['152', '區2']);
      expect(routeBadgeLines('黃17末班'), ['黃17', '末班']);
      expect(routeBadgeLines('藍20不經三總'), ['藍20', '不經三總']);
      expect(routeBadgeLines('200跳蛙公車'), ['200', '跳蛙公車']);
      expect(routeBadgeLines('市民小巴4延'), ['市民小巴', '4延']);
      expect(routeBadgeLines('幸福霧臺1路'), ['幸福霧臺', '1路']);
    });

    test('drops separators and keeps brackets on the second line', () {
      expect(routeBadgeLines('19路 大灣→安平'), ['19路', '大灣→安平']);
      expect(routeBadgeLines('貓空左線-動物園線'), ['貓空左線', '動物園線']);
      expect(routeBadgeLines('F931-1630'), ['F931', '1630']);
      expect(routeBadgeLines('12(延駛飛機路)'), ['12', '(延駛飛機路)']);
    });

    test('keeps pure codes whole and halves other unbroken names', () {
      expect(routeBadgeLines('7327D'), ['7327D']);
      expect(routeBadgeLines('NWT16492'), ['NWT16492']);
      expect(routeBadgeLines('民權幹線去程半'), ['民權幹線', '去程半']);
    });

    test('has nothing to show for a blank name', () {
      expect(routeBadgeLines('  '), isEmpty);
    });
  });

  Widget buildBadge(String name) => MaterialApp(
    home: Center(child: RouteNameBadge(name: name)),
  );

  testWidgets('shows the whole route name, not its first characters', (
    tester,
  ) async {
    await tester.pumpWidget(buildBadge('131'));
    expect(find.text('131'), findsOneWidget);
    expect(tester.getSize(find.byType(RouteNameBadge)), const Size(52, 52));

    await tester.pumpWidget(buildBadge('市民小巴4延'));
    expect(find.text('市民小巴\n4延'), findsOneWidget);
    expect(tester.getSize(find.byType(RouteNameBadge)), const Size(52, 52));
  });

  testWidgets('falls back to a placeholder for a blank name', (tester) async {
    await tester.pumpWidget(buildBadge(''));
    expect(find.text('?'), findsOneWidget);
  });
}
