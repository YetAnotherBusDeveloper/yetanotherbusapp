import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../core/app_motion.dart';
import '../l10n/app_localizations.dart';

/// Which way a map faces, shared between the map and its [MapCompass].
///
/// [value] is the compass direction the top of the map faces, in degrees
/// clockwise from north, folded into `(-180, 180]`. Feed it camera updates
/// from whichever backend is showing; it then knows how to turn that backend
/// north-up again.
class MapBearing extends ValueNotifier<double> {
  MapBearing({required TickerProvider vsync}) : super(0) {
    _northTurn = AnimationController(vsync: vsync)
      ..addListener(_stepFlutterMapNorth);
  }

  late final AnimationController _northTurn;
  MapController? _turningMap;
  double _turnStartRotation = 0;
  gmaps.CameraPosition? _googleCamera;

  /// Follows a flutter_map camera; call from [MapOptions.onMapEvent].
  void followFlutterMap(MapEvent event) {
    // A twist on the map takes over from a turn that is still running.
    if (event is MapEventRotateStart) {
      _northTurn.stop();
    }
    // flutter_map turns its content clockwise, so the bearing runs the
    // other way.
    value = _signedDegrees(-event.camera.rotation);
  }

  /// Follows a Google Maps camera; call from `GoogleMap.onCameraMove`.
  void followGoogleMap(gmaps.CameraPosition position) {
    _googleCamera = position;
    value = _signedDegrees(position.bearing);
  }

  /// Starts over for a freshly created map, which always opens north-up.
  void resetForNewMap() {
    _northTurn.stop();
    _turningMap = null;
    _googleCamera = null;
    value = 0;
  }

  /// Turns a flutter_map back to north-up, the shorter way round.
  ///
  /// flutter_map has no animated rotate, so this steps the turn itself the
  /// way Google's `animateCamera` would.
  void turnFlutterMapNorth(
    MapController controller, {
    required Duration duration,
  }) {
    final double rotation;
    try {
      rotation = controller.camera.rotation;
    } catch (_) {
      // The map has not been laid out yet, so it is still north-up.
      return;
    }
    _turningMap = controller;
    _turnStartRotation = _signedDegrees(rotation);
    _northTurn
      ..duration = duration
      ..forward(from: 0);
  }

  void _stepFlutterMapNorth() {
    final map = _turningMap;
    if (map == null) {
      return;
    }
    final progress = AppMotion.curve.transform(_northTurn.value);
    try {
      map.rotate(lerpDouble(_turnStartRotation, 0, progress)!);
    } catch (_) {
      // The map went away mid-turn.
      _northTurn.stop();
    }
  }

  /// Turns Google Maps back to north-up without moving, zooming or tilting.
  ///
  /// Null until the camera has reported a position, which it always has by
  /// the time anyone turned it.
  gmaps.CameraUpdate? get googleNorthUp {
    final camera = _googleCamera;
    if (camera == null) {
      return null;
    }
    return gmaps.CameraUpdate.newCameraPosition(
      gmaps.CameraPosition(
        target: camera.target,
        zoom: camera.zoom,
        tilt: camera.tilt,
      ),
    );
  }

  @override
  void dispose() {
    _northTurn.dispose();
    super.dispose();
  }
}

/// [degrees] folded into `(-180, 180]`, so its sign says which way round is
/// shorter.
double _signedDegrees(double degrees) {
  if (!degrees.isFinite) {
    return 0;
  }
  final folded = degrees % 360;
  return folded > 180 ? folded - 360 : folded;
}

/// A compass for the corner of a map: the needle points north, and tapping
/// it turns the map back to north-up.
///
/// It only appears once the map has been turned, and takes no room until
/// then, so a map nobody rotated looks exactly as it did before rotation was
/// allowed.
class MapCompass extends StatelessWidget {
  const MapCompass({
    required this.bearing,
    required this.onPressed,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// As kept by [MapBearing].
  final ValueListenable<double> bearing;
  final VoidCallback onPressed;

  /// Space around the compass while it shows; none is taken while hidden.
  final EdgeInsetsGeometry padding;

  /// Turns smaller than this read as north-up. Hiding the compass for them
  /// keeps a stray half-degree from leaving it on screen for good.
  static const double northTolerance = 0.5;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: bearing,
      builder: (context, bearing, _) => AnimatedSwitcher(
        duration: AppMotion.duration(context, AppMotion.quick),
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.curve,
        child: bearing.abs() < northTolerance
            ? const SizedBox.shrink()
            : Padding(
                key: const ValueKey('map-compass'),
                padding: padding,
                child: _CompassButton(bearing: bearing, onPressed: onPressed),
              ),
      ),
    );
  }
}

class _CompassButton extends StatelessWidget {
  const _CompassButton({required this.bearing, required this.onPressed});

  final double bearing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: Tooltip(
        message: AppLocalizations.of(context).mapCompassResetNorth,
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.94),
          elevation: 2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 40,
              child: Transform.rotate(
                // North sits opposite the way the map faces.
                angle: -bearing * math.pi / 180,
                child: CustomPaint(
                  painter: _CompassNeedlePainter(
                    south: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  const _CompassNeedlePainter({required this.south});

  static const Color _north = Color(0xFFE53935);

  final Color south;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final length = size.shortestSide * 0.34;
    final halfWidth = size.shortestSide * 0.12;
    Path half(double tipY) => Path()
      ..moveTo(center.dx, tipY)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..close();

    canvas.drawPath(half(center.dy - length), Paint()..color = _north);
    canvas.drawPath(half(center.dy + length), Paint()..color = south);
  }

  @override
  bool shouldRepaint(_CompassNeedlePainter oldDelegate) =>
      oldDelegate.south != south;
}
