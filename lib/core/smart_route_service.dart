import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import 'bus_repository.dart';
import 'last_bus_message.dart';
import 'models.dart';
import 'smart_route_habit.dart';

/// Where one route stands among the candidates for a recommendation.
class SmartRouteRanking {
  const SmartRouteRanking({
    required this.profile,
    required this.score,
    required this.estimate,
    required this.fromHabit,
  });

  final RouteUsageProfile profile;

  /// Comparable across routes; roughly the chance the route is wanted now.
  final double score;
  final RouteHabitEstimate estimate;

  /// False when the route only qualified through the undated hourly counters
  /// of a profile that predates visit history.
  final bool fromHabit;
}

class SmartRouteService {
  const SmartRouteService._();

  /// Used around this time on at least this many separate days. One morning
  /// of reopening a page is one day, however many opens it took.
  static const int minSupportDaysForRecommendation = 2;

  /// Below this the route is not worth a place on the home screen.
  static const double minProbabilityForRecommendation = 0.12;

  /// A profile written before visits were kept needs this many opens, and
  /// [minLegacyNearbyOpens] of them within an hour of now, to be recommended
  /// from its counters alone. The old scoring asked for the same numbers,
  /// except that it let recent taps count toward the second; those carry a
  /// date, so they are weighed as habit evidence instead.
  static const int minLegacyOpens = 3;
  static const int minLegacyNearbyOpens = 2;

  /// Opens around this hour at which the counters are trusted in full.
  static const double legacyFullOpens = 5;

  /// The most the counters alone can score. Kept well under what a real
  /// habit reaches, because they cannot tell a Saturday from a Tuesday.
  static const double legacyWeight = 0.3;

  /// Days of dated use after which the counters are no longer consulted.
  static const int legacyHandoverDays = 6;

  /// A route opened in the last [recentUseWindowMinutes] is probably still
  /// the one being waited for, so it is nudged ahead of an equal habit.
  static const double recentUseBoost = 0.2;
  static const int recentUseWindowMinutes = 90;

  /// Within this distance of a stop the rider is taken to be at it.
  static const double atStopMeters = 400;

  /// Within this distance the rider's usual stop is still the one they will
  /// walk to, even if another stop of the route happens to be nearer.
  static const double usualStopReachMeters = 800;

  /// What it takes for a stop to count as the usual one: about two recent
  /// days of opening the route there, and most of the opens that named a stop.
  static const double minLearnedStopScore = 1;
  static const double minLearnedStopShare = 0.6;

  static RouteUsageProfile? chooseProfileForTime(
    Iterable<RouteUsageProfile> profiles,
    DateTime now, {
    Iterable<SmartRouteReminder> reminders = const <SmartRouteReminder>[],
  }) {
    final ranked = rankProfilesForTime(profiles, now, reminders: reminders);
    return ranked.isEmpty ? null : ranked.first.profile;
  }

  /// Every profile worth recommending at [now], best first, one per route
  /// and direction.
  ///
  /// [reminders] are the ones the background check has shown; see
  /// [SmartRouteReminder].
  static List<SmartRouteRanking> rankProfilesForTime(
    Iterable<RouteUsageProfile> profiles,
    DateTime now, {
    Iterable<SmartRouteReminder> reminders = const <SmartRouteReminder>[],
  }) {
    final reminderList = reminders.toList(growable: false);
    final ranked = <SmartRouteRanking>[];
    for (final profile in profiles) {
      final ranking = rankProfile(profile, now, reminders: reminderList);
      if (ranking != null) {
        ranked.add(ranking);
      }
    }
    ranked.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      final support = right.estimate.supportDays.compareTo(
        left.estimate.supportDays,
      );
      if (support != 0) return support;
      final latest = right.profile.latestInteractionAtMs.compareTo(
        left.profile.latestInteractionAtMs,
      );
      if (latest != 0) return latest;
      // List.sort is not stable; without a last word here two equal routes
      // could swap places between refreshes.
      final route = left.profile.routeKey.compareTo(right.profile.routeKey);
      if (route != 0) return route;
      return (left.profile.pathId ?? -1).compareTo(right.profile.pathId ?? -1);
    });

    final seen = <String>{};
    return [
      for (final ranking in ranked)
        if (seen.add(_identity(ranking.profile))) ranking,
    ];
  }

  /// Where [profile] stands at [now], or null when it should not be
  /// recommended at all.
  static SmartRouteRanking? rankProfile(
    RouteUsageProfile profile,
    DateTime now, {
    Iterable<SmartRouteReminder> reminders = const <SmartRouteReminder>[],
  }) {
    if (profile.pathId == null) {
      return null;
    }
    final evidence = RouteHabitEvidence.of(
      profile,
      now,
      reminders: SmartRouteReminder.shownFor(profile, reminders),
    );
    final estimate = evidence.estimateNow(now);
    final habitScore =
        estimate.supportDays >= minSupportDaysForRecommendation &&
            estimate.probability >= minProbabilityForRecommendation
        ? estimate.probability
        : 0.0;
    // Handed over only as dated use builds up around this time of day. Use
    // at other times says nothing about whether the counters for this one
    // are still needed.
    final legacyScore =
        legacyWeight *
        legacyStrength(profile, now, datedDays: estimate.supportDays);
    final baseScore = math.max(habitScore, legacyScore);
    if (baseScore < minProbabilityForRecommendation) {
      return null;
    }

    final sinceLastUse = evidence.minutesSinceLastUseToday(now);
    final recentBoost =
        sinceLastUse != null && sinceLastUse < recentUseWindowMinutes
        ? recentUseBoost * (1 - sinceLastUse / recentUseWindowMinutes)
        : 0.0;
    return SmartRouteRanking(
      profile: profile,
      score: baseScore + recentBoost,
      estimate: estimate,
      fromHabit: habitScore > 0 && habitScore >= legacyScore,
    );
  }

  /// How much the undated hourly counters of an older profile say about
  /// [now], 0..1.
  ///
  /// They carry a profile across the upgrade to visit history and then step
  /// aside: they fade as the moment they describe recedes, and again as
  /// [datedDays] — days of dated use around the time of [now] — accumulate
  /// to replace them.
  static double legacyStrength(
    RouteUsageProfile profile,
    DateTime now, {
    required int datedDays,
  }) {
    final asOfMs = profile.legacyAsOfMs;
    if (asOfMs == null || profile.totalOpens < minLegacyOpens) {
      return 0;
    }
    final ageDays =
        (now.millisecondsSinceEpoch - asOfMs) / Duration.millisecondsPerDay;
    if (ageDays > RouteHabitModel.lookbackDays) {
      return 0;
    }
    final hour = now.hour;
    final current = profile.countAtHour(hour);
    final adjacent =
        profile.countAtHour((hour + 23) % 24) +
        profile.countAtHour((hour + 1) % 24);
    if (current + adjacent < minLegacyNearbyOpens) {
      return 0;
    }
    final volume = math.min(1.0, (current + adjacent / 2) / legacyFullOpens);
    final handover = math.max(0.0, 1 - datedDays / legacyHandoverDays);
    return volume * RouteHabitModel.decay(ageDays) * handover;
  }

  static FavoriteStop? chooseFavoriteForRoute({
    required RouteUsageProfile routeProfile,
    required Iterable<FavoriteUsageProfile> favoriteProfiles,
    required Iterable<FavoriteStop> favorites,
    required DateTime now,
  }) {
    final favoritesForRoute = _favoritesForRoute(routeProfile, favorites);
    if (favoritesForRoute.isEmpty) {
      return null;
    }

    FavoriteUsageProfile? bestProfile;
    double bestScore = 0;
    var bestTotalSelections = 0;
    var bestLastSelectedAtMs = 0;

    for (final profile in favoriteProfiles) {
      if (!profile.matchesRoute(routeProfile) ||
          !favoritesForRoute.any(profile.matchesFavorite)) {
        continue;
      }

      final score = scoreFavoriteForTime(profile, now);
      if (score <= 0) {
        continue;
      }

      final totalSelections = profile.totalSelectionsAt(now: now);
      final lastSelectedAtMs = profile.lastSelectedAtMsAt(now: now);
      final shouldReplace =
          bestProfile == null ||
          score > bestScore ||
          (score == bestScore && totalSelections > bestTotalSelections) ||
          (score == bestScore &&
              totalSelections == bestTotalSelections &&
              lastSelectedAtMs > bestLastSelectedAtMs);
      if (!shouldReplace) {
        continue;
      }

      bestProfile = profile;
      bestScore = score;
      bestTotalSelections = totalSelections;
      bestLastSelectedAtMs = lastSelectedAtMs;
    }

    if (bestProfile == null) {
      return null;
    }

    for (final favorite in favoritesForRoute) {
      if (bestProfile.matchesFavorite(favorite)) {
        return favorite;
      }
    }
    return null;
  }

  static double scoreFavoriteForTime(
    FavoriteUsageProfile profile,
    DateTime now,
  ) {
    final currentHour = now.hour;
    final previousHour = (currentHour + 23) % 24;
    final nextHour = (currentHour + 1) % 24;
    final currentCount = profile.selectionCountAtHour(currentHour, now: now);
    final adjacentCount =
        profile.selectionCountAtHour(previousHour, now: now) +
        profile.selectionCountAtHour(nextHour, now: now);
    final totalSelections = profile.totalSelectionsAt(now: now);
    final lastSelectedAtMs = profile.lastSelectedAtMsAt(now: now);
    final recencyDays = lastSelectedAtMs <= 0
        ? 365
        : now
              .difference(DateTime.fromMillisecondsSinceEpoch(lastSelectedAtMs))
              .inDays;
    final recencyBonus = recencyDays <= 2
        ? 1.5
        : recencyDays <= 7
        ? 0.75
        : 0.0;

    return (currentCount * 4.0) +
        (adjacentCount * 2.0) +
        (totalSelections * 0.35) +
        recencyBonus;
  }

  /// The stop [profile] is usually opened at around the time of day of [at],
  /// or null when no single stop stands out.
  ///
  /// Each day votes once per stop, so a morning spent reopening the page
  /// counts the same as a morning that opened it once.
  static int? learnedStopId(RouteUsageProfile profile, DateTime at) {
    final atMs = at.millisecondsSinceEpoch;
    final time = ServiceTime.fromDateTime(at);
    final matchByStopAndDay = <int, Map<int, double>>{};
    for (final visit in profile.visitsWithin(now: at)) {
      final stopId = visit.stopId;
      if (stopId == null || visit.atMs > atMs) {
        continue;
      }
      final visited = ServiceTime.fromMs(visit.atMs);
      final match = RouteHabitModel.timeMatch(
        (visited.minute - time.minute).abs(),
      );
      if (match <= 0) {
        continue;
      }
      final byDay = matchByStopAndDay[stopId] ??= <int, double>{};
      byDay[visited.day] = math.max(byDay[visited.day] ?? 0, match);
    }

    int? bestStopId;
    var bestScore = 0.0;
    var totalScore = 0.0;
    for (final entry in matchByStopAndDay.entries) {
      var score = 0.0;
      entry.value.forEach((day, match) {
        score += RouteHabitModel.decay(time.day - day) * match;
      });
      totalScore += score;
      if (score > bestScore ||
          (score == bestScore &&
              (bestStopId == null || entry.key < bestStopId))) {
        bestScore = score;
        bestStopId = entry.key;
      }
    }
    if (bestStopId == null ||
        bestScore < minLearnedStopScore ||
        bestScore < minLearnedStopShare * totalScore) {
      return null;
    }
    return bestStopId;
  }

  /// The stop a reminder for [profile] should watch when the device's
  /// location is not available: a favorite the rider has been using at this
  /// time, else the stop the route is usually opened at, else the route's
  /// only favorite.
  static int? chooseBoardingStopId({
    required RouteUsageProfile profile,
    required Iterable<FavoriteUsageProfile> favoriteProfiles,
    required Iterable<FavoriteStop> favorites,
    required DateTime at,
  }) {
    final usedFavorite = chooseFavoriteForRoute(
      routeProfile: profile,
      favoriteProfiles: favoriteProfiles,
      favorites: favorites,
      now: at,
    );
    if (usedFavorite != null) {
      return usedFavorite.stopId;
    }
    final learned = learnedStopId(profile, at);
    if (learned != null) {
      return learned;
    }
    final stopIds = _favoritesForRoute(
      profile,
      favorites,
    ).map((favorite) => favorite.stopId).toSet();
    return stopIds.length == 1 ? stopIds.single : null;
  }

  static const String _genericReason = '根據你的使用習慣。';

  static String _reasonFor(SmartRouteRanking ranking, DateTime now) {
    final typicalMinute = ranking.estimate.typicalMinute;
    if (!ranking.fromHabit || typicalMinute == null) {
      return _genericReason;
    }
    // To the nearest five minutes: the spread of a habit is wider than that,
    // and "07:38" would claim a precision nobody has.
    final clock = ServiceTime.clockMinute((typicalMinute / 5).round() * 5);
    final hour = (clock ~/ 60).toString().padLeft(2, '0');
    final minute = (clock % 60).toString().padLeft(2, '0');
    final days = ServiceTime.isWeekend(ServiceTime.fromDateTime(now).weekday)
        ? '假日'
        : '平日';
    return '你$days常在 $hour:$minute 左右查看這條路線。';
  }

  static SmartRouteSuggestion buildSuggestion({
    required RouteUsageProfile profile,
    required double score,
    required String reason,
    required RouteDetailData detail,
    FavoriteStop? favorite,
    Position? position,
    int? learnedStopId,
    Iterable<FavoriteStop> routeFavorites = const <FavoriteStop>[],
  }) {
    final learnedPath = profile.pathId == null
        ? null
        : _findPath(detail, profile.pathId!);

    StopInfo? nearestStop;
    double? nearestDistance;
    if (position != null && profile.pathId != null) {
      for (final stop
          in detail.stopsByPath[profile.pathId] ?? const <StopInfo>[]) {
        final distance = _distanceTo(position, stop);
        if (distance == null) {
          continue;
        }
        if (nearestDistance == null || distance < nearestDistance) {
          nearestDistance = distance;
          nearestStop = stop;
        }
      }
    }

    // A favorite the rider has been choosing at this time of day comes first:
    // it is the one stop they have said, by using it, that they mean.
    final usedFavoriteStop = favorite == null
        ? null
        : _findStopInDetail(detail, favorite.pathId, favorite.stopId);
    if (favorite != null && usedFavoriteStop != null) {
      return SmartRouteSuggestion(
        profile: profile,
        score: score,
        reason: reason,
        detail: detail,
        nearestStop: nearestStop,
        nearestPath: learnedPath,
        distanceMeters: nearestDistance,
        favorite: favorite,
        favoriteStop: usedFavoriteStop,
        favoritePath: _findPath(detail, favorite.pathId),
      );
    }

    // Otherwise the stop the route is usually opened at, and failing that a
    // saved one. A saved stop nobody has used lately is shown as a plain stop
    // rather than as the favorite: opening the favorite would also bring its
    // destination along, which the rider has not asked for this time.
    final usualStop = profile.pathId == null
        ? null
        : (learnedStopId == null
                  ? null
                  : _findStopInDetail(
                      detail,
                      profile.pathId!,
                      learnedStopId,
                    )) ??
              _closestFavoriteStop(
                detail: detail,
                favorites: _favoritesForRoute(profile, routeFavorites),
                position: position,
              );
    if (usualStop != null) {
      final usualDistance = position == null
          ? null
          : _distanceTo(position, usualStop);
      // The usual stop gives way only to a stop the rider is actually at
      // while the usual one is out of reach: somebody 200 m from the stop
      // before theirs is still going to walk to theirs.
      final isElsewhereOnRoute =
          nearestDistance != null &&
          nearestDistance <= atStopMeters &&
          (usualDistance == null || usualDistance > usualStopReachMeters);
      if (!isElsewhereOnRoute) {
        return SmartRouteSuggestion(
          profile: profile,
          score: score,
          reason: reason,
          detail: detail,
          nearestStop: nearestStop,
          nearestPath: learnedPath,
          distanceMeters: usualDistance,
          learnedStop: usualStop,
        );
      }
    }

    return SmartRouteSuggestion(
      profile: profile,
      score: score,
      reason: reason,
      detail: detail,
      nearestStop: nearestStop,
      nearestPath: learnedPath,
      distanceMeters: nearestDistance,
    );
  }

  static Future<SmartRouteSuggestion?> loadSuggestion({
    required BusRepository repository,
    required Iterable<RouteUsageProfile> profiles,
    Iterable<FavoriteUsageProfile> favoriteProfiles =
        const <FavoriteUsageProfile>[],
    Iterable<FavoriteStop> favorites = const <FavoriteStop>[],
    Iterable<SmartRouteReminder> reminders = const <SmartRouteReminder>[],
    required DateTime now,
    Position? position,
  }) async {
    final suggestions = await loadSuggestions(
      repository: repository,
      profiles: profiles,
      favoriteProfiles: favoriteProfiles,
      favorites: favorites,
      reminders: reminders,
      now: now,
      position: position,
      limit: 1,
    );
    return suggestions.isEmpty ? null : suggestions.first;
  }

  static Future<List<SmartRouteSuggestion>> loadSuggestions({
    required BusRepository repository,
    required Iterable<RouteUsageProfile> profiles,
    Iterable<FavoriteUsageProfile> favoriteProfiles =
        const <FavoriteUsageProfile>[],
    Iterable<FavoriteStop> favorites = const <FavoriteStop>[],
    Iterable<SmartRouteReminder> reminders = const <SmartRouteReminder>[],
    required DateTime now,
    Position? position,
    int limit = 3,
  }) async {
    if (limit <= 0) {
      return const <SmartRouteSuggestion>[];
    }

    final favoriteProfileList = favoriteProfiles.toList(growable: false);
    final favoriteList = favorites.toList(growable: false);
    final ranked = rankProfilesForTime(profiles, now, reminders: reminders);
    final suggestions = <SmartRouteSuggestion>[];
    var next = 0;
    // Fetch only as many routes at once as there are places left to fill, in
    // rank order. The common case is one round trip instead of [limit] in a
    // row, and a route that fails or has run its last bus costs one more
    // round rather than a fetch of every profile.
    while (suggestions.length < limit && next < ranked.length) {
      final batch = ranked.sublist(
        next,
        math.min(next + limit - suggestions.length, ranked.length),
      );
      next += batch.length;
      final loaded = await Future.wait(
        batch.map(
          (ranking) => _loadSuggestion(
            repository: repository,
            ranking: ranking,
            favoriteProfiles: favoriteProfileList,
            favorites: favoriteList,
            now: now,
            position: position,
          ),
        ),
      );
      suggestions.addAll(loaded.whereType<SmartRouteSuggestion>());
    }
    return List.unmodifiable(suggestions);
  }

  static Future<SmartRouteSuggestion?> _loadSuggestion({
    required BusRepository repository,
    required SmartRouteRanking ranking,
    required List<FavoriteUsageProfile> favoriteProfiles,
    required List<FavoriteStop> favorites,
    required DateTime now,
    required Position? position,
  }) async {
    final profile = ranking.profile;
    try {
      final detail = await repository.getCompleteBusInfo(
        profile.routeKey,
        provider: profile.provider,
      );
      final suggestion = buildSuggestion(
        profile: profile,
        score: ranking.score,
        reason: _reasonFor(ranking, now),
        detail: detail,
        favorite: chooseFavoriteForRoute(
          routeProfile: profile,
          favoriteProfiles: favoriteProfiles,
          favorites: favorites,
          now: now,
        ),
        position: position,
        learnedStopId: learnedStopId(profile, now),
        routeFavorites: favorites,
      );
      return _isLastBusSuggestion(suggestion) ? null : suggestion;
    } catch (_) {
      // One route failing to load must not cost the others their place.
      return null;
    }
  }

  static bool _isLastBusSuggestion(SmartRouteSuggestion suggestion) {
    final recommendedStop = suggestion.recommendedStop;
    if (recommendedStop != null) {
      return isLastBusMessage(recommendedStop.msg) ||
          recommendedStop.etas.any((eta) => isLastBusMessage(eta.msg));
    }

    final pathId = suggestion.profile.pathId;
    final stops = pathId == null
        ? const <StopInfo>[]
        : suggestion.detail?.stopsByPath[pathId] ?? const <StopInfo>[];
    return stops.isNotEmpty &&
        stops.every(
          (stop) =>
              isLastBusMessage(stop.msg) ||
              stop.etas.any((eta) => isLastBusMessage(eta.msg)),
        );
  }

  static String _identity(RouteUsageProfile profile) =>
      '${profile.provider.name}:${profile.routeKey}:${profile.pathId}';

  static List<FavoriteStop> _favoritesForRoute(
    RouteUsageProfile profile,
    Iterable<FavoriteStop> favorites,
  ) {
    return favorites
        .where(
          (favorite) =>
              favorite.provider == profile.provider &&
              favorite.routeKey == profile.routeKey &&
              favorite.pathId == profile.pathId,
        )
        .toList();
  }

  /// The saved stop to show when none has been used lately: the only one on
  /// this direction, or the closest of several when the position is known.
  /// With several and no position there is nothing to choose between them.
  static StopInfo? _closestFavoriteStop({
    required RouteDetailData detail,
    required List<FavoriteStop> favorites,
    required Position? position,
  }) {
    final candidates = <StopInfo>[];
    final seenStopIds = <int>{};
    for (final favorite in favorites) {
      final stop = _findStopInDetail(detail, favorite.pathId, favorite.stopId);
      if (stop != null && seenStopIds.add(stop.stopId)) {
        candidates.add(stop);
      }
    }
    if (candidates.length <= 1) {
      return candidates.isEmpty ? null : candidates.single;
    }
    if (position == null) {
      return null;
    }
    StopInfo? closest;
    double? closestDistance;
    for (final candidate in candidates) {
      final distance = _distanceTo(position, candidate);
      if (distance == null) {
        continue;
      }
      if (closestDistance == null || distance < closestDistance) {
        closestDistance = distance;
        closest = candidate;
      }
    }
    return closest;
  }

  static double? _distanceTo(Position position, StopInfo stop) {
    if (stop.lat == 0 || stop.lon == 0) {
      return null;
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      stop.lat,
      stop.lon,
    );
  }

  static StopInfo? _findStopInDetail(
    RouteDetailData detail,
    int pathId,
    int stopId,
  ) {
    final stops = detail.stopsByPath[pathId] ?? const <StopInfo>[];
    for (final stop in stops) {
      if (stop.stopId == stopId) {
        return stop;
      }
    }
    return null;
  }

  static PathInfo? _findPath(RouteDetailData detail, int pathId) {
    for (final path in detail.paths) {
      if (path.pathId == pathId) {
        return path;
      }
    }
    return null;
  }
}
