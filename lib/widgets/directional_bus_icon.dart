import 'package:flutter/material.dart';

class DirectionalBusIcon extends StatelessWidget {
  const DirectionalBusIcon({
    super.key,
    required this.pathId,
    this.icon = Icons.directions_bus_rounded,
    this.size = 24,
    this.color,
  });

  final int? pathId;
  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final directionIcon = switch (pathId) {
      0 => Icons.arrow_forward_rounded,
      1 => Icons.arrow_back_rounded,
      _ => null,
    };
    if (directionIcon == null) {
      return Icon(icon, size: size, color: color);
    }

    return SizedBox.square(
      dimension: size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, size: size, color: color),
          Positioned(
            right: -2,
            bottom: -2,
            child: Icon(directionIcon, size: size * 0.55, color: color),
          ),
        ],
      ),
    );
  }
}
