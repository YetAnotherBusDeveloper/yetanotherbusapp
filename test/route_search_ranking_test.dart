import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/route_search_ranking.dart';

void main() {
  final routes = [
    route(1, '  藍1  '),
    route(2, '藍12'),
    route(3, '小藍1'),
    route(4, '', officialName: '藍1區'),
    route(5, '', officialName: ''),
    route(6, '其他', description: '藍1轉乘'),
    route(7, ' F12 ', provider: 'TPE'),
    route(8, '藍1', provider: 'TPE'),
  ];

  test('cached ranks preserve comparator ordering without mutating input', () {
    final original = routes.toList();
    for (final query in ['', ' 藍1 ', 'f1', 'TXG', '轉乘', '不存在']) {
      for (final prioritizeProvider in [false, true]) {
        int priority(BusProvider provider) =>
            provider == BusProvider.txg ? 0 : 1;
        final providerPriority = prioritizeProvider ? priority : null;
        final expected = routes.toList()
          ..sort(
            (a, b) => compareRouteSummarySearchPriority(
              a,
              b,
              query: query,
              providerPriority: providerPriority,
            ),
          );
        expect(
          sortRouteSummariesForQuery(
            routes,
            query: query,
            providerPriority: providerPriority,
          ),
          expected,
        );
      }
    }
    expect(routes, original);
    expect(sortRouteSummariesForQuery([], query: '1'), isEmpty);
  });

  test(
    'provider priority is evaluated once per route instead of per comparison',
    () {
      var evaluations = 0;
      final result = sortRouteSummariesForQuery(
        routes,
        query: '藍1',
        providerPriority: (provider) {
          evaluations++;
          return provider == BusProvider.txg ? 0 : 1;
        },
      );
      expect(evaluations, routes.length);
      expect(result.first.routeKey, 1);
    },
  );

  test('English route and path names participate in ranking', () {
    final englishRoutes = [
      route(1, '機場快線', routeNameEn: 'Airport Express'),
      route(2, '其他', pathNameEn: 'Airport Terminal'),
      route(3, 'Airport Shuttle'),
    ];

    expect(
      sortRouteSummariesForQuery(
        englishRoutes,
        query: 'Airport Express',
      ).first.routeKey,
      1,
    );
    expect(
      sortRouteSummariesForQuery(
        englishRoutes,
        query: 'Terminal',
      ).first.routeKey,
      2,
    );
  });

  test('name relevance outranks provider, which breaks ties within a tier', () {
    final matches = [
      route(1, '41慢線'),
      route(2, '藍41', provider: 'TPE'),
      route(3, '41', provider: 'TPE'),
      route(4, '41區', provider: 'TPE'),
      route(5, '41'),
      route(6, '其他', description: '經過41'),
    ];
    int priority(BusProvider provider) => provider == BusProvider.txg ? 0 : 1;

    final sorted = sortRouteSummariesForQuery(
      matches,
      query: '41',
      providerPriority: priority,
    );

    expect(sorted.map((item) => item.routeKey), [5, 3, 1, 4, 2, 6]);
    expect(
      compareRouteSummarySearchPriority(
        matches[1],
        matches[0],
        query: '41',
        providerPriority: priority,
      ),
      greaterThan(0),
    );
  });

  test('route ID matches exactly; names and paths match substrings', () {
    expect(routeSummaryMatchesQuery(route(41, '其他'), '41'), isFalse);
    expect(routeSummaryMatchesQuery(route(41, '其他'), 'TXG41'), isTrue);
    expect(routeSummaryMatchesQuery(route(42, '藍41'), '41'), isTrue);
    expect(
      routeSummaryMatchesQuery(route(43, '其他', description: '經過41'), '41'),
      isTrue,
    );
  });
}

RouteSummary route(
  int id,
  String name, {
  String provider = 'TXG',
  String officialName = '',
  String description = '',
  String? routeNameEn,
  String? pathNameEn,
}) => RouteSummary(
  sourceProvider: provider,
  hashMd5: '',
  routeKey: id,
  routeId: '$provider$id',
  routeName: name,
  officialRouteName: officialName,
  routeNameEn: routeNameEn,
  description: description,
  pathNameEn: pathNameEn,
  category: '',
  sequence: id,
  rtrip: 0,
);
