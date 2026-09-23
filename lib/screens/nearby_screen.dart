import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/ad_banner_widget.dart';
import '../app/bus_app.dart';
import '../widgets/app_content_transition.dart';
import '../core/bus_repository.dart';
import '../core/catchability_estimator.dart';
import '../core/models.dart';
import '../core/route_direction_label.dart';
import '../core/user_location.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import 'adaptive_settings_presenter.dart';
import '../widgets/background_image_wrapper.dart';
import '../widgets/eta_badge.dart';
import '../widgets/transit_station_name.dart';
import 'route_detail_navigation.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyStopGroup {
  const _NearbyStopGroup({
    required this.stopName,
    required this.distanceMeters,
    required this.routes,
  });

  final String stopName;
  final double distanceMeters;
  final List<NearbyRouteRow> routes;
}

String _catchabilityMessage(
  AppLocalizations l10n,
  CatchabilityAssessment assessment,
) {
  final isChinese = l10n.localeName.startsWith('zh');
  return switch (assessment.status) {
    CatchabilityStatus.likely =>
      isChinese
          ? '預估來得及，約剩餘 ${assessment.remainingMinutes} 分鐘'
          : 'Likely in time, about ${assessment.remainingMinutes} min left',
    CatchabilityStatus.possible =>
      isChinese
          ? '可能來得及，步行時間約 ${assessment.walkingMinutes} 分鐘'
          : 'Possible, walking takes about ${assessment.walkingMinutes} min',
    CatchabilityStatus.unlikely =>
      isChinese
          ? '可能來不及，步行約 ${assessment.walkingMinutes} 分鐘；建議搭乘下一班'
          : 'May miss it; walking takes about ${assessment.walkingMinutes} min. Try the next bus',
    CatchabilityStatus.departed =>
      isChinese ? '公車可能已進站或離站' : 'The bus may already be at or past the stop',
    CatchabilityStatus.unavailable =>
      isChinese
          ? '定位或即時資料不足，無法準確判斷'
          : 'Not enough location or live data for an accurate estimate',
  };
}

class _CatchabilityLabel extends StatelessWidget {
  const _CatchabilityLabel({
    required this.assessment,
    required this.theme,
    required this.l10n,
  });

  final CatchabilityAssessment assessment;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (assessment.status) {
      CatchabilityStatus.likely => (
        Icons.directions_walk_rounded,
        theme.colorScheme.tertiary,
      ),
      CatchabilityStatus.possible => (
        Icons.access_time_rounded,
        theme.colorScheme.primary,
      ),
      CatchabilityStatus.unlikely => (
        Icons.warning_amber_rounded,
        theme.colorScheme.error,
      ),
      CatchabilityStatus.departed => (
        Icons.directions_bus_filled_rounded,
        theme.colorScheme.onSurfaceVariant,
      ),
      CatchabilityStatus.unavailable => (
        Icons.help_outline_rounded,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    final message = _catchabilityMessage(l10n, assessment);
    final hint = l10n.localeName.startsWith('zh')
        ? '步行時間為估算值，已保留定位誤差與資料延遲緩衝，僅供參考。'
        : 'Walking time is an estimate with location and realtime buffers.';

    return Tooltip(
      message: '$message\n$hint',
      child: Semantics(
        label: message,
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyScreenState extends State<NearbyScreen> {
  bool _loading = true;
  String? _error;
  LocationFailure? _locationFailure;
  List<NearbyStopResult> _results = const [];
  Map<String, LiveStopMap> _liveMaps = const {};
  double? _locationAccuracyMeters;
  bool _loadingEtas = false;
  int _requestGeneration = 0;
  int _etaLoadsInFlight = 0;
  int _etaLoadSequence = 0;
  final Map<String, int> _liveMapSequenceByRoute = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNearbyStops();
    });
  }

  Future<void> _loadNearbyStops() async {
    final requestGeneration = ++_requestGeneration;
    final controller = AppControllerScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
      _locationFailure = null;
      _liveMaps = const {};
      _locationAccuracyMeters = null;
      _liveMapSequenceByRoute.clear();
      _etaLoadsInFlight = 0;
      _loadingEtas = false;
    });

    try {
      final position = await resolveUserPosition();
      final results = await controller.getNearbyStops(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() {
        _results = results;
        _locationAccuracyMeters = position.accuracy.isFinite
            ? position.accuracy
            : null;
      });

      unawaited(_loadEtas(results, requestGeneration: requestGeneration));
      // Phase 2: fill every visible stop group, then load any ETAs that were
      // not already embedded by the station endpoint. Seed ETA loading runs in
      // parallel so slow station-group completion cannot delay first arrivals.
      unawaited(
        _completeNearbyStops(
          position: position,
          seedResults: results,
          requestGeneration: requestGeneration,
        ),
      );
    } catch (error) {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() {
        _results = const [];
        _error = localizedFriendlyError(AppLocalizations.of(context), error);
        _locationFailure = error is LocationFailure ? error : null;
      });
    } finally {
      if (mounted && requestGeneration == _requestGeneration) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _completeNearbyStops({
    required Position position,
    required List<NearbyStopResult> seedResults,
    required int requestGeneration,
  }) async {
    if (seedResults.isEmpty ||
        !mounted ||
        requestGeneration != _requestGeneration) {
      return;
    }

    final controller = AppControllerScope.read(context);

    var completedResults = seedResults;
    try {
      completedResults = await controller.completeNearbyStopGroups(
        latitude: position.latitude,
        longitude: position.longitude,
        seedResults: seedResults,
      );
    } catch (_) {
      // Group completion is an enhancement. Keep the seed list usable when a
      // downloaded database or station lookup becomes unavailable.
    }

    if (!mounted || requestGeneration != _requestGeneration) {
      return;
    }
    final mergedResults = _preserveEmbeddedEtas(completedResults, _results);
    setState(() {
      _results = mergedResults;
    });
    await _loadEtas(mergedResults, requestGeneration: requestGeneration);
  }

  bool _hasEmbeddedLiveData(StopInfo stop) {
    return stop.sec != null ||
        (stop.msg?.trim().isNotEmpty ?? false) ||
        (stop.t?.trim().isNotEmpty ?? false) ||
        stop.buses.isNotEmpty ||
        stop.etas.isNotEmpty;
  }

  Future<void> _loadEtas(
    List<NearbyStopResult> results, {
    required int requestGeneration,
  }) async {
    if (!mounted || requestGeneration != _requestGeneration) {
      return;
    }

    final controller = AppControllerScope.read(context);

    final routeIds = results
        .where((result) => !_hasEmbeddedLiveData(result.stop))
        .map((result) => result.route.routeId)
        .toSet()
        .toList(growable: false);
    if (routeIds.isEmpty) {
      return;
    }

    final loadSequence = ++_etaLoadSequence;
    _etaLoadsInFlight += 1;
    setState(() => _loadingEtas = true);
    Map<String, LiveStopMap> liveMaps = const {};
    try {
      try {
        liveMaps = await controller.repository.getBatchLiveStopMaps(routeIds);
      } catch (_) {}

      final missingRouteIds = routeIds
          .map((routeId) => routeId.trim())
          .where((routeId) => !liveMaps.containsKey(routeId))
          .toSet();
      if (missingRouteIds.isNotEmpty) {
        final fallbackEntries = await Future.wait(
          missingRouteIds.map((routeId) async {
            try {
              final liveMap = await controller.repository.getLiveStopMap(
                routeId,
              );
              return MapEntry(routeId, liveMap);
            } catch (_) {
              return null;
            }
          }),
        );
        final merged = Map<String, LiveStopMap>.from(liveMaps);
        for (final entry in fallbackEntries) {
          if (entry != null) {
            merged[entry.key] = entry.value;
          }
        }
        liveMaps = merged;
      }

      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() {
        final merged = Map<String, LiveStopMap>.from(_liveMaps);
        for (final entry in liveMaps.entries) {
          if (loadSequence >= (_liveMapSequenceByRoute[entry.key] ?? 0)) {
            merged[entry.key] = entry.value;
            _liveMapSequenceByRoute[entry.key] = loadSequence;
          }
        }
        _liveMaps = merged;
      });
    } finally {
      if (mounted && requestGeneration == _requestGeneration) {
        _etaLoadsInFlight -= 1;
        setState(() {
          _loadingEtas = _etaLoadsInFlight > 0;
        });
      }
    }
  }

  List<NearbyStopResult> _preserveEmbeddedEtas(
    List<NearbyStopResult> completed,
    List<NearbyStopResult> current,
  ) {
    final currentByKey = {
      for (final item in current) _nearbyResultKey(item): item,
    };
    return completed
        .map((item) {
          final previous = currentByKey[_nearbyResultKey(item)];
          if (previous == null ||
              _hasEmbeddedLiveData(item.stop) ||
              !_hasEmbeddedLiveData(previous.stop)) {
            return item;
          }
          return NearbyStopResult(
            route: item.route,
            stop: previous.stop,
            distanceMeters: item.distanceMeters,
          );
        })
        .toList(growable: false);
  }

  String _nearbyResultKey(NearbyStopResult item) {
    final stopId = item.stop.rawStopId?.trim().isNotEmpty == true
        ? item.stop.rawStopId!.trim()
        : item.stop.stopId.toString();
    return '${item.route.routeId.trim()}:${item.stop.pathId}:$stopId';
  }

  StopInfo _liveStop(NearbyStopResult item) {
    final liveMap = _liveMaps[item.route.routeId.trim()];
    final payload = liveMap?['${item.stop.pathId}:${item.stop.stopId}'];
    if (payload == null) {
      return item.stop;
    }
    return item.stop.copyWith(
      sec: payload.sec,
      msg: payload.msg,
      t: payload.t,
      buses: payload.buses,
      etas: payload.etas,
    );
  }

  // Returns the minute-of-day if the message starts with HH:MM, else null.
  int? _messageEtaMinutes(StopInfo stop) {
    final message = stop.msg?.trim();
    if (message == null || message.isEmpty) {
      return null;
    }
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(message);
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) {
      return null;
    }
    return hour * 60 + minute;
  }

  // Bucket 0: sec ETA  1: HH:MM message  2: other message  3: no data
  int _etaBucket(StopInfo stop) {
    if (stop.sec != null) {
      return 0;
    }
    if (_messageEtaMinutes(stop) != null) {
      return 1;
    }
    if (stop.msg?.trim().isNotEmpty ?? false) {
      return 2;
    }
    return 3;
  }

  int _compareByEta(NearbyStopResult a, NearbyStopResult b) {
    final aStop = _liveStop(a);
    final bStop = _liveStop(b);
    final aBucket = _etaBucket(aStop);
    final bBucket = _etaBucket(bStop);
    if (aBucket != bBucket) {
      return aBucket.compareTo(bBucket);
    }
    final aSec = aStop.sec;
    final bSec = bStop.sec;
    if (aSec != null && bSec != null && aSec != bSec) {
      return aSec.compareTo(bSec);
    }
    final aMin = _messageEtaMinutes(aStop);
    final bMin = _messageEtaMinutes(bStop);
    if (aMin != null && bMin != null && aMin != bMin) {
      return aMin.compareTo(bMin);
    }
    return a.route.routeKey.compareTo(b.route.routeKey);
  }

  /// Groups flat results (one per route) into stops, preserving distance
  /// order. Routes within each group are sorted by ETA once live data is
  /// available.
  List<_NearbyStopGroup> _buildGroups(String locale) {
    final groupOrder = <String>[];
    final groupDistances = <String, double>{};
    final groupRoutes = <String, List<NearbyStopResult>>{};

    for (final item in _results) {
      final name = item.stop.stopName;
      if (!groupRoutes.containsKey(name)) {
        groupOrder.add(name);
        groupDistances[name] = item.distanceMeters;
        groupRoutes[name] = [];
      }
      groupRoutes[name]!.add(item);
    }

    return [
      for (final name in groupOrder)
        _NearbyStopGroup(
          stopName: name,
          distanceMeters: groupDistances[name]!,
          // Sort first: the labeller only appends a direction ordinal when two
          // rows would otherwise read alike, so it has to see the final order.
          routes: labelNearbyRouteDirections(
            groupRoutes[name]!..sort(_compareByEta),
            locale: locale,
          ),
        ),
    ];
  }

  /// One route row inside a stop-name card.
  ///
  /// Two lines rather than one: the group merges both directions of a stop, so
  /// the direction is the only thing telling two rows apart and must not be the
  /// first casualty of `TextOverflow.ellipsis` on a narrow screen. The row
  /// height is still set by the 44px [EtaBadge], so nothing grows.
  Widget _buildRouteRow(
    ThemeData theme,
    NearbyRouteRow row, {
    required bool alwaysShowSeconds,
  }) {
    final item = row.result;
    final liveStop = _liveStop(item);
    final catchability = estimateCatchability(
      distanceMeters: item.distanceMeters,
      etaSeconds: liveStop.sec,
      locationAccuracyMeters: _locationAccuracyMeters,
    );
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final providerLabel = busProviderFromString(
      item.route.sourceProvider,
    ).label;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openRoute(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              EtaBadge(
                stop: liveStop,
                alwaysShowSeconds: alwaysShowSeconds,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.route.transitName.displayForLocale(locale),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            providerLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: _CatchabilityLabel(
                            assessment: catchability,
                            theme: theme,
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                    if (row.directionLabel.isNotEmpty)
                      TransitDirectionLabel(
                        label: row.directionLabel,
                        primaryStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRoute(NearbyStopResult item) async {
    final controller = AppControllerScope.read(context);
    final routeProvider = busProviderFromString(item.route.sourceProvider);
    unawaited(() async {
      final autoFavorited = await controller.recordRouteSelection(
        provider: routeProvider,
        routeKey: item.route.routeKey,
        routeName: item.route.routeName,
        source: 'nearby',
        pathId: item.stop.pathId,
        stopId: item.stop.stopId,
        stopName: item.stop.stopName,
      );
      if (mounted && autoFavorited != null) {
        showAutoFavoritedSnackBar(context, autoFavorited);
      }
    }());
    await openRouteDetailPage(
      context,
      routeKey: item.route.routeKey,
      provider: routeProvider,
      routeIdHint: item.route.routeId,
      routeNameHint: item.route.routeName,
      initialPathId: item.stop.pathId,
      initialStopId: item.stop.stopId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hasNearbyBackgroundImage = hasBackgroundImageForPage(
      controller.settings,
      pageKey: 'nearby',
    );
    final groups = _buildGroups(locale);

    return BackgroundImageWrapper(
      pageKey: 'nearby',
      child: Scaffold(
        backgroundColor: hasNearbyBackgroundImage ? Colors.transparent : null,
        appBar: AppBar(
          title: Text(l10n.nearbyTitle),
          actions: [
            IconButton(
              tooltip: l10n.commonRefresh,
              onPressed: _loading ? null : _loadNearbyStops,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: AppContentTransition(
          state: _loading
              ? 'loading'
              : _error != null
              ? 'error'
              : groups.isEmpty
              ? 'empty'
              : 'content',
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton(
                              onPressed: _loadNearbyStops,
                              child: Text(l10n.commonRetry),
                            ),
                            OutlinedButton(
                              onPressed:
                                  _locationFailure?.serviceDisabled == true
                                  ? () => unawaited(
                                      Geolocator.openLocationSettings(),
                                    )
                                  : _locationFailure?.deniedForever == true
                                  ? () =>
                                        unawaited(Geolocator.openAppSettings())
                                  : () => openAdaptiveSettingsScreen(context),
                              child: Text(
                                _locationFailure?.serviceDisabled == true
                                    ? l10n.nearbyLocationSettings
                                    : _locationFailure?.deniedForever == true
                                    ? l10n.nearbyPermissionSettings
                                    : l10n.commonOpenSettings,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : groups.isEmpty
              ? Center(child: Text(l10n.nearbyEmpty))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Column(
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Text(
                                            formatDistance(
                                              group.distanceMeters,
                                            ),
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.labelMedium,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: TransitStationName(
                                            name: group
                                                .routes
                                                .first
                                                .result
                                                .stop
                                                .transitName,
                                            primaryStyle: theme
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_loadingEtas) ...[
                                      const SizedBox(height: 10),
                                      const LinearProgressIndicator(
                                        minHeight: 2,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    for (
                                      var index = 0;
                                      index < group.routes.length;
                                      index++
                                    ) ...[
                                      if (index > 0) const Divider(height: 1),
                                      _buildRouteRow(
                                        theme,
                                        group.routes[index],
                                        alwaysShowSeconds: controller
                                            .settings
                                            .alwaysShowSeconds,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (index == groups.length - 1)
                              const AdBannerWidget(
                                minimumDensity: 2,
                                isInline: true,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
