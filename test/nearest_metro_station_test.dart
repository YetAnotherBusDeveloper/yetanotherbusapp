import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/nearest_metro_station.dart';
import 'package:taiwanbus_flutter/core/transit_repository.dart';

MetroLine _line(String id) =>
    MetroLine(lineId: id, lineNo: id, name: id, nameEn: id, color: '');

MetroStation _station(
  String id, {
  double latitude = 25,
  double longitude = 121,
  String lineId = '',
}) => MetroStation(
  stationId: id,
  name: id,
  nameEn: id,
  lineId: lineId,
  lat: latitude,
  lon: longitude,
);

MetroStationOfLine _membership(String lineId, List<String> stationIds) =>
    MetroStationOfLine(
      lineId: lineId,
      direction: 0,
      stations: [
        for (var index = 0; index < stationIds.length; index++)
          MetroStationSequence(
            stationId: stationIds[index],
            name: stationIds[index],
            nameEn: stationIds[index],
            sequence: index + 1,
          ),
      ],
    );

MetroSystemData _system(
  String code, {
  required List<MetroStation> stations,
  List<String> lines = const ['R'],
  List<MetroStationOfLine>? stationOfLine,
}) => MetroSystemData(
  system: MetroSystem(system: code, city: code, name: code, nameEn: code),
  lines: lines.map(_line).toList(),
  stations: stations,
  stationOfLine:
      stationOfLine ??
      [_membership(lines.first, stations.map((s) => s.stationId).toList())],
);

void main() {
  test(
    'chooses the closest station across systems regardless of preference',
    () {
      final result = nearestMetroStation(
        [
          _system('TRTC', stations: [_station('far', latitude: 25.2)]),
          _system('TYMC', stations: [_station('near', latitude: 25.001)]),
        ],
        latitude: 25,
        longitude: 121,
        preferredSystem: 'TRTC',
        preferredLineId: 'R',
      );

      expect(result!.data.system.system, 'TYMC');
      expect(result.station.stationId, 'near');
      expect(result.distanceMeters, closeTo(111, 1));
    },
  );

  test(
    'uses station membership even when station line ID is empty or wrong',
    () {
      for (final lineId in ['', 'unknown']) {
        final result = nearestMetroStation(
          [
            _system('TRTC', stations: [_station('R01', lineId: lineId)]),
          ],
          latitude: 25,
          longitude: 121,
        );

        expect(result!.line.lineId, 'R');
        expect(result.station.stationId, 'R01');
      }
    },
  );

  test('ignores missing and invalid station coordinates', () {
    final invalidStations = [
      _station('zero', latitude: 0, longitude: 0),
      _station('nan', latitude: double.nan),
      _station('infinity', longitude: double.infinity),
      _station('latitude', latitude: 91),
      _station('longitude', longitude: -181),
    ];
    final result = nearestMetroStation(
      [
        _system(
          'TRTC',
          stations: [...invalidStations, _station('valid', latitude: 25.1)],
        ),
      ],
      latitude: 25,
      longitude: 121,
    );

    expect(result!.station.stationId, 'valid');
    expect(
      nearestMetroStation(
        [_system('TRTC', stations: invalidStations)],
        latitude: 25,
        longitude: 121,
      ),
      isNull,
    );
  });

  test('ignores stations without membership in an available line', () {
    final result = nearestMetroStation(
      [
        _system(
          'TRTC',
          stations: [
            _station('orphan', lineId: 'R'),
            _station('unknown-line'),
            _station('empty-line'),
            _station('valid', latitude: 25.1),
          ],
          lines: ['R', ''],
          stationOfLine: [
            _membership('missing', ['unknown-line']),
            _membership('', ['empty-line']),
            _membership('R', ['valid']),
          ],
        ),
      ],
      latitude: 25,
      longitude: 121,
    );

    expect(result!.station.stationId, 'valid');
  });

  test('prefers the current line at an interchange only in its own system', () {
    final systems = [
      _system('TYMC', stations: [_station('A1')], lines: ['G']),
      _system(
        'TRTC',
        stations: [_station('interchange')],
        lines: ['R', 'G'],
        stationOfLine: [
          _membership('R', ['interchange']),
          _membership('G', ['interchange']),
        ],
      ),
    ];
    final result = nearestMetroStation(
      systems,
      latitude: 25,
      longitude: 121,
      preferredSystem: 'TRTC',
      preferredLineId: 'G',
    );

    expect(result!.data.system.system, 'TRTC');
    expect(result.line.lineId, 'G');
    expect(result.station.stationId, 'interchange');
  });

  test(
    'equal distances preserve input order without a matching preference',
    () {
      final result = nearestMetroStation(
        [
          _system('first', stations: [_station('first'), _station('second')]),
          _system('second', stations: [_station('third')]),
        ],
        latitude: 25,
        longitude: 121,
        preferredSystem: 'missing',
        preferredLineId: 'R',
      );

      expect(result!.data.system.system, 'first');
      expect(result.station.stationId, 'first');
    },
  );

  test('returns null for empty data or an invalid user location', () {
    expect(nearestMetroStation([], latitude: 25, longitude: 121), isNull);
    final systems = [
      _system('TRTC', stations: [_station('R01')]),
    ];
    for (final coordinates in [
      (double.nan, 121.0),
      (25.0, double.infinity),
      (-91.0, 121.0),
      (25.0, 181.0),
    ]) {
      expect(
        nearestMetroStation(
          systems,
          latitude: coordinates.$1,
          longitude: coordinates.$2,
        ),
        isNull,
      );
    }
  });
}
