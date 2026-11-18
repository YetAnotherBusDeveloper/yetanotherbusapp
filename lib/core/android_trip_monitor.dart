import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

enum AndroidBackgroundLocationPermissionRequestStatus {
  granted,
  denied,
  openedSettings,
  unavailable,
}

class AndroidDeviceInfo {
  const AndroidDeviceInfo({
    required this.manufacturer,
    required this.brand,
    required this.sdkVersion,
    this.samsungPlatformVersion,
  });

  final String manufacturer;
  final String brand;
  final int sdkVersion;
  final int? samsungPlatformVersion;
}

class TripMonitorStop {
  const TripMonitorStop({
    required this.stopId,
    required this.stopName,
    required this.sequence,
    required this.lat,
    required this.lon,
    this.rawStopId,
    this.liveData,
  });

  factory TripMonitorStop.fromStop(StopInfo stop) {
    final now = DateTime.now();
    final fresh = !isStopRealtimeStale(stop, now: now);
    return TripMonitorStop(
      stopId: stop.stopId,
      rawStopId: stop.rawStopId,
      stopName: stop.stopName,
      sequence: stop.sequence,
      lat: stop.lat,
      lon: stop.lon,
      // What the route screen is showing, for the monitor to show too — and,
      // marked apart from it, what the backend observed and when. The screen
      // counts estimates down between refreshes and keeps the last ones up
      // when a refresh fails; neither is the feed saying anything new, and
      // the monitor reads arrivals and departures only from what the feed
      // said (`observedEta`), once per observation (`observedAtMs`).
      liveData: {
        'eta': effectiveStopEtaSeconds(stop, now: now),
        'observedEta': stop.sec,
        'observedAtMs': stopRealtimeObservedAt(
          stop,
          now: now,
        )?.millisecondsSinceEpoch,
        // A stop merged from the routes of a family: what each of them
        // observed. The soonest estimate above is the badge; these are what
        // the feed said — an estimate, a bus arriving — each with the moment
        // it said it.
        if (stop.routeObservations.isNotEmpty)
          'observations': [
            for (final observation in stop.routeObservations)
              {
                'source': observation.routeId,
                'eta': observation.sec,
                'atMs': observation
                    .observedAt(now: now)
                    ?.millisecondsSinceEpoch,
                'arriving': observation.isArriving,
                'message': observation.msg,
              },
          ],
        'message': stop.msg,
        'buses': [
          if (fresh)
            for (final bus in stop.buses) {'id': bus.id},
        ],
        // Every entry, as the feed has it. Whether a bus is at the stop is
        // for the monitor to judge, and it needs what the feed says for that:
        // `is_arriving`, and the entries that carry no plate — a bus the feed
        // has at the stop without naming it is still a bus at the stop.
        'etas': [
          if (fresh)
            for (final eta in stop.etas)
              {
                'plate': normalizeBusVehicleId(eta.vehicleId) == null
                    ? null
                    : eta.vehicleId,
                'eta': normalizeBusVehicleId(eta.vehicleId) == null
                    ? eta.sec
                    : effectiveStopEtaSecondsForVehicle(
                        stop,
                        eta.vehicleId,
                        now: now,
                      ),
                'observedEta': eta.sec,
                'message': eta.msg,
                'is_arriving': eta.isArriving,
                // Which routes of the family list it: what is said of the
                // bus is as old as their observations.
                if (eta.routeIds.isNotEmpty) 'routes': eta.routeIds,
              },
        ],
      },
    );
  }

  final int stopId;
  final String? rawStopId;
  final String stopName;
  final int sequence;
  final double lat;
  final double lon;
  final Map<String, Object?>? liveData;

  Map<String, Object?> toMap() {
    return {
      'stopId': stopId,
      'rawStopId': rawStopId,
      'stopName': stopName,
      'sequence': sequence,
      'lat': lat,
      'lon': lon,
      if (liveData != null) 'liveData': liveData,
    };
  }
}

class TripMonitorSession {
  const TripMonitorSession({
    required this.providerName,
    required this.routeKey,
    this.routeId,
    this.familyRouteIds = const [],
    required this.routeName,
    required this.pathId,
    required this.pathName,
    required this.appInForeground,
    required this.backgroundLocationAlwaysGranted,
    required this.stops,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLocationTimestampMs,
    this.boardingStopId,
    this.boardingStopName,
    this.destinationStopId,
    this.destinationStopName,
  });

  final String providerName;
  final int routeKey;
  final String? routeId;
  final List<String> familyRouteIds;
  final String routeName;
  final int pathId;
  final String pathName;
  final bool appInForeground;
  final bool backgroundLocationAlwaysGranted;
  final List<TripMonitorStop> stops;
  final double? initialLatitude;
  final double? initialLongitude;

  /// When the initial position was measured, in epoch milliseconds. The route
  /// screen's last fix can be minutes old by the time a trip starts, and the
  /// monitor must not mistake where the rider was for where they are.
  final int? initialLocationTimestampMs;
  final int? boardingStopId;
  final String? boardingStopName;
  final int? destinationStopId;
  final String? destinationStopName;

  Map<String, Object?> toMap() {
    return {
      'provider': providerName,
      'routeKey': routeKey,
      'routeId': routeId,
      'familyRouteIds': familyRouteIds,
      'routeName': routeName,
      'pathId': pathId,
      'pathName': pathName,
      'appInForeground': appInForeground,
      'backgroundLocationAlwaysGranted': backgroundLocationAlwaysGranted,
      'initialLatitude': initialLatitude,
      'initialLongitude': initialLongitude,
      'initialLocationTimestampMs': initialLocationTimestampMs,
      'boardingStopId': boardingStopId,
      'boardingStopName': boardingStopName,
      'destinationStopId': destinationStopId,
      'destinationStopName': destinationStopName,
      'stops': stops.map((stop) => stop.toMap()).toList(),
    };
  }
}

class AndroidTripMonitor {
  AndroidTripMonitor._();

  static const _channel = MethodChannel(
    'tw.avianjay.taiwanbus.flutter/trip_monitor',
  );

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<T?> _invokeMethod<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!_isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } catch (_) {
      // The activity/engine can briefly detach during lifecycle transitions.
      return null;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    if (!_isAndroid) {
      return false;
    }
    return await _invokeMethod<bool>('requestNotificationPermission') ?? false;
  }

  static Future<AndroidBackgroundLocationPermissionRequestStatus>
  requestBackgroundLocationPermission() async {
    if (!_isAndroid) {
      return AndroidBackgroundLocationPermissionRequestStatus.unavailable;
    }
    final status = await _invokeMethod<String>(
      'requestBackgroundLocationPermission',
    );
    return switch (status) {
      'granted' => AndroidBackgroundLocationPermissionRequestStatus.granted,
      'opened_settings' =>
        AndroidBackgroundLocationPermissionRequestStatus.openedSettings,
      'denied' => AndroidBackgroundLocationPermissionRequestStatus.denied,
      _ => AndroidBackgroundLocationPermissionRequestStatus.unavailable,
    };
  }

  static Future<void> startOrUpdate(TripMonitorSession session) async {
    if (!_isAndroid) {
      return;
    }
    await _invokeMethod<void>('startOrUpdateTripMonitor', {
      'session': session.toMap(),
    });
  }

  static Future<void> setAppInForeground(bool value) async {
    if (!_isAndroid) {
      return;
    }
    await _invokeMethod<void>('setTripMonitorAppInForeground', {
      'appInForeground': value,
    });
  }

  static Future<void> pause(
    TripMonitorSession session, {
    String reason = 'user',
  }) async {
    if (!_isAndroid) {
      return;
    }
    await _invokeMethod<void>('pauseTripMonitor', {
      'session': session.toMap(),
      'reason': reason,
    });
  }

  static Future<void> resume() async {
    if (!_isAndroid) {
      return;
    }
    await _invokeMethod<void>('resumeTripMonitor');
  }

  static Future<bool> isPausedFor(TripMonitorSession session) async {
    if (!_isAndroid) {
      return false;
    }
    return await _invokeMethod<bool>('isTripMonitorPaused', {
          'session': session.toMap(),
        }) ??
        false;
  }

  static Future<void> stop() async {
    if (!_isAndroid) {
      return;
    }
    await _invokeMethod<void>('stopTripMonitor');
  }

  static Future<AndroidDeviceInfo?> getAndroidDeviceInfo() async {
    if (!_isAndroid) {
      return null;
    }
    final result = await _invokeMethod<Map<Object?, Object?>>(
      'getAndroidDeviceInfo',
    );
    if (result == null) return null;
    return AndroidDeviceInfo(
      manufacturer: result['manufacturer'] as String? ?? '',
      brand: result['brand'] as String? ?? '',
      sdkVersion: result['sdkVersion'] as int? ?? 0,
      samsungPlatformVersion: result['samsungPlatformVersion'] as int?,
    );
  }

  static Future<void> openNotificationChannelSettings() async {
    if (!_isAndroid) {
      return;
    }
    await _invokeMethod<void>('openNotificationChannelSettings');
  }

  static Future<bool> openSamsungLiveNotificationSettings() async {
    if (!_isAndroid) {
      return false;
    }
    return await _invokeMethod<bool>('openSamsungLiveNotificationSettings') ??
        false;
  }
}
