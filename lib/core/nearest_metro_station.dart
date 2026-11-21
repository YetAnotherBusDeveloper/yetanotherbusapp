import 'package:geolocator/geolocator.dart';

import 'transit_repository.dart';

/// The static data needed to select a station and its serving line together.
class MetroSystemData {
  const MetroSystemData({
    required this.system,
    required this.lines,
    required this.stations,
    required this.stationOfLine,
  });

  final MetroSystem system;
  final List<MetroLine> lines;
  final List<MetroStation> stations;
  final List<MetroStationOfLine> stationOfLine;
}

Future<MetroSystemData> loadMetroSystemData(
  TransitRepository repository,
  MetroSystem system,
) async {
  final results = await Future.wait([
    repository.getMetroLines(system.system),
    repository.getMetroStations(system.system),
    repository.getMetroStationOfLine(system.system),
  ]);
  return MetroSystemData(
    system: system,
    lines: results[0] as List<MetroLine>,
    stations: results[1] as List<MetroStation>,
    stationOfLine: results[2] as List<MetroStationOfLine>,
  );
}

class NearestMetroStation {
  const NearestMetroStation({
    required this.data,
    required this.station,
    required this.line,
    required this.distanceMeters,
  });

  final MetroSystemData data;
  final MetroStation station;
  final MetroLine line;
  final double distanceMeters;
}

/// Finds the nearest station that can be displayed on an available metro line.
///
/// Station-of-line membership is authoritative: the stations endpoint can
/// return an empty `line_id`. At equal distances, keep the preferred system
/// and then its preferred line (useful at interchanges); otherwise retain input
/// order. A preference never overrides a closer station.
NearestMetroStation? nearestMetroStation(
  List<MetroSystemData> systems, {
  required double latitude,
  required double longitude,
  String? preferredSystem,
  String? preferredLineId,
}) {
  if (!_validCoordinates(latitude, longitude)) {
    return null;
  }

  NearestMetroStation? nearest;
  var bestPreference = -1;
  for (final data in systems) {
    final linesById = {
      for (final line in data.lines)
        if (line.lineId.isNotEmpty) line.lineId: line,
    };
    final stationLines = <String, Set<String>>{};
    for (final entry in data.stationOfLine) {
      if (!linesById.containsKey(entry.lineId)) {
        continue;
      }
      for (final station in entry.stations) {
        stationLines
            .putIfAbsent(station.stationId, () => <String>{})
            .add(entry.lineId);
      }
    }

    for (final station in data.stations) {
      if (station.stationId.isEmpty ||
          !_validCoordinates(station.lat, station.lon) ||
          (station.lat == 0 && station.lon == 0)) {
        continue;
      }
      final lineIds = stationLines[station.stationId];
      if (lineIds == null) {
        continue;
      }
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        station.lat,
        station.lon,
      );
      for (final lineId in lineIds) {
        final preferred = data.system.system == preferredSystem;
        final preference = preferred ? (lineId == preferredLineId ? 2 : 1) : 0;
        if (nearest == null ||
            distance < nearest.distanceMeters ||
            (distance == nearest.distanceMeters &&
                preference > bestPreference)) {
          nearest = NearestMetroStation(
            data: data,
            station: station,
            line: linesById[lineId]!,
            distanceMeters: distance,
          );
          bestPreference = preference;
        }
      }
    }
  }
  return nearest;
}

bool _validCoordinates(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180;
