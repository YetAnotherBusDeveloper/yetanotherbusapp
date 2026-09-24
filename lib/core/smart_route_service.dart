import 'package:geolocator/geolocator.dart';

import 'bus_repository.dart';
import 'last_bus_message.dart';
import 'models.dart';

class SmartRouteService {
  const SmartRouteService._();

  static const int minTotalOpensForRecommendation = 3;
  static const int minRelevantInteractionsForRecommendation = 2;

  static RouteUsageProfile? chooseProfileForTime(
    Iterable<RouteUsageProfile> profiles,
    DateTime now,
  ) {
    RouteUsageProfile? bestProfile;
    double bestScore = 0;

    for (final profile in profiles) {
      if (profile.pathId == null) {
        continue;
      }
      if (!hasEnoughHistoryForRecommendation(profile, now)) {
        continue;
      }

      final score = scoreProfileForTime(profile, now);
      if (score > bestScore) {
        bestProfile = profile;
        bestScore = score;
      }
    }
    return bestProfile;
  }

  static List<RouteUsageProfile> chooseTopProfilesForTime(
    Iterable<RouteUsageProfile> profiles,
    DateTime now, {
    int limit = 3,
  }) {
    return _rankProfilesForTime(
      profiles,
      now,
    ).take(limit).map((entry) => entry.key).toList();
  }

  static List<MapEntry<RouteUsageProfile, double>> _rankProfilesForTime(
    Iterable<RouteUsageProfile> profiles,
    DateTime now,
  ) {
    final scored = <MapEntry<RouteUsageProfile, double>>[];
    for (final profile in profiles) {
      if (profile.pathId == null) {
        continue;
      }
      if (!hasEnoughHistoryForRecommendation(profile, now)) {
        continue;
      }
      final score = scoreProfileForTime(profile, now);
      if (score > 0) {
        scored.add(MapEntry(profile, score));
      }
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored;
  }

  static bool hasEnoughHistoryForRecommendation(
    RouteUsageProfile profile,
    DateTime now,
  ) {
    if (profile.totalOpens < minTotalOpensForRecommendation) {
      return false;
    }

    final currentHour = now.hour;
    final previousHour = (currentHour + 23) % 24;
    final nextHour = (currentHour + 1) % 24;
    final relevantInteractions =
        profile.combinedCountAtHour(currentHour, now: now) +
        profile.combinedCountAtHour(previousHour, now: now) +
        profile.combinedCountAtHour(nextHour, now: now);
    return relevantInteractions >= minRelevantInteractionsForRecommendation;
  }

  static double scoreProfileForTime(RouteUsageProfile profile, DateTime now) {
    final currentHour = now.hour;
    final previousHour = (currentHour + 23) % 24;
    final nextHour = (currentHour + 1) % 24;
    final currentOpenCount = profile.countAtHour(currentHour);
    final currentSelectionCount = profile.selectionCountAtHour(
      currentHour,
      now: now,
    );
    final adjacentOpenCount =
        profile.countAtHour(previousHour) + profile.countAtHour(nextHour);
    final adjacentSelectionCount =
        profile.selectionCountAtHour(previousHour, now: now) +
        profile.selectionCountAtHour(nextHour, now: now);
    final preferredCount = profile.combinedCountAtHour(
      profile.preferredHourAt(now: now),
      now: now,
    );
    final recencyDays = profile.latestInteractionAtMs <= 0
        ? 365
        : now
              .difference(
                DateTime.fromMillisecondsSinceEpoch(
                  profile.latestInteractionAtMs,
                ),
              )
              .inDays;
    final recencyBonus = recencyDays <= 2
        ? 1.5
        : recencyDays <= 7
        ? 0.75
        : 0.0;

    return (currentOpenCount * 5) +
        (currentSelectionCount * 3.5) +
        (adjacentOpenCount * 2.5) +
        (adjacentSelectionCount * 1.5) +
        (preferredCount * 0.5) +
        (profile.totalOpens * 0.15) +
        (profile.totalSelections * 0.1) +
        recencyBonus;
  }

  static FavoriteStop? chooseFavoriteForRoute({
    required RouteUsageProfile routeProfile,
    required Iterable<FavoriteUsageProfile> favoriteProfiles,
    required Iterable<FavoriteStop> favorites,
    required DateTime now,
  }) {
    final favoritesForRoute = favorites
        .where(
          (favorite) =>
              favorite.provider == routeProfile.provider &&
              favorite.routeKey == routeProfile.routeKey &&
              favorite.pathId == routeProfile.pathId,
        )
        .toList();
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

  static String buildReason(RouteUsageProfile profile, DateTime now) {
    // final currentCount = profile.combinedCountAtHour(now.hour);
    // if (currentCount > 0) {
    //   return '你常在這個時段點開這條路線。';
    // }

    // final preferredHour = profile.preferredHour;
    // final label = preferredHour.toString().padLeft(2, '0');
    // return '你通常會在 $label:00 左右點開這條路線。';
    return '根據你的使用習慣。';
  }

  static SmartRouteSuggestion buildSuggestion({
    required RouteUsageProfile profile,
    required double score,
    required String reason,
    required RouteDetailData detail,
    FavoriteStop? favorite,
    Position? position,
  }) {
    FavoriteStop? matchedFavorite;
    StopInfo? favoriteStop;
    PathInfo? favoritePath;
    final learnedPath = profile.pathId == null
        ? null
        : _findPath(detail, profile.pathId!);
    if (favorite != null) {
      favoritePath = _findPath(detail, favorite.pathId);
      favoriteStop = _findStopInDetail(
        detail,
        favorite.pathId,
        favorite.stopId,
      );
      if (favoriteStop != null) {
        matchedFavorite = favorite;
      } else {
        favoritePath = null;
      }
    }

    if (position == null) {
      return SmartRouteSuggestion(
        profile: profile,
        score: score,
        reason: reason,
        detail: detail,
        nearestPath: learnedPath,
        favorite: matchedFavorite,
        favoriteStop: favoriteStop,
        favoritePath: favoritePath,
      );
    }

    StopInfo? nearestStop;
    PathInfo? nearestPath = learnedPath;
    double? nearestDistance;

    for (final path in detail.paths.where(
      (path) => path.pathId == profile.pathId,
    )) {
      final stops = detail.stopsByPath[path.pathId] ?? const <StopInfo>[];
      for (final stop in stops) {
        if (stop.lat == 0 || stop.lon == 0) {
          continue;
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          stop.lat,
          stop.lon,
        );
        if (nearestDistance == null || distance < nearestDistance) {
          nearestDistance = distance;
          nearestStop = stop;
          nearestPath = path;
        }
      }
    }

    return SmartRouteSuggestion(
      profile: profile,
      score: score,
      reason: reason,
      detail: detail,
      nearestStop: nearestStop,
      nearestPath: nearestPath,
      distanceMeters: nearestDistance,
      favorite: matchedFavorite,
      favoriteStop: favoriteStop,
      favoritePath: favoritePath,
    );
  }

  static Future<SmartRouteSuggestion?> loadSuggestion({
    required BusRepository repository,
    required Iterable<RouteUsageProfile> profiles,
    Iterable<FavoriteUsageProfile> favoriteProfiles =
        const <FavoriteUsageProfile>[],
    Iterable<FavoriteStop> favorites = const <FavoriteStop>[],
    required DateTime now,
    Position? position,
  }) async {
    final suggestions = await loadSuggestions(
      repository: repository,
      profiles: profiles,
      favoriteProfiles: favoriteProfiles,
      favorites: favorites,
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
    required DateTime now,
    Position? position,
    int limit = 3,
  }) async {
    if (limit <= 0) {
      return const <SmartRouteSuggestion>[];
    }

    final suggestions = <SmartRouteSuggestion>[];
    final seen = <String>{};
    for (final entry in _rankProfilesForTime(profiles, now)) {
      final profile = entry.key;
      final identity =
          '${profile.provider.name}:${profile.routeKey}:${profile.pathId}';
      if (!seen.add(identity)) {
        continue;
      }
      try {
        final detail = await repository.getCompleteBusInfo(
          profile.routeKey,
          provider: profile.provider,
        );
        final favorite = chooseFavoriteForRoute(
          routeProfile: profile,
          favoriteProfiles: favoriteProfiles,
          favorites: favorites,
          now: now,
        );
        final suggestion = buildSuggestion(
          profile: profile,
          score: entry.value,
          reason: buildReason(profile, now),
          detail: detail,
          favorite: favorite,
          position: position,
        );
        if (_isLastBusSuggestion(suggestion)) {
          continue;
        }
        suggestions.add(suggestion);
        if (suggestions.length == limit) {
          break;
        }
      } catch (_) {
        // Keep scanning lower-ranked profiles until the requested limit is met.
      }
    }
    return List.unmodifiable(suggestions);
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
