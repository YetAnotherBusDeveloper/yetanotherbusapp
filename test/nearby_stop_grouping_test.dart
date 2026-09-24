import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/screens/nearby_stop_grouping.dart';

NearbyStopResult _result({
  required String routeName,
  required int pathId,
  required double distance,
  String description = 'Downtown',
  String? rawStopId,
  double lat = 25.0,
  double lon = 121.0,
}) {
  return NearbyStopResult(
    route: RouteSummary(
      sourceProvider: 'tpe',
      hashMd5: '',
      routeKey: routeName.hashCode,
      routeId: 'TPE$routeName',
      routeName: routeName,
      officialRouteName: routeName,
      description: description,
      category: '',
      sequence: pathId,
      rtrip: pathId,
    ),
    stop: StopInfo(
      routeKey: routeName.hashCode,
      pathId: pathId,
      stopId: routeName.hashCode,
      rawStopId: rawStopId,
      stopName: 'City Hall',
      sequence: 1,
      lon: lon,
      lat: lat,
    ),
    distanceMeters: distance,
  );
}

void main() {
  test('groups routes by raw stop ID and orders sides by distance', () {
    final farA = _result(
      routeName: '307',
      pathId: 0,
      distance: 30,
      rawStopId: 'SIDE-A',
    );
    final farB = _result(
      routeName: '262',
      pathId: 0,
      distance: 31,
      rawStopId: 'SIDE-A',
    );
    final near = _result(
      routeName: 'Blue7',
      pathId: 1,
      distance: 20,
      rawStopId: 'SIDE-B',
    );

    final group = groupNearbyStops(
      [farA, farB, near],
      locale: 'zh-TW',
      compareRoutes: (left, right) =>
          right.route.routeName.compareTo(left.route.routeName),
    ).single;

    expect(group.sides.map((side) => side.key), ['id:SIDE-B', 'id:SIDE-A']);
    expect(group.sides.last.routes.map((row) => row.result), [farA, farB]);
  });

  test('fallback combines coordinates with normalized path identity', () {
    final first = _result(
      routeName: 'A',
      pathId: 0,
      distance: 10,
      description: '  DOWN town ',
    );
    final sameSide = _result(
      routeName: 'B',
      pathId: 0,
      distance: 11,
      description: 'down   TOWN',
    );
    final oppositeDirection = _result(
      routeName: 'A',
      pathId: 1,
      distance: 10,
      description: 'down town',
    );

    final sides = groupNearbyStops([
      first,
      sameSide,
      oppositeDirection,
    ], locale: 'en').single.sides;

    expect(sides, hasLength(2));
    expect(sides.first.routes.map((row) => row.result), [first, sameSide]);
    expect(sides.last.routes.single.result, same(oppositeDirection));
  });

  test('equal-distance sides retain their input order', () {
    final first = _result(
      routeName: 'A',
      pathId: 0,
      distance: 10,
      rawStopId: 'FIRST',
    );
    final second = _result(
      routeName: 'B',
      pathId: 1,
      distance: 10,
      rawStopId: 'SECOND',
    );

    final sides = groupNearbyStops([first, second], locale: 'en').single.sides;

    expect(sides.map((side) => side.key), ['id:FIRST', 'id:SECOND']);
  });
}
