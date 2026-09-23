import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../app/bus_app.dart';
import '../widgets/app_content_transition.dart';
import '../core/android_home_integration.dart';
import '../core/app_routes.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import '../widgets/eta_badge.dart';
import '../widgets/transit_station_name.dart';

class StationDetailScreen extends StatefulWidget {
  const StationDetailScreen({
    required this.provider,
    required this.stationId,
    this.stationName,
    super.key,
  });

  final BusProvider provider;
  final String stationId;
  final String? stationName;

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  StationPassbyData? _station;
  String? _error;
  bool _loading = true;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _pinStationShortcut() async {
    final station = _station;
    final l10n = AppLocalizations.of(context);
    final didPin = await AndroidHomeIntegration.pinFavoriteShortcut(
      favorite: FavoriteStation(
        provider: widget.provider,
        stationId: widget.stationId,
        stationName:
            station?.stationName ??
            widget.stationName ??
            l10n.stationFallbackTitle,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          didPin ? l10n.stationShortcutRequested : l10n.shortcutUnsupported,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_station == null && _loading) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final station = await AppControllerScope.read(context).repository
          .getStationPassby(widget.stationId, provider: widget.provider);
      if (!mounted) return;
      setState(() {
        _station = station;
        _error = station == null ? l10n.stationNotFound : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = localizedFriendlyError(l10n, error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final station = _station;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: station == null
            ? Text(widget.stationName ?? l10n.stationFallbackTitle)
            : TransitStationName(
                name: station.transitName,
                primaryStyle: Theme.of(context).textTheme.titleLarge,
              ),
        actions: [
          if (_isAndroid)
            IconButton(
              onPressed: () => unawaited(_pinStationShortcut()),
              tooltip: l10n.stationPinTooltip,
              icon: const Icon(Icons.add_to_home_screen_rounded),
            ),
          IconButton(
            onPressed: _loading ? null : () => unawaited(_load()),
            tooltip: l10n.commonRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AppContentTransition(
        state: station != null
            ? 'content'
            : _loading
            ? 'loading'
            : 'error',
        child: _loading && station == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && station == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => unawaited(_load()),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              )
            : _buildStation(station!),
      ),
    );
  }

  Widget _buildStation(StationPassbyData station) {
    final l10n = AppLocalizations.of(context);
    final sides = station.sides;
    if (sides.isEmpty) {
      return Center(child: Text(l10n.stationNoSides));
    }
    return DefaultTabController(
      length: sides.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: sides.length > 3,
              tabs: [
                for (final side in sides)
                  Tab(
                    text: side.direction?.isNotEmpty == true
                        ? l10n.stationSideDirection(side.label, side.direction!)
                        : l10n.stationSideLabel(side.label),
                  ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              children: [for (final side in sides) _buildSide(side)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSide(StationSideData side) {
    final l10n = AppLocalizations.of(context);
    if (side.routes.isEmpty) {
      return Center(child: Text(l10n.stationSideNoRoutes(side.label)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: side.routes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final arrival = side.routes[index];
          final route = arrival.result.route;
          final stop = arrival.result.matchedStop;
          return Card(
            child: ListTile(
              leading: EtaBadge(
                stop: stop,
                alwaysShowSeconds: AppControllerScope.read(
                  context,
                ).settings.alwaysShowSeconds,
              ),
              title: TransitStationName(
                name: route.transitName,
                primaryMaxLines: 1,
                secondaryMaxLines: 1,
              ),
              subtitle: TransitDirectionLabel(
                label:
                    route.description.trim().isNotEmpty ||
                        (route.pathNameEn?.trim().isNotEmpty ?? false)
                    ? localizedRouteDirectionForRoute(
                        l10n,
                        route: route,
                        pathId: stop.pathId,
                      )
                    : (side.direction ?? l10n.stationSideLabel(side.label)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.routeDetailPath(
                  provider: widget.provider,
                  routeKey: route.routeKey,
                  routeId: route.routeId,
                  pathId: stop.pathId,
                  stopId: stop.stopId,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
