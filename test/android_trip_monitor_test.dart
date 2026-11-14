import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/android_trip_monitor.dart';
import 'package:taiwanbus_flutter/core/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('session serializes family IDs and merged stop vehicles', () {
    final stop = TripMonitorStop.fromStop(
      const StopInfo(
        routeKey: 500,
        pathId: 0,
        stopId: 1,
        rawStopId: 'MAIN-STOP',
        stopName: '共用站',
        sequence: 1,
        lat: 24.1,
        lon: 120.6,
        sec: 60,
        buses: [
          BusVehicle(
            id: 'FAMILY-001',
            type: '0',
            note: '',
            full: false,
            carOnStop: false,
          ),
        ],
        etas: [StopEta(sec: 60, vehicleId: 'FAMILY-001')],
      ),
    );
    final map = TripMonitorSession(
      providerName: 'txg',
      routeKey: 500,
      routeId: 'TXG500',
      familyRouteIds: const ['TXG500', 'TXG501'],
      routeName: '500',
      pathId: 0,
      pathName: '去程',
      appInForeground: true,
      backgroundLocationAlwaysGranted: true,
      stops: [stop],
    ).toMap();
    expect(map['familyRouteIds'], ['TXG500', 'TXG501']);
    final saved = (map['stops'] as List).single as Map;
    expect(saved['rawStopId'], 'MAIN-STOP');
    expect((saved['liveData'] as Map)['eta'], 60);
    expect((saved['liveData'] as Map)['buses'], [
      {'id': 'FAMILY-001'},
    ]);
  });

  test('session carries when its initial position was measured', () {
    // The route screen's last fix can be minutes old when a trip starts. The
    // monitor judges staleness from this, so it has to cross the channel.
    final measuredAt = DateTime.utc(2026, 11, 12, 8, 30);
    final map = TripMonitorSession(
      providerName: 'txg',
      routeKey: 1,
      routeName: '1',
      pathId: 0,
      pathName: '去程',
      appInForeground: true,
      backgroundLocationAlwaysGranted: false,
      stops: const <TripMonitorStop>[],
      initialLatitude: 24.1,
      initialLongitude: 120.6,
      initialLocationTimestampMs: measuredAt.millisecondsSinceEpoch,
    ).toMap();

    expect(
      map['initialLocationTimestampMs'],
      measuredAt.millisecondsSinceEpoch,
    );
  });

  test('session keeps 64-bit stop ids at full width', () {
    // 高雄 stop ids exceed 32 bits. The native side folds them for its own
    // feed joins, but what it is handed has to be the id Dart itself holds —
    // that is what a notification tap is launched back with.
    const stopId = 101111144601;
    final map = TripMonitorSession(
      providerName: 'khh',
      routeKey: 100,
      routeId: 'KHH100',
      routeName: '100',
      pathId: 0,
      pathName: '去程',
      appInForeground: true,
      backgroundLocationAlwaysGranted: false,
      boardingStopId: stopId,
      destinationStopId: stopId + 30,
      stops: [
        TripMonitorStop.fromStop(
          const StopInfo(
            routeKey: 100,
            pathId: 0,
            stopId: stopId,
            stopName: '測試站',
            sequence: 1,
            lat: 22.6,
            lon: 120.3,
          ),
        ),
      ],
    ).toMap();

    expect(map['boardingStopId'], stopId);
    expect(map['destinationStopId'], stopId + 30);
    expect(((map['stops'] as List).single as Map)['stopId'], stopId);
  });

  test('lifecycle calls tolerate a detached platform channel', () async {
    const session = TripMonitorSession(
      providerName: 'txg',
      routeKey: 1,
      routeId: 'TXG1',
      routeName: '1',
      pathId: 0,
      pathName: '往終點',
      appInForeground: true,
      backgroundLocationAlwaysGranted: true,
      stops: <TripMonitorStop>[],
    );

    await AndroidTripMonitor.setAppInForeground(false);
    await AndroidTripMonitor.startOrUpdate(session);
    expect(await AndroidTripMonitor.isPausedFor(session), isFalse);
    await AndroidTripMonitor.stop();
  });
}
