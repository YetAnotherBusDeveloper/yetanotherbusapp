import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/app_analytics.dart';

void main() {
  testWidgets('slow analytics does not block UI or settings events', (
    tester,
  ) async {
    final ready = Completer<FirebaseAnalytics?>();
    var starts = 0;
    final analytics = AppAnalytics.deferred(
      initializer: () {
        starts++;
        return ready.future;
      },
    );
    expect(starts, 0);

    final startup = analytics.start();
    expect(identical(startup, analytics.start()), isTrue);
    expect(starts, 1);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [analytics.observer],
        home: const Scaffold(body: Text('Ready')),
      ),
    );
    expect(find.text('Ready'), findsOneWidget);
    expect(analytics.isEnabled, isFalse);

    var eventCompleted = false;
    unawaited(
      analytics.logSeedColorChanged(usesCustomColor: true).then((_) {
        eventCompleted = true;
      }),
    );
    await tester.pump();
    expect(eventCompleted, isTrue);
    expect(ready.isCompleted, isFalse);

    // Navigation before Firebase is ready should record the current screen,
    // rather than losing the first screen view or replaying stale pages.
    unawaited(navigator.currentState!.push<void>(_page('/search')));
    await tester.pumpAndSettle();
    final sdk = _RecordingAnalytics();
    ready.complete(sdk);
    await startup;
    await tester.pump();
    expect(analytics.isEnabled, isTrue);
    expect(sdk.screens, ['/search']);
    expect(sdk.events, hasLength(1));
    expect(sdk.events.single.$1, 'seed_color_changed');
    expect(sdk.events.single.$2, {'uses_custom_color': 1});

    unawaited(navigator.currentState!.push<void>(_page('/favorites')));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(sdk.screens, ['/search', '/favorites', '/search']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'failed analytics startup stays non-fatal for subsequent events',
    () async {
      final failed = Completer<FirebaseAnalytics?>();
      final analytics = AppAnalytics.deferred(initializer: () => failed.future);
      final startup = analytics.start();
      await analytics.logSeedColorChanged(usesCustomColor: true);
      failed.completeError(StateError('SDK unavailable'));
      await startup;
      await analytics.logSeedColorChanged(usesCustomColor: false);
      expect(analytics.isEnabled, isFalse);
    },
  );
}

MaterialPageRoute<void> _page(String name) => MaterialPageRoute<void>(
  settings: RouteSettings(name: name),
  builder: (_) => Scaffold(body: Text(name)),
);

class _RecordingAnalytics extends Fake implements FirebaseAnalytics {
  final screens = <String?>[];
  final events = <(String, Map<String, Object>?)>[];

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    screens.add(screenName);
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {
    events.add((name, parameters));
  }
}
