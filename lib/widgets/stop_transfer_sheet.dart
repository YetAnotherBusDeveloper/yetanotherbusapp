import 'dart:async';

import 'package:flutter/material.dart';

import 'directional_bus_icon.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import '../core/route_direction_label.dart';
import '../core/transit_name.dart';
import '../core/transit_repository.dart';
import '../core/transfer_options.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import 'transit_station_name.dart';

class StopTransferSheet extends StatefulWidget {
  const StopTransferSheet({
    required this.controller,
    required this.provider,
    required this.currentRouteId,
    required this.stop,
    super.key,
  });

  final AppController controller;
  final BusProvider provider;
  final String currentRouteId;
  final StopInfo stop;

  @override
  State<StopTransferSheet> createState() => _StopTransferSheetState();
}

class _StopTransferSheetState extends State<StopTransferSheet> {
  List<NearbyTransferStopGroup> _busGroups = const [];
  List<BikeStation> _bikeStations = const [];
  bool _missingCoordinates = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final stop = widget.stop;
    if (stop.lat == 0 && stop.lon == 0) {
      setState(() {
        _loading = false;
        _missingCoordinates = true;
      });
      return;
    }

    try {
      final nearby = await widget.controller.getNearbyStops(
        provider: widget.provider,
        latitude: stop.lat,
        longitude: stop.lon,
        radiusMeters: 250,
        limit: 80,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busGroups = groupNearbyTransferStops(
          nearby
              .where((result) => result.route.routeId != widget.currentRouteId)
              .toList(growable: false),
        );
      });
    } catch (_) {
      // The sheet can still show bike transfers when a city database is absent.
    }

    try {
      final bikes = await TransitRepository.shared.getBikeNearby(
        lat: stop.lat,
        lon: stop.lon,
        radius: 300,
      );
      if (!mounted) {
        return;
      }
      setState(() => _bikeStations = bikes);
    } catch (_) {
      // YouBike is optional for this view.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (_missingCoordinates) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.transferMissingCoordinates),
            ),
          );
        }
        if (_busGroups.isEmpty && _bikeStations.isEmpty) {
          return Center(child: Text(l10n.transferEmpty));
        }
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(l10n.transferTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              l10n.transferWalkingRanges(
                widget.stop.transitName.stationDisplayForLocale(
                  locale,
                  separator: '\n',
                ),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_busGroups.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(l10n.transitBus, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final group in _busGroups)
                Card(
                  child: ExpansionTile(
                    title: TransitStationName(
                      name: group.routes.first.stop.transitName,
                    ),
                    subtitle: Text(
                      l10n.transferRouteCount(
                        localizedDistance(l10n, group.distanceMeters),
                        group.routes.length,
                      ),
                    ),
                    children: [
                      for (final row in labelNearbyRouteDirections(
                        group.routes,
                        locale: locale,
                      ))
                        ListTile(
                          leading: DirectionalBusIcon(
                            pathId: row.result.stop.pathId,
                          ),
                          title: Text(
                            row.result.route.transitName.displayForLocale(
                              locale,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: TransitDirectionLabel(
                            label: row.directionLabel,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).pop(row.result),
                        ),
                    ],
                  ),
                ),
            ],
            if (_bikeStations.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(l10n.transitYouBike, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final station in _bikeStations)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.pedal_bike_rounded),
                    title: TransitStationName(
                      name: TransitName(
                        zh: station.name,
                        en: station.nameEn,
                        stableId: station.stationUid.trim().isEmpty
                            ? station.stationId
                            : station.stationUid,
                      ),
                    ),
                    subtitle: Text(
                      station.distanceMeters == null
                          ? l10n.transferBikeAvailability(
                              station.availableRent,
                              station.availableReturn,
                            )
                          : l10n.transferBikeAvailabilityDistance(
                              localizedDistance(
                                l10n,
                                station.distanceMeters!.toDouble(),
                              ),
                              station.availableRent,
                              station.availableReturn,
                            ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
