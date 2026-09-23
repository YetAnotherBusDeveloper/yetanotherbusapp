import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/ad_banner_widget.dart';
import '../app/bus_app.dart';
import '../core/app_controller.dart';
import '../core/app_routes.dart';
import '../core/haptic_feedback_service.dart';
import '../core/app_route_observer.dart';
import '../core/bus_repository.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import '../widgets/eta_badge.dart';
import 'favorite_groups_screen.dart';
import '../widgets/background_image_wrapper.dart';
import '../widgets/cat_state_card.dart';
import '../widgets/app_content_transition.dart';
import 'route_detail_navigation.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({this.initialGroupName, super.key});

  final String? initialGroupName;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin, RouteAware {
  TabController? _tabController;
  Timer? _countdownTimer;
  late final AnimationController _countdownProgressController;
  ModalRoute<dynamic>? _route;
  List<FavoriteResolvedItem> _items = const [];
  Map<String, StationPassbyData> _stationDataByKey = const {};
  bool _isLoading = false;
  bool _isRouteVisible = true;
  String? _error;
  String? _statusMessage;
  String? _loadedGroupName;
  String _loadedSignature = '';
  String? _refreshingGroupName;
  String _refreshingSignature = '';
  bool _refreshScheduled = false;
  bool _forceResolveStaticOnResume = false;
  bool _sortMode = false;
  int _refreshRequestId = 0;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _countdownProgressController = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route == route) {
      return;
    }
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    _route = route;
    if (route != null) {
      appRouteObserver.subscribe(this, route);
      _isRouteVisible = route.isCurrent;
    } else {
      _isRouteVisible = true;
    }
  }

  @override
  void dispose() {
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    _countdownTimer?.cancel();
    _countdownProgressController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _syncTabController(List<String> groups) {
    if (groups.isEmpty) {
      _tabController?.dispose();
      _tabController = null;
      _countdownTimer?.cancel();
      _countdownProgressController
        ..stop()
        ..value = 0;
      _items = const [];
      _stationDataByKey = const {};
      _isLoading = false;
      _error = null;
      _statusMessage = null;
      _loadedGroupName = null;
      _loadedSignature = '';
      _refreshingGroupName = null;
      _refreshingSignature = '';
      return;
    }

    final initialIndex = _tabController == null
        ? _resolveInitialGroupIndex(groups)
        : _tabController!.index.clamp(0, groups.length - 1);
    if (_tabController?.length == groups.length) {
      if (_tabController!.index != initialIndex) {
        _tabController!.index = initialIndex;
      }
      return;
    }

    _tabController?.dispose();
    _tabController = TabController(
      length: groups.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) {
        return;
      }
      setState(() {});
      _scheduleRefresh(forceResolveStatic: true);
    });
  }

  int _resolveInitialGroupIndex(List<String> groups) {
    final initialGroupName = widget.initialGroupName;
    if (initialGroupName == null) {
      return 0;
    }
    final index = groups.indexOf(initialGroupName);
    return index == -1 ? 0 : index;
  }

  String? _currentGroupName(List<String> groups) {
    if (groups.isEmpty) {
      return null;
    }
    final index = (_tabController?.index ?? 0).clamp(0, groups.length - 1);
    return groups[index];
  }

  /// Signature of a group's *contents*, deliberately insensitive to order so
  /// that reordering favorites does not trigger a full re-resolve.
  String _favoritesSignature(List<FavoriteItem> favorites) {
    final encoded =
        favorites.map((favorite) => jsonEncode(favorite.toJson())).toList()
          ..sort();
    return encoded.join('|');
  }

  String _favoriteItemKey(FavoriteStop favorite) {
    return '${favorite.provider.name}:${favorite.routeKey}:${favorite.pathId}:${favorite.stopId}';
  }

  String _routeRequestKey(FavoriteStop favorite) {
    return '${favorite.provider.name}:${favorite.routeKey}';
  }

  void _scheduleRefresh({bool forceResolveStatic = false}) {
    if (!_isRouteVisible) {
      _forceResolveStaticOnResume =
          _forceResolveStaticOnResume || forceResolveStatic;
      return;
    }
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      unawaited(_refreshCurrentGroup(forceResolveStatic: forceResolveStatic));
    });
  }

  void _scheduleRefreshIfNeeded(AppController controller, List<String> groups) {
    final groupName = _currentGroupName(groups);
    if (groupName == null) {
      return;
    }

    final signature = _favoritesSignature(
      controller.favoritesInGroup(groupName),
    );
    if (_isLoading &&
        groupName == _refreshingGroupName &&
        signature == _refreshingSignature) {
      return;
    }
    if (groupName != _loadedGroupName || signature != _loadedSignature) {
      _scheduleRefresh(forceResolveStatic: true);
    }
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    _remainingSeconds = seconds;
    _countdownProgressController
      ..stop()
      ..duration = Duration(seconds: seconds <= 0 ? 1 : seconds)
      ..value = 0;
    if (!_isRouteVisible) {
      return;
    }
    if (seconds > 0) {
      unawaited(_countdownProgressController.forward(from: 0));
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 0) {
        timer.cancel();
        unawaited(_refreshCurrentGroup());
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  Widget _buildBottomProgressIndicator() {
    return AppContentTransition(
      state: _isLoading,
      child: _isLoading
          ? const LinearProgressIndicator(minHeight: 4)
          : AnimatedBuilder(
              animation: _countdownProgressController,
              builder: (context, child) => LinearProgressIndicator(
                value: _countdownProgressController.value,
                minHeight: 4,
              ),
            ),
    );
  }

  Future<void> _refreshCurrentGroup({bool forceResolveStatic = false}) async {
    if (!_isRouteVisible) {
      _forceResolveStaticOnResume =
          _forceResolveStaticOnResume || forceResolveStatic;
      return;
    }
    final controller = AppControllerScope.read(context);
    final l10n = AppLocalizations.of(context);
    final groups = controller.favoriteGroupNames;
    final groupName = _currentGroupName(groups);
    if (groupName == null) {
      return;
    }

    final references = controller.favoritesInGroup(groupName);
    final signature = _favoritesSignature(references);
    final shouldResolveStatic =
        forceResolveStatic ||
        groupName != _loadedGroupName ||
        signature != _loadedSignature;
    final previousItemsByKey = <String, FavoriteResolvedItem>{
      for (final item in _items) _favoriteItemKey(item.reference): item,
    };
    final requestId = ++_refreshRequestId;

    setState(() {
      _isLoading = true;
      _error = null;
      _refreshingGroupName = groupName;
      _refreshingSignature = signature;
      _statusMessage = l10n.favoritesUpdating;
    });

    try {
      final stationEntriesFuture = Future.wait(
        references.whereType<FavoriteStation>().map((favorite) async {
          try {
            final station = await controller.repository.getStationPassby(
              favorite.stationId,
              provider: favorite.provider,
            );
            return MapEntry(favorite.stableKey, station);
          } catch (_) {
            return MapEntry<String, StationPassbyData?>(
              favorite.stableKey,
              null,
            );
          }
        }),
      );
      unawaited(
        stationEntriesFuture.then<void>((stationEntries) {
          if (!mounted || requestId != _refreshRequestId) {
            return;
          }
          setState(() {
            _stationDataByKey = _resolvedStationData(stationEntries);
          });
        }),
      );

      final baseItems = shouldResolveStatic
          ? await controller.resolveFavoriteGroup(groupName)
          : _items;

      if (!mounted || requestId != _refreshRequestId) {
        return;
      }

      final uniqueRoutes = <String, FavoriteStop>{};
      final routeSummariesByKey = <String, RouteSummary>{};
      for (final item in baseItems) {
        final routeRequestKey = _routeRequestKey(item.reference);
        uniqueRoutes.putIfAbsent(routeRequestKey, () => item.reference);
        routeSummariesByKey.putIfAbsent(routeRequestKey, () => item.route);
      }

      // --- Batch realtime fetch to avoid 429 ---
      // Collect unique route IDs and fetch all realtime data in a single
      // batch request.  The batch API accepts up to 25 route IDs which
      // matches the account-sync favourite limit.
      final routeIdByRequestKey = <String, String>{};
      for (final entry in uniqueRoutes.entries) {
        final routeId = entry.value.routeId?.trim();
        final routeSummary = routeSummariesByKey[entry.key];
        final effectiveRouteId =
            (routeId?.isNotEmpty == true ? routeId : null) ??
            routeSummary?.routeId;
        if (effectiveRouteId != null && effectiveRouteId.isNotEmpty) {
          routeIdByRequestKey[entry.key] = effectiveRouteId;
        }
      }

      Map<String, Map<String, LiveStopPayload>> batchLiveMap;
      if (routeIdByRequestKey.isNotEmpty) {
        try {
          batchLiveMap = await controller.repository.getBatchLiveStopMaps(
            routeIdByRequestKey.values.toList(),
          );
        } catch (_) {
          batchLiveMap = const {};
        }
      } else {
        batchLiveMap = const {};
      }

      if (!mounted || requestId != _refreshRequestId) {
        return;
      }

      final enrichedItems = baseItems.map((item) {
        final requestKey = _routeRequestKey(item.reference);
        final routeId = routeIdByRequestKey[requestKey];
        final liveMap = routeId == null ? null : batchLiveMap[routeId];
        final payload = liveMap?['${item.stop.pathId}:${item.stop.stopId}'];
        if (payload != null) {
          return _applyLivePayload(item, payload);
        }

        final previousItem =
            previousItemsByKey[_favoriteItemKey(item.reference)];
        if (previousItem != null && hasRealtimeStopData(previousItem.stop)) {
          return FavoriteResolvedItem(
            reference: item.reference,
            route: item.route,
            stop: previousItem.stop,
          );
        }

        return item;
      }).toList();
      final liveRouteCount = routeIdByRequestKey.values
          .where(batchLiveMap.containsKey)
          .toSet()
          .length;
      final failedRouteCount = uniqueRoutes.length - liveRouteCount;

      setState(() {
        _loadedGroupName = groupName;
        _loadedSignature = signature;
        _items = enrichedItems;
      });

      final stationEntries = await stationEntriesFuture;
      if (!mounted || requestId != _refreshRequestId) {
        return;
      }

      final resolvedStationData = _resolvedStationData(stationEntries);
      final failedStationCount =
          stationEntries.length - resolvedStationData.length;
      final hasStationLiveData = resolvedStationData.values.any(
        (station) => station.nextArrival != null,
      );
      final refreshRequestCount = uniqueRoutes.length + stationEntries.length;
      final failedRequestCount = failedRouteCount + failedStationCount;
      final allRequestsFailed =
          refreshRequestCount > 0 && failedRequestCount == refreshRequestCount;
      final hasAnyLiveData = liveRouteCount > 0 || hasStationLiveData;
      final nextStatusMessage = allRequestsFailed
          ? l10n.favoritesRealtimeUpdateFailed
          : refreshRequestCount == 0
          ? null
          : !hasAnyLiveData
          ? l10n.favoritesNoRealtime
          : failedRequestCount > 0
          ? l10n.favoritesPartialUpdateFailed
          : null;

      setState(() {
        _stationDataByKey = resolvedStationData;
        _isLoading = false;
        _error = null;
        _statusMessage = nextStatusMessage;
        _refreshingGroupName = null;
        _refreshingSignature = '';
      });

      _startCountdown(
        hasAnyLiveData
            ? controller.settings.busUpdateTime
            : controller.settings.busErrorUpdateTime,
      );
    } catch (error) {
      if (!mounted || requestId != _refreshRequestId) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = localizedFriendlyError(l10n, error);
        _refreshingGroupName = null;
        _refreshingSignature = '';
        _statusMessage = _items.isEmpty
            ? l10n.favoritesLoadFailed
            : l10n.favoritesUpdateFailedKeepingData;
      });
      _startCountdown(controller.settings.busErrorUpdateTime);
    }
  }

  void _pauseRefreshLoop({bool invalidateRequest = false}) {
    _countdownTimer?.cancel();
    _countdownProgressController.stop();
    if (invalidateRequest) {
      _refreshRequestId += 1;
    }
  }

  void _resumeRefreshLoop() {
    _isRouteVisible = true;
    final shouldForceResolveStatic = _forceResolveStaticOnResume;
    _forceResolveStaticOnResume = false;
    _scheduleRefresh(forceResolveStatic: shouldForceResolveStatic);
  }

  @override
  void didPush() {
    _isRouteVisible = true;
  }

  @override
  void didPopNext() {
    _resumeRefreshLoop();
  }

  @override
  void didPushNext() {
    _isRouteVisible = false;
    _pauseRefreshLoop(invalidateRequest: true);
  }

  @override
  void didPop() {
    _isRouteVisible = false;
    _pauseRefreshLoop(invalidateRequest: true);
  }

  Map<String, StationPassbyData> _resolvedStationData(
    List<MapEntry<String, StationPassbyData?>> entries,
  ) {
    return {
      for (final entry in entries)
        if (entry.value != null)
          entry.key: entry.value!
        else if (_stationDataByKey[entry.key] != null)
          entry.key: _stationDataByKey[entry.key]!,
    };
  }

  FavoriteResolvedItem _applyLivePayload(
    FavoriteResolvedItem item,
    LiveStopPayload payload,
  ) {
    final stop = item.stop;
    return FavoriteResolvedItem(
      reference: item.reference,
      route: item.route,
      stop: StopInfo(
        routeKey: stop.routeKey,
        pathId: stop.pathId,
        stopId: stop.stopId,
        stopName: stop.stopName,
        sequence: stop.sequence,
        lon: stop.lon,
        lat: stop.lat,
        rawStopId: stop.rawStopId,
        sec: payload.sec,
        msg: payload.msg,
        t: payload.t,
        buses: payload.buses,
        etas: payload.etas,
      ),
    );
  }

  Future<void> _removeFavoriteItem(
    AppController controller,
    String groupName,
    FavoriteItem item,
    String label,
  ) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      if (item is FavoriteStop) {
        _items = _items
            .where((entry) => !entry.reference.sameAs(item))
            .toList();
      } else if (item is FavoriteStation) {
        _stationDataByKey = Map<String, StationPassbyData>.from(
          _stationDataByKey,
        )..remove(item.stableKey);
      }
    });

    await controller.removeFavoriteItem(groupName, item);
    if (!mounted) {
      return;
    }
    unawaited(AppHaptics.lightImpact());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.favoriteRemoved(label, groupName))),
    );
    _scheduleRefresh(forceResolveStatic: true);
  }

  Widget _buildDismissibleFavorite({
    required BuildContext context,
    required FavoriteItem favorite,
    required VoidCallback onDismissed,
    required Widget child,
  }) {
    return Dismissible(
      key: ValueKey('favorite-${favorite.stableKey}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onDismissed(),
      child: child,
    );
  }

  Widget _buildFavoriteTypeBadge(BuildContext context, FavoriteItemType type) {
    final label = localizedFavoriteItemType(AppLocalizations.of(context), type);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRouteFavoriteCard(
    BuildContext context,
    AppController controller,
    String groupName,
    FavoriteRoute favorite,
  ) {
    final showTypeBadge =
        controller.favoriteGroupKind(groupName) == FavoriteGroupKind.mixed;
    final description = favorite.routeDescription?.trim();
    return _buildDismissibleFavorite(
      context: context,
      favorite: favorite,
      onDismissed: () => unawaited(
        _removeFavoriteItem(
          controller,
          groupName,
          favorite,
          favorite.routeName,
        ),
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: CircleAvatar(
            child: Text(
              favorite.routeName.characters.take(2).toString(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(
            favorite.routeName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTypeBadge) ...[
                  _buildFavoriteTypeBadge(context, FavoriteItemType.route),
                  const SizedBox(height: 5),
                ],
                Text(
                  '${favorite.provider.label}${description?.isNotEmpty == true ? " · $description" : ""}',
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            unawaited(AppHaptics.selectionClick());
            unawaited(
              controller.recordRouteSelection(
                provider: favorite.provider,
                routeKey: favorite.routeKey,
                routeName: favorite.routeName,
                source: 'favorite_route',
              ),
            );
            await openRouteDetailPage(
              context,
              routeKey: favorite.routeKey,
              provider: favorite.provider,
              routeIdHint: favorite.routeId,
              routeNameHint: favorite.routeName,
              suppressAutoDestinationSelection: true,
            );
          },
        ),
      ),
    );
  }

  Widget _buildStationFavoriteCard(
    BuildContext context,
    AppController controller,
    String groupName,
    FavoriteStation favorite,
  ) {
    final l10n = AppLocalizations.of(context);
    final station = _stationDataByKey[favorite.stableKey];
    final nextArrival = station?.nextArrival;
    final route = nextArrival?.result.route;
    final stop = nextArrival?.result.matchedStop;
    final showTypeBadge =
        controller.favoriteGroupKind(groupName) == FavoriteGroupKind.mixed;
    final statusText = nextArrival == null
        ? '${favorite.provider.label} · ${l10n.favoriteNoUpcomingArrivals}'
        : '${favorite.provider.label} · ${route!.routeName} · '
              '${l10n.favoriteStationSide(nextArrival.sideLabel)}';
    return _buildDismissibleFavorite(
      context: context,
      favorite: favorite,
      onDismissed: () => unawaited(
        _removeFavoriteItem(
          controller,
          groupName,
          favorite,
          favorite.stationName,
        ),
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: stop == null
              ? const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.directions_bus_filled_rounded, size: 30),
                )
              : EtaBadge(
                  stop: stop,
                  alwaysShowSeconds: controller.settings.alwaysShowSeconds,
                  size: 52,
                ),
          title: Text(favorite.stationName),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTypeBadge) ...[
                  _buildFavoriteTypeBadge(context, FavoriteItemType.station),
                  const SizedBox(height: 5),
                ],
                Text(statusText),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            unawaited(AppHaptics.selectionClick());
            Navigator.of(context).pushNamed(
              AppRoutes.stationDetailPath(
                provider: favorite.provider,
                stationId: favorite.stationId,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnresolvedBoardingCard(
    BuildContext context,
    AppController controller,
    String groupName,
    FavoriteStop favorite,
  ) {
    final l10n = AppLocalizations.of(context);
    final routeName = favorite.routeName?.trim().isNotEmpty == true
        ? favorite.routeName!.trim()
        : l10n.routeIdFallback(favorite.routeKey);
    final stopName = favorite.stopName?.trim().isNotEmpty == true
        ? favorite.stopName!.trim()
        : l10n.stopIdFallback(favorite.stopId);
    final showTypeBadge =
        controller.favoriteGroupKind(groupName) == FavoriteGroupKind.mixed;
    return _buildDismissibleFavorite(
      context: context,
      favorite: favorite,
      onDismissed: () => unawaited(
        _removeFavoriteItem(controller, groupName, favorite, stopName),
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.schedule_rounded, size: 30),
          ),
          title: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleMedium,
              children: [
                TextSpan(
                  text: '$routeName ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: stopName),
              ],
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTypeBadge) ...[
                  _buildFavoriteTypeBadge(context, FavoriteItemType.boarding),
                  const SizedBox(height: 5),
                ],
                Text(
                  '${favorite.provider.label} · '
                  '${l10n.favoriteFetchingRealtime}',
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openRouteDetailPage(
            context,
            routeKey: favorite.routeKey,
            provider: favorite.provider,
            routeIdHint: favorite.routeId,
            routeNameHint: favorite.routeName,
            initialPathId: favorite.pathId,
            initialStopId: favorite.stopId,
            initialDestinationPathId: favorite.destinationPathId,
            initialDestinationStopId: favorite.destinationStopId,
          ),
        ),
      ),
    );
  }

  Future<void> _handleFavoriteDestinationAction(
    AppController controller,
    String groupName,
    FavoriteResolvedItem item,
    _FavoriteDestinationAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (action == _FavoriteDestinationAction.setDestination) {
      final detail = await controller.getRouteDetail(
        item.reference.routeKey,
        provider: item.reference.provider,
        routeIdHint: item.reference.routeId,
        routeNameHint: item.route.routeName,
      );
      if (!mounted) {
        return;
      }
      final pathStops =
          detail.stopsByPath[item.reference.pathId] ?? const <StopInfo>[];
      if (pathStops.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.favoriteNoSelectableStops)));
        return;
      }

      final destination = await showModalBottomSheet<StopInfo>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: ListView.separated(
                itemCount: pathStops.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final stop = pathStops[index];
                  return ListTile(
                    title: Text(stop.stopName),
                    subtitle: Text(l10n.stopSequence(index + 1)),
                    trailing: stop.stopId == item.reference.destinationStopId
                        ? const Icon(Icons.flag_rounded)
                        : null,
                    onTap: () => Navigator.of(context).pop(stop),
                  );
                },
              ),
            ),
          );
        },
      );

      if (!mounted || destination == null) {
        return;
      }

      final didChange = await controller.updateFavoriteDestination(
        groupName,
        item.reference,
        destinationPathId: destination.pathId,
        destinationStopId: destination.stopId,
        destinationStopName: destination.stopName,
      );
      if (!mounted) {
        return;
      }
      if (didChange) {
        unawaited(AppHaptics.lightImpact());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.favoriteDestinationSet(destination.stopName)),
          ),
        );
        _scheduleRefresh(forceResolveStatic: true);
      }
      return;
    }

    final didChange = await controller.updateFavoriteDestination(
      groupName,
      item.reference,
      destinationPathId: null,
      destinationStopId: null,
      destinationStopName: null,
    );
    if (!mounted) {
      return;
    }
    if (didChange) {
      unawaited(AppHaptics.selectionClick());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.favoriteDestinationCleared)));
      _scheduleRefresh(forceResolveStatic: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final groups = controller.favoriteGroupNames;
    _syncTabController(groups);
    _scheduleRefreshIfNeeded(controller, groups);

    final currentGroupName = _currentGroupName(groups);
    final displayItems = currentGroupName == _loadedGroupName
        ? _items
        : const <FavoriteResolvedItem>[];
    final references = currentGroupName == null
        ? const <FavoriteItem>[]
        : controller.favoritesInGroup(currentGroupName);
    final hasFavoritesBackgroundImage = hasBackgroundImageForPage(
      controller.settings,
      pageKey: 'favorites',
    );

    return BackgroundImageWrapper(
      pageKey: 'favorites',
      child: Scaffold(
        backgroundColor: hasFavoritesBackgroundImage
            ? Colors.transparent
            : null,
        appBar: AppBar(
          title: Text(l10n.favoritesTitle),
          actions: [
            if (references.length >= 2)
              IconButton(
                tooltip: _sortMode
                    ? l10n.favoritesFinishSorting
                    : l10n.favoritesAdjustSorting,
                onPressed: () => setState(() => _sortMode = !_sortMode),
                icon: Icon(
                  _sortMode ? Icons.check_rounded : Icons.swap_vert_rounded,
                ),
              ),
            IconButton(
              tooltip: l10n.favoritesManageGroupsTooltip,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: '/favorite_groups'),
                    builder: (_) => const FavoriteGroupsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.folder_outlined),
            ),
          ],
          bottom: groups.isEmpty
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(kTextTabBarHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabs: groups.map((group) => Tab(text: group)).toList(),
                      ),
                    ),
                  ),
                ),
        ),
        bottomNavigationBar: groups.isEmpty
            ? null
            : Material(
                color:
                    Theme.of(context).bottomAppBarTheme.color ??
                    Theme.of(context).colorScheme.surface,
                child: Center(
                  // Without a heightFactor this Center expands to the full
                  // height the Scaffold offers the bottom bar, leaving the
                  // favorites list with no room at all.
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBottomProgressIndicator(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _statusMessage ??
                                    (_remainingSeconds > 0
                                        ? l10n.favoritesUpdateCountdown(
                                            _remainingSeconds,
                                          )
                                        : l10n.favoritesUpdating),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        body: groups.isEmpty
            ? const _EmptyFavoritesState()
            : _buildBody(
                context,
                controller,
                currentGroupName: currentGroupName!,
                references: references,
                items: displayItems,
              ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppController controller, {
    required String currentGroupName,
    required List<FavoriteItem> references,
    required List<FavoriteResolvedItem> items,
  }) {
    final l10n = AppLocalizations.of(context);
    if (_error != null && references.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CatStateCard(
            mood: CatStateMood.cry,
            title: l10n.favoritesErrorTitle,
            message: _error,
            actionLabel: l10n.favoritesTryAgain,
            onAction: () => _scheduleRefresh(forceResolveStatic: true),
          ),
        ),
      );
    }

    if (_isLoading && references.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (references.isEmpty) {
      return _EmptyFavoritesState(message: l10n.favoritesGroupEmpty);
    }

    final resolvedByKey = {
      for (final item in items) item.reference.stableKey: item,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: references.length,
          footer: const AdBannerWidget(minimumDensity: 2, isInline: true),
          buildDefaultDragHandles: false,
          proxyDecorator: _buildDragProxy,
          onReorderItem: (oldIndex, newIndex) =>
              _handleReorder(controller, currentGroupName, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final reference = references[index];
            return Padding(
              key: ValueKey('favorite-item-${reference.stableKey}'),
              padding: EdgeInsets.only(
                bottom: index == references.length - 1 ? 0 : 10,
              ),
              child: _buildReorderableRow(
                index: index,
                child: _buildFavoriteCard(
                  context,
                  controller,
                  currentGroupName,
                  reference,
                  resolvedByKey,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Wraps a favorite card so it can be dragged: a long press anywhere starts
  /// a drag on every platform, and sort mode adds an explicit handle.
  Widget _buildReorderableRow({required int index, required Widget child}) {
    return Row(
      children: [
        if (_sortMode)
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.drag_handle_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: child,
          ),
        ),
      ],
    );
  }

  /// Keep the dragged card at its original size without a floating/lift effect.
  Widget _buildDragProxy(Widget child, int index, Animation<double> animation) {
    return Material(type: MaterialType.transparency, child: child);
  }

  void _handleReorder(
    AppController controller,
    String groupName,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex == oldIndex) {
      return;
    }
    unawaited(AppHaptics.lightImpact());
    unawaited(controller.reorderFavoriteItem(groupName, oldIndex, newIndex));
  }

  Widget _buildFavoriteCard(
    BuildContext context,
    AppController controller,
    String currentGroupName,
    FavoriteItem reference,
    Map<String, FavoriteResolvedItem> resolvedByKey,
  ) {
    final l10n = AppLocalizations.of(context);
    if (reference is FavoriteRoute) {
      return _buildRouteFavoriteCard(
        context,
        controller,
        currentGroupName,
        reference,
      );
    }
    if (reference is FavoriteStation) {
      return _buildStationFavoriteCard(
        context,
        controller,
        currentGroupName,
        reference,
      );
    }
    if (reference is! FavoriteStop) {
      return const SizedBox.shrink();
    }
    final item = resolvedByKey[reference.stableKey];
    if (item == null) {
      return _buildUnresolvedBoardingCard(
        context,
        controller,
        currentGroupName,
        reference,
      );
    }
    final destinationSummary =
        item.reference.destinationStopName?.trim().isNotEmpty == true
        ? item.reference.destinationStopName!.trim()
        : (item.reference.destinationStopId == null
              ? null
              : l10n.stopIdFallback(item.reference.destinationStopId!));
    return _buildDismissibleFavorite(
      context: context,
      favorite: item.reference,
      onDismissed: () => unawaited(
        _removeFavoriteItem(
          controller,
          currentGroupName,
          item.reference,
          item.stop.stopName,
        ),
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: EtaBadge(
            stop: item.stop,
            alwaysShowSeconds: controller.settings.alwaysShowSeconds,
            size: 52,
          ),
          title: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleMedium,
              children: [
                TextSpan(
                  text: '${item.route.routeName} ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: item.stop.stopName),
              ],
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.favoriteGroupKind(currentGroupName) ==
                    FavoriteGroupKind.mixed) ...[
                  _buildFavoriteTypeBadge(context, FavoriteItemType.boarding),
                  const SizedBox(height: 5),
                ],
                Text(
                  '${item.reference.provider.label} · '
                  '${item.route.description.isEmpty ? l10n.routeKeyFallback(item.route.routeKey) : item.route.description}'
                  '${destinationSummary == null ? "" : "\n${l10n.destinationValue(destinationSummary)}"}',
                ),
              ],
            ),
          ),
          trailing: controller.settings.enableRouteBackgroundMonitor
              ? PopupMenuButton<_FavoriteDestinationAction>(
                  tooltip: l10n.favoriteDestinationSettings,
                  icon: Icon(
                    item.reference.destinationStopId == null
                        ? Icons.flag_outlined
                        : Icons.flag_rounded,
                  ),
                  onSelected: (action) {
                    unawaited(
                      _handleFavoriteDestinationAction(
                        controller,
                        currentGroupName,
                        item,
                        action,
                      ),
                    );
                  },
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        value: _FavoriteDestinationAction.setDestination,
                        child: Text(l10n.favoriteSetDestination),
                      ),
                      if (item.reference.destinationStopId != null)
                        PopupMenuItem(
                          value: _FavoriteDestinationAction.clearDestination,
                          child: Text(l10n.favoriteClearDestination),
                        ),
                    ];
                  },
                )
              : null,
          onTap: () async {
            unawaited(AppHaptics.selectionClick());
            unawaited(() async {
              final autoFavorited = await controller.recordRouteSelection(
                provider: item.reference.provider,
                routeKey: item.reference.routeKey,
                routeName: item.route.routeName,
                favorite: item.reference,
                source: 'favorite',
                pathId: item.reference.pathId,
                stopId: item.reference.stopId,
                stopName: item.reference.stopName ?? item.stop.stopName,
              );
              if (context.mounted && autoFavorited != null) {
                showAutoFavoritedSnackBar(context, autoFavorited);
              }
            }());
            await openRouteDetailPage(
              context,
              routeKey: item.reference.routeKey,
              provider: item.reference.provider,
              routeIdHint: item.reference.routeId ?? item.route.routeId,
              routeNameHint: item.route.routeName,
              initialPathId: item.reference.pathId,
              initialStopId: item.reference.stopId,
              initialDestinationPathId: item.reference.destinationPathId,
              initialDestinationStopId: item.reference.destinationStopId,
            );
          },
        ),
      ),
    );
  }
}

enum _FavoriteDestinationAction { setDestination, clearDestination }

class _EmptyFavoritesState extends StatelessWidget {
  const _EmptyFavoritesState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: CatStateCard(
          mood: CatStateMood.sad,
          title: l10n.favoritesEmptyTitle,
          message: message ?? l10n.favoritesEmptyMessage,
        ),
      ),
    );
  }
}
