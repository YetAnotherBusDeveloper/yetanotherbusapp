import 'dart:math' as math;

import 'models.dart';
import 'smart_route_habit.dart';
import 'smart_route_service.dart';

export 'smart_route_habit.dart' show SmartRouteReminder;

/// One stretch of one weekday during which a route is worth a reminder.
class SmartRoutePlanSlot {
  const SmartRoutePlanSlot({
    required this.provider,
    required this.routeKey,
    required this.routeId,
    required this.pathId,
    required this.routeName,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    required this.peakMinute,
    required this.confidence,
    required this.supportDays,
    required this.validUntilMs,
    required this.lastActivityAtMs,
    this.stopId,
  });

  final BusProvider provider;
  final int routeKey;

  /// What the realtime API and the stop database know the route by. The
  /// reader has no way to turn a [routeKey] back into one.
  final String routeId;
  final int pathId;
  final String routeName;

  /// [DateTime.monday]..[DateTime.sunday], of the service day.
  final int weekday;

  /// Service minutes, both inclusive. See [ServiceTime].
  final int startMinute;
  final int endMinute;

  /// When within the window the route is most often opened.
  final int peakMinute;
  final double confidence;
  final int supportDays;

  /// After this the habit has gone unconfirmed for too long to act on.
  final int validUntilMs;

  /// The last time the rider opened or chose this route, so a reminder is
  /// not sent for something they have just looked at.
  final int lastActivityAtMs;

  /// The stop to watch when the device's location is unknown.
  final int? stopId;

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'routeKey': routeKey,
    'routeId': routeId,
    'pathId': pathId,
    'routeName': routeName,
    'weekday': weekday,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'peakMinute': peakMinute,
    'confidence': double.parse(confidence.toStringAsFixed(3)),
    'supportDays': supportDays,
    'validUntilMs': validUntilMs,
    'lastActivityAtMs': lastActivityAtMs,
    if (stopId != null) 'stopId': stopId,
  };
}

/// Everything the background reminder needs to know, worked out ahead of
/// time so the platform side never has to score a habit itself.
class SmartRoutePlan {
  const SmartRoutePlan({required this.generatedAtMs, required this.slots});

  /// Bumped when a reader of an older shape could misread a newer one.
  static const int version = 1;

  final int generatedAtMs;
  final List<SmartRoutePlanSlot> slots;

  Map<String, dynamic> toJson() => {
    'version': version,
    'generatedAtMs': generatedAtMs,
    'dayStartHour': RouteHabitModel.serviceDayStartHour,
    'slots': slots.map((slot) => slot.toJson()).toList(),
  };
}

class SmartRoutePlanner {
  const SmartRoutePlanner._();

  /// A reminder interrupts, so it asks for more than a place on the home
  /// screen does: three separate days, and better-than-even odds that today
  /// is another.
  static const int minSupportDays = 3;
  static const double minProbability = 0.5;

  /// A habit not seen for this long is treated as over until it is seen
  /// again. Two weeks covers a holiday without reminding anyone of a route
  /// they stopped taking last month.
  ///
  /// The plan is only rebuilt when the app is used, so the probability above
  /// cannot be what ends a reminder for somebody who has stopped opening it:
  /// nothing would recompute it. Each slot carries this as an expiry instead,
  /// which the reader checks against the clock.
  ///
  /// It is also the one thing a shown reminder never extends. Reminders that
  /// are read and not acted on keep the habit from fading, but only opening
  /// the route, from a reminder or otherwise, confirms it is still wanted.
  /// The reader's last reminders before the expiry say that it is coming.
  static const int maxDaysSinceLastUse = 14;

  /// Resolution of the windows. The background check itself only runs every
  /// quarter of an hour, so finer than this would be false precision.
  static const int gridMinutes = 10;

  /// The most slots kept for any one provider; see [build].
  static const int maxSlots = 64;

  /// Whether [profile] has been used on enough days to be worth planning
  /// for. Callers use this to decide which routes need a route id looked up.
  static bool isCandidate(RouteUsageProfile profile, DateTime now) =>
      profile.pathId != null &&
      RouteHabitEvidence.of(profile, now).dayCount >= minSupportDays;

  /// [routeIdOf] supplies the route id for a profile; a route it cannot
  /// name is left out, since nothing could be fetched for it.
  ///
  /// [reminders] are the ones already shown. Without them a reminder that
  /// did its job would look like a day the rider stayed home, and a tap on
  /// one like a routine that had moved earlier; see [RouteHabitEvidence].
  static SmartRoutePlan build({
    required Iterable<RouteUsageProfile> profiles,
    required String? Function(RouteUsageProfile profile) routeIdOf,
    Iterable<SmartRouteReminder> reminders = const <SmartRouteReminder>[],
    Iterable<FavoriteUsageProfile> favoriteProfiles =
        const <FavoriteUsageProfile>[],
    Iterable<FavoriteStop> favorites = const <FavoriteStop>[],
    required DateTime now,
  }) {
    final favoriteProfileList = favoriteProfiles.toList(growable: false);
    final favoriteList = favorites.toList(growable: false);
    final reminderList = reminders.toList(growable: false);
    final slots = <SmartRoutePlanSlot>[];
    final seen = <String>{};
    for (final profile in profiles) {
      final pathId = profile.pathId;
      if (pathId == null ||
          !seen.add('${profile.provider.name}:${profile.routeKey}:$pathId')) {
        continue;
      }
      final evidence = RouteHabitEvidence.of(
        profile,
        now,
        reminders: SmartRouteReminder.shownFor(profile, reminderList),
      );
      if (evidence.dayCount < minSupportDays) {
        continue;
      }
      final routeId = routeIdOf(profile)?.trim() ?? '';
      if (routeId.isEmpty) {
        continue;
      }
      final worthAsking = _minutesNearUse(evidence);
      // Today and the six days after it: one of each weekday. Each is judged
      // as it will look when it arrives, so a use this morning already counts
      // toward tomorrow's reminder instead of waiting for the next rebuild.
      for (var ahead = 0; ahead < 7; ahead++) {
        final targetDay = evidence.today + ahead;
        void close(_Window window) {
          // Shown reminders can hold a habit's odds up long after it was
          // last confirmed. A slot that would have lapsed before its day
          // came is not a slot, and must not take a live one's place.
          if (targetDay - window.peak.lastSupportDay! > maxDaysSinceLastUse) {
            return;
          }
          slots.add(
            _slot(
              profile: profile,
              routeId: routeId,
              pathId: pathId,
              targetDay: targetDay,
              window: window,
              favoriteProfiles: favoriteProfileList,
              favorites: favoriteList,
            ),
          );
        }

        _Window? window;
        for (var index = 0; index < worthAsking.length; index++) {
          final minute = index * gridMinutes;
          final estimate = worthAsking[index]
              ? evidence.estimate(targetDay: targetDay, minute: minute)
              : RouteHabitEstimate.none;
          final qualifies =
              estimate.supportDays >= minSupportDays &&
              estimate.probability >= minProbability;
          if (qualifies) {
            (window ??= _Window(minute)).extend(minute, estimate);
          } else if (window != null) {
            close(window);
            window = null;
          }
        }
        if (window != null) {
          close(window);
        }
      }
    }

    // The cap is per provider. The background check only acts on the slots
    // of the provider in use, so one shared cap would let another city's
    // habits crowd out every slot the rider could actually be reminded of.
    slots.sort((left, right) => right.confidence.compareTo(left.confidence));
    final keptPerProvider = <BusProvider, int>{};
    final kept = <SmartRoutePlanSlot>[];
    for (final slot in slots) {
      final count = keptPerProvider[slot.provider] ?? 0;
      if (count < maxSlots) {
        keptPerProvider[slot.provider] = count + 1;
        kept.add(slot);
      }
    }
    kept.sort((left, right) {
      final weekday = left.weekday.compareTo(right.weekday);
      if (weekday != 0) return weekday;
      final start = left.startMinute.compareTo(right.startMinute);
      if (start != 0) return start;
      final route = left.routeKey.compareTo(right.routeKey);
      if (route != 0) return route;
      return left.pathId.compareTo(right.pathId);
    });
    return SmartRoutePlan(
      generatedAtMs: now.millisecondsSinceEpoch,
      slots: List.unmodifiable(kept),
    );
  }

  /// Which grid minutes lie close enough to some use to be worth estimating.
  /// Most of the day is nowhere near one, and skipping it is what keeps a
  /// rebuild cheap enough to do on every open.
  static List<bool> _minutesNearUse(RouteHabitEvidence evidence) {
    final worthAsking = List<bool>.filled(
      (24 * 60 / gridMinutes).ceil(),
      false,
    );
    for (final used in evidence.minutes) {
      final first = math.max(0, used - RouteHabitModel.timeCutoffMinutes);
      final last = math.min(
        24 * 60 - 1,
        used + RouteHabitModel.timeCutoffMinutes,
      );
      for (
        var index = (first / gridMinutes).ceil();
        index * gridMinutes <= last;
        index++
      ) {
        worthAsking[index] = true;
      }
    }
    return worthAsking;
  }

  static SmartRoutePlanSlot _slot({
    required RouteUsageProfile profile,
    required String routeId,
    required int pathId,
    required int targetDay,
    required _Window window,
    required List<FavoriteUsageProfile> favoriteProfiles,
    required List<FavoriteStop> favorites,
  }) {
    final peak = window.peak;
    return SmartRoutePlanSlot(
      provider: profile.provider,
      routeKey: profile.routeKey,
      routeId: routeId,
      pathId: pathId,
      routeName: profile.routeName,
      weekday: ServiceTime.weekdayOfDay(targetDay),
      startMinute: window.startMinute,
      endMinute: window.endMinute,
      peakMinute: window.peakMinute,
      confidence: peak.probability,
      supportDays: peak.supportDays,
      validUntilMs: ServiceTime.startOfDay(
        peak.lastSupportDay! + maxDaysSinceLastUse + 1,
      ).millisecondsSinceEpoch,
      lastActivityAtMs: profile.latestInteractionAtMs,
      stopId: SmartRouteService.chooseBoardingStopId(
        profile: profile,
        favoriteProfiles: favoriteProfiles,
        favorites: favorites,
        at: ServiceTime.startOfDay(
          targetDay,
        ).add(Duration(minutes: window.peakMinute)),
      ),
    );
  }
}

class _Window {
  _Window(this.startMinute) : endMinute = startMinute, peakMinute = startMinute;

  final int startMinute;
  int endMinute;
  int peakMinute;
  RouteHabitEstimate peak = RouteHabitEstimate.none;

  void extend(int minute, RouteHabitEstimate estimate) {
    endMinute = minute;
    if (estimate.probability > peak.probability) {
      peak = estimate;
      peakMinute = minute;
    }
  }
}
