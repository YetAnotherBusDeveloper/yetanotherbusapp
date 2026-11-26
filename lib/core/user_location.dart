import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'transit_repository.dart';

/// A location attempt that failed for a reason worth telling the user about.
class LocationFailure implements Exception {
  const LocationFailure(
    this.message, {
    this.deniedForever = false,
    this.permissionDenied = false,
    this.serviceDisabled = false,
  });

  final String message;

  /// The user has to go into system settings; asking again will not help.
  final bool deniedForever;

  /// Location access was denied, including when requesting again is possible.
  final bool permissionDenied;

  /// The device-wide location switch is off, so app permission settings alone
  /// cannot resolve the failure.
  final bool serviceDisabled;

  @override
  String toString() => message;
}

/// Resolves the device's position, throwing [LocationFailure] with a
/// ready-to-show Traditional Chinese message when it cannot.
///
/// This is the same service-check → permission → last-known → current-position
/// sequence that eight screens each hand-roll today (`nearby_screen.dart:58`,
/// `bus_map_screen.dart:636`, `youbike_screen.dart:111`, and friends). New code
/// should call this; migrating the existing eight is separate cleanup.
///
/// On web the browser's "prompt" state is reported as
/// [LocationPermission.denied], and `requestPermission()` itself waits for a
/// first fix with a one-day timeout. So web skips it and calls
/// `getCurrentPosition` directly, which triggers the browser prompt. The
/// plugin's own timeout is not used: `geolocator_web` 4.1.3 hands its
/// microseconds to the browser as milliseconds. Instead [timeLimit] starts once
/// the permission is no longer pending (see [_boundWebFix]), so a user still
/// reading the prompt is never timed out but a granted-yet-failed fix is
/// bounded. A refused prompt reports the permission state the browser
/// settled on, so a blocked site is `deniedForever` and a dismissed prompt is
/// retryable.
Future<Position> resolveUserPosition({
  Duration timeLimit = const Duration(seconds: 6),
  LocationAccuracy accuracy = LocationAccuracy.medium,
  @visibleForTesting bool? webOverride,
  @visibleForTesting Duration permissionPollInterval =
      const Duration(milliseconds: 250),
}) async {
  final isWeb = webOverride ?? kIsWeb;
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationFailure('定位服務尚未開啟。', serviceDisabled: true);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied && !isWeb) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationFailure(
      '沒有取得定位權限。',
      deniedForever: true,
      permissionDenied: true,
    );
  }
  if (permission == LocationPermission.denied && !isWeb) {
    throw const LocationFailure('沒有取得定位權限。', permissionDenied: true);
  }

  Position? lastKnown;
  try {
    lastKnown = await Geolocator.getLastKnownPosition();
  } catch (_) {
    lastKnown = null;
  }

  try {
    if (isWeb) {
      return await _boundWebFix(
        Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: accuracy),
        ),
        timeLimit,
        // A prompt-state site has not been granted yet; anything else has.
        permissionGranted: permission != LocationPermission.denied,
        pollInterval: permissionPollInterval,
      );
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeLimit,
      ),
    ).timeout(timeLimit);
  } on PermissionDeniedException {
    var forever = false;
    try {
      forever = await Geolocator.checkPermission() ==
          LocationPermission.deniedForever;
    } catch (_) {}
    throw LocationFailure(
      '沒有取得定位權限。',
      deniedForever: forever,
      permissionDenied: true,
    );
  } catch (_) {
    if (lastKnown != null) {
      return lastKnown;
    }
    throw const LocationFailure('目前無法取得定位，請稍後再試。');
  }
}

/// Waits for [fix], failing with a [TimeoutException] [limit] after permission
/// is granted. While the permission prompt is pending nothing times out.
Future<Position> _boundWebFix(
  Future<Position> fix,
  Duration limit, {
  required bool permissionGranted,
  required Duration pollInterval,
}) {
  final done = Completer<Position>();
  Timer? deadline;
  Timer? poll;

  void startDeadline() {
    deadline ??= Timer(limit, () {
      if (!done.isCompleted) {
        done.completeError(TimeoutException('No position fix', limit));
      }
    });
  }

  void finish() {
    deadline?.cancel();
    poll?.cancel();
  }

  if (permissionGranted) {
    startDeadline();
  } else {
    poll = Timer.periodic(pollInterval, (_) async {
      try {
        final now = await Geolocator.checkPermission();
        if (now != LocationPermission.denied) {
          poll?.cancel();
          startDeadline();
        }
      } catch (_) {}
    });
  }

  fix.then(
    (position) {
      if (!done.isCompleted) done.complete(position);
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!done.isCompleted) done.completeError(error, stackTrace);
    },
  );
  return done.future.whenComplete(finish);
}

/// A station plus how far the user is from it.
class NearestRailStation {
  const NearestRailStation({
    required this.station,
    required this.distanceMeters,
  });

  final RailStation station;
  final double distanceMeters;
}

/// Closest station to the given point, or `null` if none has coordinates.
///
/// Linear scan over roughly 240 TRA (or 12 THSR) stations — cheap enough that
/// an index would be premature. Uses `Geolocator.distanceBetween` rather than
/// adding a fifth great-circle helper to this codebase.
NearestRailStation? nearestRailStation(
  List<RailStation> stations, {
  required double latitude,
  required double longitude,
}) {
  NearestRailStation? best;
  for (final station in stations) {
    if (station.lat == 0 && station.lon == 0) {
      continue;
    }
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      station.lat,
      station.lon,
    );
    if (best == null || distance < best.distanceMeters) {
      best = NearestRailStation(station: station, distanceMeters: distance);
    }
  }
  return best;
}
