import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taiwanbus_flutter/core/user_location.dart';

class _HangingCurrentPosition extends GeolocatorPlatform {
  _HangingCurrentPosition(this.lastKnown, {this.serviceEnabled = true});

  final Position? lastKnown;
  final bool serviceEnabled;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnown;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Completer<Position>().future;
}

Position _position() => Position(
  latitude: 25.033,
  longitude: 121.5654,
  timestamp: DateTime(2026, 9, 21),
  altitude: 0,
  altitudeAccuracy: 0,
  accuracy: 20,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  test('reports when the device location service is switched off', () async {
    final original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _HangingCurrentPosition(
      null,
      serviceEnabled: false,
    );
    addTearDown(() => GeolocatorPlatform.instance = original);

    await expectLater(
      resolveUserPosition(),
      throwsA(
        isA<LocationFailure>()
            .having((failure) => failure.message, 'message', '定位服務尚未開啟。')
            .having(
              (failure) => failure.serviceDisabled,
              'serviceDisabled',
              isTrue,
            ),
      ),
    );
  });

  test('a hanging current fix falls back to the last known position', () async {
    final original = GeolocatorPlatform.instance;
    final lastKnown = _position();
    GeolocatorPlatform.instance = _HangingCurrentPosition(lastKnown);
    addTearDown(() => GeolocatorPlatform.instance = original);

    final position = await resolveUserPosition(
      timeLimit: const Duration(milliseconds: 10),
    );

    expect(position, same(lastKnown));
  });

  test(
    'a hanging current fix fails after the limit without a fallback',
    () async {
      final original = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _HangingCurrentPosition(null);
      addTearDown(() => GeolocatorPlatform.instance = original);

      await expectLater(
        resolveUserPosition(timeLimit: const Duration(milliseconds: 10)),
        throwsA(
          isA<LocationFailure>().having(
            (failure) => failure.message,
            'message',
            '目前無法取得定位，請稍後再試。',
          ),
        ),
      );
    },
  );
}
