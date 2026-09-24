import '../core/models.dart';
import '../core/route_direction_label.dart';

class NearbyStopGroup {
  const NearbyStopGroup({required this.stopName, required this.sides});

  final String stopName;
  final List<NearbyStopSideGroup> sides;
}

class NearbyStopSideGroup {
  const NearbyStopSideGroup({
    required this.key,
    required this.directionLabel,
    required this.distanceMeters,
    required this.routes,
  });

  final String key;
  final String directionLabel;
  final double distanceMeters;
  final List<NearbyRouteRow> routes;
}

class _MutableSideGroup {
  _MutableSideGroup({required this.key, required this.firstIndex});

  final String key;
  final int firstIndex;
  final List<NearbyRouteRow> routes = [];
  double distanceMeters = double.infinity;
  String directionLabel = '';
}

/// Groups nearby results into station cards and physical stop-side sections.
List<NearbyStopGroup> groupNearbyStops(
  List<NearbyStopResult> results, {
  required String locale,
  Comparator<NearbyStopResult>? compareRoutes,
}) {
  final stopOrder = <String>[];
  final resultsByStop = <String, List<NearbyStopResult>>{};
  for (final result in results) {
    final name = result.stop.stopName;
    if (!resultsByStop.containsKey(name)) {
      stopOrder.add(name);
      resultsByStop[name] = [];
    }
    resultsByStop[name]!.add(result);
  }

  return [
    for (final stopName in stopOrder)
      NearbyStopGroup(
        stopName: stopName,
        sides: _groupStopSides(
          resultsByStop[stopName]!,
          locale: locale,
          compareRoutes: compareRoutes,
        ),
      ),
  ];
}

List<NearbyStopSideGroup> _groupStopSides(
  List<NearbyStopResult> results, {
  required String locale,
  Comparator<NearbyStopResult>? compareRoutes,
}) {
  final rows = labelNearbyRouteDirections(results, locale: locale);
  final sidesByKey = <String, _MutableSideGroup>{};

  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final key = nearbyStopSideKey(row.result);
    final side = sidesByKey.putIfAbsent(
      key,
      () => _MutableSideGroup(key: key, firstIndex: index),
    );
    side.routes.add(row);
    if (side.directionLabel.isEmpty && row.directionLabel.isNotEmpty) {
      side.directionLabel = row.directionLabel;
    }
    if (row.result.distanceMeters < side.distanceMeters) {
      side.distanceMeters = row.result.distanceMeters;
    }
  }

  final sides = sidesByKey.values.toList(growable: false)
    ..sort((left, right) {
      final byDistance = left.distanceMeters.compareTo(right.distanceMeters);
      return byDistance != 0
          ? byDistance
          : left.firstIndex.compareTo(right.firstIndex);
    });

  return [
    for (final side in sides)
      NearbyStopSideGroup(
        key: side.key,
        directionLabel: side.directionLabel,
        distanceMeters: side.distanceMeters,
        routes: compareRoutes == null
            ? List.unmodifiable(side.routes)
            : (List<NearbyRouteRow>.of(side.routes)..sort(
                (left, right) => compareRoutes(left.result, right.result),
              )),
      ),
  ];
}

/// Uses the source stop ID when available. Coordinate/path identity is the
/// stable fallback for sources that do not expose one.
String nearbyStopSideKey(NearbyStopResult result) {
  final rawStopId = result.stop.rawStopId?.trim() ?? '';
  if (rawStopId.isNotEmpty) {
    return 'id:$rawStopId';
  }

  final directionIdentity = [
    result.stop.pathId.toString(),
    _normalizeIdentity(result.route.description),
    _normalizeIdentity(result.route.pathNameEn),
  ].join(':');
  return 'fallback:${result.stop.lat.toStringAsFixed(6)}:'
      '${result.stop.lon.toStringAsFixed(6)}:$directionIdentity';
}

String _normalizeIdentity(String? value) =>
    (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
