import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test(
    'route and batch realtime carry structured origin departure data',
    () async {
      final now = DateTime.now();
      final scheduled = now.subtract(const Duration(minutes: 5));
      final rawStop = {
        'stopid': 'STOP1',
        'eta': null,
        'message': '10:00',
        'departure': {
          'scheduled_at': scheduled.millisecondsSinceEpoch ~/ 1000,
          'observed_at': now.millisecondsSinceEpoch ~/ 1000,
          'status': 'not_departed',
          'grace_seconds': 600,
        },
      };
      final snapshot = {
        'paths': [
          {
            'pathid': 0,
            'stops': [rawStop],
          },
        ],
      };
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/stops')) {
          return http.Response(
            jsonEncode({
              'name': '500',
              'paths': [
                {
                  'pathid': 0,
                  'name': 'Outbound',
                  'stops': [
                    {'stopid': 'STOP1', 'name': 'Origin', 'seq': 1},
                  ],
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.contains('/batchroutes/')) {
          return http.Response(
            jsonEncode({
              'routes': {'TXG500': snapshot},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/realtime')) {
          return http.Response(jsonEncode(snapshot), 200);
        }
        return http.Response('not found', 404);
      });
      final repository = BusRepository(client: client);
      final detail = await repository.getCompleteBusInfo(
        500,
        provider: BusProvider.txg,
        routeIdHint: 'TXG500',
        routeNameHint: '500',
      );
      final stop = detail.stopsByPath[0]!.single;
      expect(stop.departure?.overdueMinutes(now), 5);
      expect(
        buildEtaPresentation(stop, alwaysShowSeconds: false, now: now).text,
        '未發車\n5分',
      );
      final batchRepository = BusRepository(client: client);
      final batch = await batchRepository.getBatchLiveStopMaps(['TXG500']);
      expect(batch['TXG500']!.values.single.departure?.overdueMinutes(now), 5);
    },
  );
  test(
    'route detail parsing preserves backfilled eta and bus metadata',
    () async {
      final updatedAt = DateTime.now();
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/api/v1/routes/TXG307/stops')) {
          return http.Response(
            jsonEncode({
              'routeid': 'TXG307',
              'name': '307',
              'paths': [
                {
                  'pathid': 0,
                  'name': 'Outbound',
                  'stops': [
                    {
                      'stopid': 'STOP2',
                      'seq': 2,
                      'name': 'Stop 2',
                      'lat': 24.1006,
                      'lon': 120.6500,
                    },
                    {
                      'stopid': 'STOP3',
                      'seq': 3,
                      'name': 'Stop 3',
                      'lat': 24.1012,
                      'lon': 120.6500,
                    },
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/api/v1/routes/TXG307/realtime')) {
          return http.Response(
            jsonEncode({
              'routeid': 'TXG307',
              'paths': [
                {
                  'pathid': 0,
                  'stops': [
                    {
                      'stopid': 'STOP2',
                      'eta': 0,
                      'message': '',
                      'updated_at': updatedAt.toIso8601String(),
                      'eta_reference_at': updatedAt.toIso8601String(),
                      'buses': [
                        {
                          'id': 'BBB-0002',
                          'type': 'normal',
                          'source': 'backfill_buses',
                        },
                      ],
                      'etas': [
                        {
                          'plate': 'BBB-0002',
                          'eta': 0,
                          'is_arriving': true,
                          'source': 'backfill_buses',
                          'estimated': true,
                        },
                      ],
                    },
                    {
                      'stopid': 'STOP3',
                      'eta': 90,
                      'message': '',
                      'updated_at': updatedAt.toIso8601String(),
                      'eta_reference_at': updatedAt.toIso8601String(),
                      'buses': const [],
                      'etas': [
                        {
                          'plate': 'BBB-0002',
                          'eta': 90,
                          'is_arriving': false,
                          'source': 'backfill_buses',
                          'estimated': true,
                        },
                      ],
                    },
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repository = BusRepository(client: client);
      final detail = await repository.getCompleteBusInfo(
        307,
        provider: BusProvider.txg,
        routeIdHint: 'TXG307',
        routeNameHint: '307',
      );

      final pathStops = detail.stopsByPath[0]!;
      final stop2 = pathStops.firstWhere((stop) => stop.stopName == 'Stop 2');
      final stop3 = pathStops.firstWhere((stop) => stop.stopName == 'Stop 3');

      expect(stop2.buses.single.id, 'BBB-0002');
      expect(stop2.buses.single.source, 'backfill_buses');
      expect(stop2.etas.single.vehicleId, 'BBB-0002');
      expect(stop2.etas.single.source, 'backfill_buses');
      expect(stop2.etas.single.estimated, isTrue);
      expect(
        effectiveStopEtaSecondsForVehicle(stop3, 'BBB-0002', now: updatedAt),
        90,
      );
    },
  );
}
