import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/smart_route_habit.dart';

import 'support/route_usage_fixtures.dart';

void main() {
  // 2026-04-08 is a Wednesday.
  final wednesdayMorning = DateTime(2026, 4, 8, 7, 40);

  RouteHabitEstimate estimateAt(RouteUsageProfile profile, DateTime now) =>
      RouteHabitEvidence.of(profile, now).estimateNow(now);

  group('ServiceTime', () {
    test('starts the day at 04:00', () {
      final beforeStart = ServiceTime.fromDateTime(DateTime(2026, 4, 8, 3, 59));
      final atStart = ServiceTime.fromDateTime(DateTime(2026, 4, 8, 4));

      expect(atStart.minute, 0);
      expect(atStart.weekday, DateTime.wednesday);
      expect(beforeStart.minute, 23 * 60 + 59);
      expect(beforeStart.weekday, DateTime.tuesday);
      expect(atStart.day, beforeStart.day + 1);
    });

    test('keeps a ride after midnight on the evening it belongs to', () {
      // 2026-04-11 is a Saturday; 00:20 that morning is Friday night.
      final lateRide = ServiceTime.fromDateTime(DateTime(2026, 4, 11, 0, 20));

      expect(lateRide.weekday, DateTime.friday);
      expect(lateRide.minute, 20 * 60 + 20);
      expect(ServiceTime.clockMinute(lateRide.minute), 20);
    });

    test('turns a day index back into the moment that day begins', () {
      final time = ServiceTime.fromDateTime(wednesdayMorning);

      expect(ServiceTime.startOfDay(time.day), DateTime(2026, 4, 8, 4));
      expect(ServiceTime.weekdayOfDay(time.day), DateTime.wednesday);
      expect(ServiceTime.weekdayOfDay(time.day + 4), DateTime.sunday);
    });
  });

  group('time match', () {
    test('falls off smoothly and then stops', () {
      expect(RouteHabitModel.timeMatch(0), 1);
      expect(RouteHabitModel.timeMatch(30), closeTo(0.607, 0.001));
      expect(RouteHabitModel.timeMatch(60), closeTo(0.135, 0.001));
      expect(RouteHabitModel.timeMatch(75), greaterThan(0));
      expect(RouteHabitModel.timeMatch(76), 0);
    });

    test('does not care which side of an hour a use fell on', () {
      // 07:58 and 08:02 are four minutes apart, not one hour bucket apart.
      final now = DateTime(2026, 4, 8, 8, 2);
      final profile = profileWithVisits(
        daysBefore(now, count: 10, hour: 7, minute: 58),
      );

      expect(estimateAt(profile, now).probability, greaterThan(0.75));
    });
  });

  group('a weekday commute', () {
    final commute = profileWithVisits(
      daysBefore(wednesdayMorning, count: 15, hour: 7, minute: 40),
    );

    test('is expected at its usual time on a weekday', () {
      final estimate = estimateAt(commute, wednesdayMorning);

      expect(estimate.probability, greaterThan(0.8));
      expect(estimate.supportDays, 15);
      expect(
        estimate.typicalMinute,
        // 07:40 is 220 minutes into a day that starts at 04:00.
        220,
      );
    });

    test('is not expected on the weekend', () {
      final saturday = DateTime(2026, 4, 11, 7, 40);

      expect(estimateAt(commute, saturday).probability, lessThan(0.1));
    });

    test('is not expected at another time of day', () {
      final afternoon = DateTime(2026, 4, 8, 14);

      final estimate = estimateAt(commute, afternoon);

      expect(estimate.probability, 0);
      expect(estimate.supportDays, 0);
    });

    test('weakens the further the clock is from the usual time', () {
      final atUsualTime = estimateAt(commute, wednesdayMorning).probability;
      final halfHourEarly = estimateAt(
        commute,
        DateTime(2026, 4, 8, 7, 10),
      ).probability;
      final anHourEarly = estimateAt(
        commute,
        DateTime(2026, 4, 8, 6, 40),
      ).probability;

      expect(halfHourEarly, lessThan(atUsualTime));
      expect(anHourEarly, lessThan(halfHourEarly));
      expect(halfHourEarly, greaterThan(0.4));
      expect(anHourEarly, lessThan(0.2));
    });
  });

  test('a class on two weekdays is told apart from the days between', () {
    // Three weeks of Tuesdays and Thursdays at 10:00.
    final tuesday = DateTime(2026, 4, 7, 10);
    final profile = profileWithVisits(
      daysBefore(
        tuesday,
        count: 6,
        hour: 10,
        minute: 0,
        weekdays: const {DateTime.tuesday, DateTime.thursday},
      ),
    );

    final onTuesday = estimateAt(profile, tuesday).probability;
    final onWednesday = estimateAt(
      profile,
      DateTime(2026, 4, 8, 10),
    ).probability;

    expect(onTuesday, greaterThan(0.6));
    expect(onWednesday, lessThan(0.25));
  });

  test('one busy morning is one day of evidence', () {
    final yesterday = DateTime(2026, 4, 7, 7, 30);
    final profile = profileWithVisits([
      for (var index = 0; index < 5; index++)
        yesterday.add(Duration(minutes: index * 25)),
    ]);

    expect(profile.visits, hasLength(5));
    expect(estimateAt(profile, wednesdayMorning).supportDays, 1);
  });

  test('a habit that stopped fades instead of lasting forever', () {
    // Every weekday until the visits stop, then nothing.
    RouteUsageProfile stoppedDaysAgo(int daysAgo) => profileWithVisits(
      daysBefore(
        wednesdayMorning.subtract(Duration(days: daysAgo)),
        count: 15,
        hour: 7,
        minute: 40,
      ),
    );

    final stillGoing = estimateAt(stoppedDaysAgo(0), wednesdayMorning);
    final twoWeeksGone = estimateAt(stoppedDaysAgo(14), wednesdayMorning);
    final sixWeeksGone = estimateAt(stoppedDaysAgo(42), wednesdayMorning);

    expect(stillGoing.probability, greaterThan(0.9));
    expect(twoWeeksGone.probability, inInclusiveRange(0.25, 0.5));
    expect(sixWeeksGone.probability, lessThan(0.1));
  });

  test('a new habit is not held back by the days before it began', () {
    // An evening trip that only started three days ago, on a route that has
    // been a morning trip for weeks.
    final evening = DateTime(2026, 4, 8, 18, 30);
    final profile = profileWithVisits([
      ...daysBefore(evening, count: 15, hour: 7, minute: 40),
      ...daysBefore(evening, count: 3, hour: 18, minute: 30),
    ]);

    final estimate = estimateAt(profile, evening);

    expect(estimate.supportDays, 3);
    expect(estimate.probability, greaterThan(0.5));
  });

  test('scattered uses over two months are not a routine', () {
    final profile = profileWithVisits([
      DateTime(2026, 2, 17, 7, 40),
      DateTime(2026, 3, 10, 7, 40),
      DateTime(2026, 3, 31, 7, 40),
    ]);

    final estimate = estimateAt(profile, wednesdayMorning);

    expect(estimate.supportDays, 3);
    expect(estimate.probability, lessThan(0.25));
  });

  test('today vouches for tomorrow but not for itself', () {
    // Used on Monday, Tuesday and — an hour ago — today.
    final now = DateTime(2026, 4, 8, 8, 40);
    final profile = profileWithVisits([
      DateTime(2026, 4, 6, 7, 40),
      DateTime(2026, 4, 7, 7, 40),
      DateTime(2026, 4, 8, 7, 40),
    ]);
    final evidence = RouteHabitEvidence.of(profile, now);
    final usualMinute = ServiceTime.fromDateTime(wednesdayMorning).minute;

    final today = evidence.estimate(
      targetDay: evidence.today,
      minute: usualMinute,
    );
    final tomorrow = evidence.estimate(
      targetDay: evidence.today + 1,
      minute: usualMinute,
    );

    expect(today.supportDays, 2);
    expect(tomorrow.supportDays, 3);
    expect(tomorrow.lastSupportDay, evidence.today);
    expect(evidence.minutesSinceLastUseToday(now), 60);
  });

  test('a visit that has not happened yet is not evidence', () {
    final profile = profileWithVisits([
      DateTime(2026, 4, 6, 7, 40),
      DateTime(2026, 4, 7, 7, 40),
      DateTime(2026, 4, 9, 7, 40),
    ]);

    expect(estimateAt(profile, wednesdayMorning).supportDays, 2);
  });

  test('taps from the last week count alongside opens', () {
    final tapped = RouteUsageProfile(
      provider: BusProvider.nwt,
      routeKey: 202,
      pathId: 0,
      routeName: '綠3',
      totalOpens: 0,
      lastOpenedAtMs: 0,
      selectionTimestampsMs: [
        for (final tap in daysBefore(
          wednesdayMorning,
          count: 3,
          hour: 7,
          minute: 35,
        ))
          tap.millisecondsSinceEpoch,
      ],
    );

    expect(estimateAt(tapped, wednesdayMorning).supportDays, 3);
  });

  group('days a reminder was shown', () {
    // Every weekday through Friday the 3rd, then twelve weekdays on which
    // the route was never opened, up to Wednesday the 22nd.
    final now = DateTime(2026, 4, 22, 7, 40);
    final commute = profileWithVisits(
      daysBefore(DateTime(2026, 4, 4), count: 15, hour: 7, minute: 40),
    );
    List<RouteReminderShown> remindersAt(int hour, int minute) => [
      for (final day in daysBefore(now, count: 12, hour: hour, minute: minute))
        (atMs: day.millisecondsSinceEpoch, forMinute: null),
    ];
    double probability({
      RouteUsageProfile? profile,
      List<RouteReminderShown> reminders = const [],
    }) => RouteHabitEvidence.of(
      profile ?? commute,
      now,
      reminders: reminders,
    ).estimateNow(now).probability;

    test('do not count as days the rider stayed away', () {
      expect(probability(), lessThan(0.4));
      expect(probability(reminders: remindersAt(7, 30)), greaterThan(0.75));
    });

    test('are only excused around the time of the reminder', () {
      expect(probability(reminders: remindersAt(18, 0)), probability());
      // Seventy-five minutes either way is as far as a use would count.
      expect(probability(reminders: remindersAt(6, 25)), greaterThan(0.75));
      expect(probability(reminders: remindersAt(6, 24)), probability());
      expect(probability(reminders: remindersAt(8, 55)), greaterThan(0.75));
      expect(probability(reminders: remindersAt(8, 56)), probability());
    });

    test('still count as a use when the route was opened as well', () {
      final usedYesterday = commute.recordOpen(DateTime(2026, 4, 21, 7, 40));

      expect(
        probability(
          profile: usedYesterday,
          reminders: [
            (
              atMs: DateTime(2026, 4, 21, 7, 30).millisecondsSinceEpoch,
              forMinute: null,
            ),
          ],
        ),
        probability(profile: usedYesterday),
      );
      expect(probability(profile: usedYesterday), greaterThan(probability()));
    });

    test('are not evidence of use by themselves', () {
      final evidence = RouteHabitEvidence.of(
        profileWithVisits(const []),
        now,
        reminders: remindersAt(7, 30),
      );

      expect(evidence.isEmpty, isTrue);
      expect(evidence.estimateNow(now).probability, 0);
    });
  });

  group('a use that answers a reminder', () {
    // A 07:40 commute, reminded at 07:26 — ahead of time, as reminders are.
    final now = DateTime(2026, 4, 8, 9);
    final usualMinute = ServiceTime.fromDateTime(
      DateTime(2026, 4, 8, 7, 40),
    ).minute;
    final history = daysBefore(now, count: 15, hour: 7, minute: 40);
    RouteReminderShown reminderOn(DateTime day, {int? forMinute}) => (
      atMs: DateTime(
        day.year,
        day.month,
        day.day,
        7,
        26,
      ).millisecondsSinceEpoch,
      forMinute: forMinute,
    );
    // The last ten of those days opened at [hour]:[minute] instead, each
    // after a reminder for 07:40.
    RouteHabitEvidence openedAt(int hour, int minute, {bool known = true}) {
      final answered = history.skip(5).toList();
      return RouteHabitEvidence.of(
        profileWithVisits([
          ...history.take(5),
          for (final day in answered)
            DateTime(day.year, day.month, day.day, hour, minute),
        ]),
        now,
        reminders: [
          for (final day in answered)
            reminderOn(day, forMinute: known ? usualMinute : null),
        ],
      );
    }

    int? typicalMinute(RouteHabitEvidence evidence) => evidence
        .estimate(targetDay: evidence.today, minute: usualMinute)
        .typicalMinute;

    test('confirms the time the reminder was for, not the time of the tap', () {
      // Tapped a minute after it appeared, every day for two weeks.
      expect(typicalMinute(openedAt(7, 27)), usualMinute);
      // Without knowing what the reminders were for, the routine would seem
      // to have moved toward them.
      expect(
        typicalMinute(openedAt(7, 27, known: false)),
        lessThan(usualMinute - 5),
      );
    });

    test('is anywhere from the reminder to the time it was for', () {
      expect(typicalMinute(openedAt(7, 26)), usualMinute);
      expect(typicalMinute(openedAt(7, 40)), usualMinute);
    });

    test('is not one made before the reminder or after its time', () {
      expect(typicalMinute(openedAt(7, 25)), lessThan(usualMinute - 5));
      expect(typicalMinute(openedAt(7, 55)), greaterThan(usualMinute + 5));
    });

    test('is still timed from when it was really made', () {
      // Tapped at 07:27, three minutes ago; read as agreeing with 07:40.
      final justTapped = DateTime(2026, 4, 8, 7, 30);
      final evidence = RouteHabitEvidence.of(
        profileWithVisits([DateTime(2026, 4, 8, 7, 27)]),
        justTapped,
        reminders: [reminderOn(justTapped, forMinute: usualMinute)],
      );

      expect(evidence.minutesSinceLastUseToday(justTapped), 3);
      expect(
        evidence.minutesSinceLastUseToday(DateTime(2026, 4, 8, 8, 30)),
        63,
      );
    });
  });

  group('today', () {
    // An evening trip made on Monday, Tuesday and Wednesday, asked about on
    // Thursday the 9th with nothing opened yet that day.
    final newHabit = profileWithVisits([
      DateTime(2026, 4, 6, 18, 10),
      DateTime(2026, 4, 7, 18, 10),
      DateTime(2026, 4, 8, 18, 10),
    ]);
    final usualMinute = ServiceTime.fromDateTime(
      DateTime(2026, 4, 9, 18, 10),
    ).minute;
    double fridayAsSeenAt(int hour, int minute) {
      final evidence = RouteHabitEvidence.of(
        newHabit,
        DateTime(2026, 4, 9, hour, minute),
      );
      return evidence
          .estimate(targetDay: evidence.today + 1, minute: usualMinute)
          .probability;
    }

    test('is not held against tomorrow while there is still time', () {
      // Three days out of three in the morning; three out of four by night.
      expect(fridayAsSeenAt(7, 40), greaterThan(0.55));
      expect(fridayAsSeenAt(21, 0), lessThan(0.5));
    });

    test('has run out of time once a use would no longer count', () {
      // 19:25 is the last minute a use would still match 18:10.
      expect(fridayAsSeenAt(19, 25), fridayAsSeenAt(7, 40));
      expect(fridayAsSeenAt(19, 26), fridayAsSeenAt(21, 0));
    });
  });

  test('a Friday-night habit is found after midnight on Saturday', () {
    // 00:20 on four consecutive Saturday mornings.
    final saturdayAfterMidnight = DateTime(2026, 4, 11, 0, 10);
    final profile = profileWithVisits([
      for (var week = 1; week <= 4; week++)
        DateTime(2026, 4, 11 - week * 7, 0, 20),
    ]);

    final onFridayNight = estimateAt(profile, saturdayAfterMidnight);
    final onMondayNight = estimateAt(profile, DateTime(2026, 4, 7, 0, 10));

    expect(onFridayNight.supportDays, 4);
    expect(onFridayNight.probability, greaterThan(0.6));
    expect(onMondayNight.probability, lessThan(0.2));
  });
}
