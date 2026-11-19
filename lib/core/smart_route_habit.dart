import 'dart:convert';
import 'dart:math' as math;

import 'models.dart';

/// A moment placed on the service-day grid the habit model works on.
///
/// A service day runs from [RouteHabitModel.serviceDayStartHour] to the same
/// hour the next morning, the way a bus timetable does. A ride home at 00:20
/// on Saturday therefore belongs to Friday, and no time-of-day comparison ever
/// has to wrap around midnight.
class ServiceTime {
  const ServiceTime({required this.day, required this.minute});

  factory ServiceTime.fromDateTime(DateTime time) {
    final shifted = time.toLocal().subtract(
      const Duration(hours: RouteHabitModel.serviceDayStartHour),
    );
    return ServiceTime(
      day:
          DateTime.utc(
            shifted.year,
            shifted.month,
            shifted.day,
          ).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay,
      minute: shifted.hour * 60 + shifted.minute,
    );
  }

  factory ServiceTime.fromMs(int ms) =>
      ServiceTime.fromDateTime(DateTime.fromMillisecondsSinceEpoch(ms));

  /// Whole service days since the epoch, counted on the local calendar.
  final int day;

  /// Minutes since the service day began, 0..1439.
  final int minute;

  int get weekday => weekdayOfDay(day);

  /// [DateTime.monday]..[DateTime.sunday] for a service-day index. Day 0 is
  /// 1970-01-01, a Thursday.
  static int weekdayOfDay(int day) => ((day + 3) % 7 + 7) % 7 + 1;

  static bool isWeekend(int weekday) =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  /// The local instant at which service day [day] begins.
  static DateTime startOfDay(int day) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      day * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return DateTime(
      date.year,
      date.month,
      date.day,
      RouteHabitModel.serviceDayStartHour,
    );
  }

  /// [minute] as a wall-clock minute of the day, 0..1439.
  static int clockMinute(int minute) =>
      (minute + RouteHabitModel.serviceDayStartHour * 60) % (24 * 60);
}

/// How likely a route is to be wanted at one time on one kind of day.
class RouteHabitEstimate {
  const RouteHabitEstimate({
    required this.probability,
    required this.supportDays,
    this.lastSupportDay,
    this.typicalMinute,
  });

  static const none = RouteHabitEstimate(probability: 0, supportDays: 0);

  /// Estimated chance, 0..1, that the route is used around the asked time on
  /// a day like the asked one.
  final double probability;

  /// Distinct past days on which the route was used around that time, on any
  /// day of the week. A sample size, not a rate.
  final int supportDays;

  /// The most recent of those days, as a service-day index.
  final int? lastSupportDay;

  /// Where those uses centre, in service minutes.
  final int? typicalMinute;
}

/// A reminder that was shown for a route: when, and the service minute it was
/// sent for — the peak of its window — where that is known.
typedef RouteReminderShown = ({int atMs, int? forMinute});

/// A reminder the background check actually showed, as it logs them.
///
/// Everything that reads a habit has to be given these — the reminder plan
/// and the home screen alike. Without them a reminder that did its job looks
/// like a day the rider stayed home, and a tap on one like a routine that
/// moved earlier; see [RouteHabitEvidence].
class SmartRouteReminder {
  const SmartRouteReminder({
    required this.provider,
    required this.routeKey,
    required this.pathId,
    required this.atMs,
    this.peakMinute,
  });

  final BusProvider provider;
  final int routeKey;
  final int pathId;
  final int atMs;

  /// The peak minute of the plan slot it was shown for.
  final int? peakMinute;

  bool isFor(RouteUsageProfile profile) =>
      provider == profile.provider &&
      routeKey == profile.routeKey &&
      pathId == profile.pathId;

  /// The ones among [reminders] that were for [profile], in the form
  /// [RouteHabitEvidence.of] takes them.
  static List<RouteReminderShown> shownFor(
    RouteUsageProfile profile,
    Iterable<SmartRouteReminder> reminders,
  ) => [
    for (final reminder in reminders)
      if (reminder.isFor(profile))
        (atMs: reminder.atMs, forMinute: reminder.peakMinute),
  ];

  /// Reads the log the platform side keeps. Anything unreadable is skipped:
  /// a lost entry only makes the model a little more cautious.
  static List<SmartRouteReminder> parseLog(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <SmartRouteReminder>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const <SmartRouteReminder>[];
    }
    if (decoded is! List) {
      return const <SmartRouteReminder>[];
    }
    final providers = BusProvider.values.asNameMap();
    final reminders = <SmartRouteReminder>[];
    for (final entry in decoded) {
      if (entry is! Map) {
        continue;
      }
      // The name the plan gave the worker, and nothing looser: a reminder
      // that cannot be placed must not be pinned on some other city's route.
      final provider = providers[entry['provider']];
      final routeKey = entry['routeKey'];
      final pathId = entry['pathId'];
      final atMs = entry['atMs'];
      final peakMinute = entry['peakMinute'];
      if (provider == null ||
          routeKey is! int ||
          pathId is! int ||
          atMs is! int ||
          atMs <= 0) {
        continue;
      }
      reminders.add(
        SmartRouteReminder(
          provider: provider,
          routeKey: routeKey,
          pathId: pathId,
          atMs: atMs,
          peakMinute:
              peakMinute is int && peakMinute >= 0 && peakMinute < 24 * 60
              ? peakMinute
              : null,
        ),
      );
    }
    return reminders;
  }
}

/// The times a route was used, arranged for [RouteHabitModel].
class RouteHabitEvidence {
  RouteHabitEvidence._(
    this._minutesByDay,
    this._usedTodayAt,
    this._remindersByDay,
    this.today,
    this._nowMinute,
    this.nowMs,
  );

  /// [reminders] are the ones shown for this route. A reminder changes what
  /// the rider does next, so the days it was shown on cannot be read the way
  /// other days are; see [estimate] and [_minuteSpokenFor].
  factory RouteHabitEvidence.of(
    RouteUsageProfile profile,
    DateTime now, {
    Iterable<RouteReminderShown> reminders = const <RouteReminderShown>[],
  }) {
    final nowMs = now.millisecondsSinceEpoch;
    final nowTime = ServiceTime.fromDateTime(now);
    final today = nowTime.day;
    final minutesByDay = <int, List<int>>{};
    final usedTodayAt = <int>[];
    final remindersByDay = <int, List<_DayReminder>>{};
    for (final reminder in reminders) {
      final time = ServiceTime.fromMs(reminder.atMs);
      (remindersByDay[time.day] ??= <_DayReminder>[]).add((
        minute: time.minute,
        forMinute: reminder.forMinute,
      ));
    }
    final timestamps = <int>[
      for (final visit in profile.visitsWithin(now: now)) visit.atMs,
      // A tap that never became a ten-second open is still a use. These are
      // only kept for a week, so they sharpen the recent picture rather than
      // carry it.
      ...profile.selectionTimestampsWithin(now: now),
    ];
    for (final timestamp in timestamps) {
      if (timestamp > nowMs) {
        continue;
      }
      final time = ServiceTime.fromMs(timestamp);
      if (today - time.day > RouteHabitModel.lookbackDays) {
        continue;
      }
      (minutesByDay[time.day] ??= <int>[]).add(
        _minuteSpokenFor(time.minute, remindersByDay[time.day]),
      );
      if (time.day == today) {
        usedTodayAt.add(time.minute);
      }
    }
    return RouteHabitEvidence._(
      minutesByDay,
      usedTodayAt,
      remindersByDay,
      today,
      nowTime.minute,
      nowMs,
    );
  }

  /// The time of day a use at [minute] is evidence for.
  ///
  /// A reminder goes out ahead of the time the route is usually opened, and
  /// tapping it opens the route there and then. Taken at face value, every
  /// such tap would say the routine is a little earlier than believed; the
  /// next reminder would go out earlier still, and be tapped earlier still.
  /// So a use between a reminder and the time it was sent for agrees with
  /// that time rather than moving it.
  ///
  /// Nothing else is moved. A use before the reminder was the rider's own
  /// doing. One after the time it was for may well have been prompted by a
  /// reminder that came late, but that only happens when no bus was due any
  /// sooner, and then later is when looking was of use.
  static int _minuteSpokenFor(int minute, List<_DayReminder>? reminders) {
    var spokenFor = minute;
    for (final reminder in reminders ?? const <_DayReminder>[]) {
      final forMinute = reminder.forMinute;
      if (forMinute != null &&
          reminder.minute <= minute &&
          forMinute > spokenFor) {
        spokenFor = forMinute;
      }
    }
    return spokenFor;
  }

  /// The minutes each day's uses are evidence for; see [_minuteSpokenFor].
  final Map<int, List<int>> _minutesByDay;

  /// When the route was actually used today, whatever that is evidence for.
  final List<int> _usedTodayAt;
  final Map<int, List<_DayReminder>> _remindersByDay;

  /// The service day [RouteHabitEvidence.of] was asked on.
  final int today;
  final int _nowMinute;
  final int nowMs;

  /// Distinct service days with any use at all.
  int get dayCount => _minutesByDay.length;

  bool get isEmpty => _minutesByDay.isEmpty;

  /// Every minute at which the route was used, for callers that need to know
  /// which parts of the day are worth asking about.
  Iterable<int> get minutes => _minutesByDay.values.expand((day) => day);

  /// How closely the use on [day] matches [minute]: 1 for a use at exactly
  /// that minute, falling to 0 past [RouteHabitModel.timeCutoffMinutes].
  double matchOn(int day, int minute) => _bestMatch(day, minute).$1;

  (double, int?) _bestMatch(int day, int minute) {
    final minutes = _minutesByDay[day];
    if (minutes == null) {
      return (0, null);
    }
    var best = 0.0;
    int? bestMinute;
    for (final used in minutes) {
      final match = RouteHabitModel.timeMatch((used - minute).abs());
      if (match > best) {
        best = match;
        bestMinute = used;
      }
    }
    return (best, bestMinute);
  }

  /// Whether [day], on which the route was not used around [minute], was a
  /// chance to use it that was passed up.
  ///
  /// Two kinds of day cannot say. One is a day a reminder was shown around
  /// that time: it gave the rider what they would have opened the route for,
  /// so not opening it is no sign they stayed home — and counting it as one
  /// would have every reminder that worked argue for sending fewer. The
  /// other is today, for as long as there is still time: the plan for the
  /// week is usually drawn up in the morning, and this evening has not been
  /// missed yet.
  bool _wasPassedUp(int day, int minute) {
    final withinReach = RouteHabitModel.timeCutoffMinutes;
    if (day == today && _nowMinute <= minute + withinReach) {
      return false;
    }
    final reminders = _remindersByDay[day];
    return reminders == null ||
        reminders.every(
          (reminder) => (reminder.minute - minute).abs() > withinReach,
        );
  }

  /// Minutes since the most recent use today, or null when there was none.
  int? minutesSinceLastUseToday(DateTime now) {
    final nowMinute = ServiceTime.fromDateTime(now).minute;
    int? best;
    for (final used in _usedTodayAt) {
      final age = nowMinute - used;
      if (age >= 0 && (best == null || age < best)) {
        best = age;
      }
    }
    return best;
  }

  /// The chance the route is used around [minute] on service day [targetDay].
  ///
  /// Only days before [targetDay] count, and never days after [today]: asking
  /// about today leaves today out, so a use this morning cannot vouch for
  /// itself, while asking about tomorrow counts it.
  ///
  /// A day without a use counts against the habit only if it was a chance
  /// that was passed up; see [_wasPassedUp].
  RouteHabitEstimate estimate({required int targetDay, required int minute}) {
    final lastDay = math.min(targetDay - 1, today);
    final firstDay = targetDay - RouteHabitModel.lookbackDays;
    final matches = <int, double>{};
    var supportDays = 0;
    int? lastSupportDay;
    int? firstUseDay;
    var typicalWeight = 0.0;
    var typicalSum = 0.0;
    for (final day in _minutesByDay.keys) {
      if (day < firstDay || day > lastDay) {
        continue;
      }
      final (match, usedMinute) = _bestMatch(day, minute);
      if (match <= 0) {
        continue;
      }
      matches[day] = match;
      if (match < RouteHabitModel.supportMatchThreshold) {
        continue;
      }
      supportDays += 1;
      if (lastSupportDay == null || day > lastSupportDay) {
        lastSupportDay = day;
      }
      if (firstUseDay == null || day < firstUseDay) {
        firstUseDay = day;
      }
      final weight = RouteHabitModel.decay(targetDay - day) * match;
      typicalWeight += weight;
      typicalSum += weight * usedMinute!;
    }
    if (firstUseDay == null) {
      return RouteHabitEstimate.none;
    }

    // Every day since the habit was first seen was a chance to repeat it, so
    // a day without a use counts against it. Days before that do not: nobody
    // can skip a routine they had not started.
    final targetWeekday = ServiceTime.weekdayOfDay(targetDay);
    final targetIsWeekend = ServiceTime.isWeekend(targetWeekday);
    var usedSameWeekday = 0.0;
    var chancesSameWeekday = 0.0;
    var usedSameKind = 0.0;
    var chancesSameKind = 0.0;
    for (var day = firstUseDay; day <= lastDay; day++) {
      final weekday = ServiceTime.weekdayOfDay(day);
      if (ServiceTime.isWeekend(weekday) != targetIsWeekend) {
        continue;
      }
      final match = matches[day];
      if (match == null && !_wasPassedUp(day, minute)) {
        continue;
      }
      final weight = RouteHabitModel.decay(targetDay - day);
      final used = weight * (match ?? 0);
      usedSameKind += used;
      chancesSameKind += weight;
      if (weekday == targetWeekday) {
        usedSameWeekday += used;
        chancesSameWeekday += weight;
      }
    }

    // Two levels, each pulled toward the one above while it has little to go
    // on: a Tuesday leans on weekdays in general until enough Tuesdays have
    // been seen, and weekdays lean on a low base rate until enough of those
    // have. This is what lets a Tuesday/Thursday class stand apart from a
    // daily commute without waiting eight weeks to recommend either.
    final sameKindRate =
        (usedSameKind +
            RouteHabitModel.kindPriorDays * RouteHabitModel.baseRate) /
        (chancesSameKind + RouteHabitModel.kindPriorDays);
    final probability =
        (usedSameWeekday + RouteHabitModel.weekdayPriorDays * sameKindRate) /
        (chancesSameWeekday + RouteHabitModel.weekdayPriorDays);

    return RouteHabitEstimate(
      probability: probability.clamp(0.0, 1.0),
      supportDays: supportDays,
      lastSupportDay: lastSupportDay,
      typicalMinute: typicalWeight > 0
          ? (typicalSum / typicalWeight).round()
          : null,
    );
  }

  /// [estimate] for the moment [now] itself.
  RouteHabitEstimate estimateNow(DateTime now) {
    final time = ServiceTime.fromDateTime(now);
    return estimate(targetDay: time.day, minute: time.minute);
  }
}

typedef _DayReminder = ({int minute, int? forMinute});

/// The constants and curves the habit model is built from.
class RouteHabitModel {
  const RouteHabitModel._();

  /// 04:00. Late enough that the last night buses are still "yesterday",
  /// early enough that the first morning ones are "today".
  static const int serviceDayStartHour = 4;

  /// Matches [RouteUsageProfile.visitHistoryRetention].
  static const int lookbackDays = 56;

  /// A use two weeks ago counts half as much as one today.
  static const double halfLifeDays = 14;

  /// Spread of the time-of-day match. Half an hour either way still counts
  /// for most of a use; an hour away counts for little.
  static const double timeSigmaMinutes = 30;

  /// Beyond this a use says nothing about the asked time.
  static const int timeCutoffMinutes = 75;

  /// How close a use must be to count as a day the route was used "around
  /// this time". 0.1 is a little over an hour away.
  static const double supportMatchThreshold = 0.1;

  /// How often an arbitrary route is wanted at an arbitrary time, absent any
  /// evidence.
  static const double baseRate = 0.05;

  /// How many days of the base rate a weekday/weekend estimate starts with.
  static const double kindPriorDays = 2;

  /// How many days of the weekday/weekend rate a single weekday starts with.
  static const double weekdayPriorDays = 1;

  static double decay(num ageDays) {
    if (ageDays <= 0) {
      return 1;
    }
    return math.pow(0.5, ageDays / halfLifeDays).toDouble();
  }

  static double timeMatch(int minutesApart) {
    if (minutesApart > timeCutoffMinutes) {
      return 0;
    }
    final scaled = minutesApart / timeSigmaMinutes;
    return math.exp(-0.5 * scaled * scaled);
  }
}
