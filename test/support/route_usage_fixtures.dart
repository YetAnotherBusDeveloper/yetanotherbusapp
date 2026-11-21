import 'package:taiwanbus_flutter/core/models.dart';

/// The [count] most recent days before [now] whose weekday is in [weekdays],
/// each at [hour]:[minute], oldest first. Never includes the day of [now].
List<DateTime> daysBefore(
  DateTime now, {
  required int count,
  required int hour,
  required int minute,
  Set<int> weekdays = const {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  },
}) {
  final days = <DateTime>[];
  for (var back = 1; days.length < count; back++) {
    final day = DateTime(now.year, now.month, now.day - back, hour, minute);
    if (weekdays.contains(day.weekday)) {
      days.add(day);
    }
  }
  return days.reversed.toList();
}

/// A profile whose only history is the given visits, as one written by a
/// version that keeps them would look.
RouteUsageProfile profileWithVisits(
  Iterable<DateTime> visits, {
  int routeKey = 101,
  int? pathId = 0,
  String routeName = '307',
  BusProvider provider = BusProvider.nwt,
  int? stopId,
}) {
  var profile = RouteUsageProfile(
    provider: provider,
    routeKey: routeKey,
    pathId: pathId,
    routeName: routeName,
    totalOpens: 0,
    lastOpenedAtMs: 0,
  );
  for (final visit in visits.toList()..sort()) {
    profile = profile.recordOpen(visit, stopId: stopId);
  }
  return profile;
}
