import 'models.dart';

typedef RouteSearchProviderPriority = int Function(BusProvider provider);

List<RouteSummary> sortRouteSummariesForQuery(
  Iterable<RouteSummary> routes, {
  required String query,
  RouteSearchProviderPriority? providerPriority,
}) {
  final sorted = routes.toList();
  final normalizedQuery = _normalizeRouteSearchText(query);
  // Normalize each route once rather than allocating two ranks for every
  // comparison (O(n log n)). Keep these caches local to this query.
  final ranks = <RouteSummary, _RouteSearchRank>{
    for (final route in sorted)
      route: _RouteSearchRank.fromSummary(route, normalizedQuery),
  };
  final priorities = <RouteSummary, int>{
    if (providerPriority != null)
      for (final route in sorted)
        route: providerPriority(busProviderFromString(route.sourceProvider)),
  };
  sorted.sort((left, right) {
    final priority = (priorities[left] ?? 0).compareTo(priorities[right] ?? 0);
    return priority != 0
        ? priority
        : _compareRanks(ranks[left]!, ranks[right]!);
  });
  return sorted;
}

int compareRouteSummarySearchPriority(
  RouteSummary left,
  RouteSummary right, {
  required String query,
  RouteSearchProviderPriority? providerPriority,
}) {
  if (providerPriority != null) {
    final leftPriority = providerPriority(
      busProviderFromString(left.sourceProvider),
    );
    final rightPriority = providerPriority(
      busProviderFromString(right.sourceProvider),
    );
    if (leftPriority != rightPriority) {
      return leftPriority.compareTo(rightPriority);
    }
  }

  final normalizedQuery = _normalizeRouteSearchText(query);
  final leftRank = _RouteSearchRank.fromSummary(left, normalizedQuery);
  final rightRank = _RouteSearchRank.fromSummary(right, normalizedQuery);

  return _compareRanks(leftRank, rightRank);
}

int _compareRanks(_RouteSearchRank leftRank, _RouteSearchRank rightRank) {
  if (leftRank.matchTier != rightRank.matchTier) {
    return leftRank.matchTier.compareTo(rightRank.matchTier);
  }
  if (leftRank.lengthGap != rightRank.lengthGap) {
    return leftRank.lengthGap.compareTo(rightRank.lengthGap);
  }
  if (leftRank.nameLength != rightRank.nameLength) {
    return leftRank.nameLength.compareTo(rightRank.nameLength);
  }

  final routeNameCompare = leftRank.routeName.compareTo(rightRank.routeName);
  if (routeNameCompare != 0) {
    return routeNameCompare;
  }

  final routeIdCompare = leftRank.routeId.compareTo(rightRank.routeId);
  if (routeIdCompare != 0) {
    return routeIdCompare;
  }

  return leftRank.description.compareTo(rightRank.description);
}

class _RouteSearchRank {
  const _RouteSearchRank({
    required this.matchTier,
    required this.lengthGap,
    required this.nameLength,
    required this.routeName,
    required this.routeId,
    required this.description,
  });

  factory _RouteSearchRank.fromSummary(
    RouteSummary route,
    String normalizedQuery,
  ) {
    final routeName = _normalizeRouteSearchText(_displayRouteName(route));
    final routeNameEn = _normalizeRouteSearchText(
      route.routeNameEn ?? route.officialRouteName,
    );
    final routeId = _normalizeRouteSearchText(route.routeId);
    final description = _normalizeRouteSearchText(route.description);
    final descriptionEn = _normalizeRouteSearchText(route.pathNameEn ?? '');
    final nameLengthGaps = [routeName, routeNameEn]
        .where((name) => name.isNotEmpty)
        .map((name) => (name.length - normalizedQuery.length).abs());
    return _RouteSearchRank(
      matchTier: _matchTier(
        routeName,
        routeNameEn,
        routeId,
        description,
        descriptionEn,
        normalizedQuery,
      ),
      lengthGap: normalizedQuery.isEmpty
          ? 0
          : nameLengthGaps.isEmpty
          ? normalizedQuery.length
          : nameLengthGaps.reduce((left, right) => left < right ? left : right),
      nameLength: routeName.isEmpty ? 9999 : routeName.length,
      routeName: routeName,
      routeId: routeId,
      description: description,
    );
  }

  final int matchTier;
  final int lengthGap;
  final int nameLength;
  final String routeName;
  final String routeId;
  final String description;

  static int _matchTier(
    String routeName,
    String routeNameEn,
    String routeId,
    String description,
    String descriptionEn,
    String query,
  ) {
    if (query.isEmpty) {
      return 0;
    }
    if (routeName == query || routeNameEn == query) {
      return 0;
    }
    if (routeName.startsWith(query) || routeNameEn.startsWith(query)) {
      return 1;
    }
    if (routeName.contains(query) || routeNameEn.contains(query)) {
      return 2;
    }
    if (routeId == query) {
      return 3;
    }
    if (routeId.contains(query)) {
      return 4;
    }
    if (description.contains(query) || descriptionEn.contains(query)) {
      return 5;
    }
    return 6;
  }
}

String _displayRouteName(RouteSummary route) {
  final routeName = route.routeName.trim();
  if (routeName.isNotEmpty) {
    return routeName;
  }
  final officialRouteName = route.officialRouteName.trim();
  if (officialRouteName.isNotEmpty) {
    return officialRouteName;
  }
  return route.routeId.trim();
}

String _normalizeRouteSearchText(String value) {
  return value.trim().toLowerCase();
}
