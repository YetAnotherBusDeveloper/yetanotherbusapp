import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/smart_route_plan.dart';

import 'support/route_usage_fixtures.dart';

void main() {
  // 2026-04-08 is a Wednesday.
  final wednesdayEarly = DateTime(2026, 4, 8, 6);

  String? routeIdOf(RouteUsageProfile profile) => 'KHH${profile.routeKey}';

  RouteUsageProfile commute({int? stopId, DateTime? before}) =>
      profileWithVisits(
        daysBefore(before ?? wednesdayEarly, count: 15, hour: 7, minute: 40),
        stopId: stopId,
      );

  test('a weekday commute is planned for weekdays, around its usual time', () {
    final plan = SmartRoutePlanner.build(
      routeIdOf: routeIdOf,
      profiles: [commute(stopId: 1001)],
      now: wednesdayEarly,
    );

    expect(plan.slots.map((slot) => slot.weekday), [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ]);
    for (final slot in plan.slots) {
      // 07:10 to 08:10, in minutes since 04:00.
      expect(slot.startMinute, 190);
      expect(slot.endMinute, 250);
      expect(slot.peakMinute, 220);
      expect(slot.confidence, greaterThan(0.85));
      expect(slot.supportDays, 15);
      expect(slot.stopId, 1001);
      expect(slot.routeKey, 101);
      expect(slot.routeId, 'KHH101');
      expect(slot.pathId, 0);
    }
    expect(plan.generatedAtMs, wednesdayEarly.millisecondsSinceEpoch);
  });

  test('a slot expires two weeks after the habit was last seen', () {
    final plan = SmartRoutePlanner.build(
      routeIdOf: routeIdOf,
      profiles: [commute()],
      now: wednesdayEarly,
    );

    // Last seen on Tuesday the 7th; good through the service day of the 21st,
    // which ends at 04:00 on the 22nd.
    expect(plan.slots.map((slot) => slot.validUntilMs).toSet(), {
      DateTime(2026, 4, 22, 4).millisecondsSinceEpoch,
    });
    expect(plan.slots.map((slot) => slot.lastActivityAtMs).toSet(), {
      DateTime(2026, 4, 7, 7, 40).millisecondsSinceEpoch,
    });
  });

  test('two days of use are not enough to interrupt anyone', () {
    final plan = SmartRoutePlanner.build(
      routeIdOf: routeIdOf,
      profiles: [
        profileWithVisits(
          daysBefore(wednesdayEarly, count: 2, hour: 7, minute: 40),
        ),
      ],
      now: wednesdayEarly,
    );

    expect(plan.slots, isEmpty);
  });

  test('a use this morning counts toward tomorrow, not toward today', () {
    final afterTodaysRide = DateTime(2026, 4, 8, 9);
    final plan = SmartRoutePlanner.build(
      routeIdOf: routeIdOf,
      profiles: [
        profileWithVisits([
          DateTime(2026, 4, 6, 7, 40),
          DateTime(2026, 4, 7, 7, 40),
          DateTime(2026, 4, 8, 7, 40),
        ]),
      ],
      now: afterTodaysRide,
    );

    expect(plan.slots.map((slot) => slot.weekday), [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.thursday,
      DateTime.friday,
    ]);
    expect(plan.slots.map((slot) => slot.supportDays).toSet(), {3});
  });

  test('separate habits on one route get separate windows', () {
    final now = DateTime(2026, 4, 8, 5);
    final plan = SmartRoutePlanner.build(
      routeIdOf: routeIdOf,
      profiles: [
        profileWithVisits([
          ...daysBefore(now, count: 10, hour: 7, minute: 40),
          ...daysBefore(now, count: 10, hour: 18, minute: 10),
        ]),
      ],
      now: now,
    );

    final wednesday = plan.slots
        .where((slot) => slot.weekday == DateTime.wednesday)
        .toList();
    expect(wednesday.map((slot) => slot.peakMinute), [
      // 07:40 and 18:10.
      220,
      850,
    ]);
    expect(wednesday.first.endMinute, lessThan(wednesday.last.startMinute));
  });

  test('a route that cannot be named is left out', () {
    final plan = SmartRoutePlanner.build(
      profiles: [
        commute(),
        profileWithVisits(
          daysBefore(wednesdayEarly, count: 15, hour: 9, minute: 0),
          routeKey: 303,
        ),
      ],
      routeIdOf: (profile) => profile.routeKey == 303 ? '  ' : 'KHH101',
      now: wednesdayEarly,
    );

    expect(plan.slots.map((slot) => slot.routeKey).toSet(), {101});
  });

  test('says which routes are worth looking a route id up for', () {
    expect(SmartRoutePlanner.isCandidate(commute(), wednesdayEarly), isTrue);
    expect(
      SmartRoutePlanner.isCandidate(
        profileWithVisits(
          daysBefore(wednesdayEarly, count: 2, hour: 7, minute: 40),
        ),
        wednesdayEarly,
      ),
      isFalse,
    );
    expect(
      SmartRoutePlanner.isCandidate(
        profileWithVisits(
          daysBefore(wednesdayEarly, count: 15, hour: 7, minute: 40),
          pathId: null,
        ),
        wednesdayEarly,
      ),
      isFalse,
    );
  });

  test('routes without a direction, and repeats, are left out', () {
    final plan = SmartRoutePlanner.build(
      routeIdOf: routeIdOf,
      profiles: [
        profileWithVisits(
          daysBefore(wednesdayEarly, count: 15, hour: 7, minute: 40),
          pathId: null,
        ),
        commute(),
        commute(),
      ],
      now: wednesdayEarly,
    );

    expect(plan.slots, hasLength(5));
  });

  test('the stop is the one in use at the time of the window', () {
    final now = DateTime(2026, 4, 8, 5);
    var profile = profileWithVisits(
      daysBefore(now, count: 10, hour: 7, minute: 40),
      stopId: 1001,
    );
    for (final visit in daysBefore(now, count: 10, hour: 18, minute: 10)) {
      profile = profile.recordOpen(visit, stopId: 2002);
    }

    final plan = SmartRoutePlanner.build(
      profiles: [profile],
      routeIdOf: routeIdOf,
      now: now,
    );

    final wednesday = plan.slots
        .where((slot) => slot.weekday == DateTime.wednesday)
        .toList();
    expect(wednesday.map((slot) => slot.stopId), [1001, 2002]);
  });

  test('keeps the most confident slots when there are too many', () {
    final now = DateTime(2026, 4, 8, 5);
    final profiles = [
      // Fifteen daily routes, each with five weekday slots: 75 in all.
      for (var index = 0; index < 15; index++)
        profileWithVisits(
          daysBefore(
            now,
            count: index < 3 ? 15 : 4,
            hour: 6 + index,
            minute: 0,
          ),
          routeKey: 100 + index,
        ),
    ];

    final plan = SmartRoutePlanner.build(
      profiles: profiles,
      routeIdOf: routeIdOf,
      now: now,
    );

    expect(plan.slots, hasLength(SmartRoutePlanner.maxSlots));
    // The three routes with the longest record keep every one of theirs.
    for (final routeKey in [100, 101, 102]) {
      expect(plan.slots.where((slot) => slot.routeKey == routeKey).length, 5);
    }
  });

  test('each provider has a cap of its own', () {
    // The background check only acts on the provider in use. Fifteen routes
    // in one city, each surer than the one route in the other, must not
    // leave that one without a slot.
    final now = DateTime(2026, 4, 8, 5);
    final plan = SmartRoutePlanner.build(
      profiles: [
        for (var index = 0; index < 15; index++)
          profileWithVisits(
            daysBefore(now, count: 15, hour: 6 + index, minute: 0),
            routeKey: 100 + index,
            provider: BusProvider.tpe,
          ),
        profileWithVisits(
          daysBefore(now, count: 4, hour: 7, minute: 40),
          routeKey: 500,
          provider: BusProvider.khh,
        ),
      ],
      routeIdOf: routeIdOf,
      now: now,
    );

    expect(
      plan.slots.where((slot) => slot.provider == BusProvider.tpe).length,
      SmartRoutePlanner.maxSlots,
    );
    expect(
      plan.slots
          .where((slot) => slot.provider == BusProvider.khh)
          .map((slot) => slot.routeKey)
          .toSet(),
      {500},
    );
  });

  test('a plan drawn up before the usual time does not count today out', () {
    // An evening trip made on Monday, Tuesday and Wednesday. On Thursday
    // morning the evening is still to come; by Thursday night it was missed.
    final newHabit = profileWithVisits([
      DateTime(2026, 4, 6, 18, 10),
      DateTime(2026, 4, 7, 18, 10),
      DateTime(2026, 4, 8, 18, 10),
    ]);
    Set<int> weekdaysPlannedAt(DateTime now) => SmartRoutePlanner.build(
      profiles: [newHabit],
      routeIdOf: routeIdOf,
      now: now,
    ).slots.map((slot) => slot.weekday).toSet();

    expect(weekdaysPlannedAt(DateTime(2026, 4, 9, 7, 40)), {1, 2, 3, 4, 5});
    expect(weekdaysPlannedAt(DateTime(2026, 4, 9, 21)), {1, 2, 3, 4});
  });

  group('reminders already shown', () {
    // A commuter who, once reminders began on Monday the 6th, opened the
    // route on only three of the weekdays since: the 8th, 14th and 20th.
    final commuter = profileWithVisits([
      ...daysBefore(DateTime(2026, 4, 4), count: 15, hour: 7, minute: 40),
      DateTime(2026, 4, 8, 7, 40),
      DateTime(2026, 4, 14, 7, 40),
      DateTime(2026, 4, 20, 7, 40),
    ]);
    // One on every weekday from the 6th up to, but not on, the day of [now].
    List<SmartRouteReminder> shownBefore(
      DateTime now, {
      int routeKey = 101,
      int pathId = 0,
      BusProvider provider = BusProvider.nwt,
    }) => [
      for (final day in daysBefore(now, count: 40, hour: 7, minute: 30))
        if (!day.isBefore(DateTime(2026, 4, 6)))
          SmartRouteReminder(
            provider: provider,
            routeKey: routeKey,
            pathId: pathId,
            atMs: day.millisecondsSinceEpoch,
            peakMinute: 220,
          ),
    ];
    SmartRoutePlan planAt(
      DateTime now, {
      List<SmartRouteReminder> reminders = const [],
    }) => SmartRoutePlanner.build(
      profiles: [commuter],
      routeIdOf: routeIdOf,
      reminders: reminders,
      now: now,
    );
    Set<int> weekdays(SmartRoutePlan plan) =>
        plan.slots.map((slot) => slot.weekday).toSet();

    final wednesday = DateTime(2026, 4, 22, 6);

    test('keep a habit from fading on the days they did its job', () {
      // Read as nine days of staying home, the habit drops below the bar on
      // most weekdays; read as nine days of being told, it holds on all five.
      expect(weekdays(planAt(wednesday)), {1, 3});
      expect(weekdays(planAt(wednesday, reminders: shownBefore(wednesday))), {
        1,
        2,
        3,
        4,
        5,
      });
    });

    test('do not put off the day an unconfirmed habit lapses', () {
      final plan = planAt(wednesday, reminders: shownBefore(wednesday));

      // Last opened on Monday the 20th, reminders or no: good through the
      // service day of May the 4th.
      expect(plan.slots.map((slot) => slot.validUntilMs).toSet(), {
        DateTime(2026, 5, 5, 4).millisecondsSinceEpoch,
      });
    });

    test('cannot carry a habit past that day', () {
      final lastDay = DateTime(2026, 5, 4, 6);
      final dayAfter = DateTime(2026, 5, 5, 6);

      // Monday the 4th can still be reminded of; no day after it can, so
      // none is planned, however sure the habit looks.
      expect(weekdays(planAt(lastDay, reminders: shownBefore(lastDay))), {1});
      expect(planAt(dayAfter, reminders: shownBefore(dayAfter)).slots, isEmpty);
    });

    test('that are tapped do not draw the next one earlier', () {
      // Reminded at 07:26 for 07:40 on each of the last ten weekdays, and
      // tapped a minute later every time.
      final days = daysBefore(wednesday, count: 15, hour: 7, minute: 40);
      final answered = days.skip(5).toList();
      final tapper = profileWithVisits([
        ...days.take(5),
        for (final day in answered)
          DateTime(day.year, day.month, day.day, 7, 27),
      ]);
      Set<int> peaks({required bool saidWhatFor}) => SmartRoutePlanner.build(
        profiles: [tapper],
        routeIdOf: routeIdOf,
        reminders: [
          for (final day in answered)
            SmartRouteReminder(
              provider: BusProvider.nwt,
              routeKey: 101,
              pathId: 0,
              atMs: DateTime(
                day.year,
                day.month,
                day.day,
                7,
                26,
              ).millisecondsSinceEpoch,
              peakMinute: saidWhatFor ? 220 : null,
            ),
        ],
        now: wednesday,
      ).slots.map((slot) => slot.peakMinute).toSet();

      // 07:40 still. Taken at face value the taps say 07:30, the next round
      // of reminders would go out for that, and so on down the morning.
      expect(peaks(saidWhatFor: true), {220});
      expect(peaks(saidWhatFor: false), {210});
    });

    test('for another route, direction or city change nothing', () {
      final elsewhere = [
        ...shownBefore(wednesday, routeKey: 999),
        ...shownBefore(wednesday, pathId: 1),
        ...shownBefore(wednesday, provider: BusProvider.tpe),
      ];

      expect(
        jsonEncode(planAt(wednesday, reminders: elsewhere).toJson()),
        jsonEncode(planAt(wednesday).toJson()),
      );
    });

    test('are read from the log the worker keeps', () {
      // The same file SmartRouteReminderRulesTest expects the worker to
      // write. If it has to change here, it has to change there.
      final reminders = SmartRouteReminder.parseLog(
        File(
          'test/fixtures/smart_route_reminder_log_v1.json',
        ).readAsStringSync(),
      );

      expect(
        reminders.map(
          (entry) => (
            entry.provider,
            entry.routeKey,
            entry.pathId,
            entry.atMs,
            entry.peakMinute,
          ),
        ),
        [
          (BusProvider.khh, 101, 0, 1775604360000, 220),
          (BusProvider.khh, 202, 1, 1775901000000, 840),
        ],
      );
    });

    test('are skipped one by one when an entry cannot be read', () {
      Map<String, Object?> entry([Map<String, Object?> changes = const {}]) => {
        'provider': 'nwt',
        'routeKey': 101,
        'pathId': 0,
        'atMs': 1775604360000,
        'peakMinute': 220,
        ...changes,
      };
      final reminders = SmartRouteReminder.parseLog(
        jsonEncode([
          entry(),
          entry({'routeKey': '101'}),
          entry({'pathId': null}),
          entry({'atMs': 0}),
          entry({'atMs': 1775604360000.5}),
          // Not a name the plan could have written; not anyone's reminder.
          entry({'provider': 'twn'}),
          entry({'provider': 7}),
          'not an entry',
          // What it was for is worth having, but not worth losing it over.
          entry({'atMs': 2, 'peakMinute': 1440}),
          entry({'atMs': 3, 'peakMinute': -1}),
          entry({'atMs': 4})..remove('peakMinute'),
        ]),
      );

      expect(reminders.map((entry) => (entry.atMs, entry.peakMinute)), [
        (1775604360000, 220),
        (2, null),
        (3, null),
        (4, null),
      ]);
      expect(reminders.every((entry) => entry.isFor(commuter)), isTrue);
    });

    test('are none when there is no log to read', () {
      expect(SmartRouteReminder.parseLog(null), isEmpty);
      expect(SmartRouteReminder.parseLog(''), isEmpty);
      expect(SmartRouteReminder.parseLog('[]'), isEmpty);
      expect(SmartRouteReminder.parseLog('{"provider": "nwt"}'), isEmpty);
      expect(SmartRouteReminder.parseLog('[{'), isEmpty);
    });
  });

  test('matches the shape the Android worker is tested against', () {
    // The same file is parsed by SmartRoutePlanTest on the Kotlin side. If
    // this test needs the file changed, that reader needs to change with it.
    final fixture =
        jsonDecode(
              File('test/fixtures/smart_route_plan_v1.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final commuter = profileWithVisits(
      daysBefore(wednesdayEarly, count: 15, hour: 7, minute: 40),
      provider: BusProvider.khh,
      stopId: 100100128221,
    );
    final saturdays = profileWithVisits(
      [
        for (var week = 1; week <= 4; week++)
          DateTime(2026, 4, 11 - week * 7, 18),
      ],
      routeKey: 202,
      pathId: 1,
      routeName: '紅12',
      provider: BusProvider.khh,
    );

    final plan =
        jsonDecode(
              jsonEncode(
                SmartRoutePlanner.build(
                  routeIdOf: routeIdOf,
                  profiles: [commuter, saturdays],
                  now: wednesdayEarly,
                ).toJson(),
              ),
            )
            as Map<String, dynamic>;

    // Instants depend on the zone the test runs in; everything else is fixed.
    Map<String, dynamic> withoutInstants(Map<String, dynamic> source) => {
      ...source,
      'generatedAtMs': 0,
      'slots': [
        for (final slot in source['slots'] as List)
          {
            ...slot as Map<String, dynamic>,
            'validUntilMs': 0,
            'lastActivityAtMs': 0,
          },
      ],
    };
    expect(withoutInstants(plan), withoutInstants(fixture));
    expect(plan.keys.toSet(), fixture.keys.toSet());
  });
}
