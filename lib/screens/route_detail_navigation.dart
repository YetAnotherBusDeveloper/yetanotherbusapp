import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'route_detail_screen.dart';

Route<void> buildRouteDetailRoute({
  required int routeKey,
  required BusProvider provider,
  String? routeIdHint,
  String? routeNameHint,
  int? initialPathId,
  int? initialStopId,
  int? initialDestinationPathId,
  int? initialDestinationStopId,
  Future<RouteDetailData?>? initialTopologyFuture,
  Future<List<RouteAlert>>? initialAlertsFuture,
  Future<List<CancelledDeparture>>? initialCancelledDeparturesFuture,
  bool suppressAutoDestinationSelection = false,
  bool updateSearchHistoryOnDestinationChange = false,
}) {
  return MaterialPageRoute<void>(
    settings: RouteSettings(
      name: AppRoutes.routeDetailPath(
        provider: provider,
        routeKey: routeKey,
        routeId: routeIdHint,
        pathId: initialPathId,
        stopId: initialStopId,
        destinationPathId: initialDestinationPathId,
        destinationStopId: initialDestinationStopId,
      ),
    ),
    builder: (_) => RouteDetailScreen(
      routeKey: routeKey,
      provider: provider,
      routeIdHint: routeIdHint,
      routeNameHint: routeNameHint,
      initialPathId: initialPathId,
      initialStopId: initialStopId,
      initialDestinationPathId: initialDestinationPathId,
      initialDestinationStopId: initialDestinationStopId,
      initialTopologyFuture: initialTopologyFuture,
      initialAlertsFuture: initialAlertsFuture,
      initialCancelledDeparturesFuture: initialCancelledDeparturesFuture,
      suppressAutoDestinationSelection: suppressAutoDestinationSelection,
      updateSearchHistoryOnDestinationChange:
          updateSearchHistoryOnDestinationChange,
    ),
  );
}

/// Shows a one-off notice when [recordRouteSelection] auto-adds a
/// frequently-visited stop into the "常用" favorites group.
void showAutoFavoritedSnackBar(BuildContext context, FavoriteStop favorite) {
  final l10n = AppLocalizations.of(context);
  final label = favorite.stopName?.trim().isNotEmpty == true
      ? favorite.stopName!.trim()
      : favorite.routeName?.trim().isNotEmpty == true
      ? favorite.routeName!.trim()
      : l10n.autoFavoriteFallback;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.autoFavoriteAdded(label))));
}

Future<void> openRouteDetailPage(
  BuildContext context, {
  required int routeKey,
  required BusProvider provider,
  String? routeIdHint,
  String? routeNameHint,
  int? initialPathId,
  int? initialStopId,
  int? initialDestinationPathId,
  int? initialDestinationStopId,
  Future<RouteDetailData?>? initialTopologyFuture,
  Future<List<RouteAlert>>? initialAlertsFuture,
  Future<List<CancelledDeparture>>? initialCancelledDeparturesFuture,
  bool suppressAutoDestinationSelection = false,
  bool updateSearchHistoryOnDestinationChange = false,
}) {
  return Navigator.of(context).push(
    buildRouteDetailRoute(
      routeKey: routeKey,
      provider: provider,
      routeIdHint: routeIdHint,
      routeNameHint: routeNameHint,
      initialPathId: initialPathId,
      initialStopId: initialStopId,
      initialDestinationPathId: initialDestinationPathId,
      initialDestinationStopId: initialDestinationStopId,
      initialTopologyFuture: initialTopologyFuture,
      initialAlertsFuture: initialAlertsFuture,
      initialCancelledDeparturesFuture: initialCancelledDeparturesFuture,
      suppressAutoDestinationSelection: suppressAutoDestinationSelection,
      updateSearchHistoryOnDestinationChange:
          updateSearchHistoryOnDestinationChange,
    ),
  );
}
