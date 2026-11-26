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
/// `getCurrentPosition` directly: that triggers the browser prompt, and the
/// browser starts [timeLimit] only once permission is granted, so a user who is
/// still deciding is never timed out, while a granted-but-failed fix is bounded.
/// A position error there is a failed fix, not a permission refusal.
Future<Position> resolveUserPosition({
  Duration timeLimit = const Duration(seconds: 6),
  LocationAccuracy accuracy = LocationAccuracy.medium,
  @visibleForTesting bool? webOverride,
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
    final fix = Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeLimit,
      ),
    );
    // On web the browser enforces the limit after the prompt is answered; a
    // Dart-side timeout would also expire a prompt the user is still reading.
    return await (isWeb ? fix : fix.timeout(timeLimit));
  } on PermissionDeniedException {
    throw const LocationFailure('沒有取得定位權限。', permissionDenied: true);
  } catch (_) {
    if (lastKnown != null) {
      return lastKnown;
    }
    throw const LocationFailure('目前無法取得定位，請稍後再試。');
  }
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
