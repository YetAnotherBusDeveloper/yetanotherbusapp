import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/route_family.dart';

void main() {
  test('resolves the same family name for trunk and supported variants', () {
    expect(routeFamilyName('500'), '500');
    expect(routeFamilyName('500延'), '500');
    expect(routeFamilyName('500跳蛙'), '500');
    expect(routeFamilyName('500延跳蛙'), '500');
    expect(routeFamilyName('500區'), '500區');
  });

  StopInfo stop({
    required String rawStopId,
    required String name,
    required double lat,
    required double lon,
  }) {
    return StopInfo(
      routeKey: 0,
      pathId: 0,
      stopId: rawStopId.hashCode,
      rawStopId: rawStopId,
      stopName: name,
      sequence: 0,
      lat: lat,
      lon: lon,
    );
  }

  test(
    'matches route-family stops with matching names and nearby coordinates',
    () {
      expect(
        routeFamilyStopsSharePhysicalSide(
          stop(
            rawStopId: '500-main',
            name: '捷運文心櫻花站',
            lat: 24.171000,
            lon: 120.653000,
          ),
          stop(
            rawStopId: '500-extension',
            name: '捷運文心櫻花站',
            lat: 24.171015,
            lon: 120.653015,
          ),
        ),
        isTrue,
      );
    },
  );

  test(
    'does not match route-family stops with different physical locations',
    () {
      expect(
        routeFamilyStopsSharePhysicalSide(
          stop(
            rawStopId: '500-main',
            name: '捷運文心櫻花站',
            lat: 24.171000,
            lon: 120.653000,
          ),
          stop(
            rawStopId: '500-extension',
            name: '捷運文心櫻花站',
            lat: 24.172000,
            lon: 120.654000,
          ),
        ),
        isFalse,
      );
    },
  );

  test('combines family live data into the selected route stop', () {
    final merged = mergeRouteFamilyStopLiveData(
      stop(
        rawStopId: '500-main',
        name: '捷運文心櫻花站',
        lat: 24.171000,
        lon: 120.653000,
      ).copyWith(
        sec: 240,
        buses: const [
          BusVehicle(
            id: 'KKA-0001',
            type: '0',
            note: '',
            full: false,
            carOnStop: false,
          ),
        ],
      ),
      [
        stop(
          rawStopId: '500-extension',
          name: '捷運文心櫻花站',
          lat: 24.171015,
          lon: 120.653015,
        ).copyWith(
          sec: 120,
          buses: const [
            BusVehicle(
              id: 'KKA-0002',
              type: '0',
              note: '',
              full: false,
              carOnStop: false,
            ),
          ],
        ),
      ],
    );

    expect(merged.sec, 120);
    expect(merged.buses.map((bus) => bus.id), ['KKA-0001', 'KKA-0002']);
  });

  test('a variant bus the feed has arriving is still arriving once merged', () {
    final merged = mergeRouteFamilyStopLiveData(
      stop(
        rawStopId: '500-main',
        name: '捷運文心櫻花站',
        lat: 24.171000,
        lon: 120.653000,
      ).copyWith(
        sec: 240,
        etas: const [StopEta(sec: 240, vehicleId: 'KKA-0001')],
      ),
      [
        stop(
          rawStopId: '500-extension',
          name: '捷運文心櫻花站',
          lat: 24.171015,
          lon: 120.653015,
        ).copyWith(
          sec: 40,
          etas: const [
            StopEta(sec: 40, vehicleId: 'KKA-0002', isArriving: true),
            // The same bus and estimate, not flagged: a different thing said.
            StopEta(sec: 40, vehicleId: 'KKA-0002'),
          ],
        ),
      ],
    );

    expect(
      [for (final eta in merged.etas) '${eta.vehicleId}:${eta.isArriving}'],
      ['KKA-0001:false', 'KKA-0002:true', 'KKA-0002:false'],
    );
  });

  test('a merged stop keeps what each route observed, and when', () {
    // Moments ago: a stop observed long ago lends no vehicles.
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String reference(int offsetSeconds) =>
        (nowSeconds - 5 + offsetSeconds).toString();
    final merged = mergeRouteFamilyStopLiveData(
      stop(
        rawStopId: '500-main',
        name: '捷運文心櫻花站',
        lat: 24.171000,
        lon: 120.653000,
      ).copyWith(
        sec: -1,
        t: reference(-20),
        etaReferenceAt: reference(-20),
        etas: const [StopEta(sec: -1, vehicleId: 'EAL-5389', isArriving: true)],
      ),
      [
        stop(
          rawStopId: '500-extension',
          name: '捷運文心櫻花站',
          lat: 24.171015,
          lon: 120.653015,
        ).copyWith(
          sec: 0,
          msg: '進站中',
          t: reference(0),
          etaReferenceAt: reference(0),
          etas: const [StopEta(sec: 0, vehicleId: 'KKA-0002')],
        ),
        // One that lists the bus the route itself has arriving, just as it
        // does.
        stop(
          rawStopId: '500-branch',
          name: '捷運文心櫻花站',
          lat: 24.171015,
          lon: 120.653015,
        ).copyWith(
          sec: 40,
          t: reference(-10),
          etaReferenceAt: reference(-10),
          etas: const [
            StopEta(sec: -1, vehicleId: 'EAL-5389', isArriving: true),
          ],
        ),
        // A route with nothing to say of the stop observed nothing.
        stop(
          rawStopId: '500-other',
          name: '捷運文心櫻花站',
          lat: 24.171015,
          lon: 120.653015,
        ),
      ],
      baseRouteId: 'TXG500',
      sharedRouteIds: const ['TXG5002', 'TXG5003', 'TXG5004'],
    );

    expect(
      [
        for (final observation in merged.routeObservations)
          '${observation.routeId} ${observation.sec} '
              '${observation.etaReferenceAt}',
      ],
      [
        'TXG500 -1 ${reference(-20)}',
        'TXG5002 0 ${reference(0)}',
        'TXG5003 40 ${reference(-10)}',
      ],
    );
    // A bus arriving is the route's that flagged it, like its estimate; the
    // message is passed on for the monitor to read.
    expect(
      [
        for (final observation in merged.routeObservations)
          '${observation.isArriving} ${observation.msg}',
      ],
      ['true null', 'false 進站中', 'true null'],
    );
    // And each bus stays with the routes that list it.
    expect(
      {for (final eta in merged.etas) eta.vehicleId: eta.routeIds},
      {
        'EAL-5389': ['TXG500', 'TXG5003'],
        'KKA-0002': ['TXG5002'],
      },
    );
    expect(
      merged.etas.first.etaReferenceAt,
      reference(-20),
      reason: 'as the first route to list it observed it',
    );
    // And they stay with the stop when its live data is carried over.
    expect(merged.copyWith(msg: '').routeObservations, hasLength(3));
  });

  test(
    'replaces an unavailable trunk ETA with a variant ETA at shared stops',
    () {
      RouteDetailData detail({
        required String routeId,
        required String routeName,
        required StopInfo stop,
      }) {
        return RouteDetailData(
          route: RouteSummary(
            sourceProvider: 'TXG',
            hashMd5: '',
            routeKey: routeId.hashCode,
            routeId: routeId,
            routeName: routeName,
            officialRouteName: routeName,
            description: '',
            category: '',
            sequence: 0,
            rtrip: 0,
          ),
          paths: const [PathInfo(routeKey: 0, pathId: 0, name: '臺中車站')],
          stopsByPath: {
            0: [stop],
          },
          hasLiveData: true,
        );
      }

      final sharedStop = stop(
        rawStopId: '8150',
        name: '邱厝里',
        lat: 24.156715,
        lon: 120.676500,
      );
      final merged = mergeRouteFamilyLiveData(
        detail(
          routeId: 'TXG5000',
          routeName: '500',
          stop: sharedStop.copyWith(msg: '尚未發車'),
        ),
        [
          detail(
            routeId: 'TXG5002',
            routeName: '500延',
            stop: sharedStop.copyWith(sec: 33),
          ),
        ],
      );

      final sharedLiveStop = merged.stopsByPath[0]!.single;
      expect(sharedLiveStop.sec, 33);
      expect(sharedLiveStop.msg, isNull);
      expect(merged.familyRouteIds, ['TXG5000', 'TXG5002']);
      // The trunk had nothing to say of the stop; what was observed there
      // is the variant's, and is kept as the variant's.
      expect(
        [
          for (final observation in sharedLiveStop.routeObservations)
            '${observation.routeId} ${observation.sec}',
        ],
        ['TXG5002 33'],
      );
    },
  );
}
