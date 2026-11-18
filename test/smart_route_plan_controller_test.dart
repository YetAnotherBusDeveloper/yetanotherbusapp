import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';

import 'support/ad_test_controller.dart';
import 'support/route_usage_fixtures.dart';

class _Repository extends BusRepository {
  /// Each lookup as `provider:key,key`, keys in ascending order.
  final List<String> lookups = [];
  bool databaseMissing = false;

  @override
  Future<Map<int, String>> routeIdsForRouteKeys(
    BusProvider provider,
    Set<int> routeKeys,
  ) async {
    lookups.add('${provider.name}:${(routeKeys.toList()..sort()).join(',')}');
    if (databaseMissing) {
      throw DatabaseNotReadyException('尚未下載路線資料庫。');
    }
    return {
      for (final routeKey in routeKeys)
        if (routeKey != 404) routeKey: '${provider.prefix}$routeKey',
    };
  }
}

const _homeChannel = MethodChannel(
  'tw.avianjay.taiwanbus.flutter/home_integration',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> homeCalls;

  // Fifteen weekday mornings, all at one stop: enough for a reminder on any
  // weekday, whatever day and hour the test happens to run at.
  RouteUsageProfile commute({
    int routeKey = 101,
    BusProvider provider = BusProvider.khh,
  }) => profileWithVisits(
    daysBefore(DateTime.now(), count: 15, hour: 7, minute: 40),
    routeKey: routeKey,
    provider: provider,
    stopId: 100100128221,
  );

  void seed({
    List<RouteUsageProfile> profiles = const [],
    bool notifications = false,
  }) {
    SharedPreferences.setMockInitialValues({
      'flutter.route_usage_profiles': jsonEncode([
        for (final profile in profiles) profile.toJson(),
      ]),
      'flutter.app_settings': jsonEncode({
        ...AppSettings.defaults().toJson(),
        'enableSmartRouteNotifications': notifications,
      }),
    });
  }

  Future<Map<String, dynamic>?> storedPlan() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      'smart_route_plan',
    );
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<AppController> start(_Repository repository) async {
    final controller = await createAdTestController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initializeForFirstFrame();
    return controller;
  }

  List<Object?> syncedStates() => [
    for (final call in homeCalls)
      if (call.method == 'setSmartRouteNotificationsEnabled')
        (call.arguments as Map)['enabled'],
  ];

  setUp(() {
    homeCalls = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(_homeChannel, (call) async {
      homeCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_homeChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'turning reminders on writes the plan before the worker is told',
    () async {
      seed(profiles: [commute()]);
      final repository = _Repository();
      final controller = await start(repository);
      Map<String, dynamic>? planWhenScheduled;
      messenger.setMockMethodCallHandler(_homeChannel, (call) async {
        homeCalls.add(call);
        if (call.method == 'setSmartRouteNotificationsEnabled') {
          planWhenScheduled = await storedPlan();
        }
        return null;
      });

      await controller.updateEnableSmartRouteNotifications(true);

      // The scheduler decides whether to run by reading the plan, so it has to
      // be there already.
      expect(planWhenScheduled, isNotNull);
      expect(syncedStates(), [true]);
      final plan = (await storedPlan())!;
      expect(plan['version'], 1);
      expect(plan['dayStartHour'], 4);
      final slots = (plan['slots'] as List).cast<Map<String, dynamic>>();
      expect(slots.map((slot) => slot['weekday']).toSet(), {1, 2, 3, 4, 5});
      for (final slot in slots) {
        expect(slot['provider'], 'khh');
        expect(slot['routeKey'], 101);
        expect(slot['routeId'], 'KHH101');
        expect(slot['pathId'], 0);
        expect(slot['peakMinute'], 220);
        expect(slot['stopId'], 100100128221);
      }
      expect(repository.lookups, ['khh:101']);
    },
  );

  test('turning reminders off removes the plan', () async {
    seed(profiles: [commute()], notifications: true);
    final controller = await start(_Repository());
    await controller.updateEnableSmartRouteNotifications(true);
    expect(await storedPlan(), isNotNull);

    await controller.updateEnableSmartRouteNotifications(false);

    expect(await storedPlan(), isNull);
    expect(syncedStates(), [true, false]);
  });

  test(
    'a route id is looked up once, and only for routes with a habit',
    () async {
      seed(
        profiles: [
          commute(),
          commute(routeKey: 202, provider: BusProvider.tpe),
          // Opened on two days only: not worth a lookup.
          profileWithVisits(
            daysBefore(DateTime.now(), count: 2, hour: 9, minute: 0),
            routeKey: 303,
            provider: BusProvider.khh,
          ),
        ],
        notifications: true,
      );
      final repository = _Repository();
      final controller = await start(repository);

      await controller.updateEnableSmartRouteNotifications(true);
      await controller.updateEnableSmartRouteNotifications(true);

      expect(repository.lookups, unorderedEquals(['khh:101', 'tpe:202']));
      final slots = ((await storedPlan())!['slots'] as List)
          .cast<Map<String, dynamic>>();
      expect(slots.map((slot) => slot['routeId']).toSet(), {
        'KHH101',
        'TPE202',
      });
    },
  );

  test(
    'a route the database cannot name is left out and asked about again',
    () async {
      seed(profiles: [commute(routeKey: 404), commute()], notifications: true);
      final repository = _Repository();
      final controller = await start(repository);

      await controller.updateEnableSmartRouteNotifications(true);
      await controller.updateEnableSmartRouteNotifications(true);

      final slots = ((await storedPlan())!['slots'] as List)
          .cast<Map<String, dynamic>>();
      expect(slots.map((slot) => slot['routeKey']).toSet(), {101});
      expect(repository.lookups, ['khh:101,404', 'khh:404']);
    },
  );

  test(
    'a missing database leaves an empty plan rather than an error',
    () async {
      seed(profiles: [commute()], notifications: true);
      final repository = _Repository()..databaseMissing = true;
      final controller = await start(repository);

      await controller.updateEnableSmartRouteNotifications(true);

      expect((await storedPlan())!['slots'], isEmpty);
      expect(syncedStates(), [true]);
    },
  );

  test('a visit is remembered with its stop and refreshes the plan', () async {
    seed(profiles: [commute()], notifications: true);
    final controller = await start(_Repository());
    await controller.updateEnableSmartRouteNotifications(true);
    final before = (await storedPlan())!;
    final openedAt = DateTime.now();

    await controller.recordRouteVisit(
      const RouteSummary(
        sourceProvider: 'khh',
        hashMd5: '',
        routeKey: 101,
        routeId: 'KHH101',
        routeName: '307',
        officialRouteName: '307',
        description: '',
        category: '',
        sequence: 0,
        rtrip: 0,
      ),
      provider: BusProvider.khh,
      pathId: 0,
      stopId: 2002,
      openedAt: openedAt,
    );

    final visit = controller.routeUsageProfiles.single.visits.last;
    expect(visit.atMs, openedAt.millisecondsSinceEpoch);
    expect(visit.stopId, 2002);
    final after = (await storedPlan())!;
    expect(
      after['generatedAtMs'],
      greaterThanOrEqualTo(before['generatedAtMs']),
    );
    // The worker reads this to know the route has just been looked at.
    expect(
      ((after['slots'] as List).cast<Map<String, dynamic>>())
          .map((slot) => slot['lastActivityAtMs'])
          .toSet(),
      {openedAt.millisecondsSinceEpoch},
    );
    expect(syncedStates(), [true, true]);
  });

  test('a first visit to a route starts its history with that visit', () async {
    seed();
    final controller = await start(_Repository());
    final openedAt = DateTime(2026, 4, 8, 7, 40);

    await controller.recordRouteVisit(
      const RouteSummary(
        sourceProvider: 'khh',
        hashMd5: '',
        routeKey: 55,
        routeId: 'KHH55',
        routeName: '紅12',
        officialRouteName: '紅12',
        description: '',
        category: '',
        sequence: 0,
        rtrip: 0,
      ),
      provider: BusProvider.khh,
      pathId: 1,
      stopId: 3003,
      openedAt: openedAt,
    );

    final profile = controller.routeUsageProfiles.single;
    expect(profile.routeName, '紅12');
    expect(profile.totalOpens, 1);
    expect(profile.lastOpenedAtMs, openedAt.millisecondsSinceEpoch);
    expect(profile.hourlyOpens, {7: 1});
    expect(profile.visits.single.atMs, openedAt.millisecondsSinceEpoch);
    expect(profile.visits.single.stopId, 3003);
    // Nothing here predates visit history, so the counters are not consulted.
    expect(profile.legacyAsOfMs, isNull);
  });

  test(
    'reminders the worker has shown are read before the plan is made',
    () async {
      // Opened on three weekdays, then not on the five since: left at that,
      // a habit that has all but stopped.
      final recent = daysBefore(DateTime.now(), count: 8, hour: 7, minute: 40);
      seed(
        profiles: [
          profileWithVisits(recent.take(3), provider: BusProvider.khh),
        ],
        notifications: true,
      );
      final controller = await start(_Repository());
      await controller.updateEnableSmartRouteNotifications(true);
      final slotsUnreminded = ((await storedPlan())!['slots'] as List).length;

      // The same five days, had a reminder gone out on each of them.
      final log = jsonEncode([
        for (final day in recent.skip(3))
          {
            'provider': 'khh',
            'routeKey': 101,
            'pathId': 0,
            'atMs': DateTime(
              day.year,
              day.month,
              day.day,
              7,
              28,
            ).millisecondsSinceEpoch,
            'peakMinute': 220,
          },
      ]);
      homeCalls.clear();
      messenger.setMockMethodCallHandler(_homeChannel, (call) async {
        homeCalls.add(call);
        return call.method == 'getSmartRouteReminderLog' ? log : null;
      });
      await controller.updateEnableSmartRouteNotifications(true);

      expect(
        [
          for (final call in homeCalls)
            if (call.method == 'getSmartRouteReminderLog' ||
                call.method == 'setSmartRouteNotificationsEnabled')
              call.method,
        ],
        ['getSmartRouteReminderLog', 'setSmartRouteNotificationsEnabled'],
      );
      expect(
        ((await storedPlan())!['slots'] as List).length,
        greaterThan(slotsUnreminded),
      );
    },
  );

  test(
    'a worker that cannot say what it showed does not hold the plan up',
    () async {
      seed(profiles: [commute()], notifications: true);
      final controller = await start(_Repository());
      messenger.setMockMethodCallHandler(_homeChannel, (call) async {
        homeCalls.add(call);
        if (call.method == 'getSmartRouteReminderLog') {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      });

      await controller.updateEnableSmartRouteNotifications(true);

      expect((await storedPlan())!['slots'], isNotEmpty);
      expect(syncedStates(), [true]);
    },
  );

  test(
    'clearing what was learned clears the reminders that came of it',
    () async {
      seed(profiles: [commute()], notifications: true);
      final controller = await start(_Repository());
      await controller.updateEnableSmartRouteNotifications(true);
      expect((await storedPlan())!['slots'], isNotEmpty);
      homeCalls.clear();

      await controller.clearRouteUsageProfiles();

      expect(controller.routeUsageProfiles, isEmpty);
      expect((await storedPlan())!['slots'], isEmpty);
      expect(
        homeCalls.map((call) => call.method),
        contains('forgetSmartRouteReminders'),
      );
    },
  );

  test('where there is no background check, no plan is written', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    seed(profiles: [commute()], notifications: true);
    final repository = _Repository();
    final controller = await start(repository);

    await controller.updateEnableSmartRouteNotifications(true);

    expect(await storedPlan(), isNull);
    expect(repository.lookups, isEmpty);

    await controller.clearRouteUsageProfiles();

    expect(homeCalls, isEmpty);
  });
}
