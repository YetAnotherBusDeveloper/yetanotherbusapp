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

/// A short, transit-oriented status included in a social update.
enum SocialShareActivity {
  waiting,
  riding,
  arriving,
  meetUp;

  String get label => switch (this) {
    waiting => '正在等車',
    riding => '正在搭車',
    arriving => '即將抵達',
    meetUp => '想約人同行',
  };
}

/// How long the sender considers an update relevant.
///
/// This is deliberately described as a viewing deadline, rather than a hard
/// expiry: content copied to another app cannot be remotely revoked.
enum SocialShareDuration {
  fifteenMinutes(Duration(minutes: 15), '15 分鐘'),
  oneHour(Duration(hours: 1), '1 小時'),
  oneDay(Duration(days: 1), '24 小時');

  const SocialShareDuration(this.duration, this.label);

  final Duration duration;
  final String label;
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

/// Builds a privacy-conscious social update for the system share sheet.
class SocialShareMessage {
  const SocialShareMessage._();

  static const int noteMaxLength = 120;

  static String normalizeNote(String note) {
    final normalized = note.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= noteMaxLength) {
      return normalized;
    }
    return normalized.substring(0, noteMaxLength).trimRight();
  }

  static String compose({
    required String displayName,
    required SocialShareActivity activity,
    required SocialShareDuration duration,
    Position? position,
    LocationSharePrecision precision = LocationSharePrecision.approximate,
    String note = '',
    DateTime? createdAt,
  }) {
    final sender = displayName.trim();
    final created = (createdAt ?? DateTime.now()).toLocal();
    final viewUntil = created.add(duration.duration);
    final normalizedNote = normalizeNote(note);
    final lines = <String>[
      '${sender.isEmpty ? '我的' : '$sender 的'}近況｜${activity.label}',
      if (normalizedNote.isNotEmpty) normalizedNote,
      if (position != null) ...[
        '',
        '位置（${precision.label}）',
        LocationShareMessage.mapUrl(
          latitude: position.latitude,
          longitude: position.longitude,
          precision: precision,
        ),
        precision == LocationSharePrecision.exact
            ? '含有精確座標，請只分享給信任的人。'
            : '位置已簡化為約 100 公尺範圍。',
      ],
      '',
      '分享時間：${_formatDateTime(created)}',
      '建議查看至：${_formatDateTime(viewUntil)}（${duration.label}）',
      '這是一次性分享；複製或轉傳到其他 App 後無法遠端撤回。',
    ];
    return lines.join('\n');
  }

  static String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}/${twoDigits(value.month)}/${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
