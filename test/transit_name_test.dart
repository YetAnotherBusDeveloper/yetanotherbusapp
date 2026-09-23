import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/transit_name.dart';

void main() {
  group('TransitName', () {
    test('forLocale keeps single-language priority for non-UI use', () {
      const name = TransitName(
        zh: '台北車站',
        en: 'Taipei Main Station',
        stableId: 'STOP-1',
      );

      expect(name.forLocale('zh-TW'), '台北車站');
      expect(name.forLocale('en_US'), 'Taipei Main Station');
      expect(
        const TransitName(
          zh: '台北車站',
          en: '  ',
          stableId: 'STOP-1',
        ).forLocale('en'),
        '台北車站',
      );
    });

    test('display shows Chinese only in Chinese interfaces', () {
      const name = TransitName(
        zh: '台北車站',
        en: 'Taipei Main Station',
        stableId: 'STOP-1',
      );

      expect(name.displayForLocale('zh'), '台北車站');
      expect(name.displayForLocale('zh-TW'), '台北車站');
    });

    test('display shows English first and retains Chinese', () {
      const name = TransitName(
        zh: '台北車站',
        en: 'Taipei Main Station',
        stableId: 'STOP-1',
      );

      expect(name.displayForLocale('en_US'), 'Taipei Main Station / 台北車站');
      expect(
        name.displayForLocale('en', separator: '\n'),
        'Taipei Main Station\n台北車站',
      );
      expect(name.displayForLocale('ja'), 'Taipei Main Station / 台北車站');
    });

    test('station display always keeps Chinese first', () {
      const name = TransitName(
        zh: '台北車站',
        en: 'Taipei Main Station',
        stableId: 'STOP-1',
      );

      expect(name.stationDisplayForLocale('zh-TW'), '台北車站');
      expect(name.stationDisplayForLocale('en'), '台北車站\nTaipei Main Station');
      expect(name.foreignSecondaryForLocale('zh-TW'), isNull);
      expect(name.foreignSecondaryForLocale('en'), 'Taipei Main Station');
    });

    test('display falls back cleanly and omits normalized duplicates', () {
      expect(
        const TransitName(
          zh: '台北車站',
          en: '  ',
          stableId: 'STOP-1',
        ).displayForLocale('en'),
        '台北車站',
      );
      expect(
        const TransitName(
          zh: '',
          en: 'Taipei Main Station',
          stableId: 'STOP-1',
        ).displayForLocale('zh-TW'),
        'Taipei Main Station',
      );
      expect(
        const TransitName(
          zh: 'Route  307',
          en: ' route 307 ',
          stableId: 'TPE307',
        ).displayForLocale('en'),
        'route 307',
      );
      expect(
        const TransitName(
          zh: '',
          en: null,
          stableId: 'TPE307',
        ).displayForLocale('en'),
        'TPE307',
      );
    });
  });

  test('transit models parse optional English names without changing IDs', () {
    final route = RouteSummary.fromMap({
      'route_key': 307,
      'route_id': 'TPE307',
      'route_name': '307',
      'official_route_name': 'legacy',
      'route_name_en': 'Route 307',
      'path_name_en': 'To Songshan',
    });
    final path = PathInfo.fromMap({
      'route_key': 307,
      'path_id': 1,
      'path_name': '往松山',
      'path_name_en': 'To Songshan',
    });
    final stop = StopInfo.fromMap({
      'route_key': 307,
      'path_id': 1,
      'stop_id': 42,
      'stop_name': '市政府',
      'stop_name_en': 'City Hall',
    });

    expect(route.routeId, 'TPE307');
    expect(route.routeNameEn, 'Route 307');
    expect(route.pathNameEn, 'To Songshan');
    expect(path.pathId, 1);
    expect(path.nameEn, 'To Songshan');
    expect(stop.stopId, 42);
    expect(stop.stopNameEn, 'City Hall');
  });

  test('station and city-map names retain stable ID fallback', () {
    const station = StationPassbyData(
      provider: BusProvider.tpe,
      stationId: 'TPE-STATION-1',
      stationName: '市政府',
      stationNameEn: 'City Hall',
      lat: 25,
      lon: 121,
      sides: [],
    );
    const bus = CityBus(
      bus: RouteRealtimeBus(
        id: 'BUS-1',
        routeId: 'TPE-EMPTY',
        pathId: 0,
        lat: 25,
        lon: 121,
      ),
      routeUid: 'TPE-UID',
      routeId: 'TPE-EMPTY',
    );
    const snapshot = CityBusSnapshot(
      provider: BusProvider.tpe,
      buses: [bus],
      routes: {},
      families: {},
      ttlSeconds: 15,
    );

    expect(station.transitName.forLocale('zh-TW'), '市政府');
    expect(station.transitName.forLocale('en'), 'City Hall');
    expect(snapshot.transitNameFor(bus).forLocale('en'), 'TPE-EMPTY');
  });
}
