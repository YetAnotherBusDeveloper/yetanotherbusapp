import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';

Map<String, Object> stopRow({String name = '臺北車站'}) => {
  'routeid': 'INTTHB1815',
  'city_code': 'INT',
  'route_name': '1815',
  'route_name_en': 'Route 1815',
  'pathid': 1,
  'path_name': '往基隆',
  'path_name_en': 'To Keelung',
  'stopid': '0123',
  'stop_name': name,
  'stop_name_en': 'Taipei Main Station',
  'seq': 4,
  'lat': 25.04,
  'lon': 121.51,
};

http.Response rowsResponse(List<Map<String, Object>> rows) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(rows)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

void main() {
  test(
    'combines authorities in one request and preserves bilingual direction and raw stop ID',
    () async {
      var calls = 0;
      final repository = BusRepository(
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/v1/stops/search');
          expect(request.url.queryParameters['cities'], 'InterCity,Taipei');
          expect(request.url.queryParameters['query'], 'Taipei Main Station');
          return rowsResponse([stopRow()]);
        }),
      );
      final results = await repository.searchRoutesByStopFromApi(
        'Taipei Main Station',
        providers: [BusProvider.tpe, BusProvider.inter],
      );
      expect(calls, 1);
      final result = results.single;
      expect(result.route.sourceProvider, 'inter');
      expect(result.route.routeId, 'INTTHB1815');
      expect(result.route.routeNameEn, 'Route 1815');
      expect(result.route.pathNameEn, 'To Keelung');
      expect(result.matchedStop.rawStopId, '0123');
      expect(result.matchedStop.stopId, 123);
      expect(result.matchedStop.pathId, 1);
      expect(result.matchedStop.stopNameEn, 'Taipei Main Station');
    },
  );

  test(
    'nationwide lookup has no scope and empty queries/scopes make no requests',
    () async {
      var calls = 0;
      final repository = BusRepository(
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters.containsKey('cities'), isFalse);
          return rowsResponse([]);
        }),
      );
      expect(await repository.searchRoutesByStopFromApi('  '), isEmpty);
      expect(
        await repository.searchRoutesByStopFromApi('市政府', providers: []),
        isEmpty,
      );
      expect(calls, 0);
      await repository.searchRoutesByStopFromApi('市政府');
      expect(calls, 1);
    },
  );

  test(
    'equivalent queries coalesce and successful empty results are cached',
    () async {
      var calls = 0;
      final response = Completer<http.Response>();
      final repository = BusRepository(
        client: MockClient((_) {
          calls++;
          return response.future;
        }),
      );
      final first = repository.searchRoutesByStopFromApi(
        ' 臺北 ',
        providers: [BusProvider.tpe, BusProvider.inter],
      );
      final second = repository.searchRoutesByStopFromApi(
        '台北',
        providers: [BusProvider.inter, BusProvider.tpe],
      );
      await until(() => calls == 1);
      response.complete(rowsResponse([]));
      expect(await first, isEmpty);
      expect(await second, isEmpty);
      expect(
        await repository.searchRoutesByStopFromApi(
          '台北',
          providers: [BusProvider.tpe, BusProvider.inter],
        ),
        isEmpty,
      );
      expect(calls, 1);
    },
  );

  test('failed and malformed searches stay retryable', () async {
    var calls = 0;
    final repository = BusRepository(
      client: MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('unavailable', 503);
        if (calls == 2) return http.Response('{}', 200);
        return rowsResponse([stopRow()]);
      }),
    );
    await expectLater(
      repository.searchRoutesByStopFromApi('台北'),
      throwsException,
    );
    await expectLater(
      repository.searchRoutesByStopFromApi('台北'),
      throwsA(isA<FormatException>()),
    );
    expect(await repository.searchRoutesByStopFromApi('台北'), hasLength(1));
    expect(calls, 3);
  });

  test(
    'database invalidation cannot be undone by an older search response',
    () async {
      final pending = <Completer<http.Response>>[];
      final repository = BusRepository(
        client: MockClient((_) {
          final response = Completer<http.Response>();
          pending.add(response);
          return response.future;
        }),
      );
      final old = repository.searchRoutesByStopFromApi('台北');
      await until(() => pending.length == 1);
      repository.invalidateRouteData();
      final fresh = repository.searchRoutesByStopFromApi('台北');
      await until(() => pending.length == 2);
      pending[1].complete(rowsResponse([stopRow(name: '台北新站')]));
      await fresh;
      pending[0].complete(rowsResponse([stopRow(name: '台北舊站')]));
      await old;
      expect(
        (await repository.searchRoutesByStopFromApi(
          '台北',
        )).single.matchedStop.stopName,
        '台北新站',
      );
      expect(pending.length, 2);
    },
  );
}
