import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/smart_route_habit.dart';
import 'package:taiwanbus_flutter/core/smart_route_service.dart';

import 'support/route_usage_fixtures.dart';

RouteDetailData _detail(
  int routeKey, {
  BusProvider provider = BusProvider.nwt,
  String? routeName,
  List<PathInfo> paths = const [],
  Map<int, List<StopInfo>> stopsByPath = const {},
}) {
  return RouteDetailData(
    route: RouteSummary(
      sourceProvider: provider.name,
      hashMd5: '',
      routeKey: routeKey,
      routeId: '$routeKey',
      routeName: routeName ?? '$routeKey',
      officialRouteName: routeName ?? '$routeKey',
      description: '',
      category: '',
      sequence: 0,
      rtrip: 0,
    ),
    paths: paths,
    stopsByPath: stopsByPath,
    hasLiveData: true,
  );
}

class _PartiallyFailingRepository extends BusRepository {
  @override
  Future<RouteDetailData> getCompleteBusInfo(
    int routeKey, {
    required BusProvider provider,
    String? routeIdHint,
    String? routeNameHint,
  }) async {
    if (routeKey == 1) {
      throw StateError('route unavailable');
    }
    return _detail(routeKey, provider: provider, routeName: routeNameHint);
  }
}

class _LastBusRepository extends BusRepository {
  final List<int> requestedRouteKeys = <int>[];

  @override
  Future<RouteDetailData> getCompleteBusInfo(
    int routeKey, {
    required BusProvider provider,
    String? routeIdHint,
    String? routeNameHint,
  }) async {
    requestedRouteKeys.add(routeKey);
    return _detail(
      routeKey,
      provider: provider,
      routeName: routeNameHint,
      paths: [PathInfo(routeKey: routeKey, pathId: 0, name: '往測試站')],
      stopsByPath: {
        0: [
          StopInfo(
            routeKey: routeKey,
            pathId: 0,
            stopId: routeKey,
            stopName: '測試站$routeKey',
            sequence: 1,
            lon: 121.5654,
            lat: 25.033,
            sec: 120,
            msg: routeKey == 1 ? '末班車：已經駛離。' : null,
          ),
        ],
      },
    );
  }
}

/// Holds every request open until [release] is called, so a test can see how
/// many were asked for before the first one came back.
class _GatedRepository extends BusRepository {
  final Completer<void> _gate = Completer<void>();
  int inFlight = 0;
  int mostInFlight = 0;

  void release() => _gate.complete();

  @override
  Future<RouteDetailData> getCompleteBusInfo(
    int routeKey, {
    required BusProvider provider,
    String? routeIdHint,
    String? routeNameHint,
  }) async {
    inFlight += 1;
    if (inFlight > mostInFlight) {
      mostInFlight = inFlight;
    }
    await _gate.future;
    inFlight -= 1;
    return _detail(routeKey, provider: provider, routeName: routeNameHint);
  }
}

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime(2026, 9, 21),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  // 2026-04-08 is a Wednesday, 2026-04-11 a Saturday.
  final wednesdayMorning = DateTime(2026, 4, 8, 7, 20);
  final saturdayMorning = DateTime(2026, 4, 11, 7, 20);

  RouteUsageProfile commute({
    int routeKey = 101,
    int? pathId = 0,
    String routeName = '307',
    int days = 10,
    int hour = 7,
    int minute = 40,
    DateTime? before,
    int? stopId,
  }) => profileWithVisits(
    daysBefore(
      before ?? wednesdayMorning,
      count: days,
      hour: hour,
      minute: minute,
    ),
    routeKey: routeKey,
    pathId: pathId,
    routeName: routeName,
    stopId: stopId,
  );

  group('recording use', () {
    test('recordOpen increments total and hourly counters', () {
      const profile = RouteUsageProfile(
        provider: BusProvider.nwt,
        routeKey: 12,
        pathId: 0,
        routeName: '307',
        totalOpens: 2,
        lastOpenedAtMs: 0,
        hourlyOpens: <int, int>{7: 2},
      );

      final updated = profile.recordOpen(
        DateTime(2026, 4, 4, 7, 30),
        routeName: '307',
      );

      expect(updated.totalOpens, 3);
      expect(updated.countAtHour(7), 3);
      expect(updated.preferredHour, 7);
      expect(updated.visits.single.atMs, updated.lastOpenedAtMs);
    });

    test('opens within twenty minutes are one visit', () {
      final first = DateTime(2026, 4, 4, 7, 30);
      final profile = profileWithVisits([
        first,
        first.add(const Duration(minutes: 5)),
        first.add(const Duration(minutes: 19)),
        first.add(const Duration(minutes: 21)),
      ]);

      expect(profile.totalOpens, 4);
      expect(profile.visits.map((visit) => visit.atMs), [
        first.millisecondsSinceEpoch,
        first.add(const Duration(minutes: 21)).millisecondsSinceEpoch,
      ]);
    });

    test('a visit takes its stop from whichever open knew it', () {
      final first = DateTime(2026, 4, 4, 7, 30);
      final profile = profileWithVisits([first])
          .recordOpen(first.add(const Duration(minutes: 2)), stopId: 1001)
          .recordOpen(first.add(const Duration(minutes: 4)), stopId: 2002);

      expect(profile.visits.single.atMs, first.millisecondsSinceEpoch);
      expect(profile.visits.single.stopId, 1001);
    });

    test('visits older than eight weeks are dropped', () {
      final now = DateTime(2026, 4, 8, 7, 40);
      final profile = profileWithVisits([
        now.subtract(const Duration(days: 57)),
        now.subtract(const Duration(days: 55)),
      ]).recordOpen(now);

      expect(profile.visits.map((visit) => visit.atMs), [
        now.subtract(const Duration(days: 55)).millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      ]);
    });

    test('recordSelection increments selection counters', () {
      const profile = RouteUsageProfile(
        provider: BusProvider.nwt,
        routeKey: 12,
        pathId: 0,
        routeName: '307',
        totalOpens: 0,
        lastOpenedAtMs: 0,
      );

      final updated = profile.recordSelection(
        DateTime(2026, 4, 4, 18, 10),
        routeName: '307',
      );

      final now = DateTime(2026, 4, 4, 18, 10);
      expect(updated.totalSelectionsAt(now: now), 1);
      expect(updated.selectionCountAtHour(18, now: now), 1);
      expect(updated.preferredHourAt(now: now), 18);
    });

    test('recordSelection prunes entries older than seven days', () {
      final now = DateTime(2026, 4, 10, 18, 10);
      final profile = RouteUsageProfile(
        provider: BusProvider.nwt,
        routeKey: 12,
        pathId: 0,
        routeName: '307',
        totalOpens: 0,
        lastOpenedAtMs: 0,
        selectionTimestampsMs: <int>[
          now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
          now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
        ],
      );

      final updated = profile.recordSelection(now, routeName: '307');

      expect(updated.totalSelectionsAt(now: now), 2);
      expect(updated.selectionCountAtHour(18, now: now), 2);
    });

    test('clearing selections keeps the visits but not their stops', () {
      final now = DateTime.now();
      final profile = profileWithVisits([
        now.subtract(const Duration(days: 2)),
        now.subtract(const Duration(days: 1)),
      ], stopId: 1001).recordSelection(now);

      final cleared = profile.clearSelections();

      expect(cleared.totalSelectionsAt(now: now), 0);
      // Stop usage was promised gone; when the route was opened was not.
      expect(
        cleared.visits.map((visit) => visit.atMs),
        profile.visits.map((visit) => visit.atMs),
      );
      expect(cleared.visits.map((visit) => visit.stopId), [null, null]);
      expect(cleared.toJson()['visits'], everyElement(isNot(contains('s'))));
    });

    test('a stop learned before clearing selections is not used after', () {
      final now = DateTime(2026, 4, 8, 7, 40);
      final profile = commute(stopId: 1001, before: now);
      expect(SmartRouteService.learnedStopId(profile, now), 1001);

      final cleared = profile.clearSelections();

      expect(SmartRouteService.learnedStopId(cleared, now), isNull);
      expect(
        SmartRouteService.chooseBoardingStopId(
          profile: cleared,
          favoriteProfiles: const [],
          favorites: const [],
          at: now,
        ),
        isNull,
      );
    });

    test('visits and their stops survive being saved and loaded', () {
      final now = DateTime.now();
      final profile = profileWithVisits([
        now.subtract(const Duration(days: 2)),
        now.subtract(const Duration(days: 1)),
      ], stopId: 100100128221);

      final restored = RouteUsageProfile.fromJson(
        jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
      );

      expect(
        restored.visits.map((visit) => (visit.atMs, visit.stopId)),
        profile.visits.map((visit) => (visit.atMs, visit.stopId)),
      );
      expect(restored.legacyAsOfMs, isNull);
    });

    test('a profile saved before visits existed starts from its last open', () {
      final lastOpened = DateTime.now().subtract(const Duration(days: 1));
      final restored = RouteUsageProfile.fromJson({
        'provider': 'nwt',
        'routeKey': 101,
        'pathId': 0,
        'routeName': '307',
        'totalOpens': 8,
        'lastOpenedAtMs': lastOpened.millisecondsSinceEpoch,
        'hourlyOpens': {'7': 6, '8': 2},
      });

      expect(restored.visits.single.atMs, lastOpened.millisecondsSinceEpoch);
      expect(restored.legacyAsOfMs, lastOpened.millisecondsSinceEpoch);

      // Once saved in the new shape it keeps that date rather than moving it
      // forward with every later open.
      final reopened = RouteUsageProfile.fromJson(
        jsonDecode(jsonEncode(restored.recordOpen(DateTime.now()).toJson()))
            as Map<String, dynamic>,
      );
      expect(reopened.legacyAsOfMs, lastOpened.millisecondsSinceEpoch);
      expect(reopened.visits, hasLength(2));
    });
  });

  group('choosing a route', () {
    test('prefers the route used in this time window', () {
      final morningRoute = commute();
      final nightRoute = commute(
        routeKey: 102,
        routeName: '300',
        hour: 21,
        minute: 0,
        days: 20,
      );

      final result = SmartRouteService.chooseProfileForTime([
        nightRoute,
        morningRoute,
      ], wednesdayMorning);

      expect(result?.routeKey, 101);
    });

    test('returns nothing outside learned hours', () {
      final result = SmartRouteService.chooseProfileForTime([
        commute(),
      ], DateTime(2026, 4, 8, 14));

      expect(result, isNull);
    });

    test('ignores history that has no direction', () {
      final result = SmartRouteService.chooseProfileForTime([
        commute(pathId: null),
      ], wednesdayMorning);

      expect(result, isNull);
    });

    test('does not offer a weekday commute on a Saturday', () {
      final result = SmartRouteService.chooseProfileForTime([
        commute(before: saturdayMorning),
      ], saturdayMorning);

      expect(result, isNull);
    });

    test('does not take one busy morning for a habit', () {
      final yesterday = DateTime(2026, 4, 7, 7, 0);
      final busyMorning = profileWithVisits([
        for (var index = 0; index < 5; index++)
          yesterday.add(Duration(minutes: index * 25)),
      ]);

      expect(busyMorning.totalOpens, 5);
      expect(
        SmartRouteService.chooseProfileForTime([busyMorning], wednesdayMorning),
        isNull,
      );
    });

    test('needs the route on two separate days', () {
      expect(
        SmartRouteService.chooseProfileForTime([
          commute(days: 1),
        ], wednesdayMorning),
        isNull,
      );
      expect(
        SmartRouteService.chooseProfileForTime([
          commute(days: 2),
        ], wednesdayMorning)?.routeKey,
        101,
      );
    });

    test('also uses selection history', () {
      final tapped = RouteUsageProfile(
        provider: BusProvider.nwt,
        routeKey: 202,
        pathId: 0,
        routeName: '綠3',
        totalOpens: 0,
        lastOpenedAtMs: 0,
        selectionTimestampsMs: [
          for (final tap in daysBefore(
            wednesdayMorning,
            count: 3,
            hour: 7,
            minute: 30,
          ))
            tap.millisecondsSinceEpoch,
        ],
      );

      final result = SmartRouteService.chooseProfileForTime([
        tapped,
      ], wednesdayMorning);

      expect(result?.routeKey, 202);
    });

    test('ignores expired selection history', () {
      final now = DateTime(2026, 4, 10, 18, 15);
      final expiredSelectionRoute = RouteUsageProfile(
        provider: BusProvider.nwt,
        routeKey: 202,
        pathId: 0,
        routeName: '綠3',
        totalOpens: 3,
        lastOpenedAtMs: now
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch,
        hourlyOpens: const <int, int>{9: 3},
        selectionTimestampsMs: <int>[
          now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
          now
              .subtract(const Duration(days: 9, minutes: 5))
              .millisecondsSinceEpoch,
        ],
      );

      final result = SmartRouteService.chooseProfileForTime([
        expiredSelectionRoute,
      ], now);

      expect(result, isNull);
    });

    test('puts the steadier habit first', () {
      final everyWeekday = commute(routeKey: 1, days: 20);
      final threeDaysAWeek = profileWithVisits(
        daysBefore(
          wednesdayMorning,
          count: 12,
          hour: 7,
          minute: 40,
          weekdays: const {
            DateTime.monday,
            DateTime.wednesday,
            DateTime.friday,
          },
        ),
        routeKey: 2,
      );

      final ranked = SmartRouteService.rankProfilesForTime([
        threeDaysAWeek,
        everyWeekday,
      ], wednesdayMorning);

      expect(ranked.map((entry) => entry.profile.routeKey), [1, 2]);
      expect(ranked.first.score, greaterThan(ranked.last.score));
    });

    test('nudges a route opened a moment ago ahead of an equal habit', () {
      final now = DateTime(2026, 4, 8, 7, 45);
      final untouched = commute(routeKey: 1, before: now);
      final justOpened = commute(
        routeKey: 2,
        before: now,
      ).recordOpen(now.subtract(const Duration(minutes: 5)));

      final ranked = SmartRouteService.rankProfilesForTime([
        untouched,
        justOpened,
      ], now);

      expect(ranked.map((entry) => entry.profile.routeKey), [2, 1]);
      expect(
        ranked.first.score - ranked.last.score,
        closeTo(SmartRouteService.recentUseBoost * (1 - 5 / 90), 1e-9),
      );
    });

    test('lists a route and direction once', () {
      final ranked = SmartRouteService.rankProfilesForTime([
        commute(routeKey: 1, days: 10),
        commute(routeKey: 1, days: 6),
        commute(routeKey: 1, pathId: 1, days: 8),
      ], wednesdayMorning);

      expect(
        ranked.map((entry) => (entry.profile.routeKey, entry.profile.pathId)),
        [(1, 0), (1, 1)],
      );
      expect(ranked.first.estimate.supportDays, 10);
    });

    test('a stop learned before selections were cleared is gone after', () {
      final now = DateTime(2026, 4, 8, 7, 40);
      final profile = commute(stopId: 1001, before: now);
      expect(SmartRouteService.learnedStopId(profile, now), 1001);

      final cleared = profile.clearSelections();

      expect(SmartRouteService.learnedStopId(cleared, now), isNull);
      expect(
        SmartRouteService.chooseBoardingStopId(
          profile: cleared,
          favoriteProfiles: const [],
          favorites: const [],
          at: now,
        ),
        isNull,
      );
    });

    test('a reminder tapped early does not move the habit earlier', () {
      // Each weekday a reminder went out at 07:26 for a habit centred on
      // 07:40, and the route was opened from it at 07:27. An hour later the
      // habit is still around 07:40, and still recommended.
      final now = DateTime(2026, 4, 8, 8, 37);
      final opens = daysBefore(now, count: 10, hour: 7, minute: 27);
      final profile = profileWithVisits(opens);
      final reminders = [
        for (final open in opens)
          SmartRouteReminder(
            provider: BusProvider.nwt,
            routeKey: 101,
            pathId: 0,
            atMs: open
                .subtract(const Duration(minutes: 1))
                .millisecondsSinceEpoch,
            peakMinute: 220,
          ),
        // Another route's reminders are not this one's.
        SmartRouteReminder(
          provider: BusProvider.nwt,
          routeKey: 102,
          pathId: 0,
          atMs: now.millisecondsSinceEpoch,
          peakMinute: 300,
        ),
      ];

      expect(SmartRouteService.rankProfile(profile, now), isNull);
      final ranking = SmartRouteService.rankProfile(
        profile,
        now,
        reminders: reminders,
      );
      expect(ranking?.fromHabit, isTrue);
      expect(ranking!.estimate.supportDays, 10);
      expect(
        SmartRouteService.chooseProfileForTime(
          [profile],
          now,
          reminders: reminders,
        )?.routeKey,
        101,
      );
    });
  });

  group('a profile from before visits were kept', () {
    RouteUsageProfile legacy({
      required DateTime lastOpened,
      Map<String, int> hourlyOpens = const {'7': 6, '8': 2},
      int totalOpens = 8,
    }) => RouteUsageProfile.fromJson({
      'provider': 'nwt',
      'routeKey': 101,
      'pathId': 0,
      'routeName': '307',
      'totalOpens': totalOpens,
      'lastOpenedAtMs': lastOpened.millisecondsSinceEpoch,
      'hourlyOpens': hourlyOpens,
    });

    // fromJson measures retention against the real clock, so these are placed
    // relative to it rather than on a fixed date.
    final today = DateTime.now();
    final thisMorning = DateTime(today.year, today.month, today.day, 7, 20);
    final yesterdayMorning = thisMorning.subtract(
      const Duration(hours: 23, minutes: 50),
    );

    test('is still recommended at the hour it used to be opened', () {
      final ranking = SmartRouteService.rankProfile(
        legacy(lastOpened: yesterdayMorning),
        thisMorning,
      );

      expect(ranking, isNotNull);
      expect(ranking!.fromHabit, isFalse);
      expect(ranking.score, lessThanOrEqualTo(SmartRouteService.legacyWeight));
      expect(ranking.score, greaterThan(0.2));
    });

    test('is not recommended at other hours', () {
      expect(
        SmartRouteService.rankProfile(
          legacy(lastOpened: yesterdayMorning),
          thisMorning.add(const Duration(hours: 7)),
        ),
        isNull,
      );
    });

    test('needs the opens the old rule asked for', () {
      expect(
        SmartRouteService.rankProfile(
          legacy(
            lastOpened: yesterdayMorning,
            totalOpens: 2,
            hourlyOpens: const {'7': 2},
          ),
          thisMorning,
        ),
        isNull,
      );
      expect(
        SmartRouteService.rankProfile(
          legacy(
            lastOpened: yesterdayMorning,
            totalOpens: 9,
            hourlyOpens: const {'7': 1, '15': 8},
          ),
          thisMorning,
        ),
        isNull,
      );
    });

    test('is forgotten once its counters are stale', () {
      final profile = legacy(
        lastOpened: thisMorning.subtract(const Duration(days: 30)),
      );

      // Thirty days is a little over two half-lives.
      expect(
        SmartRouteService.legacyStrength(profile, thisMorning, datedDays: 0),
        closeTo(math.pow(0.5, 30 / 14), 0.005),
      );
      expect(SmartRouteService.rankProfile(profile, thisMorning), isNull);
    });

    test('hands over to dated history as it builds up', () {
      final profile = legacy(lastOpened: yesterdayMorning);

      final atFirst = SmartRouteService.legacyStrength(
        profile,
        thisMorning,
        datedDays: 0,
      );
      final halfway = SmartRouteService.legacyStrength(
        profile,
        thisMorning,
        datedDays: 3,
      );
      final handedOver = SmartRouteService.legacyStrength(
        profile,
        thisMorning,
        datedDays: SmartRouteService.legacyHandoverDays,
      );

      expect(atFirst, greaterThan(0.9));
      expect(halfway, closeTo(atFirst / 2, 1e-9));
      expect(handedOver, 0);
    });

    test('is not handed over by use at other times of day', () {
      // Upgraded with a long morning record, then used only in the evening
      // for a week: those evenings say nothing about the mornings.
      final evenings = daysBefore(thisMorning, count: 6, hour: 18, minute: 0);
      final profile = RouteUsageProfile.fromJson({
        'provider': 'nwt',
        'routeKey': 101,
        'pathId': 0,
        'routeName': '307',
        'totalOpens': 8,
        'lastOpenedAtMs': evenings.first
            .subtract(const Duration(hours: 11))
            .millisecondsSinceEpoch,
        'hourlyOpens': const {'7': 6, '8': 2},
      });
      var upgraded = profile;
      for (final evening in evenings) {
        upgraded = upgraded.recordOpen(evening);
      }

      final ranking = SmartRouteService.rankProfile(upgraded, thisMorning);

      // Counted as handed over, the counters would be worth nothing and the
      // morning route would not be recommended at all.
      expect(ranking, isNotNull);
      expect(ranking!.fromHabit, isFalse);
      expect(
        ranking.score,
        greaterThanOrEqualTo(SmartRouteService.minProbabilityForRecommendation),
      );
    });

    test('is handed over by use around the same time of day', () {
      final mornings = daysBefore(
        thisMorning,
        count: SmartRouteService.legacyHandoverDays,
        hour: 7,
        minute: 20,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
      );
      var upgraded = legacy(
        lastOpened: mornings.first.subtract(const Duration(days: 1)),
      );
      for (final morning in mornings) {
        upgraded = upgraded.recordOpen(morning);
      }

      final ranking = SmartRouteService.rankProfile(upgraded, thisMorning);

      expect(ranking?.fromHabit, isTrue);
    });

    test('counters alone do not qualify a profile that has visits', () {
      // Five opens in one hour on a profile created after visits were kept:
      // the counters look like a habit, the visits show it was one morning.
      final yesterday = thisMorning.subtract(const Duration(days: 1));
      final busyMorning = profileWithVisits([
        for (var index = 0; index < 5; index++)
          yesterday.add(Duration(minutes: index * 2)),
      ]);

      expect(busyMorning.countAtHour(7), 5);
      expect(busyMorning.legacyAsOfMs, isNull);
      expect(SmartRouteService.rankProfile(busyMorning, thisMorning), isNull);
    });
  });

  group('choosing a stop', () {
    test(
      'chooseFavoriteForRoute prefers the favorite used in this time window',
      () {
        final now = DateTime(2026, 4, 4, 18, 15);
        final routeProfile = RouteUsageProfile(
          provider: BusProvider.nwt,
          routeKey: 12,
          pathId: 1,
          routeName: '307',
          totalOpens: 6,
          lastOpenedAtMs: now
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          hourlyOpens: const <int, int>{18: 4, 17: 1, 19: 1},
        );
        final eveningFavoriteProfile = FavoriteUsageProfile(
          provider: BusProvider.nwt,
          routeKey: 12,
          pathId: 1,
          stopId: 1001,
          selectionTimestampsMs: <int>[
            now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
            now
                .subtract(const Duration(days: 2, minutes: 10))
                .millisecondsSinceEpoch,
          ],
        );
        final morningFavoriteProfile = FavoriteUsageProfile(
          provider: BusProvider.nwt,
          routeKey: 12,
          pathId: 2,
          stopId: 2002,
          selectionTimestampsMs: <int>[
            DateTime(2026, 4, 4, 7, 20).millisecondsSinceEpoch,
            DateTime(2026, 4, 3, 7, 10).millisecondsSinceEpoch,
            DateTime(2026, 4, 2, 7, 0).millisecondsSinceEpoch,
          ],
        );

        final result = SmartRouteService.chooseFavoriteForRoute(
          routeProfile: routeProfile,
          favoriteProfiles: [eveningFavoriteProfile, morningFavoriteProfile],
          favorites: const [
            FavoriteStop(
              provider: BusProvider.nwt,
              routeKey: 12,
              pathId: 1,
              stopId: 1001,
              destinationPathId: 1,
              destinationStopId: 1010,
              destinationStopName: '市政府',
            ),
            FavoriteStop(
              provider: BusProvider.nwt,
              routeKey: 12,
              pathId: 2,
              stopId: 2002,
              destinationPathId: 2,
              destinationStopId: 2020,
              destinationStopName: '捷運站',
            ),
          ],
          now: now,
        );

        expect(result?.pathId, 1);
        expect(result?.stopId, 1001);
        expect(result?.destinationStopId, 1010);
      },
    );

    test('learns the stop a route is usually opened at', () {
      final profile = profileWithVisits(
        daysBefore(wednesdayMorning, count: 4, hour: 7, minute: 40),
        stopId: 1001,
      ).recordOpen(DateTime(2026, 4, 1, 7, 45), stopId: 2002);

      expect(
        SmartRouteService.learnedStopId(profile, DateTime(2026, 4, 8, 7, 40)),
        1001,
      );
    });

    test('learns a different stop for a different time of day', () {
      final evening = DateTime(2026, 4, 8, 18, 0);
      var profile = commute(stopId: 1001, before: evening);
      for (final visit in daysBefore(evening, count: 5, hour: 18, minute: 0)) {
        profile = profile.recordOpen(visit, stopId: 2002);
      }

      expect(
        SmartRouteService.learnedStopId(profile, DateTime(2026, 4, 8, 7, 40)),
        1001,
      );
      expect(SmartRouteService.learnedStopId(profile, evening), 2002);
    });

    test('learns no stop from a single day or an even split', () {
      final now = DateTime(2026, 4, 8, 7, 40);
      final oneDay = profileWithVisits([
        DateTime(2026, 4, 7, 7, 40),
      ], stopId: 1001);
      var evenSplit = profileWithVisits(const []);
      final days = daysBefore(now, count: 6, hour: 7, minute: 40);
      for (var index = 0; index < days.length; index++) {
        evenSplit = evenSplit.recordOpen(
          days[index],
          stopId: index.isEven ? 1001 : 2002,
        );
      }

      expect(SmartRouteService.learnedStopId(oneDay, now), isNull);
      expect(SmartRouteService.learnedStopId(evenSplit, now), isNull);
    });

    group('for a reminder', () {
      final at = DateTime(2026, 4, 8, 7, 40);
      const favoriteAt3003 = FavoriteStop(
        provider: BusProvider.nwt,
        routeKey: 101,
        pathId: 0,
        stopId: 3003,
      );
      const favoriteAt4004 = FavoriteStop(
        provider: BusProvider.nwt,
        routeKey: 101,
        pathId: 0,
        stopId: 4004,
      );

      test('takes a favorite in use over a learned stop', () {
        final result = SmartRouteService.chooseBoardingStopId(
          profile: commute(stopId: 1001, before: at),
          favoriteProfiles: [
            FavoriteUsageProfile(
              provider: BusProvider.nwt,
              routeKey: 101,
              pathId: 0,
              stopId: 3003,
              selectionTimestampsMs: [
                at.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
              ],
            ),
          ],
          favorites: const [favoriteAt3003],
          at: at,
        );

        expect(result, 3003);
      });

      test('takes a learned stop over a favorite nobody is using', () {
        final result = SmartRouteService.chooseBoardingStopId(
          profile: commute(stopId: 1001, before: at),
          favoriteProfiles: const [],
          favorites: const [favoriteAt3003],
          at: at,
        );

        expect(result, 1001);
      });

      test('falls back to the only saved stop on the direction', () {
        expect(
          SmartRouteService.chooseBoardingStopId(
            profile: commute(before: at),
            favoriteProfiles: const [],
            favorites: const [
              favoriteAt3003,
              FavoriteStop(
                provider: BusProvider.nwt,
                routeKey: 101,
                pathId: 1,
                stopId: 5005,
              ),
            ],
            at: at,
          ),
          3003,
        );
      });

      test('does not guess between two saved stops', () {
        expect(
          SmartRouteService.chooseBoardingStopId(
            profile: commute(before: at),
            favoriteProfiles: const [],
            favorites: const [favoriteAt3003, favoriteAt4004],
            at: at,
          ),
          isNull,
        );
      });
    });
  });

  group('buildSuggestion', () {
    const profile = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 12,
      pathId: 1,
      routeName: '307',
      totalOpens: 5,
      lastOpenedAtMs: 1712000000000,
      hourlyOpens: <int, int>{18: 5},
    );

    // Three stops up one road, about 220 m and then 2 km apart.
    const usualStop = StopInfo(
      routeKey: 12,
      pathId: 1,
      stopId: 1001,
      stopName: '常用站',
      sequence: 1,
      lon: 121.565,
      lat: 25.040,
      sec: 120,
    );
    const nextStop = StopInfo(
      routeKey: 12,
      pathId: 1,
      stopId: 1002,
      stopName: '下一站',
      sequence: 2,
      lon: 121.565,
      lat: 25.042,
      sec: 180,
    );
    const farStop = StopInfo(
      routeKey: 12,
      pathId: 1,
      stopId: 1003,
      stopName: '遠方站',
      sequence: 3,
      lon: 121.565,
      lat: 25.060,
      sec: 600,
    );
    final roadDetail = _detail(
      12,
      routeName: '307',
      paths: const [PathInfo(routeKey: 12, pathId: 1, name: '往市政府')],
      stopsByPath: const {
        1: [usualStop, nextStop, farStop],
      },
    );

    SmartRouteSuggestion build({
      RouteDetailData? detail,
      FavoriteStop? favorite,
      Position? position,
      int? learnedStopId,
      List<FavoriteStop> routeFavorites = const [],
    }) => SmartRouteService.buildSuggestion(
      profile: profile,
      score: 12,
      reason: '根據使用習慣。',
      detail: detail ?? roadDetail,
      favorite: favorite,
      position: position,
      learnedStopId: learnedStopId,
      routeFavorites: routeFavorites,
    );

    test('promotes matched favorite stop', () {
      const favorite = FavoriteStop(
        provider: BusProvider.nwt,
        routeKey: 12,
        pathId: 1,
        stopId: 1001,
        destinationPathId: 1,
        destinationStopId: 1010,
        destinationStopName: '市政府',
      );

      final suggestion = build(favorite: favorite, learnedStopId: 1002);

      expect(suggestion.favorite?.stopId, 1001);
      expect(suggestion.favorite?.destinationStopId, 1010);
      expect(suggestion.recommendedStop?.stopId, 1001);
      expect(suggestion.recommendedPath?.pathId, 1);
    });

    test('includes the nearest stop when location is available', () {
      final suggestion = build(position: _position(25.0421, 121.5651));

      expect(suggestion.recommendedStop?.stopName, '下一站');
      expect(suggestion.recommendedPath?.pathId, 1);
      expect(suggestion.distanceMeters, lessThan(50));
    });

    test('only searches the learned direction', () {
      final detail = _detail(
        12,
        routeName: '307',
        paths: const [
          PathInfo(routeKey: 12, pathId: 0, name: '往反方向'),
          PathInfo(routeKey: 12, pathId: 1, name: '往市政府'),
        ],
        stopsByPath: const {
          0: [
            StopInfo(
              routeKey: 12,
              pathId: 0,
              stopId: 1,
              stopName: '較近但方向錯誤',
              sequence: 1,
              lon: 121.5655,
              lat: 25.0331,
              sec: 60,
            ),
          ],
          1: [
            StopInfo(
              routeKey: 12,
              pathId: 1,
              stopId: 2,
              stopName: '正確方向',
              sequence: 1,
              lon: 121.57,
              lat: 25.04,
              sec: 120,
            ),
          ],
        },
      );

      final suggestion = build(
        detail: detail,
        position: _position(25.0331, 121.5655),
      );

      expect(suggestion.recommendedPath?.pathId, 1);
      expect(suggestion.recommendedStop?.stopId, 2);
    });

    test('shows the usual stop when the position is unknown', () {
      final suggestion = build(learnedStopId: 1001);

      expect(suggestion.recommendedStop?.stopId, 1001);
      expect(suggestion.favorite, isNull);
      expect(suggestion.distanceMeters, isNull);
    });

    test('keeps the usual stop when another is nearer but it is in reach', () {
      // Standing at the next stop, 220 m from the usual one.
      final suggestion = build(
        learnedStopId: 1001,
        position: _position(25.042, 121.565),
      );

      expect(suggestion.nearestStop?.stopId, 1002);
      expect(suggestion.recommendedStop?.stopId, 1001);
      expect(suggestion.distanceMeters, closeTo(222, 5));
    });

    test('shows the stop the rider is at when the usual one is far off', () {
      final suggestion = build(
        learnedStopId: 1001,
        position: _position(25.0601, 121.565),
      );

      expect(suggestion.recommendedStop?.stopId, 1003);
      expect(suggestion.learnedStop, isNull);
      expect(suggestion.distanceMeters, lessThan(50));
    });

    test('keeps the usual stop when the rider is at no stop at all', () {
      // A kilometre past the far stop: nowhere near any of them.
      final suggestion = build(
        learnedStopId: 1001,
        position: _position(25.070, 121.565),
      );

      expect(suggestion.nearestStop?.stopId, 1003);
      expect(suggestion.recommendedStop?.stopId, 1001);
    });

    test('ignores a learned stop that is not on this direction', () {
      final suggestion = build(
        learnedStopId: 9999,
        position: _position(25.0421, 121.5651),
      );

      expect(suggestion.learnedStop, isNull);
      expect(suggestion.recommendedStop?.stopId, 1002);
    });

    test('shows a saved stop nobody has used lately as a plain stop', () {
      const saved = FavoriteStop(
        provider: BusProvider.nwt,
        routeKey: 12,
        pathId: 1,
        stopId: 1002,
        destinationPathId: 1,
        destinationStopId: 1003,
      );

      final suggestion = build(routeFavorites: const [saved]);

      expect(suggestion.recommendedStop?.stopId, 1002);
      // Not offered as the favorite: that would carry its destination along.
      expect(suggestion.favorite, isNull);
      expect(suggestion.favoriteStop, isNull);
    });

    test('picks the closest of several saved stops, or none without a fix', () {
      const savedStops = [
        FavoriteStop(
          provider: BusProvider.nwt,
          routeKey: 12,
          pathId: 1,
          stopId: 1001,
        ),
        FavoriteStop(
          provider: BusProvider.nwt,
          routeKey: 12,
          pathId: 1,
          stopId: 1003,
        ),
        // The other direction's saved stop must not be considered.
        FavoriteStop(
          provider: BusProvider.nwt,
          routeKey: 12,
          pathId: 0,
          stopId: 1002,
        ),
      ];

      final withoutFix = build(routeFavorites: savedStops);
      final nearFarStop = build(
        routeFavorites: savedStops,
        position: _position(25.066, 121.565),
      );

      expect(withoutFix.recommendedStop, isNull);
      expect(nearFarStop.recommendedStop?.stopId, 1003);
    });
  });

  group('loadSuggestions', () {
    final now = DateTime(2026, 9, 21, 8);

    RouteUsageProfile used(int routeKey, int days) => profileWithVisits(
      daysBefore(now, count: days, hour: 8, minute: 0),
      routeKey: routeKey,
      routeName: '$routeKey',
    );

    test('keeps successful routes when one route fails', () async {
      final suggestions = await SmartRouteService.loadSuggestions(
        repository: _PartiallyFailingRepository(),
        profiles: [used(1, 10), used(2, 5)],
        now: now,
        limit: 1,
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.profile.routeKey, 2);
    });

    test('skips duplicate last-bus candidates and fills limit', () async {
      final repository = _LastBusRepository();

      final suggestions = await SmartRouteService.loadSuggestions(
        repository: repository,
        profiles: [used(1, 10), used(1, 8), used(2, 5)],
        now: now,
        position: _position(25.0331, 121.5655),
        limit: 1,
      );

      expect(suggestions.single.profile.routeKey, 2);
      expect(repository.requestedRouteKeys, [1, 2]);
    });

    test('asks for the top routes together, and no more of them', () async {
      final repository = _GatedRepository();

      final pending = SmartRouteService.loadSuggestions(
        repository: repository,
        profiles: [used(1, 10), used(2, 8), used(3, 6), used(4, 4)],
        now: now,
        limit: 3,
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.inFlight, 3);

      repository.release();
      final suggestions = await pending;

      expect(suggestions.map((entry) => entry.profile.routeKey), [1, 2, 3]);
      expect(repository.mostInFlight, 3);
    });

    test('says when the route is usually opened', () async {
      final suggestions = await SmartRouteService.loadSuggestions(
        repository: _LastBusRepository(),
        profiles: [
          profileWithVisits(
            daysBefore(now, count: 10, hour: 7, minute: 38),
            routeKey: 2,
          ),
        ],
        now: DateTime(2026, 9, 21, 7, 30),
        limit: 1,
      );

      expect(suggestions.single.reason, '你平日常在 07:40 左右查看這條路線。');
    });
  });
}
