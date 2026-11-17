import 'dart:math' as math;

import 'models.dart';
import 'route_direction_label.dart';

String routeFamilyName(String routeName) {
  final normalizedName = routeName.trim();
  final familyName = normalizedName.replaceFirst(RegExp(r'(?:延|跳蛙)+$'), '');
  return familyName.isEmpty ? normalizedName : familyName;
}

/// Whether two route-variant stops refer to the same side of a physical stop.
///
/// TDX commonly assigns different stop IDs to the same platform for separate
/// routes, so a matching nonempty raw ID is sufficient but not required.
/// Name and coordinates provide a conservative fallback for those cases.
bool routeFamilyStopsSharePhysicalSide(StopInfo first, StopInfo second) {
  final firstRawStopId = first.rawStopId?.trim();
  final secondRawStopId = second.rawStopId?.trim();
  if (firstRawStopId != null &&
      firstRawStopId.isNotEmpty &&
      firstRawStopId == secondRawStopId) {
    return true;
  }

  if (_normalizedStopName(first.stopName) !=
          _normalizedStopName(second.stopName) ||
      !_hasCoordinates(first) ||
      !_hasCoordinates(second)) {
    return false;
  }

  return _distanceMeters(first, second) <= 60;
}

/// Combines live data from route-family variants that serve one physical stop.
///
/// The selected route owns the stop identity. The earliest live ETA becomes
/// the shared badge value while vehicle and vehicle-specific ETA lists combine.
///
/// [baseRouteId] and [sharedRouteIds] say which route each stop is from, the
/// latter in the order of [sharedStops]. Given them, the merged stop also
/// keeps what each route observed, estimate and moment together.
StopInfo mergeRouteFamilyStopLiveData(
  StopInfo baseStop,
  List<StopInfo> sharedStops, {
  String? baseRouteId,
  List<String>? sharedRouteIds,
}) {
  final allStops = <StopInfo>[baseStop, ...sharedStops];
  final routeObservations = <String, StopRouteObservation>{};
  if (baseRouteId != null &&
      sharedRouteIds != null &&
      sharedRouteIds.length == sharedStops.length) {
    final routeIds = <String>[baseRouteId, ...sharedRouteIds];
    for (var index = 0; index < allStops.length; index++) {
      final stop = allStops[index];
      if (stop.sec == null && stop.etaReferenceAt == null && stop.t == null) {
        continue;
      }
      routeObservations.putIfAbsent(
        routeIds[index],
        () => StopRouteObservation(
          routeId: routeIds[index],
          sec: stop.sec,
          etaReferenceAt: stop.etaReferenceAt,
          updatedAt: stop.t,
        ),
      );
    }
  }
  final etaStops =
      allStops
          .where((stop) => effectiveStopEtaSeconds(stop) != null)
          .toList(growable: false)
        ..sort(
          (left, right) => effectiveStopEtaSeconds(
            left,
          )!.compareTo(effectiveStopEtaSeconds(right)!),
        );
  final primaryEtaStop = etaStops.isEmpty ? null : etaStops.first;
  final primaryMessageStop = allStops.firstWhere(
    (stop) => stop.msg?.trim().isNotEmpty == true,
    orElse: () => baseStop,
  );
  final busesById = <String, BusVehicle>{};
  final etasByKey = <String, StopEta>{};
  for (final stop in allStops) {
    if (isStopRealtimeStale(stop)) continue;
    for (final bus in stop.buses) {
      busesById.putIfAbsent(
        bus.id.trim().isEmpty ? '${bus.source}:${busesById.length}' : bus.id,
        () => bus,
      );
    }
    for (final eta in stop.etas) {
      final key =
          '${eta.vehicleId}:${eta.sec}:${eta.msg}:${eta.source}:${eta.estimated}'
          ':${eta.isArriving}';
      etasByKey.putIfAbsent(
        key,
        () => StopEta(
          sec: eta.sec,
          msg: eta.msg,
          vehicleId: eta.vehicleId,
          source: eta.source,
          estimated: eta.estimated,
          isArriving: eta.isArriving,
          etaReferenceAt: eta.etaReferenceAt ?? stop.etaReferenceAt,
          updatedAt: eta.updatedAt ?? stop.t,
        ),
      );
    }
  }

  return StopInfo(
    routeKey: baseStop.routeKey,
    pathId: baseStop.pathId,
    stopId: baseStop.stopId,
    rawStopId: baseStop.rawStopId,
    stopName: baseStop.stopName,
    stopNameEn: baseStop.stopNameEn,
    sequence: baseStop.sequence,
    lon: baseStop.lon,
    lat: baseStop.lat,
    sec: primaryEtaStop?.sec,
    msg: primaryEtaStop == null ? primaryMessageStop.msg : null,
    t: (primaryEtaStop ?? primaryMessageStop).t,
    etaReferenceAt: (primaryEtaStop ?? primaryMessageStop).etaReferenceAt,
    buses: busesById.values.toList(growable: false),
    etas: etasByKey.values.toList(growable: false),
    routeObservations: routeObservations.values.toList(growable: false),
  );
}

/// Preserves the selected route's topology while sharing live data from its
/// variants at stops that both directions physically serve.
RouteDetailData mergeRouteFamilyLiveData(
  RouteDetailData selected,
  List<RouteDetailData> variants,
) {
  if (variants.isEmpty) {
    return selected;
  }

  final stopsByPath = <int, List<StopInfo>>{};
  for (final path in selected.paths) {
    final selectedStops =
        selected.stopsByPath[path.pathId] ?? const <StopInfo>[];
    final variantStops = <({String routeId, StopInfo stop})>[];
    for (final variant in variants) {
      for (final variantPath in variant.paths) {
        if (directionOrdinalLabel(variantPath.pathId) !=
            directionOrdinalLabel(path.pathId)) {
          continue;
        }
        for (final stop
            in variant.stopsByPath[variantPath.pathId] ?? const <StopInfo>[]) {
          variantStops.add((routeId: variant.route.routeId, stop: stop));
        }
      }
    }
    stopsByPath[path.pathId] = selectedStops
        .map((stop) {
          final shared = variantStops
              .where(
                (variant) =>
                    routeFamilyStopsSharePhysicalSide(stop, variant.stop),
              )
              .toList(growable: false);
          return shared.isEmpty
              ? stop
              : mergeRouteFamilyStopLiveData(
                  stop,
                  [for (final variant in shared) variant.stop],
                  baseRouteId: selected.route.routeId,
                  sharedRouteIds: [
                    for (final variant in shared) variant.routeId,
                  ],
                );
        })
        .toList(growable: false);
  }

  return RouteDetailData(
    route: selected.route,
    paths: selected.paths,
    stopsByPath: stopsByPath,
    hasLiveData:
        selected.hasLiveData || variants.any((variant) => variant.hasLiveData),
    familyRouteIds: <String>{
      selected.route.routeId,
      ...variants.map((variant) => variant.route.routeId),
    }.toList(growable: false),
  );
}

String _normalizedStopName(String stopName) =>
    stopName.trim().replaceAll(RegExp(r'\s+'), '');

bool _hasCoordinates(StopInfo stop) => stop.lat != 0 || stop.lon != 0;

double _distanceMeters(StopInfo first, StopInfo second) {
  const earthRadiusMeters = 6378137.0;
  final latitudeDelta = _toRadians(second.lat - first.lat);
  final longitudeDelta = _toRadians(second.lon - first.lon);
  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(_toRadians(first.lat)) *
          math.cos(_toRadians(second.lat)) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
