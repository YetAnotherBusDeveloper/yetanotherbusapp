import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/smart_route_service.dart';

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
    return RouteDetailData(
      route: RouteSummary(
        sourceProvider: provider.name,
        hashMd5: '',
        routeKey: routeKey,
        routeId: '$routeKey',
        routeName: routeNameHint ?? '$routeKey',
        officialRouteName: routeNameHint ?? '$routeKey',
        description: '',
        category: '',
        sequence: 0,
        rtrip: 0,
      ),
      paths: const [],
      stopsByPath: const {},
      hasLiveData: true,
    );
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
    return RouteDetailData(
      route: RouteSummary(
        sourceProvider: provider.name,
        hashMd5: '',
        routeKey: routeKey,
        routeId: '$routeKey',
        routeName: routeNameHint ?? '$routeKey',
        officialRouteName: routeNameHint ?? '$routeKey',
        description: '',
        category: '',
        sequence: 0,
        rtrip: 0,
      ),
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
      hasLiveData: true,
    );
  }
}

void main() {
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

  test('chooseProfileForTime prefers the route used in this time window', () {
    const morningRoute = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 101,
      pathId: 0,
      routeName: '307',
      totalOpens: 8,
      lastOpenedAtMs: 1712000000000,
      hourlyOpens: <int, int>{7: 5, 8: 2},
    );
    const nightRoute = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 102,
      pathId: 0,
      routeName: '300',
      totalOpens: 20,
      lastOpenedAtMs: 1712000000000,
      hourlyOpens: <int, int>{21: 10},
    );

    final result = SmartRouteService.chooseProfileForTime(const [
      morningRoute,
      nightRoute,
    ], DateTime(2026, 4, 4, 7, 20));

    expect(result?.routeKey, 101);
  });

  test('chooseProfileForTime returns null outside learned hours', () {
    const morningRoute = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 101,
      pathId: 0,
      routeName: '307',
      totalOpens: 8,
      lastOpenedAtMs: 1712000000000,
      hourlyOpens: <int, int>{7: 5, 8: 2},
    );

    final result = SmartRouteService.chooseProfileForTime(const [
      morningRoute,
    ], DateTime(2026, 4, 4, 14, 00));

    expect(result, isNull);
  });

  test('chooseProfileForTime ignores legacy directionless history', () {
    const legacyProfile = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 101,
      routeName: '307',
      totalOpens: 10,
      lastOpenedAtMs: 1712000000000,
      hourlyOpens: <int, int>{7: 10},
    );

    final result = SmartRouteService.chooseProfileForTime(const [
      legacyProfile,
    ], DateTime(2026, 4, 4, 7, 20));

    expect(result, isNull);
  });

  test('chooseProfileForTime also uses selection history', () {
    const selectedRoute = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 202,
      pathId: 0,
      routeName: '綠3',
      totalOpens: 3,
      lastOpenedAtMs: 1712000000000,
      totalSelections: 4,
      lastSelectedAtMs: 1712000000000,
      hourlyOpens: <int, int>{18: 1, 17: 1, 19: 1},
      hourlySelections: <int, int>{18: 4},
    );
    const weakerRoute = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 303,
      pathId: 0,
      routeName: '綠5',
      totalOpens: 3,
      lastOpenedAtMs: 1712000000000,
      hourlyOpens: <int, int>{18: 2, 17: 1},
    );

    final result = SmartRouteService.chooseProfileForTime(const [
      selectedRoute,
      weakerRoute,
    ], DateTime(2026, 4, 4, 18, 15));

    expect(result?.routeKey, 202);
  });

  test('chooseProfileForTime ignores expired selection history', () {
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
            .subtract(const Duration(days: 8, minutes: 5))
            .millisecondsSinceEpoch,
      ],
    );

    final result = SmartRouteService.chooseProfileForTime([
      expiredSelectionRoute,
    ], now);

    expect(result, isNull);
  });

  test('chooseProfileForTime requires enough actual opens', () {
    const notLearnedEnough = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 88,
      pathId: 0,
      routeName: '11',
      totalOpens: 1,
      lastOpenedAtMs: 1712000000000,
      totalSelections: 4,
      lastSelectedAtMs: 1712000000000,
      hourlyOpens: <int, int>{7: 1},
      hourlySelections: <int, int>{7: 4},
    );

    final result = SmartRouteService.chooseProfileForTime(const [
      notLearnedEnough,
    ], DateTime(2026, 4, 4, 7, 10));

    expect(result, isNull);
  });

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

  test('buildSuggestion promotes matched favorite stop', () {
    const profile = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 12,
      pathId: 1,
      routeName: '307',
      totalOpens: 5,
      lastOpenedAtMs: 1712000000000,
      hourlyOpens: <int, int>{18: 5},
    );
    const favorite = FavoriteStop(
      provider: BusProvider.nwt,
      routeKey: 12,
      pathId: 1,
      stopId: 1001,
      destinationPathId: 1,
      destinationStopId: 1010,
      destinationStopName: '市政府',
    );
    const detail = RouteDetailData(
      route: RouteSummary(
        sourceProvider: 'nwt',
        hashMd5: '',
        routeKey: 12,
        routeId: '307',
        routeName: '307',
        officialRouteName: '307',
        description: '忠孝幹線',
        category: '',
        sequence: 0,
        rtrip: 0,
      ),
      paths: [PathInfo(routeKey: 12, pathId: 1, name: '往市政府')],
      stopsByPath: {
        1: [
          StopInfo(
            routeKey: 12,
            pathId: 1,
            stopId: 1001,
            stopName: '捷運國父紀念館站',
            sequence: 1,
            lon: 121.553,
            lat: 25.041,
            sec: 120,
          ),
        ],
      },
      hasLiveData: true,
    );

    final suggestion = SmartRouteService.buildSuggestion(
      profile: profile,
      score: 12,
      reason: '根據使用習慣。',
      detail: detail,
      favorite: favorite,
    );

    expect(suggestion.favorite?.stopId, 1001);
    expect(suggestion.favorite?.destinationStopId, 1010);
    expect(suggestion.recommendedStop?.stopId, 1001);
    expect(suggestion.recommendedPath?.pathId, 1);
  });

  test(
    'buildSuggestion includes the nearest stop when location is available',
    () {
      const profile = RouteUsageProfile(
        provider: BusProvider.nwt,
        routeKey: 12,
        pathId: 1,
        routeName: '307',
        totalOpens: 5,
        lastOpenedAtMs: 1712000000000,
        hourlyOpens: <int, int>{18: 5},
      );
      const detail = RouteDetailData(
        route: RouteSummary(
          sourceProvider: 'nwt',
          hashMd5: '',
          routeKey: 12,
          routeId: '307',
          routeName: '307',
          officialRouteName: '307',
          description: '',
          category: '',
          sequence: 0,
          rtrip: 0,
        ),
        paths: [PathInfo(routeKey: 12, pathId: 1, name: '往市政府')],
        stopsByPath: {
          1: [
            StopInfo(
              routeKey: 12,
              pathId: 1,
              stopId: 1001,
              stopName: '最近站牌',
              sequence: 1,
              lon: 121.5654,
              lat: 25.033,
              sec: 120,
            ),
            StopInfo(
              routeKey: 12,
              pathId: 1,
              stopId: 1002,
              stopName: '較遠站牌',
              sequence: 2,
              lon: 121.6,
              lat: 25.06,
              sec: 300,
            ),
          ],
        },
        hasLiveData: true,
      );
      final position = Position(
        latitude: 25.0331,
        longitude: 121.5655,
        timestamp: DateTime(2026, 9, 21),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      final suggestion = SmartRouteService.buildSuggestion(
        profile: profile,
        score: 12,
        reason: '根據使用習慣。',
        detail: detail,
        position: position,
      );

      expect(suggestion.recommendedStop?.stopName, '最近站牌');
      expect(suggestion.recommendedPath?.pathId, 1);
    },
  );

  test('buildSuggestion only searches the learned direction', () {
    const profile = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 12,
      pathId: 1,
      routeName: '307',
      totalOpens: 5,
      lastOpenedAtMs: 1712000000000,
      hourlyOpens: <int, int>{18: 5},
    );
    const detail = RouteDetailData(
      route: RouteSummary(
        sourceProvider: 'nwt',
        hashMd5: '',
        routeKey: 12,
        routeId: '307',
        routeName: '307',
        officialRouteName: '307',
        description: '',
        category: '',
        sequence: 0,
        rtrip: 0,
      ),
      paths: [
        PathInfo(routeKey: 12, pathId: 0, name: '往反方向'),
        PathInfo(routeKey: 12, pathId: 1, name: '往市政府'),
      ],
      stopsByPath: {
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
      hasLiveData: true,
    );
    final position = Position(
      latitude: 25.0331,
      longitude: 121.5655,
      timestamp: DateTime(2026, 9, 21),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    final suggestion = SmartRouteService.buildSuggestion(
      profile: profile,
      score: 12,
      reason: '根據使用習慣。',
      detail: detail,
      position: position,
    );

    expect(suggestion.recommendedPath?.pathId, 1);
    expect(suggestion.recommendedStop?.stopId, 2);
  });

  test(
    'loadSuggestions keeps successful routes when one route fails',
    () async {
      final now = DateTime(2026, 9, 21, 8);
      final suggestions = await SmartRouteService.loadSuggestions(
        repository: _PartiallyFailingRepository(),
        profiles: [
          RouteUsageProfile(
            provider: BusProvider.nwt,
            routeKey: 1,
            pathId: 0,
            routeName: '失敗路線',
            totalOpens: 4,
            lastOpenedAtMs: now.millisecondsSinceEpoch,
            hourlyOpens: const {8: 4},
          ),
          RouteUsageProfile(
            provider: BusProvider.nwt,
            routeKey: 2,
            pathId: 0,
            routeName: '成功路線',
            totalOpens: 3,
            lastOpenedAtMs: now.millisecondsSinceEpoch,
            hourlyOpens: const {8: 3},
          ),
        ],
        now: now,
        limit: 1,
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.profile.routeKey, 2);
    },
  );

  test(
    'loadSuggestions skips duplicate last-bus candidates and fills limit',
    () async {
      final now = DateTime(2026, 9, 21, 8);
      final repository = _LastBusRepository();
      final position = Position(
        latitude: 25.0331,
        longitude: 121.5655,
        timestamp: now,
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      RouteUsageProfile profile(int routeKey, int opens) => RouteUsageProfile(
        provider: BusProvider.nwt,
        routeKey: routeKey,
        pathId: 0,
        routeName: '$routeKey',
        totalOpens: opens,
        lastOpenedAtMs: now.millisecondsSinceEpoch,
        hourlyOpens: <int, int>{8: opens},
      );

      final suggestions = await SmartRouteService.loadSuggestions(
        repository: repository,
        profiles: [profile(1, 5), profile(1, 4), profile(2, 3)],
        now: now,
        position: position,
        limit: 1,
      );

      expect(suggestions.single.profile.routeKey, 2);
      expect(repository.requestedRouteKeys, [1, 2]);
    },
  );
}
