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

class _DeniedPosition extends _HangingCurrentPosition {
  _DeniedPosition(this.permission) : super(null);

  final LocationPermission permission;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    throw StateError('Must not request a position without permission');
  }
}

/// Browser first visit: permission reads as `denied` (prompt) and
/// `requestPermission()` would block on a fix, so it must not be called.
class _WebPrompt extends _HangingCurrentPosition {
  _WebPrompt(this.result, {this.afterwards = LocationPermission.denied})
    : super(null);

  final Future<Position> Function() result;

  /// What `checkPermission()` reports once the prompt has been answered.
  final LocationPermission afterwards;
  bool answered = false;
  LocationSettings? settings;

  @override
  Future<LocationPermission> checkPermission() async =>
      answered ? afterwards : LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() =>
      throw StateError('Web must not call requestPermission');

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return result();
  }
}

/// A browser without `navigator.permissions` (Safari 15): the state can't be
/// read, so the plugin reports `unableToDetermine`.
class _WebUnknown extends _WebPrompt {
  _WebUnknown(super.result);

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.unableToDetermine;
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
  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test('reports $permission as a permission failure', () async {
      final original = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _DeniedPosition(permission);
      addTearDown(() => GeolocatorPlatform.instance = original);

      await expectLater(
        resolveUserPosition(),
        throwsA(
          isA<LocationFailure>()
              .having(
                (error) => error.permissionDenied,
                'permissionDenied',
                true,
              )
              .having(
                (error) => error.deniedForever,
                'deniedForever',
                permission == LocationPermission.deniedForever,
              ),
        ),
      );
    });
  }

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

  group('web first visit', () {
    const poll = Duration(milliseconds: 5);

    test('asks the browser directly and skips the plugin timeout', () async {
      final original = GeolocatorPlatform.instance;
      final fix = _position();
      final platform = _WebPrompt(() async => fix);
      GeolocatorPlatform.instance = platform;
      addTearDown(() => GeolocatorPlatform.instance = original);

      final position = await resolveUserPosition(
        webOverride: true,
        permissionPollInterval: poll,
      );

      expect(position, same(fix));
      // geolocator_web 4.1.3 treats this as microseconds-as-milliseconds.
      expect(platform.settings?.timeLimit, isNull);
    });

    test('a pending prompt is never timed out', () async {
      final original = GeolocatorPlatform.instance;
      final fix = Completer<Position>();
      final platform = _WebPrompt(() => fix.future);
      GeolocatorPlatform.instance = platform;
      addTearDown(() => GeolocatorPlatform.instance = original);

      var settled = false;
      final result = resolveUserPosition(
        webOverride: true,
        timeLimit: const Duration(milliseconds: 20),
        permissionPollInterval: poll,
      ).whenComplete(() => settled = true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(settled, isFalse, reason: 'user is still reading the prompt');

      fix.complete(_position());
      await result;
    });

    test('the limit starts when the prompt is answered, not before', () async {
      final original = GeolocatorPlatform.instance;
      final platform = _WebPrompt(
        () => Completer<Position>().future,
        afterwards: LocationPermission.whileInUse,
      );
      GeolocatorPlatform.instance = platform;
      addTearDown(() => GeolocatorPlatform.instance = original);

      const limit = Duration(milliseconds: 60);
      final clock = Stopwatch()..start();
      final result = resolveUserPosition(
        webOverride: true,
        timeLimit: limit,
        permissionPollInterval: poll,
      );
      // The user takes much longer than the limit to answer the prompt.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final answeredAt = clock.elapsed;
      platform.answered = true;

      await expectLater(
        result,
        throwsA(
          isA<LocationFailure>()
              .having((f) => f.permissionDenied, 'permissionDenied', false)
              .having((f) => f.message, 'message', '目前無法取得定位，請稍後再試。'),
        ),
      );
      // Anchored to the answer (200ms in), not the start; tolerate timer slack.
      expect(
        clock.elapsed - answeredAt,
        greaterThanOrEqualTo(limit - const Duration(milliseconds: 10)),
      );
    });

    group('without the Permissions API (unknown state)', () {
      test('a slow answer is not cut off at the normal limit', () async {
        final original = GeolocatorPlatform.instance;
        final fix = Completer<Position>();
        GeolocatorPlatform.instance = _WebUnknown(() => fix.future);
        addTearDown(() => GeolocatorPlatform.instance = original);

        final result = resolveUserPosition(
          webOverride: true,
          timeLimit: const Duration(milliseconds: 20),
          unknownPermissionLimit: const Duration(seconds: 5),
          permissionPollInterval: poll,
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
        fix.complete(_position());

        expect(await result, isA<Position>());
      });

      test('a request that never resolves still ends', () async {
        final original = GeolocatorPlatform.instance;
        GeolocatorPlatform.instance = _WebUnknown(
          () => Completer<Position>().future,
        );
        addTearDown(() => GeolocatorPlatform.instance = original);

        await expectLater(
          resolveUserPosition(
            webOverride: true,
            timeLimit: const Duration(milliseconds: 20),
            unknownPermissionLimit: const Duration(milliseconds: 100),
            permissionPollInterval: poll,
          ),
          throwsA(isA<LocationFailure>()),
        );
      });
    });

    test('an already-granted site keeps the time limit', () async {
      final original = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _HangingCurrentPosition(null);
      addTearDown(() => GeolocatorPlatform.instance = original);

      await expectLater(
        resolveUserPosition(
          webOverride: true,
          timeLimit: const Duration(milliseconds: 20),
          permissionPollInterval: poll,
        ),
        throwsA(isA<LocationFailure>()),
      );
    });

    for (final (after, forever) in [
      (LocationPermission.deniedForever, true),
      (LocationPermission.denied, false),
    ]) {
      test('a refused prompt reports the settled state ($after)', () async {
        final original = GeolocatorPlatform.instance;
        late _WebPrompt platform;
        platform = _WebPrompt(() {
          platform.answered = true;
          throw const PermissionDeniedException('denied');
        }, afterwards: after);
        GeolocatorPlatform.instance = platform;
        addTearDown(() => GeolocatorPlatform.instance = original);

        await expectLater(
          resolveUserPosition(webOverride: true, permissionPollInterval: poll),
          throwsA(
            isA<LocationFailure>()
                .having((f) => f.permissionDenied, 'permissionDenied', true)
                .having((f) => f.deniedForever, 'deniedForever', forever),
          ),
        );
      });
    }
  });
}
