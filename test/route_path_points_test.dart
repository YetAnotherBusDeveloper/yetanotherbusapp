import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/widgets/bus_map_geometry.dart';

// Also run with `flutter test --platform chrome test/route_path_points_test.dart`:
// JavaScript and native Dart have different signed bitwise semantics.
void main() {
  test('route polyline preserves southbound and westbound segments', () async {
    final points = await _loadPolyline('ggxwCwf~dVgEgE@??@dEdE??fEfEgEgE');
    const expected = [
      LatLng(25.033, 121.5654),
      LatLng(25.034, 121.5664),
      LatLng(25.03399, 121.5664),
      LatLng(25.03399, 121.56639),
      LatLng(25.033, 121.5654),
      LatLng(25.033, 121.5654),
      LatLng(25.032, 121.5644),
      LatLng(25.033, 121.5654),
    ];

    // Covers positive, zero, and negative deltas, including -1 on either axis.
    _expectCoordinates(points, expected);
    // Both bus maps filter invalid coordinates through RouteGeometry. Every
    // point must survive that step, including the part after the first turn.
    expect(RouteGeometry.fromPoints(points).points, expected);
  });

  test('route polyline decodes the Google reference example', () async {
    // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    final points = await _loadPolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    const expected = [
      LatLng(38.5, -120.2),
      LatLng(40.7, -120.95),
      LatLng(43.252, -126.453),
    ];

    _expectCoordinates(points, expected);
    expect(RouteGeometry.fromPoints(points).points, expected);
  });
}

Future<List<RoutePathPoint>> _loadPolyline(String polyline) async {
  final client = MockClient((request) async {
    expect(request.url.path, '/api/v1/routes/TPE101320/paths/0/points');
    return http.Response(
      jsonEncode({'polyline': polyline}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  addTearDown(client.close);
  return BusRepository(
    client: client,
  ).getRoutePathPoints('TPE101320', pathId: 0);
}

void _expectCoordinates(List<RoutePathPoint> actual, List<LatLng> expected) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    expect(actual[index].lat, closeTo(expected[index].latitude, 1e-8));
    expect(actual[index].lon, closeTo(expected[index].longitude, 1e-8));
  }
}
