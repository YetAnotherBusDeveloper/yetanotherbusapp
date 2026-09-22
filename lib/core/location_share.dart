import 'package:geolocator/geolocator.dart';

/// Controls how much coordinate detail is included in a shared map link.
enum LocationSharePrecision {
  approximate,
  exact;

  String get label => switch (this) {
    approximate => '概略位置',
    exact => '精確位置',
  };

  String get description => switch (this) {
    approximate => '約 100 公尺範圍，較適合一般聯絡。',
    exact => '會分享目前座標，請只傳給信任的人。',
  };
}

/// Creates a one-time map link for the system share sheet.
///
/// The app deliberately does not persist or upload the coordinates. The
/// caller must explicitly ask for a position immediately before sharing.
class LocationShareMessage {
  const LocationShareMessage._();

  static String mapUrl({
    required double latitude,
    required double longitude,
    LocationSharePrecision precision = LocationSharePrecision.approximate,
  }) {
    final places = precision == LocationSharePrecision.exact ? 6 : 3;
    final coordinate =
        '${latitude.toStringAsFixed(places)},'
        '${longitude.toStringAsFixed(places)}';
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': coordinate,
    }).toString();
  }

  static String text({
    required Position position,
    LocationSharePrecision precision = LocationSharePrecision.approximate,
  }) {
    final url = mapUrl(
      latitude: position.latitude,
      longitude: position.longitude,
      precision: precision,
    );
    final privacyNote = precision == LocationSharePrecision.exact
        ? '這會包含精確座標，請只分享給信任的人。'
        : '這是約 100 公尺範圍的概略位置。';
    return '我目前的位置（${precision.label}）\n$url\n$privacyNote\n'
        '這是一次性分享，不會持續追蹤。';
  }
}
