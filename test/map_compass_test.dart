import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taiwanbus_flutter/core/app_motion.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/widgets/bus_map_markers.dart';
import 'package:taiwanbus_flutter/widgets/map_compass.dart';
import 'package:taiwanbus_flutter/widgets/platform_map_provider.dart';

const _center = LatLng(25.0478, 121.5170);

/// A bare flutter_map wired to a compass the way the map screens do it.
class _CompassMap extends StatefulWidget {
  const _CompassMap({this.markers = const []});

  final List<Marker> markers;

  @override
  State<_CompassMap> createState() => _CompassMapState();
}

class _CompassMapState extends State<_CompassMap>
    with TickerProviderStateMixin {
  final MapController controller = MapController();
  late final MapBearing bearing;

  @override
  void initState() {
    super.initState();
    bearing = MapBearing(vsync: this);
  }

  @override
  void dispose() {
    bearing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 15,
            interactionOptions: mapInteractionOptions,
            onMapReady: bearing.resetForNewMap,
            onMapEvent: bearing.followFlutterMap,
          ),
          children: [MarkerLayer(rotate: true, markers: widget.markers)],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: MapCompass(
            bearing: bearing,
            onPressed: () => bearing.turnFlutterMapNorth(
              controller,
              duration: AppMotion.duration(context),
            ),
          ),
        ),
      ],
    );
  }
}

Future<_CompassMapState> _pumpCompassMap(
  WidgetTester tester, {
  List<Marker> markers = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: _CompassMap(markers: markers)),
    ),
  );
  await tester.pump();
  return tester.state<_CompassMapState>(find.byType(_CompassMap));
}

final _compass = find.byTooltip('Turn map to north');

void main() {
  testWidgets('the compass only appears once the map is turned', (
    tester,
  ) async {
    final map = await _pumpCompassMap(tester);
    expect(_compass, findsNothing);
    expect(map.bearing.value, 0);

    // flutter_map turns its content clockwise, so the top of the screen
    // now faces west.
    map.controller.rotate(90);
    await tester.pump();
    expect(map.bearing.value, -90);
    expect(_compass, findsOneWidget);

    // Nudged back to within a hair of north, it hides again.
    map.controller.rotate(0.2);
    await tester.pumpAndSettle();
    expect(_compass, findsNothing);
  });

  testWidgets('tapping the compass turns the map north the short way round', (
    tester,
  ) async {
    final map = await _pumpCompassMap(tester);
    map.controller.rotate(300);
    await tester.pump();
    expect(map.bearing.value, closeTo(60, 1e-9));

    await tester.tap(_compass);
    await tester.pump();
    await tester.pump(AppMotion.standard ~/ 2);
    // 300° is 60° short of north: the turn goes that way, not back through
    // 180°.
    final midway = map.controller.camera.rotation;
    expect(midway, greaterThan(-60));
    expect(midway, lessThan(0));

    await tester.pumpAndSettle();
    expect(map.controller.camera.rotation, 0);
    expect(map.bearing.value, 0);
    expect(_compass, findsNothing);
  });

  testWidgets('a twist on the map takes over from the turn north', (
    tester,
  ) async {
    final map = await _pumpCompassMap(tester);
    map.controller.rotate(90);
    await tester.pump();
    await tester.tap(_compass);
    await tester.pump();
    await tester.pump(AppMotion.standard ~/ 2);

    map.bearing.followFlutterMap(
      MapEventRotateStart(
        camera: map.controller.camera,
        source: MapEventSource.onMultiFinger,
      ),
    );
    final heldAt = map.controller.camera.rotation;
    await tester.pump(AppMotion.standard);
    expect(map.controller.camera.rotation, heldAt);
  });

  testWidgets('bus heading follows the street on a turned map', (tester) async {
    final map = await _pumpCompassMap(
      tester,
      markers: [
        Marker(
          point: _center,
          width: 64,
          height: 64,
          child: const BusMapBusMarker(
            color: Colors.blue,
            selected: true,
            label: 'test bus',
            heading: 0,
          ),
        ),
      ],
    );
    // North now points right on screen, so a northbound bus points right.
    map.controller.rotate(90);
    await tester.pump();

    final busIcon = find.byIcon(Icons.directions_bus_rounded);
    final busCenter = tester.getCenter(busIcon);
    final arrowCenter = tester.getCenter(find.byIcon(Icons.navigation_rounded));
    expect(arrowCenter.dx, greaterThan(busCenter.dx + 20));
    expect((arrowCenter.dy - busCenter.dy).abs(), lessThan(1));

    // The badge itself stays upright.
    final topLeft = tester.getTopLeft(busIcon);
    final bottomRight = tester.getBottomRight(busIcon);
    expect(topLeft.dx, lessThan(bottomRight.dx));
    expect(topLeft.dy, lessThan(bottomRight.dy));
  });

  testWidgets('a fresh map starts north-up whatever the last one did', (
    tester,
  ) async {
    final map = await _pumpCompassMap(tester);
    map.controller.rotate(45);
    await tester.pump();
    expect(_compass, findsOneWidget);

    map.bearing.resetForNewMap();
    await tester.pumpAndSettle();
    expect(_compass, findsNothing);
  });
}
