import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/app_motion.dart';
import 'package:taiwanbus_flutter/widgets/app_content_transition.dart';

void main() {
  Widget content(Object state, {bool reduced = false, bool active = true}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: active,
            child: AppContentTransition(
              state: state,
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        ),
      );

  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(AppContentTransition),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets('state changes fade in place and refreshes do not restart it', (
    tester,
  ) async {
    await tester.pumpWidget(content('loading'));
    expect(opacity(tester), 1);
    final bounds = tester.getRect(find.byType(AppContentTransition));
    await tester.pumpWidget(content('content'));
    expect(opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 110));
    expect(opacity(tester), inExclusiveRange(0, 1));
    expect(tester.getRect(find.byType(AppContentTransition)), bounds);
    final halfway = opacity(tester);
    await tester.pumpWidget(content('content'));
    expect(opacity(tester), halfway);
    await tester.pump(AppMotion.standard);
    expect(opacity(tester), 1);
    for (final type in [ScaleTransition, SlideTransition]) {
      expect(
        find.descendant(
          of: find.byType(AppContentTransition),
          matching: find.byType(type),
        ),
        findsNothing,
      );
    }
  });

  testWidgets(
    'reduced motion and hidden panels finish transitions immediately',
    (tester) async {
      await tester.pumpWidget(content('loading'));
      await tester.pumpWidget(content('content'));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(content('content', reduced: true));
      expect(opacity(tester), 1);
      await tester.pumpWidget(content('error', reduced: true));
      expect(opacity(tester), 1);
      await tester.pumpWidget(content('hidden', active: false));
      expect(opacity(tester), 1);
      await tester.pumpWidget(content('hidden'));
      expect(opacity(tester), 1);
    },
  );

  testWidgets('rapid state re-entry retains only the current child', (
    tester,
  ) async {
    Widget progress(bool loading) => MaterialApp(
      home: AppContentTransition(
        state: loading,
        child: loading
            ? const LinearProgressIndicator(key: ValueKey('progress'))
            : const LinearProgressIndicator(
                key: ValueKey('countdown'),
                value: 0.5,
              ),
      ),
    );
    await tester.pumpWidget(progress(true));
    await tester.pumpWidget(progress(false));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(progress(true));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(progress(false));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('content changes retain one subtree and its scroll position', (
    tester,
  ) async {
    final key = GlobalKey();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    Widget page(int revision) => MaterialApp(
      home: AppContentTransition(
        state: revision,
        child: ListView.builder(
          key: key,
          controller: scroll,
          itemExtent: 50,
          itemCount: 100,
          itemBuilder: (_, index) => Text('row $index'),
        ),
      ),
    );
    await tester.pumpWidget(page(1));
    scroll.jumpTo(400);
    await tester.pump();
    await tester.pumpWidget(page(2));
    await tester.pump(const Duration(milliseconds: 110));
    expect(scroll.offset, 400);
    expect(find.byKey(key), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page navigation fades without changing page geometry', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    const pageKey = ValueKey('destination');
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: ThemeData(pageTransitionsTheme: AppMotion.pageTransitions),
        home: const Scaffold(body: Text('home')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(key: pageKey, body: Text('destination')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(tester.getTopLeft(find.byKey(pageKey)), Offset.zero);
    final fade = find.ancestor(
      of: find.byKey(pageKey),
      matching: find.byType(FadeTransition),
    );
    expect(
      tester.widget<FadeTransition>(fade.first).opacity.value,
      inExclusiveRange(0, 1),
    );
    expect(
      find.ancestor(
        of: find.byKey(pageKey),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byKey(pageKey), findsNothing);
  });
}
