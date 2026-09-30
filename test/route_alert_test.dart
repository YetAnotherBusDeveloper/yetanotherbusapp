import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';

void main() {
  test('parses alert impact and official source metadata', () {
    final alert = RouteAlert.fromJson({
      'alert_id': 'alert-1',
      'title': 'Road work',
      'description': 'The route is detoured.',
      'status': 2,
      'cause': 4,
      'effect': 1,
      'scope': ['Stop A', 'Stop B'],
      'start_time': 1790000000,
      'end_time': 1790003600,
      'source': {'name': 'TDX', 'url': 'https://tdx.transportdata.tw/'},
    });

    expect(alert.scope, 'Stop A、Stop B');
    expect(alert.source, 'TDX');
    expect(alert.sourceUrl, 'https://tdx.transportdata.tw/');
    expect(alert.effectText, '車輛改道/站牌不停靠');
    expect(alert.causeText, '施工');
    expect(alert.isNegative, isTrue);
  });

  test('fetches route alerts from the encoded route endpoint and caches them',
      () async {
    var requests = 0;
    Uri? requestUri;
    final repository = BusRepository(
      client: MockClient((request) async {
        requests++;
        requestUri = request.url;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'routeid': 'TPE/123',
              'alerts': [
                {
                  'alert_id': 'alert-1',
                  'title': 'Delay',
                  'description': '',
                  'status': 2,
                  'effect': 7,
                },
              ],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final first = await repository.fetchRouteAlerts('TPE/123');
    final second = await repository.fetchRouteAlerts('TPE/123');

    expect(requests, 1);
    expect(requestUri?.pathSegments.last, 'TPE/123');
    expect(first.single.alertId, 'alert-1');
    expect(second.single.effectText, '重大延遲');

    repository.invalidateRouteData();
    await repository.fetchRouteAlerts('TPE/123');
    expect(requests, 2);
  });
}
