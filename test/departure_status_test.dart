import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';

DateTime at(String clock) => DateTime.parse('2026-10-26T$clock:00+08:00');

void main() {
  final departure = DepartureInfo(
    scheduledAt: at('10:00'),
    observedAt: at('10:05'),
    nextScheduledAt: at('10:20'),
    reportedNotDeparted: true,
    grace: const Duration(minutes: 10),
  );
  final pending = StopInfo(
    routeKey: 500,
    pathId: 0,
    stopId: 2,
    stopName: 'Downstream stop',
    sequence: 2,
    lon: 120.6,
    lat: 24.1,
    msg: '10:00',
    departure: departure,
  );

  EtaPresentation presentation(StopInfo stop, DateTime now) =>
      buildEtaPresentation(stop, alwaysShowSeconds: true, now: now);

  test('counts elapsed origin minutes upward, never arrival seconds', () {
    expect(presentation(pending, at('10:05')).text, '未發車\n5分');
    expect(presentation(pending, at('10:06')).text, '未發車\n6分');
    expect(effectiveStopEtaSeconds(pending, now: at('10:05')), isNull);
    expect(
      presentation(pending, at('10:05')).description,
      contains('起點表定 10:00'),
    );
    expect(
      presentation(pending, at('10:05')).description,
      contains('已逾表定 5 分鐘'),
    );
  });

  test('stale source becomes unconfirmed without restarting elapsed time', () {
    final now = at('10:06').add(const Duration(seconds: 31));
    expect(presentation(pending, now).text, '未確認\n逾6分');
    expect(presentation(pending, now).description, contains('動態未確認'));
    final refreshed = pending.copyWith(
      departure: DepartureInfo(
        scheduledAt: departure.scheduledAt,
        observedAt: now,
        reportedNotDeparted: true,
      ),
    );
    expect(presentation(refreshed, now).text, '未發車\n6分');
  });

  test('before departure shows only the time in every locale', () {
    expect(presentation(pending, at('09:59')).text, '10:00');
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(
        buildEtaPresentation(
          pending,
          alwaysShowSeconds: true,
          now: at('09:59'),
          l10n: l10n,
        ).text,
        '10:00',
      );
    }
    expect(presentation(pending, at('09:59')).description, '起點表定 10:00 發車');
  });

  test('zero elapsed minutes is not arriving', () {
    final stop = pending.copyWith(
      departure: DepartureInfo(
        scheduledAt: at('10:00'),
        observedAt: at('10:00'),
        reportedNotDeparted: true,
      ),
    );
    expect(presentation(stop, at('10:00')).text, '未發車');
    expect(effectiveStopEtaSeconds(stop, now: at('10:00')), isNull);
  });

  test(
    'grace boundary selects next timetable but retains preceding trip detail',
    () {
      expect(presentation(pending, at('10:09')).text, '未確認\n逾9分');
      final afterGrace = presentation(pending, at('10:10'));
      expect(afterGrace.text, '下班\n10:20');
      expect(afterGrace.description, contains('前班起點表定 10:00'));
      expect(afterGrace.description, contains('動態未確認'));
      expect(presentation(pending, at('10:21')).text, '未確認\n逾21分');
    },
  );

  test('missing next departure never fabricates a time or cancellation', () {
    final stop = pending.copyWith(
      departure: DepartureInfo(
        scheduledAt: at('10:00'),
        reportedNotDeparted: false,
      ),
    );
    expect(presentation(stop, at('10:30')).text, '未確認\n逾30分');
  });

  test('fresh ETA without GPS replaces overdue count even after grace', () {
    final live = pending.copyWith(
      sec: 720,
      t: at('10:12').toIso8601String(),
      etaReferenceAt: at('10:12').toIso8601String(),
    );
    expect(live.buses, isEmpty);
    expect(presentation(live, at('10:12')).text, '12分\n0秒');
    expect(
      effectiveStopEtaMessageForVehicle(live, null, now: at('10:12')),
      isNull,
    );
    expect(effectiveStopEtaSeconds(live, now: at('10:12')), 720);
  });

  test('old arriving ETA cannot mask a new departure observation', () {
    final old = pending.copyWith(sec: 0, t: at('09:58').toIso8601String());
    expect(presentation(old, at('10:05')).text, '未發車\n5分');
    expect(effectiveStopEtaSeconds(old, now: at('10:05')), isNull);
  });

  test('fresh origin observation does not refresh an undated stop ETA', () {
    final unknownAge = pending.copyWith(
      sec: 0,
      etaReferenceAt: at('10:05').toIso8601String(),
    );
    expect(presentation(unknownAge, at('10:05')).text, '未發車\n5分');
    expect(effectiveStopEtaSeconds(unknownAge, now: at('10:05')), isNull);
  });

  test('a looping vehicle old trip cannot hide the pending departure', () {
    final stop = pending.copyWith(
      etas: [
        StopEta(
          vehicleId: 'LOOP-500',
          sec: 0,
          updatedAt: at('09:55').toIso8601String(),
        ),
      ],
    );
    expect(
      effectiveStopEtaSecondsForVehicle(stop, 'LOOP-500', now: at('10:05')),
      isNull,
    );
    expect(
      effectiveStopEtaMessageForVehicle(stop, 'LOOP-500', now: at('10:05')),
      '未發車\n5分',
    );
  });

  test('replacement snapshot clears pending status and old numeric ETA', () {
    final oldVehicle = pending.copyWith(
      etas: const [StopEta(sec: 0, vehicleId: 'OLD')],
    );
    final live = oldVehicle.copyWith(replaceLiveData: true, sec: 240);
    expect(live.etas, isEmpty);
    expect(live.departure, isNull);
    expect(live.msg, isNull);
    final waiting = live.copyWith(replaceLiveData: true, departure: departure);
    expect(waiting.sec, isNull);
    expect(presentation(waiting, at('10:05')).text, '未發車\n5分');
    expect(hasRealtimeStopData(waiting), isTrue);
  });

  test('cross-midnight counters and displayed clocks are Taiwan-local', () {
    final midnight = DepartureInfo(
      scheduledAt: DateTime.parse('2026-10-26T23:58:00+08:00'),
      observedAt: DateTime.parse('2026-10-27T00:03:00+08:00'),
      reportedNotDeparted: true,
    );
    final now = DateTime.parse('2026-10-27T00:03:00+08:00');
    expect(midnight.label(now.toUtc()), '未發車\n5分');
    expect(midnight.description(now), contains('23:58'));
  });

  test('API decoding rejects invalid times and bounds grace periods', () {
    expect(DepartureInfo.fromJson(null), isNull);
    expect(DepartureInfo.fromJson({'scheduled_at': 'oops'}), isNull);
    final parsed = DepartureInfo.fromJson({
      'scheduled_at': at('10:00').millisecondsSinceEpoch ~/ 1000,
      'observed_at': at('10:05').millisecondsSinceEpoch ~/ 1000,
      'next_scheduled_at': at('09:00').millisecondsSinceEpoch ~/ 1000,
      'status': 'not_departed',
      'grace_seconds': 3600,
      'trip_id': '500-1',
    })!;
    expect(parsed.scheduledAt, at('10:00'));
    expect(parsed.grace, const Duration(minutes: 15));
    expect(parsed.nextScheduledAt, isNull);
    expect(parsed.label(at('10:05')), '未發車\n5分');
  });

  test('English labels distinguish elapsed delay from arrival ETA', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(departure.label(at('10:05'), l10n: l10n), 'Not departed\n5m late');
    expect(
      departure.description(at('10:05'), l10n: l10n),
      contains('past departure'),
    );
  });
}
