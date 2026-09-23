import 'package:flutter/material.dart';

/// Which top-level transit mode is active.
enum TransitMode { bus, metro, thsr, tra, youbike }

class TransitModeDestination {
  const TransitModeDestination({required this.mode, required this.icon});

  final TransitMode mode;
  final IconData icon;
}

const kTransitModeDestinations = <TransitModeDestination>[
  TransitModeDestination(
    mode: TransitMode.bus,
    icon: Icons.directions_bus_rounded,
  ),
  TransitModeDestination(mode: TransitMode.metro, icon: Icons.subway_rounded),
  TransitModeDestination(mode: TransitMode.thsr, icon: Icons.train_rounded),
  TransitModeDestination(mode: TransitMode.tra, icon: Icons.tram_rounded),
  TransitModeDestination(
    mode: TransitMode.youbike,
    icon: Icons.pedal_bike_rounded,
  ),
];

/// Minimum screen width to show the persistent desktop navigation rail.
const double kDesktopNavigationRailBreakpoint = 1100;
