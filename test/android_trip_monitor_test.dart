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
    expect((saved['liveData'] as Map)['buses'], [{'id': 'FAMILY-001'}]);
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
