import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/core/account_sync_models.dart';
import 'package:taiwanbus_flutter/core/account_sync_service.dart';
import 'package:taiwanbus_flutter/core/app_analytics.dart';
import 'package:taiwanbus_flutter/core/app_build_info.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';

import 'support/route_usage_fixtures.dart';

class _Repository extends BusRepository {
  /// Each lookup as `provider:key,key`, keys in ascending order.
  final List<String> lookups = [];
  bool databaseMissing = false;

  /// While set, lookups wait for it: a rebuild can be held mid-way.
  Completer<void>? gate;

  @override
  Future<Map<int, String>> routeIdsForRouteKeys(
    BusProvider provider,
    Set<int> routeKeys,
  ) async {
    lookups.add('${provider.name}:${(routeKeys.toList()..sort()).join(',')}');
    await gate?.future;
    if (databaseMissing) {
      throw DatabaseNotReadyException('尚未下載路線資料庫。');
    }
    return {
      for (final routeKey in routeKeys)
        if (routeKey != 404) routeKey: '${provider.prefix}$routeKey',
    };
  }

  @override
  Future<void> downloadDatabase(BusProvider provider) async {
    databaseMissing = false;
  }

  @override
  Future<bool> databaseExists(BusProvider provider) async => !databaseMissing;

  @override
  Future<RouteDetailData> getCompleteBusInfo(
    int routeKey, {
    required BusProvider provider,
    String? routeIdHint,
    String? routeNameHint,
  }) async => RouteDetailData(
    route: RouteSummary(
      sourceProvider: provider.name,
      hashMd5: '',
      routeKey: routeKey,
      routeId: '${provider.prefix}$routeKey',
      routeName: '307',
      officialRouteName: '307',
      description: '',
      category: '',
      sequence: 0,
      rtrip: 0,
    ),
    paths: [PathInfo(routeKey: routeKey, pathId: 0, name: '往市區')],
    stopsByPath: {
      0: [
        StopInfo(
          routeKey: routeKey,
          pathId: 0,
          stopId: 1,
          stopName: '站',
          sequence: 1,
          lon: 120.3,
          lat: 22.6,
          sec: 300,
        ),
      ],
    },
    hasLiveData: true,
  );
}

/// Logging out without asking a server about it.
class _OfflineAuthService extends AuthService {
  @override
  Future<void> logout() async {}
}

/// Fails to write the reminder plan while [failPlan] is set.
class _Storage extends StorageService {
  bool failPlan = false;
  bool failProfiles = false;

  /// Every plan written, in order.
  final List<Map<String, dynamic>> savedPlans = [];

  @override
  Future<void> saveSmartRoutePlan(Map<String, dynamic> plan) async {
    if (failPlan) {
      throw StateError('disk full');
    }
    savedPlans.add(plan);
    await super.saveSmartRoutePlan(plan);
  }

  @override
  Future<void> saveRouteUsageProfiles(List<RouteUsageProfile> profiles) async {
    if (failProfiles) {
      throw StateError('disk full');
    }
    await super.saveRouteUsageProfiles(profiles);
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
    Map<String, Object> extra = const {},
  }) {
    SharedPreferences.setMockInitialValues({
      'flutter.route_usage_profiles': jsonEncode([
        for (final profile in profiles) profile.toJson(),
      ]),
      'flutter.app_settings': jsonEncode({
        ...AppSettings.defaults().toJson(),
        'enableSmartRouteNotifications': notifications,
      }),
      ...extra,
    });
  }

  Future<Map<String, dynamic>?> storedPlan() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      'smart_route_plan',
    );
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> storedSlots() async =>
      ((await storedPlan())!['slots'] as List).cast<Map<String, dynamic>>();

  Future<AppController> start(
    _Repository repository, {
    StorageService? storage,
    AuthService? authService,
  }) async {
    const buildInfo = AppBuildInfo(
      version: '1.0.0',
      buildNumber: '1',
      gitSha: 'test',
      defaultUpdateChannel: AppUpdateChannel.release,
    );
    final client = MockClient((_) async => http.Response('{}', 200));
    final previousPlatform = debugDefaultTargetPlatformOverride;
    final AppAnalytics analytics;
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      analytics = await AppAnalytics.initialize();
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
    final controller = AppController(
      repository: repository,
      storage: storage ?? StorageService(),
      analytics: analytics,
      buildInfo: buildInfo,
      appUpdateService: AppUpdateService(buildInfo: buildInfo, client: client),
      appUpdateInstaller: createAppUpdateInstaller(),
      authService: authService ?? AuthService(),
      accountSyncService: AccountSyncService(client: client),
    );
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

  test(
    'a rebuild overtaken by clearing the history does not write it back',
    () async {
      seed(profiles: [commute()], notifications: true);
      final repository = _Repository();
      final storage = _Storage();
      final controller = await start(repository, storage: storage);
      await controller.updateEnableSmartRouteNotifications(true);
      expect(await storedSlots(), isNotEmpty);

      // A rebuild that has read the history and is waiting on the platform
      // when the rider clears it.
      final logRequested = Completer<void>();
      final releaseLog = Completer<String?>();
      messenger.setMockMethodCallHandler(_homeChannel, (call) async {
        homeCalls.add(call);
        if (call.method == 'getSmartRouteReminderLog' &&
            !logRequested.isCompleted) {
          logRequested.complete();
          return releaseLog.future;
        }
        return null;
      });
      final slowRebuild = controller.updateEnableSmartRouteNotifications(true);
      await logRequested.future;
      homeCalls.clear();
      final plansBefore = storage.savedPlans.length;
      final clearing = controller.clearRouteUsageProfiles();
      // Until the clearing has done all it can without the rebuild.
      for (
        var turn = 0;
        turn < 100 &&
            !homeCalls.any(
              (call) => call.method == 'forgetSmartRouteReminders',
            );
        turn++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);
      releaseLog.complete('[]');
      await slowRebuild;
      await clearing;

      expect(await storedSlots(), isEmpty);
      // Only the rebuild that began after the clearing wrote anything: the
      // overtaken one, made from a reminder log read before the clearing,
      // never reached the worker even for a moment.
      expect(storage.savedPlans.length - plansBefore, 1);
      final methods = homeCalls.map((call) => call.method).toList();
      // The reminder log went before the plan that was written after it.
      expect(
        methods.indexOf('forgetSmartRouteReminders'),
        lessThan(methods.lastIndexOf('getSmartRouteReminderLog')),
      );
      expect(syncedStates().last, isTrue);
    },
  );

  test('clearing goes on past a step that fails, then reports it', () async {
    seed(profiles: [commute()], notifications: true);
    final storage = _Storage();
    final controller = await start(_Repository(), storage: storage);
    await controller.updateEnableSmartRouteNotifications(true);
    expect(await storedSlots(), isNotEmpty);
    homeCalls.clear();

    storage.failProfiles = true;
    await expectLater(controller.clearRouteUsageProfiles(), throwsStateError);

    // The steps after the failed one were still taken.
    expect(
      homeCalls.map((call) => call.method),
      contains('forgetSmartRouteReminders'),
    );
    expect(await storedSlots(), isEmpty);
  });

  test(
    'a failed plan write leaves no plan and still clears everything',
    () async {
      seed(profiles: [commute()], notifications: true);
      final storage = _Storage();
      final controller = await start(_Repository(), storage: storage);
      await controller.updateEnableSmartRouteNotifications(true);
      expect(await storedSlots(), isNotEmpty);
      homeCalls.clear();

      storage.failPlan = true;
      await expectLater(controller.clearRouteUsageProfiles(), throwsStateError);

      expect(controller.routeUsageProfiles, isEmpty);
      expect(await StorageService().loadRouteUsageProfiles(), isEmpty);
      expect(
        homeCalls.map((call) => call.method),
        contains('forgetSmartRouteReminders'),
      );
      // What was there is gone rather than left to remind of a cleared
      // history.
      expect(await storedPlan(), isNull);
      expect(syncedStates(), isNotEmpty);
    },
  );

  test('a favourite removed is no longer a stop to watch', () async {
    // A route opened without a stop, whose only favourite is what a
    // reminder would watch.
    seed(
      profiles: [
        profileWithVisits(
          daysBefore(DateTime.now(), count: 15, hour: 7, minute: 40),
          provider: BusProvider.khh,
        ),
      ],
      notifications: true,
    );
    final controller = await start(_Repository());
    const favorite = FavoriteStop(
      provider: BusProvider.khh,
      routeKey: 101,
      pathId: 0,
      stopId: 4004,
    );
    await controller.addFavoriteStop(favorite);
    expect((await storedSlots()).map((slot) => slot['stopId']).toSet(), {4004});

    await controller.removeFavoriteStop(
      AppController.defaultFavoriteGroupName,
      favorite,
    );

    expect((await storedSlots()).map((slot) => slot['stopId']).toSet(), {null});
  });

  test(
    'routes left out for want of a database come back once it is downloaded',
    () async {
      seed(profiles: [commute()], notifications: true);
      final repository = _Repository()..databaseMissing = true;
      final controller = await start(repository);
      await controller.updateEnableSmartRouteNotifications(true);
      expect(await storedSlots(), isEmpty);
      homeCalls.clear();

      await controller.downloadProviderDatabases([BusProvider.khh]);

      expect((await storedSlots()).map((slot) => slot['routeId']).toSet(), {
        'KHH101',
      });
      expect(syncedStates(), [true]);
    },
  );

  test('logging out takes other devices\' routes out of the plan', () async {
    final otherDevicesRoute = commute(routeKey: 202);
    final ownRoute = commute();
    seed(
      profiles: [ownRoute, otherDevicesRoute],
      notifications: true,
      extra: {
        'flutter.auth_token': 'token',
        'flutter.auth_account_id': 'account',
        'flutter.auth_device_id': 'device',
        // What this device contributed before it was merged with others.
        'flutter.account_sync_state:account': jsonEncode(
          AccountSyncLocalState.empty()
              .copyWith(
                routeHistoryDevicePayload: {
                  'modifiedAtMs': 1,
                  'history': const [],
                  'routeUsageProfiles': [ownRoute.toJson()],
                },
              )
              .toJson(),
        ),
      },
    );
    final controller = await start(
      _Repository(),
      authService: _OfflineAuthService(),
    );
    await controller.updateEnableSmartRouteNotifications(true);
    expect((await storedSlots()).map((slot) => slot['routeKey']).toSet(), {
      101,
      202,
    });

    await controller.logoutAuth();

    expect(controller.routeUsageProfiles.map((profile) => profile.routeKey), [
      101,
    ]);
    expect((await storedSlots()).map((slot) => slot['routeKey']).toSet(), {
      101,
    });
  });

  test('the home screen reads the reminders already shown', () async {
    // Every weekday a reminder went out at 07:26 for a habit centred on
    // 07:40, and the rider opened the route from it at 07:27. Read without
    // the reminders, the habit looks like 07:27.
    final ask = daysBefore(
      DateTime.now(),
      count: 1,
      hour: 7,
      minute: 35,
    ).single;
    final days = daysBefore(ask, count: 10, hour: 7, minute: 27);
    seed(
      profiles: [profileWithVisits(days, provider: BusProvider.khh)],
      extra: {
        'flutter.app_settings': jsonEncode({
          ...AppSettings.defaults().toJson(),
          'provider': 'khh',
        }),
      },
    );
    final log = jsonEncode([
      for (final day in days)
        {
          'provider': 'khh',
          'routeKey': 101,
          'pathId': 0,
          'atMs': day
              .subtract(const Duration(minutes: 1))
              .millisecondsSinceEpoch,
          'peakMinute': 220,
        },
    ]);
    final controller = await start(_Repository());
    Future<String> reason({required bool withLog}) async {
      messenger.setMockMethodCallHandler(_homeChannel, (call) async {
        homeCalls.add(call);
        return call.method == 'getSmartRouteReminderLog' && withLog
            ? log
            : null;
      });
      return (await controller.getSmartRouteSuggestions(
        now: ask,
      )).single.reason;
    }

    expect(await reason(withLog: false), '你平日常在 07:25 左右查看這條路線。');
    expect(await reason(withLog: true), '你平日常在 07:40 左右查看這條路線。');
  });
}
