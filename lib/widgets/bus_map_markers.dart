import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MapCamera;

import '../core/app_motion.dart';
import '../l10n/app_localizations.dart';

/// Bus and user-location markers shared by the route sheet and the city map.
///
/// Google Maps takes bitmaps rather than widgets, so every marker exists twice:
/// as a Flutter widget for `flutter_map`, and as a rasterised PNG for the
/// platform view. Lifted verbatim from `route_bus_map_sheet.dart`.

/// Black or white, whichever reads better on a bus badge of [color].
Color _busMarkerForeground(Color color) =>
    color.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;

class BusMapBusMarker extends StatelessWidget {
  const BusMapBusMarker({
    super.key,
    required this.color,
    required this.selected,
    required this.label,
    this.heading = 0,
  });

  final Color color;
  final bool selected;
  final String label;
  final double heading;

  @override
  Widget build(BuildContext context) {
    final foreground = _busMarkerForeground(color);
    final markerSize = selected ? 64.0 : 56.0;
    final circleSize = selected ? 40.0 : 34.0;
    return Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: markerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.quick),
              curve: AppMotion.curve,
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: selected ? 3 : 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.directions_bus_rounded,
                color: foreground,
                size: 22,
              ),
            ),
            BusMapHeadingIndicator(
              heading: heading,
              color: foreground,
              size: selected ? 11 : 10,
              orbitDiameter: markerSize,
            ),
          ],
        ),
      ),
    );
  }
}

class BusMapHeadingIndicator extends StatelessWidget {
  const BusMapHeadingIndicator({
    super.key,
    required this.heading,
    required this.color,
    required this.size,
    required this.orbitDiameter,
  });

  final double heading;
  final Color color;
  final double size;
  final double orbitDiameter;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: orbitDiameter,
      child: _MapAlignedRotation(
        heading: heading,
        child: Align(
          alignment: Alignment.topCenter,
          child: Icon(Icons.navigation_rounded, color: color, size: size),
        ),
      ),
    );
  }
}

/// Turns [child] to [heading], counted from north on the map underneath.
///
/// Markers are kept upright on a rotated flutter_map, so a bare heading would
/// point along the screen rather than the street. Only this transform reads
/// the camera, which keeps the rebuild on every camera frame to one widget.
class _MapAlignedRotation extends StatelessWidget {
  const _MapAlignedRotation({required this.heading, required this.child});

  final double heading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // flutter_map turns its content clockwise by `rotation`; outside a map
    // there is nothing to follow.
    final mapRotation = MapCamera.maybeOf(context)?.rotation ?? 0;
    return Transform.rotate(
      angle: normalizeMarkerHeading(heading + mapRotation) * math.pi / 180,
      child: child,
    );
  }
}

double normalizeMarkerHeading(double heading) {
  if (!heading.isFinite) {
    return 0;
  }
  final normalized = heading % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

class BusMapUserLocationMarker extends StatelessWidget {
  const BusMapUserLocationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).busMapYourLocation,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E88E5),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bitmap for a Google Maps bus marker.
///
/// Google Maps can turn a flat marker with the map but cannot keep part of a
/// bitmap upright, so each bus is two markers sharing one anchor: an upright
/// badge, and a flat [headingPointer] the map itself keeps pointed along the
/// street via `Marker.rotation`.
class GoogleBusIconRequest {
  const GoogleBusIconRequest({
    required this.key,
    required this.color,
    required this.selected,
    required this.pixelRatio,
    this.headingPointer = false,
  });

  final String key;
  final Color color;
  final bool selected;
  final double pixelRatio;

  /// Draws only the heading pointer, aimed north, instead of the badge.
  final bool headingPointer;

  double get logicalSize => selected ? 64 : 56;

  double get radius => selected ? 20 : 17;

  double get borderWidth => selected ? 3 : 2;

  double get iconSize => selected ? 24 : 20;
}

class GoogleUserLocationIconRequest {
  const GoogleUserLocationIconRequest({required this.pixelRatio});

  static const double baseLogicalSize = 24;

  final double pixelRatio;

  double get logicalSize => baseLogicalSize;

  double get outerRadius => 10;

  double get innerRadius => 7.2;
}

String googleBusIconKey({
  required Color color,
  required bool selected,
  required double pixelRatio,
}) {
  return [
    color.toARGB32().toRadixString(16),
    selected ? 'selected' : 'normal',
    pixelRatio.toStringAsFixed(2),
  ].join('|');
}

/// The pointer is drawn in the badge's foreground, so buses of every dark
/// colour share one bitmap, and every light colour another.
String googleBusHeadingIconKey({
  required Color color,
  required bool selected,
  required double pixelRatio,
}) {
  return [
    'heading',
    _busMarkerForeground(color).toARGB32().toRadixString(16),
    selected ? 'selected' : 'normal',
    pixelRatio.toStringAsFixed(2),
  ].join('|');
}

/// Identifies reusable stationary markers for one rendered map state.
String staticBusMarkerCacheKey({
  required Iterable<String> visibleBusIds,
  required int dataGeneration,
  required String viewportKey,
  required double zoom,
  required String filterKey,
  required String selectionKey,
  required String locale,
}) {
  final identities = visibleBusIds.toList()..sort();
  final encodedIdentities = identities
      .map((identity) => '${identity.length}:$identity')
      .join();
  return [
    dataGeneration,
    viewportKey,
    zoom.toStringAsFixed(2),
    filterKey,
    selectionKey,
    locale,
    encodedIdentities,
  ].join('|');
}

Future<Uint8List> drawGoogleBusIcon(GoogleBusIconRequest request) async {
  final pixelSize = (request.logicalSize * request.pixelRatio).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..scale(request.pixelRatio, request.pixelRatio);
  final center = ui.Offset(request.logicalSize / 2, request.logicalSize / 2);
  final foreground = _busMarkerForeground(request.color);

  if (request.headingPointer) {
    // Same canvas as the badge, so the pointer orbits it from the shared
    // anchor at the centre.
    final pointerBaseY = center.dy - request.radius - 1;
    final pointer = ui.Path()
      ..moveTo(center.dx, pointerBaseY - 9)
      ..lineTo(center.dx + 5, pointerBaseY)
      ..lineTo(center.dx, pointerBaseY - 2)
      ..lineTo(center.dx - 5, pointerBaseY)
      ..close();
    canvas.drawPath(
      pointer,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeJoin = ui.StrokeJoin.round
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
    canvas.drawPath(pointer, ui.Paint()..color = foreground);
    return _encodeGoogleIcon(recorder, pixelSize);
  }

  canvas.drawCircle(
    center.translate(0, 1.5),
    request.radius,
    ui.Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
  );
  canvas.drawCircle(center, request.radius, ui.Paint()..color = request.color);
  canvas.drawCircle(
    center,
    request.radius,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = request.borderWidth
      ..color = Colors.white,
  );

  final busIconPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.directions_bus_rounded.codePoint),
      style: TextStyle(
        fontFamily: Icons.directions_bus_rounded.fontFamily,
        package: Icons.directions_bus_rounded.fontPackage,
        fontSize: request.iconSize,
        color: foreground,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  busIconPainter.paint(
    canvas,
    center - ui.Offset(busIconPainter.width / 2, busIconPainter.height / 2),
  );

  return _encodeGoogleIcon(recorder, pixelSize);
}

Future<Uint8List> _encodeGoogleIcon(
  ui.PictureRecorder recorder,
  int pixelSize,
) async {
  final picture = recorder.endRecording();
  final image = await picture.toImage(pixelSize, pixelSize);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return byteData!.buffer.asUint8List();
}

Future<Uint8List> drawGoogleUserLocationIcon(double pixelRatio) async {
  final request = GoogleUserLocationIconRequest(pixelRatio: pixelRatio);
  final pixelSize = (request.logicalSize * pixelRatio).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(pixelRatio, pixelRatio);
  final center = ui.Offset(request.logicalSize / 2, request.logicalSize / 2);

  canvas.drawCircle(
    center,
    request.outerRadius,
    ui.Paint()..color = const Color(0x331E88E5),
  );
  canvas.drawCircle(
    center.translate(0, 1.5),
    request.innerRadius,
    ui.Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
  );
  canvas.drawCircle(
    center,
    request.innerRadius,
    ui.Paint()..color = const Color(0xFF1E88E5),
  );
  canvas.drawCircle(
    center,
    request.innerRadius,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(pixelSize, pixelSize);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return byteData!.buffer.asUint8List();
}

/// A count bubble standing in for several buses at low zoom.
class BusMapClusterMarker extends StatelessWidget {
  const BusMapClusterMarker({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).busMapClusterSemantics(count),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.surface, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          clusterCountLabel(count),
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Keeps the bubble readable, and the Google bitmap cache bounded.
String clusterCountLabel(int count) => count > 99 ? '99+' : '$count';

/// How wide a cluster bubble is for a given count.
double clusterMarkerSize(int count) {
  if (count >= 50) {
    return 52;
  }
  if (count >= 10) {
    return 44;
  }
  return 36;
}

String googleClusterIconKey({required int count, required double pixelRatio}) {
  return [clusterCountLabel(count), pixelRatio.toStringAsFixed(2)].join('|');
}

/// The same bubble, rasterised for the Google Maps platform view.
Future<Uint8List> drawGoogleClusterIcon({
  required int count,
  required double pixelRatio,
  required Color background,
  required Color foreground,
  required Color border,
}) async {
  final logicalSize = clusterMarkerSize(count);
  final pixelSize = (logicalSize * pixelRatio).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(pixelRatio, pixelRatio);
  final center = ui.Offset(logicalSize / 2, logicalSize / 2);
  final radius = logicalSize / 2 - 2;

  canvas.drawCircle(
    center.translate(0, 1.5),
    radius,
    ui.Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
  );
  canvas.drawCircle(center, radius, ui.Paint()..color = background);
  canvas.drawCircle(
    center,
    radius,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = border,
  );

  final painter = TextPainter(
    text: TextSpan(
      text: clusterCountLabel(count),
      style: TextStyle(
        color: foreground,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    center - ui.Offset(painter.width / 2, painter.height / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(pixelSize, pixelSize);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return byteData!.buffer.asUint8List();
}
