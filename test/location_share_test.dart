import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taiwanbus_flutter/core/location_share.dart';

Position _position() => Position(
  latitude: 25.0331234,
  longitude: 121.5654321,
  timestamp: DateTime(2026, 9, 22),
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
  accuracy: 10,
);

void main() {
  test('approximate links round coordinates before sharing', () {
    final url = LocationShareMessage.mapUrl(
      latitude: 25.0331234,
      longitude: 121.5654321,
    );

    final uri = Uri.parse(url);
    expect(uri.queryParameters['query'], '25.033,121.565');
    expect(uri.queryParameters['query'], isNot(contains('25.033123')));
  });

  test('exact links retain six decimal places', () {
    final url = LocationShareMessage.mapUrl(
      latitude: 25.0331234,
      longitude: 121.5654321,
      precision: LocationSharePrecision.exact,
    );

    expect(Uri.parse(url).queryParameters['query'], '25.033123,121.565432');
  });

  test('share text clearly states precision and one-time behavior', () {
    final text = LocationShareMessage.text(position: _position());

    expect(text, contains('概略位置'));
    expect(text, contains('一次性分享'));
    expect(text, contains('100 公尺'));
  });
}
