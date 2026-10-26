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

  test('monitor snapshot keeps physical stop identity and each vehicle ETA', () {
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
        etas: [
          StopEta(sec: 300, vehicleId: 'MAIN-001'),
          StopEta(sec: 60, vehicleId: 'FAMILY-001'),
        ],
      ),
    ).toMap();
    expect(stop['rawStopId'], 'MAIN-STOP');
    final live = stop['liveData'] as Map;
    expect(live['eta'], 60);
    expect(live['etas'], [
      {'plate': 'MAIN-001', 'eta': 300, 'message': null},
      {'plate': 'FAMILY-001', 'eta': 60, 'message': null},
    ]);
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
