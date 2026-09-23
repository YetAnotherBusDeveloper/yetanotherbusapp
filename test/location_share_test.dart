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

  test('social update can share information without requesting a location', () {
    final text = SocialShareMessage.compose(
      displayName: 'Steven',
      activity: SocialShareActivity.waiting,
      duration: SocialShareDuration.fifteenMinutes,
      note: '  我在捷運站  2 號出口等你  ',
      createdAt: DateTime(2026, 9, 23, 9, 30),
    );

    expect(text, contains('Steven 的近況｜正在等車'));
    expect(text, contains('我在捷運站 2 號出口等你'));
    expect(text, contains('建議查看至：2026/09/23 09:45'));
    expect(text, isNot(contains('google.com/maps')));
  });

  test('social update includes privacy-labelled approximate location', () {
    final text = SocialShareMessage.compose(
      displayName: '',
      activity: SocialShareActivity.arriving,
      duration: SocialShareDuration.oneHour,
      position: _position(),
      createdAt: DateTime(2026, 9, 23, 9, 30),
    );

    expect(text, contains('我的近況｜即將抵達'));
    expect(text, contains('位置（概略位置）'));
    expect(text, contains('25.033%2C121.565'));
    expect(text, contains('無法遠端撤回'));
  });

  test('social update limits long notes', () {
    final note = List.filled(140, 'a').join();
    final text = SocialShareMessage.compose(
      displayName: 'Steven',
      activity: SocialShareActivity.riding,
      duration: SocialShareDuration.oneDay,
      note: note,
      createdAt: DateTime(2026, 9, 23),
    );

    expect(text, contains(List.filled(120, 'a').join()));
    expect(text, isNot(contains(List.filled(121, 'a').join())));
  });
}
