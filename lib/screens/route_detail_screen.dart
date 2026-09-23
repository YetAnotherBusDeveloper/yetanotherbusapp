import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app/bus_app.dart';
import '../core/app_motion.dart';
import '../core/android_home_integration.dart';
import '../core/android_trip_monitor.dart';
import '../core/app_controller.dart';
import '../core/haptic_feedback_service.dart';
import '../core/app_launch_service.dart';
import '../core/app_route_observer.dart';
import '../core/app_routes.dart';
import '../core/bus_repository.dart';
import '../core/desktop_discord_presence_service.dart';
import '../core/live_activity_service.dart';
import '../core/models.dart';
import '../core/route_detail_launch_bridge.dart';
import '../core/samsung_live_notification_prompt_service.dart';
import '../core/stop_route_merge.dart';
import '../core/trip_monitor_notifications.dart';
import '../core/twbusforum.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import '../widgets/background_image_wrapper.dart';
import '../widgets/cat_state_card.dart';
import '../widgets/eta_badge.dart';
import '../widgets/route_bus_map_sheet.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/app_content_transition.dart';
import '../widgets/stop_transfer_sheet.dart';
import '../widgets/transit_station_name.dart';
import 'favorite_groups_screen.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    required this.routeKey,
    required this.provider,
    this.routeIdHint,
    this.routeNameHint,
    this.initialPathId,
    this.initialStopId,
    this.initialDestinationPathId,
    this.initialDestinationStopId,
    this.initialTopologyFuture,
    this.initialAlertsFuture,
    this.initialCancelledDeparturesFuture,
    this.suppressAutoDestinationSelection = false,
    super.key,
  });

  final int routeKey;
  final BusProvider provider;
  final String? routeIdHint;
  final String? routeNameHint;
  final int? initialPathId;
  final int? initialStopId;
  final int? initialDestinationPathId;
  final int? initialDestinationStopId;
  final Future<RouteDetailData?>? initialTopologyFuture;
  final Future<List<RouteAlert>>? initialAlertsFuture;
  final Future<List<CancelledDeparture>>? initialCancelledDeparturesFuture;
  final bool suppressAutoDestinationSelection;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailLoadResult {
  const _RouteDetailLoadResult.success(this.detail)
    : error = null,
      stackTrace = null;

  const _RouteDetailLoadResult.failure(this.error, this.stackTrace)
    : detail = null;

  final RouteDetailData? detail;
  final Object? error;
  final StackTrace? stackTrace;
}

enum _RouteDetailStatus {
  refreshing,
  loadingRoute,
  loadingRealtime,
  realtimeUnavailable,
  loadFailed,
  loadingFamily,
}

class _RouteDetailScreenState extends State<RouteDetailScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  static const double _wideLayoutBreakpoint = 1080;
  static const Duration _maxMergedPreviousLiveAge = Duration(seconds: 90);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final RouteDetailLaunchHandler _launchHandler;
  late final ValueNotifier<int?> _selectedMapPathId;
  String? _focusedMapVehicleId;
  int _focusedMapVehicleRequest = 0;
  late final ValueNotifier<Map<int, List<StopInfo>>> _liveMapStopsByPath;
  late final ValueNotifier<List<String>> _liveMapFamilyRouteIds;
  ModalRoute<dynamic>? _route;
  bool _isLoading = true;
  bool _hasCompletedInitialRealtime = false;
  bool _isFamilyLoading = false;
  bool _supplementaryNoticesLoading = false;
  String? _error;
  _RouteDetailStatus? _status;
  RouteDetailData? _detail;
  Timer? _countdownTimer;
  late final AnimationController _countdownProgressController;
  late final AnimationController _initialStopsRevealController;
  late final Animation<double> _initialStopsOpacity;
  bool _initialStopsRevealScheduled = false;
  TabController? _tabController;
  StreamSubscription<Position>? _positionSubscription;
  Future<void>? _locationTrackingInFlight;
  bool? _locationTrackingInFlightForBackground;
  int _locationTrackingGeneration = 0;
  Position? _lastPosition;
  late final ValueNotifier<int> _remainingSeconds;
  bool _didScrollToInitialStop = false;
  bool _isScrollingToInitialStop = false;
  int? _autoScrolledPathId;
  bool _didAttemptLocationTracking = false;
  bool _didRecordRouteVisit = false;
  Timer? _routeVisitTimer;
  bool? _wakelockEnabled;
  bool _backgroundTripMonitorReady = false;
  bool _backgroundTripMonitorPromptInProgress = false;
  bool _samsungLiveNotificationPromptInProgress = false;
  bool _backgroundTripMonitorPaused = false;
  bool _backgroundDataRefreshInFlight = false;
  bool _awaitingBackgroundLocationPermission = false;
  bool _destinationPromptShown = false;
  bool _liveActivityActive = false;
  bool _showWideMapPanel = true;
  bool _isRouteVisible = true;
  bool _keepPendingRefreshWhileCovered = false;
  int? _liveActivityStopId;
  int? _liveActivityPathId;
  int? _liveActivityRouteKey;
  String? _liveActivityProviderName;
  String? _liveActivityId;
  String? _liveActivityRidingVehicleId;
  bool _liveActivityBoardingWindowOpen = false;
  bool _liveActivityRideConfirmed = false;
  DateTime? _liveActivityBoardingWindowOpenedAt;
  bool _liveActivityBoardingArrivalAlertSent = false;
  bool _liveActivityDestinationSetupAlertSent = false;
  int _liveActivityDestinationAlertStage = 0;
  bool _iosBoardingCheckPromptSent = false;
  bool _locationTrackingConfiguredForBackground = false;
  bool _backgroundLocationAlwaysGranted = false;
  int? _liveActivityLastNearestStopIndex;
  DateTime? _lastBackgroundDataRefreshAt;
  int? _requestedPathId;
  int? _requestedStopId;
  int? _targetInitialPathId;
  int? _requestedDestinationPathId;
  int? _requestedDestinationStopId;
  int? _boardingStopId;
  String? _boardingStopName;
  int? _destinationStopId;
  String? _destinationStopName;
  List<RouteAlert> _alerts = const <RouteAlert>[];
  List<CancelledDeparture> _initialCancelledDepartures =
      const <CancelledDeparture>[];
  bool _alertsFetched = false;
  bool _alertsRead = false;
  bool _cancelledDeparturePromptChecked = false;
  Future<void>? _cancelledDepartureDialogFuture;
  int _supplementaryDialogDepth = 0;
  int _refreshRequestId = 0;
  bool _didStartInitialRefresh = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  Map<int, int> _nearestStopByPath = const <int, int>{};
  final Map<int, GlobalKey> _stopKeys = <int, GlobalKey>{};
  final Map<int, ScrollController> _scrollControllers =
      <int, ScrollController>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _launchHandler = _handleLaunchAction;
    RouteDetailLaunchBridge.instance.attach(_launchHandler);
    _selectedMapPathId = ValueNotifier<int?>(widget.initialPathId);
    _liveMapStopsByPath = ValueNotifier<Map<int, List<StopInfo>>>(
      const <int, List<StopInfo>>{},
    );
    _liveMapFamilyRouteIds = ValueNotifier<List<String>>(const <String>[]);
    _remainingSeconds = ValueNotifier<int>(0);
    _countdownProgressController = AnimationController(vsync: this);
    _initialStopsRevealController = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
    _initialStopsOpacity = CurvedAnimation(
      parent: _initialStopsRevealController,
      curve: AppMotion.curve,
    );
    _requestedPathId = widget.initialPathId;
    _requestedStopId = widget.initialStopId;
    _requestedDestinationPathId = widget.initialDestinationPathId;
    _requestedDestinationStopId = widget.initialDestinationStopId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _initialStopsRevealController.value = 1;
    }
    final route = ModalRoute.of(context);
    if (_route != route) {
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
    _syncWakelock(
      AppControllerScope.of(context).settings.keepScreenAwakeOnRouteDetail,
    );
    if (!_didStartInitialRefresh) {
      _didStartInitialRefresh = true;
      _watchInitialSupplementaryData();
      unawaited(_refresh(setLoadingState: false));
    }
    unawaited(_configureBackgroundTripMonitorIfNeeded());
  }

  void _watchInitialSupplementaryData() {
    final alertsFuture = widget.initialAlertsFuture;
    if (alertsFuture != null) {
      unawaited(() async {
        try {
          final alerts = await alertsFuture;
          if (mounted && _detail == null && alerts.isNotEmpty) {
            setState(() {
              _alerts = alerts;
            });
          }
        } catch (_) {
          // Supplementary information must never delay route loading.
        }
      }());
    }

    final cancelledFuture = widget.initialCancelledDeparturesFuture;
    if (cancelledFuture != null) {
      unawaited(() async {
        try {
          final departures = await cancelledFuture;
          if (mounted && _detail == null && departures.isNotEmpty) {
            setState(() {
              _initialCancelledDepartures = departures;
            });
          }
        } catch (_) {
          // Supplementary information must never delay route loading.
        }
      }());
    }
  }

  @override
  void dispose() {
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    RouteDetailLaunchBridge.instance.detach(_launchHandler);
    _countdownTimer?.cancel();
    _routeVisitTimer?.cancel();
    _countdownProgressController.dispose();
    _initialStopsRevealController.dispose();
    _selectedMapPathId.dispose();
    _liveMapStopsByPath.dispose();
    _liveMapFamilyRouteIds.dispose();
    _remainingSeconds.dispose();
    _locationTrackingGeneration += 1;
    _locationTrackingInFlight = null;
    _positionSubscription?.cancel();
    _tabController?.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    if (_wakelockEnabled == true) {
      unawaited(_setWakelock(false));
    }
    unawaited(TripMonitorNotifications.cancelBoardingCheckPrompt());
    unawaited(AndroidTripMonitor.stop());
    if (_liveActivityId != null) {
      unawaited(
        LiveActivityService.endLiveActivity(ownerActivityId: _liveActivityId),
      );
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _appIsForeground;
    _appLifecycleState = state;
    final isForeground = _appIsForeground;

    if (!isForeground) {
      _pauseForegroundRefreshLoop(invalidateRequest: true);
      if (!_locationTrackingConfiguredForBackground) {
        _pauseForegroundLocationTracking();
      }
      if (_isAndroid) {
        unawaited(AndroidTripMonitor.setAppInForeground(false));
      }
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _awaitingBackgroundLocationPermission) {
      _awaitingBackgroundLocationPermission = false;
      if (_isAndroid) {
        unawaited(_handleReturnedFromAndroidBackgroundLocationSettings());
      } else {
        unawaited(
          _configureBackgroundTripMonitorIfNeeded(forcePermissionCheck: true),
        );
      }
    }
    if (state == AppLifecycleState.resumed && _isIOS) {
      unawaited(TripMonitorNotifications.cancelBoardingCheckPrompt());
    }

    if (_isAndroid) {
      unawaited(AndroidTripMonitor.setAppInForeground(true));
      if (_backgroundTripMonitorReady) {
        unawaited(_syncBackgroundTripMonitorPausedState());
      }
    }
    if (!wasForeground && _isRouteVisible && _detail != null) {
      unawaited(_refresh());
      unawaited(_ensureLocationTracking(requestPermissionIfNeeded: false));
    }
  }

  Future<void> _refresh({bool setLoadingState = true}) async {
    if (_shouldSuspendForegroundRefreshes) {
      return;
    }
    final requestId = ++_refreshRequestId;
    final controller = AppControllerScope.read(context);
    final l10n = AppLocalizations.of(context);
    final previousDetail = _detail;

    if (setLoadingState) {
      setState(() {
        _isLoading = true;
        _isFamilyLoading = false;
        _error = null;
        _status = _RouteDetailStatus.refreshing;
      });
    } else {
      _isLoading = true;
      _isFamilyLoading = false;
      _error = null;
      _status = _RouteDetailStatus.loadingRoute;
    }

    final primaryDetailFuture = controller
        .getPrimaryRouteDetail(
          widget.routeKey,
          provider: widget.provider,
          routeIdHint: widget.routeIdHint,
          routeNameHint: widget.routeNameHint,
        )
        .then<_RouteDetailLoadResult>(
          _RouteDetailLoadResult.success,
          onError: (Object error, StackTrace stackTrace) =>
              _RouteDetailLoadResult.failure(error, stackTrace),
        );

    if (previousDetail == null) {
      try {
        final prefetchedTopology = await widget.initialTopologyFuture;
        final topology =
            prefetchedTopology ??
            await controller.getRouteTopology(
              widget.routeKey,
              provider: widget.provider,
              routeIdHint: widget.routeIdHint,
              routeNameHint: widget.routeNameHint,
            );
        if (mounted &&
            requestId == _refreshRequestId &&
            _canApplyPendingForegroundResult) {
          _syncLiveMapData(topology);
          _syncTabController(topology);
          setState(() {
            _detail = topology;
            _isLoading = false;
            _status = _RouteDetailStatus.loadingRealtime;
          });
          _scheduleInitialStopsReveal();
          _updateDesktopPresence();
          if (_isRouteVisible) {
            unawaited(_loadSupplementaryNotices(topology));
          }
          _scrollToInitialStopIfNeeded();
        }
      } catch (_) {
        // The primary detail request reports the actionable error below.
      }
    }

    try {
      final primaryResult = await primaryDetailFuture;
      if (primaryResult.error case final error?) {
        Error.throwWithStackTrace(error, primaryResult.stackTrace!);
      }
      final fetchedDetail = primaryResult.detail!;
      if (!mounted ||
          requestId != _refreshRequestId ||
          !_canApplyPendingForegroundResult) {
        return;
      }

      final displayDetail = !fetchedDetail.hasLiveData && previousDetail != null
          ? _mergeDetailWithPreviousLiveData(fetchedDetail, previousDetail)
          : fetchedDetail;

      _syncLiveMapData(displayDetail);
      _syncTabController(displayDetail);
      setState(() {
        _detail = displayDetail;
        _isLoading = false;
        _hasCompletedInitialRealtime = true;
        _error = null;
        _status = fetchedDetail.hasLiveData
            ? null
            : _RouteDetailStatus.realtimeUnavailable;
      });
      _scheduleInitialStopsReveal();
      _updateDesktopPresence();
      if (!_didRecordRouteVisit) {
        _didRecordRouteVisit = true;
        _routeVisitTimer = Timer(const Duration(seconds: 10), () {
          if (!mounted) return;
          final detail = _detail;
          if (detail == null) return;
          unawaited(
            AppControllerScope.read(context).recordRouteVisit(
              detail.route,
              provider: widget.provider,
              pathId: _currentPathId,
            ),
          );
        });
      }
      if (_isRouteVisible) {
        unawaited(_loadSupplementaryNotices(displayDetail));
      }
      _startCountdown(
        fetchedDetail.hasLiveData
            ? controller.settings.busUpdateTime
            : controller.settings.busErrorUpdateTime,
      );
      unawaited(
        _loadRouteFamilyAfterCurrentFrame(displayDetail, requestId: requestId),
      );
      _scrollToInitialStopIfNeeded();
      _recalculateNearestStops();
      await _applyRequestedDestinationIfPossible();
      if (_isRouteVisible) {
        unawaited(_ensureLocationTracking());
        unawaited(_maybePromptForBackgroundTripMonitor());
        unawaited(_maybePromptForSamsungLiveNotifications());
        unawaited(_configureBackgroundTripMonitorIfNeeded());
      }
    } catch (error) {
      if (!mounted || requestId != _refreshRequestId) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasCompletedInitialRealtime = true;
        _isFamilyLoading = false;
        _error = localizedFriendlyError(l10n, error);
        _status = _detail == null
            ? _RouteDetailStatus.loadFailed
            : _RouteDetailStatus.realtimeUnavailable;
      });
      _updateDesktopPresence();
      _startCountdown(controller.settings.busErrorUpdateTime);
    }
  }

  Future<void> _loadRouteFamily(
    RouteDetailData selected, {
    required int requestId,
  }) async {
    if (!mounted || requestId != _refreshRequestId) {
      return;
    }
    setState(() {
      _isFamilyLoading = true;
      _status = _RouteDetailStatus.loadingFamily;
    });
    try {
      final enriched = await AppControllerScope.read(
        context,
      ).enrichRouteWithFamily(selected, provider: widget.provider);
      if (!mounted ||
          requestId != _refreshRequestId ||
          !_canApplyPendingForegroundResult) {
        return;
      }
      _syncLiveMapData(enriched, replaceFamilyRouteIds: true);
      _syncTabController(enriched);
      setState(() {
        _detail = enriched;
        _isFamilyLoading = false;
        _status = enriched.hasLiveData
            ? null
            : _RouteDetailStatus.realtimeUnavailable;
      });
      _updateDesktopPresence();
      _recalculateNearestStops();
    } catch (_) {
      if (!mounted || requestId != _refreshRequestId) {
        return;
      }
      setState(() {
        _isFamilyLoading = false;
        _status = selected.hasLiveData
            ? null
            : _RouteDetailStatus.realtimeUnavailable;
      });
    }
  }

  Future<void> _loadRouteFamilyAfterCurrentFrame(
    RouteDetailData selected, {
    required int requestId,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || requestId != _refreshRequestId) {
      return;
    }
    await _loadRouteFamily(selected, requestId: requestId);
  }

  void _scheduleInitialStopsReveal() {
    if (_initialStopsRevealScheduled) {
      return;
    }
    _initialStopsRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _initialStopsRevealController.value = 1;
      } else {
        unawaited(_initialStopsRevealController.forward());
      }
    });
  }

  void _syncLiveMapData(
    RouteDetailData detail, {
    bool replaceFamilyRouteIds = false,
  }) {
    _liveMapStopsByPath.value = detail.stopsByPath.map(
      (pathId, stops) => MapEntry(pathId, List<StopInfo>.of(stops)),
    );
    if (replaceFamilyRouteIds || _liveMapFamilyRouteIds.value.isEmpty) {
      final nextFamilyRouteIds = List<String>.of(detail.familyRouteIds);
      if (!listEquals(_liveMapFamilyRouteIds.value, nextFamilyRouteIds)) {
        _liveMapFamilyRouteIds.value = nextFamilyRouteIds;
      }
    }
  }

  Future<void> _loadSupplementaryNotices(RouteDetailData detail) async {
    if (_supplementaryNoticesLoading) {
      return;
    }
    _supplementaryNoticesLoading = true;
    try {
      if (!_cancelledDeparturePromptChecked) {
        await _maybeShowTaichungCancelledDepartures(detail);
      }
      if (!mounted || !_canApplyPendingForegroundResult || _alertsFetched) {
        return;
      }
      _alertsFetched = true;
      await _fetchAndShowAlerts(detail.route.routeId);
    } finally {
      _supplementaryNoticesLoading = false;
    }
  }

  Future<void> _fetchAndShowAlerts(String routeId) async {
    try {
      final controller = AppControllerScope.read(context);
      final alerts =
          await (widget.initialAlertsFuture ??
              controller.getRouteAlerts(routeId));
      if (!mounted) return;
      final activeAlertIds = alerts
          .map((alert) => alert.alertId.trim())
          .where((alertId) => alertId.isNotEmpty)
          .toSet();
      await controller.syncReadRouteAlertsForRoute(
        routeId,
        activeAlertIds: activeAlertIds,
      );
      final readAlertIds = controller.readRouteAlertIdsForRoute(routeId);
      final unseenAlerts = alerts
          .where((alert) => !readAlertIds.contains(alert.alertId.trim()))
          .toList();
      setState(() {
        _alerts = alerts;
        _alertsRead = alerts.isEmpty || unseenAlerts.isEmpty;
      });
      if (unseenAlerts.isNotEmpty) {
        await controller.syncReadRouteAlertsForRoute(
          routeId,
          activeAlertIds: activeAlertIds,
          markAsReadAlertIds: unseenAlerts.map((alert) => alert.alertId),
        );
        if (!mounted) return;
        final cancelledDialog = _cancelledDepartureDialogFuture;
        if (cancelledDialog != null) {
          await cancelledDialog;
        }
        if (!mounted || !_isRouteVisible) return;
        setState(() {
          _alertsRead = true;
        });
        _showAlertsDialog();
      }
    } catch (_) {
      // Silently ignore alert fetch errors.
    }
  }

  Future<void> _maybeShowTaichungCancelledDepartures(
    RouteDetailData detail,
  ) async {
    if (_cancelledDeparturePromptChecked ||
        widget.provider != BusProvider.txg) {
      return;
    }
    _cancelledDeparturePromptChecked = true;
    try {
      final departures =
          await (widget.initialCancelledDeparturesFuture ??
              AppControllerScope.read(
                context,
              ).repository.fetchTaichungCancelledDepartures(
                routeId: detail.route.routeId,
                routeName: detail.route.routeName,
                date: DateTime.now(),
              ));
      if (!mounted || !_isRouteVisible || departures.isEmpty) {
        return;
      }
      final departuresByDirection = <int, List<CancelledDeparture>>{};
      for (final departure in departures) {
        (departuresByDirection[departure.direction] ??= <CancelledDeparture>[])
            .add(departure);
      }
      final directions = departuresByDirection.keys.toList()..sort();
      final dialogFuture = _showSupplementaryDialog<void>(
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final l10n = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(l10n.routeDetailCancelledToday),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final direction in directions) ...[
                    Text(
                      l10n.routeDetailDirectionHeading(
                        _taichungCancelledDestinationLabel(detail, direction),
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localizedList(
                        l10n,
                        departuresByDirection[direction]!.map(
                          (departure) => departure.departureTime,
                        ),
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (direction != directions.last)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonAcknowledge),
              ),
            ],
          );
        },
      ).then<void>((_) {});
      _cancelledDepartureDialogFuture = dialogFuture;
      unawaited(
        dialogFuture.whenComplete(() {
          if (identical(_cancelledDepartureDialogFuture, dialogFuture)) {
            _cancelledDepartureDialogFuture = null;
          }
        }),
      );
    } catch (_) {
      // Cancellation data is supplementary; keep route details usable.
    }
  }

  String _taichungCancelledDestinationLabel(
    RouteDetailData detail,
    int direction,
  ) {
    final pathId = direction - 1;
    String? pathName;
    final locale = Localizations.localeOf(context).toLanguageTag();
    for (final path in detail.paths) {
      if (path.pathId == pathId) {
        pathName = path.transitName.stationDisplayForLocale(locale);
        break;
      }
    }
    return localizedRouteDirection(
      AppLocalizations.of(context),
      pathName: pathName,
      pathId: pathId,
      routeName: detail.route.routeName,
    );
  }

  void _playSelectionHaptic() {
    unawaited(AppHaptics.selectionClick());
  }

  void _playSuccessHaptic() {
    unawaited(AppHaptics.lightImpact());
  }

  Future<void> _markCurrentRouteAlertsAsRead() async {
    final routeId = _detail?.route.routeId.trim();
    if (routeId == null || routeId.isEmpty || _alerts.isEmpty) {
      return;
    }
    final controller = AppControllerScope.read(context);
    await controller.syncReadRouteAlertsForRoute(
      routeId,
      activeAlertIds: _alerts.map((alert) => alert.alertId),
      markAsReadAlertIds: _alerts.map((alert) => alert.alertId),
    );
  }

  void _showRouteInfoDialog(RouteDetailData detail) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _RouteInfoDialog(
          detail: detail,
          alerts: _alerts,
          repository: AppControllerScope.read(context).repository,
          provider: widget.provider,
          routeKey: widget.routeKey,
          onFavoriteRoute: _handleRouteFavorite,
          onPinRoute: _isAndroid ? _handlePinnedRouteShortcut : null,
        );
      },
    );
  }

  void _showAlertsDialog() {
    if (_alerts.isEmpty || !mounted) return;
    unawaited(
      _showSupplementaryDialog<void>(
        builder: (context) {
          final theme = Theme.of(context);
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.routeDetailOperationsNotice)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _alerts.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final alert = _alerts[index];
                  return _buildAlertTile(alert, theme);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonClose),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<T?> _showSupplementaryDialog<T>({
    required WidgetBuilder builder,
  }) async {
    _supplementaryDialogDepth += 1;
    _keepPendingRefreshWhileCovered = true;
    try {
      return await showDialog<T>(context: context, builder: builder);
    } finally {
      _supplementaryDialogDepth -= 1;
      if (_supplementaryDialogDepth == 0) {
        _keepPendingRefreshWhileCovered = false;
        final detail = _detail;
        if (mounted && _isRouteVisible && detail != null) {
          final settings = AppControllerScope.read(context).settings;
          _startCountdown(
            detail.hasLiveData
                ? settings.busUpdateTime
                : settings.busErrorUpdateTime,
          );
        }
      }
    }
  }

  Widget _buildAlertTile(RouteAlert alert, ThemeData theme) {
    final effectLabel = alert.effectText;
    final causeLabel = alert.causeText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: alert.statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(alert.title, style: theme.textTheme.titleSmall),
            ),
          ],
        ),
        if (effectLabel.isNotEmpty || causeLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 16),
            child: Wrap(
              spacing: 6,
              children: [
                if (effectLabel.isNotEmpty)
                  Chip(
                    label: Text(effectLabel),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: theme.textTheme.labelSmall,
                    padding: EdgeInsets.zero,
                  ),
                if (causeLabel.isNotEmpty)
                  Chip(
                    label: Text(causeLabel),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: theme.textTheme.labelSmall,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        if (alert.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 16),
            child: Text(alert.description, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }

  RouteDetailData _mergeDetailWithPreviousLiveData(
    RouteDetailData next,
    RouteDetailData previous,
  ) {
    final now = DateTime.now();
    final previousStops = <int, StopInfo>{};
    for (final entry in previous.stopsByPath.entries) {
      for (final stop in entry.value) {
        previousStops[_keyForStop(stop.pathId, stop.stopId)] = stop;
      }
    }

    final mergedStopsByPath = <int, List<StopInfo>>{};
    for (final entry in next.stopsByPath.entries) {
      mergedStopsByPath[entry.key] = entry.value.map((stop) {
        if (hasRealtimeStopData(stop)) {
          return stop;
        }

        final previousStop =
            previousStops[_keyForStop(stop.pathId, stop.stopId)];
        if (previousStop == null || !hasRealtimeStopData(previousStop)) {
          return stop;
        }

        final previousUpdatedAt = _parseStopRealtimeUpdatedAt(
          previousStop.t,
          now,
        );
        if (previousUpdatedAt == null ||
            now.difference(previousUpdatedAt) > _maxMergedPreviousLiveAge) {
          return stop;
        }

        return stop.copyWith(
          sec: previousStop.sec,
          msg: previousStop.msg,
          t: previousStop.t,
          buses: previousStop.buses,
          etas: previousStop.etas,
        );
      }).toList();
    }

    return RouteDetailData(
      route: next.route,
      paths: next.paths,
      stopsByPath: mergedStopsByPath,
      hasLiveData: next.hasLiveData,
      familyRouteIds: next.familyRouteIds,
    );
  }

  DateTime? _parseStopRealtimeUpdatedAt(String? value, DateTime now) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final numericValue = int.tryParse(text);
    if (numericValue != null) {
      if (numericValue > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(
          numericValue,
          isUtc: true,
        ).toLocal();
      }
      if (numericValue > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(
          numericValue * 1000,
          isUtc: true,
        ).toLocal();
      }
    }

    final parsed = DateTime.tryParse(text)?.toLocal();
    if (parsed == null ||
        parsed.isAfter(now.add(const Duration(seconds: 15)))) {
      return null;
    }
    return parsed;
  }

  void _syncTabController(RouteDetailData detail) {
    final pathIds = detail.paths.map((path) => path.pathId).toList();
    if (pathIds.isEmpty) {
      _tabController?.dispose();
      _tabController = null;
      _targetInitialPathId = null;
      _syncSelectedMapPathId(null);
      return;
    }

    final initialIndex = _resolveInitialPathIndex(detail.paths);
    _targetInitialPathId = detail.paths[initialIndex].pathId;
    // Preserve the selection by pathId rather than raw tab index, so a
    // refresh that reorders (or adds/removes) paths cannot silently switch
    // the screen, and the Live Activity, to a different direction.
    final previousSelectedPathId = _currentPathId;
    final preservedIndex = previousSelectedPathId == null
        ? -1
        : pathIds.indexOf(previousSelectedPathId);
    final selectedIndex = _tabController == null
        ? initialIndex
        : (preservedIndex != -1
              ? preservedIndex
              : _tabController!.index.clamp(0, pathIds.length - 1));

    if (_tabController?.length == pathIds.length) {
      _tabController!.index = selectedIndex;
      _syncSelectedMapPathId(detail.paths[selectedIndex].pathId);
      return;
    }

    _tabController?.dispose();
    _tabController = TabController(
      length: pathIds.length,
      vsync: this,
      initialIndex: selectedIndex,
    );
    _syncSelectedMapPathId(detail.paths[selectedIndex].pathId);
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) {
        return;
      }
      if (_destinationStopId != null &&
          _currentPathStops.every(
            (stop) => stop.stopId != _destinationStopId,
          )) {
        final boardingStop = _findStopById(_currentPathStops, _boardingStopId);
        _boardingStopId = boardingStop?.stopId;
        _boardingStopName = boardingStop?.stopName;
        _destinationStopId = null;
        _destinationStopName = null;
        _resetLiveActivityRideState();
      }
      if (_isIOS && _backgroundTripMonitorPaused) {
        _backgroundTripMonitorPaused = false;
      }
      _syncSelectedMapPathId();
      setState(() {});
      _updateDesktopPresence();
      _scrollToInitialStopIfNeeded();
      _maybeScrollToCurrentLocation();
      unawaited(_configureBackgroundTripMonitorIfNeeded());
    });
  }

  int _resolveInitialPathIndex(List<PathInfo> paths) {
    if (paths.isEmpty) {
      return 0;
    }

    final requestedPathId = _requestedPathId;
    if (requestedPathId == null) {
      return _resolvePathIndexFromStopId(paths, _requestedStopId) ?? 0;
    }

    final exactMatch = paths.indexWhere(
      (path) => path.pathId == requestedPathId,
    );
    if (exactMatch != -1) {
      return exactMatch;
    }

    final legacyIndex = requestedPathId;
    if (legacyIndex >= 0 && legacyIndex < paths.length) {
      return legacyIndex;
    }
    return _resolvePathIndexFromStopId(paths, _requestedStopId) ?? 0;
  }

  int? _resolvePathIndexFromStopId(List<PathInfo> paths, int? stopId) {
    final detail = _detail;
    if (detail == null || stopId == null) {
      return null;
    }

    for (var index = 0; index < paths.length; index++) {
      final path = paths[index];
      final stops = detail.stopsByPath[path.pathId] ?? const <StopInfo>[];
      if (stops.any((stop) => stop.stopId == stopId)) {
        return index;
      }
    }
    return null;
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    _remainingSeconds.value = seconds;
    _countdownProgressController
      ..stop()
      ..duration = Duration(seconds: seconds <= 0 ? 1 : seconds)
      ..value = 0;
    if (seconds > 0) {
      unawaited(_countdownProgressController.forward(from: 0));
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_shouldSuspendForegroundRefreshes) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds.value <= 0) {
        timer.cancel();
        unawaited(_refresh());
        return;
      }
      _remainingSeconds.value -= 1;
    });
  }

  void _updateDesktopPresence() {
    if (!mounted) {
      return;
    }
    final controller = AppControllerScope.read(context);
    unawaited(
      desktopDiscordPresenceService.updateScreen(
        settings: controller.settings,
        screenLabel: AppLocalizations.of(context).routeDetailViewRoutePresence,
        provider: widget.provider,
        routeName: _detail?.route.routeName,
        stateLabel: _buildDesktopDiscordArrivalStatus(controller.settings),
      ),
    );
  }

  Future<bool> _handleLaunchAction(AppLaunchAction action) async {
    if (!mounted ||
        action.target != AppLaunchTarget.routeDetail ||
        action.provider != widget.provider ||
        action.routeKey != widget.routeKey) {
      return false;
    }

    final route = ModalRoute.of(context);
    if (route == null) {
      return false;
    }

    final navigator = route.navigator;
    if (navigator == null || !route.isActive) {
      return false;
    }

    if (!route.isCurrent) {
      navigator.popUntil((candidate) => identical(candidate, route));
      if (!mounted || !route.isCurrent) {
        return false;
      }
    }

    await _applyLaunchFocus(
      requestedPathId: action.pathId,
      requestedStopId: action.stopId,
      requestedDestinationPathId: action.destinationPathId,
      requestedDestinationStopId: action.destinationStopId,
    );
    return true;
  }

  Future<void> _applyLaunchFocus({
    required int? requestedPathId,
    required int? requestedStopId,
    required int? requestedDestinationPathId,
    required int? requestedDestinationStopId,
  }) async {
    final detail = _detail;
    final resolvedPathId = _resolveRequestedPathId(
      requestedPathId: requestedPathId,
      requestedStopId: requestedStopId,
    );

    setState(() {
      _requestedPathId = resolvedPathId;
      _requestedStopId = requestedStopId;
      _requestedDestinationPathId = requestedDestinationPathId;
      _requestedDestinationStopId = requestedDestinationStopId;
      _targetInitialPathId = resolvedPathId;
      _didScrollToInitialStop = requestedStopId == null;
      _autoScrolledPathId = null;
    });

    if (detail != null && _tabController != null && resolvedPathId != null) {
      final targetIndex = detail.paths.indexWhere(
        (path) => path.pathId == resolvedPathId,
      );
      if (targetIndex != -1 && _tabController!.index != targetIndex) {
        _tabController!.animateTo(
          targetIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        for (var attempt = 0; attempt < 12; attempt++) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted ||
              _tabController == null ||
              !_tabController!.indexIsChanging) {
            break;
          }
        }
      }
    }

    await _applyRequestedDestinationIfPossible();
    _scrollToInitialStopIfNeeded();
    unawaited(_configureBackgroundTripMonitorIfNeeded());
    unawaited(_refresh());
  }

  int? _resolveRequestedPathId({
    required int? requestedPathId,
    required int? requestedStopId,
  }) {
    final detail = _detail;
    if (detail == null) {
      return requestedPathId;
    }

    if (requestedPathId != null) {
      for (final path in detail.paths) {
        if (path.pathId == requestedPathId) {
          return path.pathId;
        }
      }
      if (requestedPathId >= 0 && requestedPathId < detail.paths.length) {
        return detail.paths[requestedPathId].pathId;
      }
    }

    if (requestedStopId != null) {
      for (final path in detail.paths) {
        final stops = detail.stopsByPath[path.pathId] ?? const <StopInfo>[];
        if (stops.any((stop) => stop.stopId == requestedStopId)) {
          return path.pathId;
        }
      }
    }

    return _currentPathId;
  }

  Future<void> _applyRequestedDestinationIfPossible() async {
    final requestedDestinationStopId = _requestedDestinationStopId;
    final detail = _detail;
    if (requestedDestinationStopId == null || detail == null) {
      return;
    }

    final resolvedPathId = _resolveRequestedPathId(
      requestedPathId: _requestedDestinationPathId,
      requestedStopId: requestedDestinationStopId,
    );
    if (resolvedPathId == null) {
      return;
    }

    if (_tabController != null) {
      final targetIndex = detail.paths.indexWhere(
        (path) => path.pathId == resolvedPathId,
      );
      if (targetIndex != -1 && _tabController!.index != targetIndex) {
        _tabController!.animateTo(
          targetIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        for (var attempt = 0; attempt < 12; attempt++) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted ||
              _tabController == null ||
              !_tabController!.indexIsChanging) {
            break;
          }
        }
      }
    }

    final pathStops = detail.stopsByPath[resolvedPathId] ?? const <StopInfo>[];
    final destinationStop = _findStopById(
      pathStops,
      requestedDestinationStopId,
    );
    if (destinationStop == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requestedDestinationPathId = null;
        _requestedDestinationStopId = null;
      });
      return;
    }

    final boardingStop = _findStopById(
      pathStops,
      _nearestStopByPath[resolvedPathId],
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _resetLiveActivityRideState();
      if (_isIOS) {
        _backgroundTripMonitorPaused = false;
      }
      _requestedDestinationPathId = null;
      _requestedDestinationStopId = null;
      _destinationStopId = destinationStop.stopId;
      _destinationStopName = destinationStop.stopName;
      _boardingStopId = boardingStop?.stopId;
      _boardingStopName = boardingStop?.stopName;
    });

    await _configureBackgroundTripMonitorIfNeeded();
  }

  StopInfo? _findStopById(List<StopInfo> stops, int? stopId) {
    if (stopId == null) {
      return null;
    }
    for (final stop in stops) {
      if (stop.stopId == stopId) {
        return stop;
      }
    }
    return null;
  }

  Widget _buildBottomProgressIndicator() {
    return ValueListenableBuilder<int>(
      valueListenable: _remainingSeconds,
      builder: (context, remainingSeconds, child) {
        final loading = remainingSeconds <= 0 || _isLoading || _isFamilyLoading;
        return AppContentTransition(
          state: loading,
          child: loading
              ? const LinearProgressIndicator(minHeight: 4)
              : AnimatedBuilder(
                  animation: _countdownProgressController,
                  builder: (context, child) => LinearProgressIndicator(
                    value: _countdownProgressController.value,
                    minHeight: 4,
                  ),
                ),
        );
      },
    );
  }

  void _scrollToInitialStopIfNeeded() {
    final requestedStopId = _requestedStopId;
    if (_didScrollToInitialStop ||
        _isScrollingToInitialStop ||
        requestedStopId == null ||
        _detail == null) {
      return;
    }

    final pathId = _currentPathId;
    if (pathId == null) {
      return;
    }
    if (_targetInitialPathId != null && _targetInitialPathId != pathId) {
      return;
    }

    unawaited(_attemptScrollToInitialStop(pathId, requestedStopId));
  }

  Future<void> _attemptScrollToInitialStop(int pathId, int stopId) async {
    _isScrollingToInitialStop = true;
    try {
      final didScroll = await _scrollToStop(pathId, stopId);
      if (didScroll) {
        _didScrollToInitialStop = true;
      }
    } finally {
      _isScrollingToInitialStop = false;
    }
  }

  Future<bool> _scrollToStop(
    int pathId,
    int stopId, {
    double alignment = 0.5,
    Duration duration = const Duration(milliseconds: 360),
  }) async {
    var hasPrimedLazyList = false;
    for (var attempt = 0; attempt < 12; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return false;
      }
      if (_currentPathId != pathId) {
        return false;
      }

      final key = _stopKeys[_keyForStop(pathId, stopId)];
      final targetContext = key?.currentContext;
      if (targetContext == null || !targetContext.mounted) {
        if (!hasPrimedLazyList) {
          hasPrimedLazyList = await _scrollNearStop(
            pathId,
            stopId,
            alignment: alignment,
          );
        }
        continue;
      }

      await Scrollable.ensureVisible(
        targetContext,
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: alignment,
      );
      return true;
    }

    return false;
  }

  Future<bool> _scrollNearStop(
    int pathId,
    int stopId, {
    required double alignment,
  }) async {
    final detail = _detail;
    final scrollController = _scrollControllers[pathId];
    if (detail == null ||
        scrollController == null ||
        !scrollController.hasClients) {
      return false;
    }

    final pathStops = detail.stopsByPath[pathId] ?? const <StopInfo>[];
    final targetIndex = pathStops.indexWhere((stop) => stop.stopId == stopId);
    if (targetIndex == -1) {
      return false;
    }

    final maxScrollExtent = scrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) {
      return false;
    }

    final stopRatio = pathStops.length <= 1
        ? 0.0
        : targetIndex / (pathStops.length - 1);
    final viewport = scrollController.position.viewportDimension;
    final targetOffset = (maxScrollExtent * stopRatio) - (viewport * alignment);
    scrollController.jumpTo(
      targetOffset.clamp(0.0, maxScrollExtent).toDouble(),
    );
    return true;
  }

  int? get _currentPathId {
    final detail = _detail;
    final tabController = _tabController;
    if (detail == null || detail.paths.isEmpty || tabController == null) {
      return null;
    }

    return detail.paths[tabController.index].pathId;
  }

  int _keyForStop(int pathId, int stopId) {
    return Object.hash(pathId, stopId);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _appIsForeground =>
      _appLifecycleState == AppLifecycleState.resumed ||
      _appLifecycleState == AppLifecycleState.inactive;

  bool get _shouldSuspendForegroundRefreshes =>
      !_appIsForeground || !_isRouteVisible;

  bool get _canApplyPendingForegroundResult =>
      _appIsForeground && (_isRouteVisible || _keepPendingRefreshWhileCovered);

  void _pauseForegroundRefreshLoop({bool invalidateRequest = false}) {
    _countdownTimer?.cancel();
    _countdownProgressController.stop();
    if (invalidateRequest) {
      _refreshRequestId += 1;
    }
  }

  @override
  void didPush() {
    _isRouteVisible = true;
  }

  @override
  void didPopNext() {
    _isRouteVisible = true;
    if (_supplementaryDialogDepth > 0) {
      return;
    }
    unawaited(_refresh());
    unawaited(_ensureLocationTracking(requestPermissionIfNeeded: false));
  }

  @override
  void didPushNext() {
    _isRouteVisible = false;
    _pauseForegroundRefreshLoop(
      invalidateRequest: !_keepPendingRefreshWhileCovered,
    );
    if (!_keepPendingRefreshWhileCovered &&
        !_locationTrackingConfiguredForBackground) {
      _pauseForegroundLocationTracking();
    }
  }

  @override
  void didPop() {
    _isRouteVisible = false;
    _pauseForegroundRefreshLoop(invalidateRequest: true);
  }

  void _syncSelectedMapPathId([int? pathId]) {
    final nextPathId = pathId ?? _currentPathId;
    if (_selectedMapPathId.value == nextPathId) {
      return;
    }
    _selectedMapPathId.value = nextPathId;
  }

  void _handleMapPathSelection(int pathId) {
    _syncSelectedMapPathId(pathId);
    final detail = _detail;
    final tabController = _tabController;
    if (detail == null || tabController == null) {
      return;
    }
    final targetIndex = detail.paths.indexWhere(
      (path) => path.pathId == pathId,
    );
    if (targetIndex == -1 || tabController.index == targetIndex) {
      return;
    }
    tabController.animateTo(
      targetIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _requestMapVehicleFocus(String vehicleId) {
    final normalizedVehicleId = normalizeBusVehicleId(vehicleId);
    if (normalizedVehicleId == null) {
      return;
    }
    setState(() {
      _focusedMapVehicleId = normalizedVehicleId;
      _focusedMapVehicleRequest += 1;
    });
  }

  Future<void> _openBusMapSheet({int? pathId, String? vehicleId}) async {
    final detail = _detail;
    final routeId = detail?.route.routeId.trim() ?? '';
    final currentPathId = pathId ?? _currentPathId;
    if (detail == null ||
        detail.paths.isEmpty ||
        routeId.isEmpty ||
        currentPathId == null) {
      return;
    }

    _syncSelectedMapPathId(currentPathId);
    if (vehicleId != null) {
      _requestMapVehicleFocus(vehicleId);
    }
    final controller = AppControllerScope.read(context);
    _keepPendingRefreshWhileCovered = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: true,
        isDismissible: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.55,
            maxChildSize: 1,
            snap: true,
            snapSizes: const [0.82, 1],
            builder: (context, scrollController) {
              return RouteBusMapSheet(
                routeKey: widget.routeKey,
                provider: widget.provider,
                routeId: routeId,
                routeIdHint: widget.routeIdHint,
                routeName: detail.route.routeName,
                routeNameEn: detail.route.routeNameEn,
                paths: detail.paths,
                stopsByPath: detail.stopsByPath,
                familyRouteIds: detail.familyRouteIds,
                familyRouteIdsListenable: _liveMapFamilyRouteIds,
                liveStopsByPathListenable: _liveMapStopsByPath,
                alwaysShowSeconds: controller.settings.alwaysShowSeconds,
                selectedPathIdListenable: _selectedMapPathId,
                focusedVehicleId: _focusedMapVehicleId,
                focusedVehicleRequest: _focusedMapVehicleRequest,
                refreshIntervalSeconds: controller.settings.busUpdateTime,
                dragScrollController: scrollController,
                onSelectedPathChanged: _handleMapPathSelection,
              );
            },
          );
        },
      );
    } finally {
      _keepPendingRefreshWhileCovered = false;
    }
  }

  PathInfo? get _currentPathInfo {
    final detail = _detail;
    final pathId = _currentPathId;
    if (detail == null || pathId == null) {
      return null;
    }
    for (final path in detail.paths) {
      if (path.pathId == pathId) {
        return path;
      }
    }
    return null;
  }

  List<StopInfo> get _currentPathStops {
    final detail = _detail;
    final pathId = _currentPathId;
    if (detail == null || pathId == null) {
      return const <StopInfo>[];
    }
    return detail.stopsByPath[pathId] ?? const <StopInfo>[];
  }

  bool _isDestinationStop(StopInfo stop) {
    return stop.pathId == _currentPathId && stop.stopId == _destinationStopId;
  }

  bool _stopHasAlert(StopInfo stop) {
    if (_alerts.isEmpty) return false;
    final stopIdStr = stop.stopId.toString();
    for (final alert in _alerts) {
      if (alert.stopIds.isNotEmpty && alert.stopIds.contains(stopIdStr)) {
        return true;
      }
    }
    return false;
  }

  Color _alertColorForStop(StopInfo stop) {
    final stopIdStr = stop.stopId.toString();
    Color color = const Color(0xFFF57C00); // default orange
    for (final alert in _alerts) {
      if (alert.stopIds.isNotEmpty && alert.stopIds.contains(stopIdStr)) {
        if (alert.status == 0) return const Color(0xFFD32F2F);
        if (alert.status == 2) color = const Color(0xFFF57C00);
      }
    }
    return color;
  }

  static Future<bool> isOppoOrRealmeAndAndroid16Plus() async {
    if (!_isAndroidPlatform) return false;

    try {
      final androidInfo = await AndroidTripMonitor.getAndroidDeviceInfo();
      if (androidInfo == null) return false;

      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final brand = androidInfo.brand.toLowerCase();

      final isTargetBrand =
          manufacturer.contains('oppo') ||
          brand.contains('oppo') ||
          manufacturer.contains('realme') ||
          brand.contains('realme') ||
          manufacturer.contains('oneplus') ||
          brand.contains('oneplus');

      final isAndroid16Plus = androidInfo.sdkVersion >= 36;

      return isTargetBrand && isAndroid16Plus;
    } catch (e) {
      return false;
    }
  }

  static bool get _isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _maybePromptForBackgroundTripMonitor() async {
    if (_detail == null || _backgroundTripMonitorPromptInProgress) {
      return;
    }
    final controller = AppControllerScope.read(context);
    if (controller.settings.hasSeenRouteBackgroundMonitorPrompt) {
      return;
    }

    _backgroundTripMonitorPromptInProgress = true;
    try {
      final enable = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.routeDetailBackgroundPromptTitle),
            content: Text(l10n.routeDetailBackgroundPromptMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonNotNow),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.commonEnable),
              ),
            ],
          );
        },
      );
      if (!mounted || enable == null) {
        return;
      }

      await controller.updateEnableRouteBackgroundMonitor(
        enable,
        markPromptSeen: true,
      );
      if (enable) {
        final notificationGranted =
            await TripMonitorNotifications.requestPermission();
        if (mounted && !notificationGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                ).routeDetailBackgroundNotificationPermission,
              ),
            ),
          );
        }
        await _configureBackgroundTripMonitorIfNeeded(
          forcePermissionCheck: true,
        );
        final isOppoOrRealme = await isOppoOrRealmeAndAndroid16Plus();
        if (isOppoOrRealme && mounted) {
          // show note blahblah
          await showDialog<void>(
            context: context,
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return AlertDialog(
                title: Text(l10n.routeDetailOppoPromptTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.routeDetailOppoPromptMessage),
                    const SizedBox(height: 8),
                    const Image(
                      image: AssetImage('assets/oppo_enable_live_alert.jpg'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      AndroidTripMonitor.openNotificationChannelSettings();
                    },
                    child: Text(l10n.commonOpenSettings),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonOkay),
                  ),
                ],
              );
            },
          );
        }
        await _maybePromptForSamsungLiveNotifications(
          allowWhileBackgroundPrompt: true,
        );
        await _maybePromptForDestinationSelection();
      }
    } finally {
      _backgroundTripMonitorPromptInProgress = false;
    }
  }

  Future<void> _maybePromptForSamsungLiveNotifications({
    bool allowWhileBackgroundPrompt = false,
  }) async {
    if (_samsungLiveNotificationPromptInProgress ||
        (!allowWhileBackgroundPrompt &&
            _backgroundTripMonitorPromptInProgress) ||
        !mounted) {
      return;
    }

    _samsungLiveNotificationPromptInProgress = true;
    try {
      final shouldShow = await SamsungLiveNotificationPromptService.shouldShow(
        backgroundTripMonitorEnabled: AppControllerScope.read(
          context,
        ).settings.enableRouteBackgroundMonitor,
      );
      if (!shouldShow || !mounted) {
        return;
      }

      final openSettings = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.routeDetailSamsungPromptTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.routeDetailSamsungPromptMessage),
                  const SizedBox(height: 12),
                  Text(l10n.routeDetailSamsungDeveloperSteps),
                  const SizedBox(height: 12),
                  Text(l10n.routeDetailSamsungLiveSteps),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonAcknowledge),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.commonOpenSettings),
              ),
            ],
          );
        },
      );
      await SamsungLiveNotificationPromptService.markShown();
      if (openSettings != true || !mounted) {
        return;
      }

      final didOpen =
          await AndroidTripMonitor.openSamsungLiveNotificationSettings();
      if (!didOpen && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).routeDetailOpenSettingsFailed,
            ),
          ),
        );
      }
    } finally {
      _samsungLiveNotificationPromptInProgress = false;
    }
  }

  TripMonitorSession? _buildTripMonitorSession({
    RouteDetailData? detail,
    PathInfo? pathInfo,
    List<StopInfo>? pathStops,
  }) {
    final resolvedDetail = detail ?? _detail;
    final resolvedPathInfo = pathInfo ?? _currentPathInfo;
    if (resolvedDetail == null || resolvedPathInfo == null) {
      return null;
    }
    final resolvedStops =
        pathStops ??
        resolvedDetail.stopsByPath[resolvedPathInfo.pathId] ??
        const <StopInfo>[];
    if (resolvedStops.isEmpty) {
      return null;
    }
    final fallbackBoardingStop = _boardingStopId == null
        ? _currentBoardingCandidateStop()
        : null;
    return TripMonitorSession(
      providerName: widget.provider.name,
      routeKey: widget.routeKey,
      routeId: resolvedDetail.route.routeId,
      routeName: resolvedDetail.route.routeName,
      pathId: resolvedPathInfo.pathId,
      pathName: resolvedPathInfo.name,
      appInForeground: _appIsForeground,
      backgroundLocationAlwaysGranted: _backgroundLocationAlwaysGranted,
      boardingStopId: _boardingStopId ?? fallbackBoardingStop?.stopId,
      boardingStopName: _boardingStopName ?? fallbackBoardingStop?.stopName,
      destinationStopId: _destinationStopId,
      destinationStopName: _destinationStopName,
      initialLatitude: _lastPosition?.latitude,
      initialLongitude: _lastPosition?.longitude,
      stops: resolvedStops
          .map(
            (stop) => TripMonitorStop(
              stopId: stop.stopId,
              stopName: stop.stopName,
              sequence: stop.sequence,
              lat: stop.lat,
              lon: stop.lon,
            ),
          )
          .toList(),
    );
  }

  Future<void> _syncBackgroundTripMonitorPausedState({
    TripMonitorSession? session,
  }) async {
    if (!_isAndroid) {
      return;
    }
    final resolvedSession = session ?? _buildTripMonitorSession();
    if (resolvedSession == null) {
      if (_backgroundTripMonitorPaused) {
        setState(() {
          _backgroundTripMonitorPaused = false;
        });
      }
      return;
    }
    final paused = await AndroidTripMonitor.isPausedFor(resolvedSession);
    if (!mounted) {
      return;
    }
    if (_backgroundTripMonitorPaused != paused) {
      setState(() {
        _backgroundTripMonitorPaused = paused;
      });
    }
  }

  Future<void> _setBackgroundTripMonitorPaused(
    bool paused, {
    String reason = 'user',
    bool showFeedback = true,
  }) async {
    if (!AppControllerScope.read(
      context,
    ).settings.enableRouteBackgroundMonitor) {
      return;
    }

    final session = _buildTripMonitorSession();
    if (paused) {
      if (_isAndroid && session != null) {
        await AndroidTripMonitor.pause(session, reason: reason);
      }
      if (_isIOS) {
        await _stopLiveActivity();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _backgroundTripMonitorPaused = true;
      });
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).routeDetailTripPaused),
          ),
        );
      }
      return;
    }

    if (_isAndroid) {
      await AndroidTripMonitor.resume();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _backgroundTripMonitorPaused = false;
    });
    await _configureBackgroundTripMonitorIfNeeded();
    if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).routeDetailTripResumed),
        ),
      );
    }
  }

  Future<void> _configureBackgroundTripMonitorIfNeeded({
    bool forcePermissionCheck = false,
  }) async {
    try {
      await _configureBackgroundTripMonitorUnchecked(
        forcePermissionCheck: forcePermissionCheck,
      );
    } catch (_) {
      // Lifecycle transitions can temporarily detach location/notification APIs.
    }
  }

  Future<void> _configureBackgroundTripMonitorUnchecked({
    required bool forcePermissionCheck,
  }) async {
    if (!mounted) {
      return;
    }

    final controller = AppControllerScope.read(context);
    if (!controller.settings.enableRouteBackgroundMonitor) {
      _backgroundTripMonitorReady = false;
      if (_isAndroid) {
        await AndroidTripMonitor.stop();
      }
      if (_isIOS) {
        await _stopLiveActivity();
        await _ensureLocationTracking(requestPermissionIfNeeded: false);
      }
      return;
    }

    final detail = _detail;
    final pathInfo = _currentPathInfo;
    if (detail == null || pathInfo == null) {
      if (_isIOS) {
        await _stopLiveActivity();
      }
      return;
    }

    if (_backgroundTripMonitorPaused && _isIOS) {
      await _stopLiveActivity();
      return;
    }

    if (_isIOS) {
      if (!_backgroundTripMonitorReady || forcePermissionCheck) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _backgroundTripMonitorReady = false;
          await _stopLiveActivity();
          if (forcePermissionCheck && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(
                    context,
                  ).routeDetailLocationServiceRequired,
                ),
              ),
            );
          }
          return;
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied && forcePermissionCheck) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _backgroundTripMonitorReady = false;
          await _stopLiveActivity();
          if (!forcePermissionCheck) {
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(
                    context,
                  ).routeDetailLocationPermissionRequired,
                ),
              ),
            );
          }
          return;
        }
        if (permission != LocationPermission.always) {
          _backgroundTripMonitorReady = false;
          await _stopLiveActivity();
          if (!forcePermissionCheck) {
            return;
          }
          final openSettings = await _showBackgroundLocationExplainer();
          if (!mounted || openSettings != true) {
            return;
          }
          _awaitingBackgroundLocationPermission = true;
          await Geolocator.openAppSettings();
          return;
        }
        _backgroundTripMonitorReady = true;
      }

      await _ensureLocationTracking(requestPermissionIfNeeded: false);
      await _syncLiveActivityForBackgroundMonitor(detail, pathInfo);
      return;
    }

    // Desktop / Web — basic notification support (no background location tracking).
    if (_isDesktop || kIsWeb) {
      if (!_backgroundTripMonitorReady || forcePermissionCheck) {
        final granted = await TripMonitorNotifications.requestPermission();
        if (granted) {
          _backgroundTripMonitorReady = true;
        } else {
          _backgroundTripMonitorReady = false;
          if (forcePermissionCheck && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(
                    context,
                  ).routeDetailNotificationPermissionRequired,
                ),
              ),
            );
          }
          return;
        }
      }
      return;
    }

    if (!_isAndroid) {
      return;
    }

    if (!_backgroundTripMonitorReady || forcePermissionCheck) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && forcePermissionCheck) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!forcePermissionCheck) {
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                ).routeDetailLocationPermissionRequired,
              ),
            ),
          );
        }
        return;
      }
      final hasAlwaysPermission = permission == LocationPermission.always;
      if (_backgroundLocationAlwaysGranted != hasAlwaysPermission) {
        _backgroundLocationAlwaysGranted = hasAlwaysPermission;
      }
      if (forcePermissionCheck && !hasAlwaysPermission) {
        final shouldUpgrade =
            await _showAndroidBackgroundLocationUpgradePrompt() ?? false;
        if (shouldUpgrade) {
          final requestStatus =
              await AndroidTripMonitor.requestBackgroundLocationPermission();
          if (!mounted) {
            return;
          }
          if (requestStatus ==
              AndroidBackgroundLocationPermissionRequestStatus.openedSettings) {
            _awaitingBackgroundLocationPermission = true;
            return;
          }
        }
        permission = await Geolocator.checkPermission();
        final updatedHasAlwaysPermission =
            permission == LocationPermission.always;
        if (_backgroundLocationAlwaysGranted != updatedHasAlwaysPermission) {
          _backgroundLocationAlwaysGranted = updatedHasAlwaysPermission;
        }
        if (!updatedHasAlwaysPermission && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                ).routeDetailBackgroundLocationFallback,
              ),
            ),
          );
        }
      }
      await TripMonitorNotifications.requestPermission();
      _backgroundTripMonitorReady = true;
    }

    await _ensureLocationTracking(requestPermissionIfNeeded: false);

    final pathStops = detail.stopsByPath[pathInfo.pathId] ?? const <StopInfo>[];
    if (pathStops.isEmpty) {
      return;
    }
    if (_boardingStopId == null) {
      final boardingStop = _currentBoardingCandidateStop();
      if (boardingStop != null) {
        _boardingStopId = boardingStop.stopId;
        _boardingStopName = boardingStop.stopName;
      }
    }
    if (_destinationStopId != null &&
        pathStops.every((stop) => stop.stopId != _destinationStopId)) {
      final boardingStop = _findStopById(pathStops, _boardingStopId);
      setState(() {
        _boardingStopId = boardingStop?.stopId;
        _boardingStopName = boardingStop?.stopName;
        _destinationStopId = null;
        _destinationStopName = null;
        _resetLiveActivityRideState();
      });
    }

    final session = _buildTripMonitorSession(
      detail: detail,
      pathInfo: pathInfo,
      pathStops: pathStops,
    );
    if (session == null) {
      return;
    }
    if (_backgroundTripMonitorPaused) {
      return;
    }

    // Prime the service as soon as we have a valid route session so the
    // foreground/background transition is not the first cold start.
    await AndroidTripMonitor.startOrUpdate(session);
    await _syncBackgroundTripMonitorPausedState(session: session);
  }

  Future<bool?> _showBackgroundLocationExplainer() {
    final l10n = AppLocalizations.of(context);
    final contentText = _isIOS
        ? l10n.routeDetailBackgroundLocationIos
        : l10n.routeDetailBackgroundLocationAndroid;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.routeDetailBackgroundLocationTitle),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonLater),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonOpenSettings),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showAndroidBackgroundLocationUpgradePrompt() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.routeDetailAlwaysLocationTitle),
          content: Text(l10n.routeDetailAlwaysLocationMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonNotNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.routeDetailEnableAction),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleReturnedFromAndroidBackgroundLocationSettings() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final hasAlwaysPermission = permission == LocationPermission.always;
    if (_backgroundLocationAlwaysGranted != hasAlwaysPermission) {
      _backgroundLocationAlwaysGranted = hasAlwaysPermission;
    }
    if (!hasAlwaysPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).routeDetailBackgroundLocationFallback,
          ),
        ),
      );
    }
    await _configureBackgroundTripMonitorIfNeeded();
  }

  Future<void> _maybePromptForDestinationSelection() async {
    if (_destinationPromptShown ||
        _destinationStopId != null ||
        _currentPathStops.isEmpty ||
        !AppControllerScope.read(
          context,
        ).settings.enableRouteBackgroundMonitor) {
      return;
    }
    _destinationPromptShown = true;

    final shouldPick = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.routeDetailDestinationPromptTitle),
          content: Text(l10n.routeDetailDestinationPromptMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonLater),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonChooseStop),
            ),
          ],
        );
      },
    );

    if (shouldPick == true) {
      await _pickDestinationStop();
    }
  }

  Future<StopInfo?> _pickTripMonitorStop({
    required String title,
    required int? selectedStopId,
    required IconData selectedIcon,
    int? blockedStopId,
    String? blockedReason,
  }) async {
    final pathStops = _currentPathStops;
    if (pathStops.isEmpty) {
      return null;
    }

    return showModalBottomSheet<StopInfo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: pathStops.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final stop = pathStops[index];
                      final isBlocked =
                          blockedStopId != null && stop.stopId == blockedStopId;
                      final subtitleParts = <String>[
                        AppLocalizations.of(context).stopSequence(index + 1),
                      ];
                      if (isBlocked && blockedReason != null) {
                        subtitleParts.add(blockedReason);
                      }
                      return ListTile(
                        enabled: !isBlocked,
                        title: TransitStationName(name: stop.transitName),
                        subtitle: Text(subtitleParts.join(' · ')),
                        trailing: isBlocked
                            ? const Icon(Icons.block_rounded)
                            : stop.stopId == selectedStopId
                            ? Icon(selectedIcon)
                            : null,
                        onTap: isBlocked
                            ? null
                            : () => Navigator.of(context).pop(stop),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickBoardingStop() async {
    final pickedStop = await _pickTripMonitorStop(
      title: AppLocalizations.of(context).routeDetailSetBoardingStop,
      selectedStopId: _boardingStopId,
      selectedIcon: Icons.directions_bus_rounded,
      blockedStopId: _destinationStopId,
      blockedReason: AppLocalizations.of(context).routeDetailBlockedDestination,
    );
    if (!mounted || pickedStop == null) {
      return;
    }

    await _setBoardingStop(pickedStop);
  }

  Future<void> _pickDestinationStop() async {
    final pickedStop = await _pickTripMonitorStop(
      title: AppLocalizations.of(context).routeDetailSetDestinationAlert,
      selectedStopId: _destinationStopId,
      selectedIcon: Icons.flag_rounded,
      blockedStopId: _resolvedBoardingStop()?.stopId,
      blockedReason: AppLocalizations.of(context).routeDetailBlockedBoarding,
    );
    if (!mounted || pickedStop == null) {
      return;
    }

    if (pickedStop.stopId == _resolvedBoardingStop()?.stopId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).routeDetailSameBoardingDestination,
          ),
        ),
      );
      return;
    }
    await _setDestinationStop(pickedStop);
  }

  Future<void> _setBoardingStop(StopInfo stop) async {
    setState(() {
      _resetLiveActivityRideState();
      if (_isIOS) {
        _backgroundTripMonitorPaused = false;
      }
      _boardingStopId = stop.stopId;
      _boardingStopName = stop.stopName;
    });
    await _configureBackgroundTripMonitorIfNeeded();
    if (!mounted) {
      return;
    }
    _playSuccessHaptic();
    final stopName = stop.transitName.stationDisplayForLocale(
      Localizations.localeOf(context).toLanguageTag(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).routeDetailBoardingStopSet(stopName),
        ),
      ),
    );
  }

  Future<void> _setDestinationStop(StopInfo stop) async {
    final boardingStop = _resolvedBoardingStop();
    setState(() {
      _resetLiveActivityRideState();
      if (_isIOS) {
        _backgroundTripMonitorPaused = false;
      }
      _boardingStopId = boardingStop?.stopId;
      _boardingStopName = boardingStop?.stopName;
      _destinationStopId = stop.stopId;
      _destinationStopName = stop.stopName;
    });
    await _configureBackgroundTripMonitorIfNeeded();
    if (!mounted) {
      return;
    }
    _playSuccessHaptic();
    final stopName = stop.transitName.stationDisplayForLocale(
      Localizations.localeOf(context).toLanguageTag(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).routeDetailDestinationSet(stopName),
        ),
      ),
    );
  }

  Future<void> _clearBoardingStop() async {
    if (_boardingStopId == null) {
      return;
    }
    final fallbackBoardingStop = _currentBoardingCandidateStop();
    setState(() {
      _resetLiveActivityRideState();
      if (_isIOS) {
        _backgroundTripMonitorPaused = false;
      }
      _boardingStopId = null;
      _boardingStopName = null;
    });
    await _configureBackgroundTripMonitorIfNeeded();
    if (!mounted) {
      return;
    }
    _playSelectionHaptic();
    final message = fallbackBoardingStop == null
        ? AppLocalizations.of(context).routeDetailManualBoardingCleared
        : AppLocalizations.of(context).routeDetailUsingCurrentLocation;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _clearDestinationStop() async {
    if (_destinationStopId == null) {
      return;
    }
    setState(() {
      _resetLiveActivityRideState();
      if (_isIOS) {
        _backgroundTripMonitorPaused = false;
      }
      _destinationStopId = null;
      _destinationStopName = null;
    });
    await _configureBackgroundTripMonitorIfNeeded();
    _playSelectionHaptic();
  }

  ScrollController _scrollControllerForPath(int pathId) {
    return _scrollControllers.putIfAbsent(pathId, ScrollController.new);
  }

  void _syncWakelock(bool enable) {
    if (_wakelockEnabled == enable) {
      return;
    }
    _wakelockEnabled = enable;
    unawaited(_setWakelock(enable));
  }

  Future<void> _setWakelock(bool enable) async {
    try {
      await WakelockPlus.toggle(enable: enable);
    } catch (_) {
      // Ignore unsupported platform or plugin errors.
    }
  }

  Future<void> _ensureLocationTracking({
    bool requestPermissionIfNeeded = true,
  }) {
    if (!mounted) {
      return Future<void>.value();
    }
    final controller = AppControllerScope.read(context);
    final enableBackgroundLocationStream =
        _isIOS &&
        controller.settings.enableRouteBackgroundMonitor &&
        _backgroundTripMonitorReady;
    if (_didAttemptLocationTracking &&
        _locationTrackingConfiguredForBackground ==
            enableBackgroundLocationStream) {
      return Future<void>.value();
    }

    final inFlight = _locationTrackingInFlight;
    if (inFlight != null &&
        _locationTrackingInFlightForBackground ==
            enableBackgroundLocationStream) {
      return inFlight;
    }

    final generation = ++_locationTrackingGeneration;
    final future = _configureLocationTracking(
      generation: generation,
      enableBackgroundLocationStream: enableBackgroundLocationStream,
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    );
    _locationTrackingInFlight = future;
    _locationTrackingInFlightForBackground = enableBackgroundLocationStream;
    return future.whenComplete(() {
      if (identical(_locationTrackingInFlight, future)) {
        _locationTrackingInFlight = null;
        _locationTrackingInFlightForBackground = null;
      }
    });
  }

  Future<void> _configureLocationTracking({
    required int generation,
    required bool enableBackgroundLocationStream,
    required bool requestPermissionIfNeeded,
  }) async {
    try {
      await _configureLocationTrackingUnchecked(
        generation: generation,
        enableBackgroundLocationStream: enableBackgroundLocationStream,
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      );
    } catch (_) {
      // Location plugins can detach briefly while Android changes lifecycle.
    }
  }

  Future<void> _configureLocationTrackingUnchecked({
    required int generation,
    required bool enableBackgroundLocationStream,
    required bool requestPermissionIfNeeded,
  }) async {
    if (!_canContinueLocationTracking(
      generation,
      allowBackground: enableBackgroundLocationStream,
    )) {
      return;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled ||
        !_canContinueLocationTracking(
          generation,
          allowBackground: enableBackgroundLocationStream,
        )) {
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (!_canContinueLocationTracking(
      generation,
      allowBackground: enableBackgroundLocationStream,
    )) {
      return;
    }
    if (permission == LocationPermission.denied) {
      if (!requestPermissionIfNeeded) {
        return;
      }
      permission = await Geolocator.requestPermission();
      if (!_canContinueLocationTracking(
        generation,
        allowBackground: enableBackgroundLocationStream,
      )) {
        return;
      }
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (!_canContinueLocationTracking(
      generation,
      allowBackground: enableBackgroundLocationStream,
    )) {
      return;
    }
    if (lastKnown != null) {
      _updateNearestStops(lastKnown);
    }

    Position? current;
    try {
      current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      current = null;
    }
    if (!_canContinueLocationTracking(
      generation,
      allowBackground: enableBackgroundLocationStream,
    )) {
      return;
    }
    if (current != null) {
      _updateNearestStops(current);
    }

    final locationSettings = enableBackgroundLocationStream
        ? AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            pauseLocationUpdatesAutomatically: false,
            activityType: ActivityType.automotiveNavigation,
            showBackgroundLocationIndicator: false,
            allowBackgroundLocationUpdates: true,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );

    await _positionSubscription?.cancel();
    if (!_canContinueLocationTracking(
      generation,
      allowBackground: enableBackgroundLocationStream,
    )) {
      return;
    }
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            if (_canContinueLocationTracking(
              generation,
              allowBackground: enableBackgroundLocationStream,
            )) {
              _updateNearestStops(position);
            }
          },
          onError: (_) {},
        );
    _didAttemptLocationTracking = true;
    _locationTrackingConfiguredForBackground = enableBackgroundLocationStream;
  }

  bool _canContinueLocationTracking(
    int generation, {
    required bool allowBackground,
  }) {
    return mounted &&
        generation == _locationTrackingGeneration &&
        (allowBackground || _appIsForeground);
  }

  void _pauseForegroundLocationTracking() {
    _locationTrackingGeneration += 1;
    _locationTrackingInFlight = null;
    _locationTrackingInFlightForBackground = null;
    _didAttemptLocationTracking = false;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  void _recalculateNearestStops() {
    final lastPosition = _lastPosition;
    if (lastPosition != null) {
      _updateNearestStops(lastPosition);
    }
  }

  void _updateNearestStops(Position position) {
    if (!mounted) {
      return;
    }
    final previousPosition = _lastPosition;
    _lastPosition = position;
    final detail = _detail;
    if (detail == null) {
      return;
    }

    final nearestByPath = <int, int>{};
    for (final path in detail.paths) {
      final pathStops = detail.stopsByPath[path.pathId] ?? const <StopInfo>[];
      StopInfo? nearestStop;
      double? nearestDistance;

      for (final stop in pathStops) {
        if (stop.lat == 0 && stop.lon == 0) {
          continue;
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          stop.lat,
          stop.lon,
        );
        if (nearestDistance == null || distance < nearestDistance) {
          nearestDistance = distance;
          nearestStop = stop;
        }
      }

      if (nearestStop != null) {
        nearestByPath[path.pathId] = nearestStop.stopId;
      }
    }

    if (!mapEquals(_nearestStopByPath, nearestByPath)) {
      setState(() {
        _nearestStopByPath = nearestByPath;
      });
      if (_destinationStopId != null && _boardingStopId == null) {
        final boardingStop = _currentBoardingCandidateStop();
        if (boardingStop != null) {
          setState(() {
            _boardingStopId = boardingStop.stopId;
            _boardingStopName = boardingStop.stopName;
          });
          unawaited(_configureBackgroundTripMonitorIfNeeded());
        }
      }
      _updateDesktopPresence();
    }
    _maybeScrollToCurrentLocation();
    if (_isAndroid &&
        previousPosition == null &&
        !_backgroundLocationAlwaysGranted &&
        _backgroundTripMonitorReady &&
        AppControllerScope.read(
          context,
        ).settings.enableRouteBackgroundMonitor) {
      unawaited(_configureBackgroundTripMonitorIfNeeded());
    }
    unawaited(_maybeRefreshBackgroundTripMonitor());
  }

  StopInfo? _currentBoardingCandidateStop() {
    final pathId = _currentPathId;
    if (pathId == null) {
      return null;
    }
    final nearestStopId = _nearestStopByPath[pathId];
    if (nearestStopId == null) {
      return null;
    }
    for (final stop in _currentPathStops) {
      if (stop.stopId == nearestStopId) {
        return stop;
      }
    }
    return null;
  }

  StopInfo? _resolvedBoardingStop() {
    return _findStopById(_currentPathStops, _boardingStopId) ??
        _currentBoardingCandidateStop();
  }

  String? _buildDesktopDiscordArrivalStatus(AppSettings settings) {
    if (!settings.desktopDiscordShowScreen) {
      return null;
    }

    final stop = _currentBoardingCandidateStop();
    if (stop == null) {
      return null;
    }

    final message = stop.msg?.trim() ?? '';
    final l10n = AppLocalizations.of(context);
    if (message.isNotEmpty) {
      return switch (message) {
        '即將進站' => l10n.routeDetailBusApproaching,
        '進站中' => l10n.etaArriving,
        '末班駛離' => l10n.routeDetailEtaLastBusPassed,
        _ => message,
      };
    }

    final seconds = effectiveStopEtaSeconds(stop);
    if (seconds == null) {
      return null;
    }
    if (seconds <= 0) {
      return l10n.etaArriving;
    }
    if (seconds < 60) {
      return l10n.routeDetailBusApproaching;
    }

    return l10n.routeDetailEtaApproxMinutes(seconds ~/ 60);
  }

  void _maybeScrollToCurrentLocation() {
    if (_requestedStopId != null) {
      return;
    }

    final pathId = _currentPathId;
    if (pathId == null || _autoScrolledPathId == pathId) {
      return;
    }
    final stopId = _nearestStopByPath[pathId];
    if (stopId == null) {
      return;
    }

    _autoScrolledPathId = pathId;
    unawaited(_scrollToStop(pathId, stopId));
  }

  bool _isInitialStop(StopInfo stop) {
    if (_requestedStopId != stop.stopId) {
      return false;
    }
    return _targetInitialPathId == null || _targetInitialPathId == stop.pathId;
  }

  bool _isNearestStop(StopInfo stop) {
    return _nearestStopByPath[stop.pathId] == stop.stopId;
  }

  void _resetLiveActivityRideState() {
    _liveActivityBoardingWindowOpen = false;
    _liveActivityRideConfirmed = false;
    _liveActivityBoardingWindowOpenedAt = null;
    _liveActivityBoardingArrivalAlertSent = false;
    _liveActivityDestinationSetupAlertSent = false;
    _liveActivityDestinationAlertStage = 0;
    _iosBoardingCheckPromptSent = false;
    _liveActivityLastNearestStopIndex = null;
    _liveActivityRidingVehicleId = null;
  }

  Future<void> _startLiveActivity(
    PathInfo pathInfo,
    LiveActivityDisplayState displayState,
  ) async {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final didStart = await LiveActivityService.startLiveActivity(
      routeName: _detail?.route.transitName.displayForLocale(locale) ?? '',
      pathName: pathInfo.transitName.displayForLocale(locale),
      routeKey: widget.routeKey,
      provider: widget.provider.name,
      pathId: pathInfo.pathId,
      state: displayState,
    );

    if (!mounted) {
      return;
    }

    if (didStart) {
      setState(() {
        _liveActivityActive = true;
        _liveActivityId = LiveActivityService.activeActivityId;
        _liveActivityStopId = displayState.stopId;
        _liveActivityPathId = pathInfo.pathId;
        _liveActivityRouteKey = widget.routeKey;
        _liveActivityProviderName = widget.provider.name;
      });
    } else {
      setState(() {
        _liveActivityActive = false;
        _liveActivityId = null;
        _liveActivityStopId = null;
        _liveActivityPathId = null;
        _liveActivityRouteKey = null;
        _liveActivityProviderName = null;
      });
    }
  }

  Future<void> _stopLiveActivity() async {
    await TripMonitorNotifications.cancelBoardingCheckPrompt();
    // Only end the activity this screen started; another route screen may
    // own the currently visible Live Activity.
    if (_liveActivityId != null) {
      await LiveActivityService.endLiveActivity(
        ownerActivityId: _liveActivityId,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _resetLiveActivityRideState();
      _liveActivityActive = false;
      _liveActivityId = null;
      _liveActivityStopId = null;
      _liveActivityPathId = null;
      _liveActivityRouteKey = null;
      _liveActivityProviderName = null;
    });
  }

  int? _resolveNearestStopIndex(List<StopInfo> pathStops) {
    if (pathStops.isEmpty) {
      return null;
    }

    final nearestStopId = _nearestStopByPath[_currentPathId];
    if (nearestStopId != null) {
      final index = pathStops.indexWhere(
        (stop) => stop.stopId == nearestStopId,
      );
      if (index != -1) {
        return index;
      }
    }

    final position = _lastPosition;
    if (position == null) {
      return null;
    }

    var nearestIndex = -1;
    double? nearestDistance;
    for (var index = 0; index < pathStops.length; index++) {
      final stop = pathStops[index];
      if (stop.lat == 0 && stop.lon == 0) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        stop.lat,
        stop.lon,
      );
      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    return nearestIndex == -1 ? null : nearestIndex;
  }

  String _displayEtaText(StopInfo stop, {String? vehicleId}) {
    final l10n = AppLocalizations.of(context);
    final message =
        effectiveStopEtaMessageForVehicle(stop, vehicleId)?.trim() ?? '';
    if (message.isNotEmpty) {
      if (message.contains('進站') || message.contains('到站')) {
        return l10n.etaArriving;
      }
      if (message.contains('即將')) {
        return l10n.routeDetailBusApproaching;
      }
      if (message.contains('未發車')) {
        return l10n.routeDetailEtaNotDeparted;
      }
      if (message.contains('末班')) {
        return l10n.routeDetailEtaLastBusPassed;
      }
      return message;
    }

    final seconds = effectiveStopEtaSecondsForVehicle(stop, vehicleId);
    if (seconds == null) {
      return '--';
    }
    if (seconds <= 0) {
      return l10n.etaArriving;
    }
    if (seconds < 60) {
      return l10n.etaSeconds(seconds);
    }
    return l10n.etaMinutes(seconds ~/ 60);
  }

  bool _isImmediateEtaText(String? etaText) {
    final value = etaText?.trim() ?? '';
    final l10n = AppLocalizations.of(context);
    return value == l10n.etaArriving ||
        value == l10n.routeDetailBusApproaching ||
        value.contains('進站') ||
        value.contains('即將');
  }

  bool _isBusApproachingStop(StopInfo stop) {
    final message = stop.msg?.trim() ?? '';
    final seconds = effectiveStopEtaSeconds(stop);
    return stop.buses.isNotEmpty ||
        stop.etas.any((eta) => normalizeBusVehicleId(eta.vehicleId) != null) ||
        (seconds != null && seconds <= 0) ||
        message.contains('進站') ||
        message.contains('到站');
  }

  int? _findClosestBusIndex(List<StopInfo> stops, int nearestIndex) {
    final busIndexes = <int>[];
    for (var index = 0; index < stops.length; index++) {
      if (_isBusApproachingStop(stops[index])) {
        busIndexes.add(index);
      }
    }
    if (busIndexes.isEmpty) {
      return null;
    }

    final behindOrAtUser = busIndexes.where((index) => index <= nearestIndex);
    if (behindOrAtUser.isNotEmpty) {
      return behindOrAtUser.reduce(math.max);
    }
    return busIndexes.reduce(math.min);
  }

  int _resolveBoardingIndex(
    List<StopInfo> pathStops,
    int nearestIndex,
    int destinationIndex,
  ) {
    final explicitBoardingIndex = _boardingStopId == null
        ? -1
        : pathStops.indexWhere((stop) => stop.stopId == _boardingStopId);
    final fallbackIndex = explicitBoardingIndex == -1
        ? nearestIndex
        : explicitBoardingIndex;
    return math.min(fallbackIndex, destinationIndex);
  }

  double? _distanceToStop(StopInfo stop) {
    final position = _lastPosition;
    if (position == null || (stop.lat == 0 && stop.lon == 0)) {
      return null;
    }

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      stop.lat,
      stop.lon,
    );
  }

  bool _updateLiveActivityRideState({
    required int nearestIndex,
    required int boardingIndex,
    required int? busStopsUntilBoarding,
    required String boardingEtaText,
    required double? boardingDistanceMeters,
    required int? busIndex,
    required String? busVehicleId,
  }) {
    final userNearBoardingStop =
        (boardingDistanceMeters != null && boardingDistanceMeters <= 180.0) ||
        nearestIndex == boardingIndex;
    final busNearBoardingStop =
        (busStopsUntilBoarding != null && busStopsUntilBoarding <= 1) ||
        _isImmediateEtaText(boardingEtaText);
    if (userNearBoardingStop && busNearBoardingStop) {
      _liveActivityBoardingWindowOpenedAt ??= DateTime.now();
      _liveActivityBoardingWindowOpen = true;
    }

    final previousNearest = _liveActivityLastNearestStopIndex;
    _liveActivityLastNearestStopIndex = nearestIndex;
    final movedForward =
        previousNearest != null && nearestIndex > previousNearest;
    final busNearUser =
        busIndex != null && (nearestIndex - busIndex).abs() <= 1;

    if (!_liveActivityRideConfirmed &&
        _liveActivityBoardingWindowOpen &&
        movedForward &&
        nearestIndex >= boardingIndex &&
        busNearUser) {
      _liveActivityRideConfirmed = true;
      _liveActivityRidingVehicleId = normalizeBusVehicleId(busVehicleId);
      unawaited(TripMonitorNotifications.cancelBoardingCheckPrompt());
    }

    return _liveActivityRideConfirmed;
  }

  String _pathStatusPrefix(String pathName) {
    final trimmed = pathName.trim();
    return trimmed.isEmpty
        ? AppLocalizations.of(context).routeDetailTripActive
        : trimmed;
  }

  String? _buildBusDistanceSummary(int? stopsAway) {
    if (stopsAway == null) {
      return null;
    }
    if (stopsAway == 0) {
      return AppLocalizations.of(context).routeDetailBusApproaching;
    }
    return AppLocalizations.of(context).routeDetailBusStopsAway(stopsAway);
  }

  // ignore: unused_element
  String _buildNearestStatusText({
    required String pathName,
    required StopInfo nearestStop,
    required String nearestEtaText,
    required int? busStopsAway,
  }) {
    final parts = <String>[
      _pathStatusPrefix(pathName),
      AppLocalizations.of(
        context,
      ).routeDetailNearestStopValue(_displayStopName(context, nearestStop)),
    ];
    if (nearestEtaText != '--') {
      parts.add(nearestEtaText);
    }
    final busDistanceSummary = _buildBusDistanceSummary(busStopsAway);
    if (busDistanceSummary != null) {
      parts.add(busDistanceSummary);
    }
    return parts.join(' · ');
  }

  String _buildWaitingBoardingText({
    required String pathName,
    required StopInfo boardingStop,
    StopInfo? destinationStop,
    required int? busStopsUntilBoarding,
  }) {
    final parts = <String>[
      _pathStatusPrefix(pathName),
      AppLocalizations.of(context).routeDetailNotBoarded,
      AppLocalizations.of(
        context,
      ).routeDetailBoardingStopValue(_displayStopName(context, boardingStop)),
    ];
    if (destinationStop != null &&
        destinationStop.stopId != boardingStop.stopId) {
      parts.add(
        AppLocalizations.of(context).routeDetailDestinationValue(
          _displayStopName(context, destinationStop),
        ),
      );
    }
    final busDistanceSummary = _buildBusDistanceSummary(busStopsUntilBoarding);
    if (busDistanceSummary != null) {
      parts.add(busDistanceSummary);
    }
    return parts.join(' · ');
  }

  String? _vehicleIdForStop(StopInfo stop, {String? preferredVehicleId}) {
    final preferred = normalizeBusVehicleId(preferredVehicleId);
    if (preferred != null &&
        (stop.buses.any(
              (vehicle) => normalizeBusVehicleId(vehicle.id) == preferred,
            ) ||
            stop.etas.any(
              (eta) => normalizeBusVehicleId(eta.vehicleId) == preferred,
            ))) {
      return preferred;
    }

    for (final vehicle in stop.buses) {
      final vehicleId = normalizeBusVehicleId(vehicle.id);
      if (vehicleId != null) {
        return vehicleId;
      }
    }
    for (final eta in stop.etas) {
      final vehicleId = normalizeBusVehicleId(eta.vehicleId);
      if (vehicleId != null) {
        return vehicleId;
      }
    }
    return null;
  }

  int? _findStopIndexForVehicleId(List<StopInfo> stops, String? vehicleId) {
    final normalizedVehicleId = normalizeBusVehicleId(vehicleId);
    if (normalizedVehicleId == null) {
      return null;
    }
    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      final vehicleSeenAtStop =
          stop.buses.any(
            (vehicle) =>
                normalizeBusVehicleId(vehicle.id) == normalizedVehicleId,
          ) ||
          stop.etas.any(
            (eta) =>
                normalizeBusVehicleId(eta.vehicleId) == normalizedVehicleId,
          );
      if (vehicleSeenAtStop) {
        return index;
      }
    }
    return null;
  }

  String? _vehicleIdAtStop(StopInfo stop, String? preferredVehicleId) {
    return _vehicleIdForStop(stop, preferredVehicleId: preferredVehicleId);
  }

  ({String? previousStopName, String? nextStopName}) _adjacentStopNames(
    List<StopInfo> pathStops,
    int stopId,
  ) {
    final stopIndex = pathStops.indexWhere((stop) => stop.stopId == stopId);
    if (stopIndex == -1) {
      return (previousStopName: null, nextStopName: null);
    }

    return (
      previousStopName: stopIndex > 0
          ? _displayStopName(context, pathStops[stopIndex - 1])
          : null,
      nextStopName: stopIndex + 1 < pathStops.length
          ? _displayStopName(context, pathStops[stopIndex + 1])
          : null,
    );
  }

  ({List<String> stopNames, int currentStopIndex, int? highlightedStopIndex})
  _buildLiveActivityStopLine(
    List<StopInfo> pathStops, {
    required int anchorIndex,
    int? highlightedIndex,
  }) {
    final clampedAnchorIndex = anchorIndex.clamp(0, pathStops.length - 1);
    var startIndex = math.max(0, clampedAnchorIndex - 2);
    var endIndex = math.min(pathStops.length, startIndex + 5);
    startIndex = math.max(0, endIndex - 5);

    final stopNames = <String>[
      for (var index = startIndex; index < endIndex; index++)
        _displayStopName(context, pathStops[index]),
    ];
    final resolvedHighlightedIndex =
        highlightedIndex != null &&
            highlightedIndex >= startIndex &&
            highlightedIndex < endIndex
        ? highlightedIndex - startIndex
        : null;

    return (
      stopNames: stopNames,
      currentStopIndex: clampedAnchorIndex - startIndex,
      highlightedStopIndex: resolvedHighlightedIndex,
    );
  }

  String? _maybeIssueLiveActivityBoardingAlert({
    required int? busStopsUntilBoarding,
    required String boardingEtaText,
  }) {
    if (_appIsForeground || _liveActivityBoardingArrivalAlertSent) {
      return null;
    }
    final shouldAlert =
        (busStopsUntilBoarding != null && busStopsUntilBoarding <= 1) ||
        _isImmediateEtaText(boardingEtaText);
    if (!shouldAlert) {
      return null;
    }
    _liveActivityBoardingArrivalAlertSent = true;
    return 'boarding_imminent';
  }

  String? _maybeIssueLiveActivityDestinationSetupAlert() {
    if (_appIsForeground || _liveActivityDestinationSetupAlertSent) {
      return null;
    }
    _liveActivityDestinationSetupAlertSent = true;
    return 'boarded_no_destination';
  }

  String? _maybeIssueLiveActivityDestinationArrivalAlert({
    required int remainingStops,
    required double? destinationDistanceMeters,
  }) {
    if (_appIsForeground) {
      return null;
    }
    if (remainingStops <= 1 ||
        (destinationDistanceMeters != null &&
            destinationDistanceMeters <= 120)) {
      if (_liveActivityDestinationAlertStage < 2) {
        _liveActivityDestinationAlertStage = 2;
        return 'destination_arriving';
      }
      return null;
    }
    if (remainingStops <= 2 && _liveActivityDestinationAlertStage < 1) {
      _liveActivityDestinationAlertStage = 1;
      return 'destination_imminent';
    }
    return null;
  }

  LiveActivityDisplayState? _buildLiveActivityDisplayState(
    RouteDetailData detail,
    PathInfo pathInfo,
  ) {
    final pathStops = detail.stopsByPath[pathInfo.pathId] ?? const <StopInfo>[];
    if (pathStops.isEmpty) {
      _resetLiveActivityRideState();
      return null;
    }

    final nearestIndex = _resolveNearestStopIndex(pathStops);
    if (nearestIndex == null) {
      _resetLiveActivityRideState();
      final stopLine = _buildLiveActivityStopLine(
        pathStops,
        anchorIndex: _findClosestBusIndex(pathStops, pathStops.length - 1) ?? 0,
      );
      return LiveActivityDisplayState(
        stopId: pathStops.first.stopId,
        stopName: AppLocalizations.of(context).routeDetailWaitingForLocation,
        lineStopNames: stopLine.stopNames,
        lineCurrentStopIndex: stopLine.currentStopIndex,
        lineHighlightedStopIndex: stopLine.highlightedStopIndex,
        modeLabel: AppLocalizations.of(context).routeDetailLocating,
        statusText: _pathStatusPrefix(_displayPathName(context, pathInfo)),
      );
    }

    final nearestStop = pathStops[nearestIndex];
    final nearestEtaText = _displayEtaText(nearestStop);
    final busIndex = _findClosestBusIndex(pathStops, nearestIndex);
    final destinationIndex = _destinationStopId == null
        ? null
        : pathStops.indexWhere((stop) => stop.stopId == _destinationStopId);
    if (destinationIndex == null || destinationIndex == -1) {
      final explicitBoardingIndex = _boardingStopId == null
          ? null
          : pathStops.indexWhere((stop) => stop.stopId == _boardingStopId);
      final boardingIndex =
          explicitBoardingIndex != null && explicitBoardingIndex != -1
          ? explicitBoardingIndex
          : nearestIndex;
      final boardingStop = pathStops[boardingIndex];
      final boardingEtaText = _displayEtaText(boardingStop);
      final busStopsUntilBoarding = busIndex == null
          ? null
          : math.max(boardingIndex - busIndex, 0);
      final hasBoarded = _updateLiveActivityRideState(
        nearestIndex: nearestIndex,
        boardingIndex: boardingIndex,
        busStopsUntilBoarding: busStopsUntilBoarding,
        boardingEtaText: boardingEtaText,
        boardingDistanceMeters: _distanceToStop(boardingStop),
        busIndex: busIndex,
        busVehicleId: busIndex == null
            ? null
            : _vehicleIdForStop(pathStops[busIndex]),
      );
      if (!hasBoarded) {
        final boardingProgressValue = busIndex == null
            ? 0
            : math.min(busIndex + 1, boardingIndex + 1);
        final stopLine = _buildLiveActivityStopLine(
          pathStops,
          anchorIndex: busIndex ?? boardingIndex,
          highlightedIndex: boardingIndex,
        );
        final adjacentStops = _adjacentStopNames(
          pathStops,
          boardingStop.stopId,
        );
        return LiveActivityDisplayState(
          stopId: boardingStop.stopId,
          stopName: _displayStopName(context, boardingStop),
          previousStopName: adjacentStops.previousStopName,
          nextStopName: adjacentStops.nextStopName,
          lineStopNames: stopLine.stopNames,
          lineCurrentStopIndex: stopLine.currentStopIndex,
          lineHighlightedStopIndex: stopLine.highlightedStopIndex,
          modeLabel: AppLocalizations.of(context).routeDetailWaitingToBoard,
          statusText: _buildWaitingBoardingText(
            pathName: _displayPathName(context, pathInfo),
            boardingStop: boardingStop,
            busStopsUntilBoarding: busStopsUntilBoarding,
          ),
          etaSeconds: effectiveStopEtaSeconds(boardingStop),
          etaMessage: boardingStop.msg,
          vehicleId: _vehicleIdForStop(boardingStop),
          progressValue: boardingProgressValue,
          progressTotal: boardingIndex + 1,
          alertKind: _maybeIssueLiveActivityBoardingAlert(
            busStopsUntilBoarding: busStopsUntilBoarding,
            boardingEtaText: boardingEtaText,
          ),
        );
      }

      final currentProgress = math.min(
        (busIndex ?? nearestIndex) + 1,
        pathStops.length,
      );
      final stopLine = _buildLiveActivityStopLine(
        pathStops,
        anchorIndex: busIndex ?? nearestIndex,
        highlightedIndex: nearestIndex,
      );
      final adjacentStops = _adjacentStopNames(pathStops, nearestStop.stopId);
      return LiveActivityDisplayState(
        stopId: nearestStop.stopId,
        stopName: _displayStopName(context, nearestStop),
        previousStopName: adjacentStops.previousStopName,
        nextStopName: adjacentStops.nextStopName,
        lineStopNames: stopLine.stopNames,
        lineCurrentStopIndex: stopLine.currentStopIndex,
        lineHighlightedStopIndex: stopLine.highlightedStopIndex,
        modeLabel: AppLocalizations.of(context).routeDetailNearestStop,
        statusText: AppLocalizations.of(context).routeDetailDestinationNotSet,
        etaSeconds: effectiveStopEtaSeconds(nearestStop),
        etaMessage: nearestStop.msg,
        vehicleId: _vehicleIdForStop(nearestStop),
        progressValue: currentProgress,
        progressTotal: pathStops.length,
        alertKind: _maybeIssueLiveActivityDestinationSetupAlert(),
      );
    }

    final destinationStop = pathStops[destinationIndex];
    final boardingIndex = _resolveBoardingIndex(
      pathStops,
      nearestIndex,
      destinationIndex,
    );
    final boardingStop = pathStops[boardingIndex];
    final boardingVehicleId = busIndex == null
        ? _vehicleIdForStop(boardingStop)
        : _vehicleIdForStop(pathStops[busIndex]);
    final boardingEtaText = _displayEtaText(
      boardingStop,
      vehicleId: boardingVehicleId,
    );
    final busStopsUntilBoarding = busIndex == null
        ? null
        : math.max(boardingIndex - busIndex, 0);
    final hasBoarded = _updateLiveActivityRideState(
      nearestIndex: nearestIndex,
      boardingIndex: boardingIndex,
      busStopsUntilBoarding: busStopsUntilBoarding,
      boardingEtaText: boardingEtaText,
      boardingDistanceMeters: _distanceToStop(boardingStop),
      busIndex: busIndex,
      busVehicleId: boardingVehicleId,
    );

    if (!hasBoarded) {
      final boardingProgressValue = busIndex == null
          ? 0
          : math.min(busIndex + 1, boardingIndex + 1);
      final stopLine = _buildLiveActivityStopLine(
        pathStops,
        anchorIndex: busIndex ?? boardingIndex,
        highlightedIndex: boardingIndex,
      );
      final adjacentStops = _adjacentStopNames(pathStops, boardingStop.stopId);
      return LiveActivityDisplayState(
        stopId: boardingStop.stopId,
        stopName: _displayStopName(context, boardingStop),
        previousStopName: adjacentStops.previousStopName,
        nextStopName: adjacentStops.nextStopName,
        lineStopNames: stopLine.stopNames,
        lineCurrentStopIndex: stopLine.currentStopIndex,
        lineHighlightedStopIndex: stopLine.highlightedStopIndex,
        modeLabel: AppLocalizations.of(context).routeDetailNotBoarded,
        statusText: _buildWaitingBoardingText(
          pathName: _displayPathName(context, pathInfo),
          boardingStop: boardingStop,
          destinationStop: destinationStop,
          busStopsUntilBoarding: busStopsUntilBoarding,
        ),
        etaSeconds: effectiveStopEtaSecondsForVehicle(
          boardingStop,
          boardingVehicleId,
        ),
        etaMessage: effectiveStopEtaMessageForVehicle(
          boardingStop,
          boardingVehicleId,
        ),
        vehicleId: boardingVehicleId,
        progressValue: boardingProgressValue,
        progressTotal: boardingIndex + 1,
      );
    }

    final currentProgress = math.min(nearestIndex + 1, destinationIndex + 1);
    final preferredRidingVehicleId = normalizeBusVehicleId(
      _liveActivityRidingVehicleId,
    );
    final hasPreferredRidingVehicleId = preferredRidingVehicleId != null;
    final ridingVehicleIndex = _findStopIndexForVehicleId(
      pathStops,
      preferredRidingVehicleId,
    );
    final displayIndex =
        ridingVehicleIndex ??
        (hasPreferredRidingVehicleId ? nearestIndex : busIndex ?? nearestIndex);
    final displayStop = pathStops[displayIndex];
    final displayVehicleId =
        ridingVehicleIndex != null || !hasPreferredRidingVehicleId
        ? _vehicleIdAtStop(displayStop, preferredRidingVehicleId)
        : null;
    if (displayVehicleId != null) {
      _liveActivityRidingVehicleId = displayVehicleId;
    }
    final stopLine = _buildLiveActivityStopLine(
      pathStops,
      anchorIndex: displayIndex,
      highlightedIndex: destinationIndex,
    );
    final adjacentStops = _adjacentStopNames(pathStops, destinationStop.stopId);
    final etaVehicleId = displayVehicleId ?? preferredRidingVehicleId;
    final destinationEtaText = _displayEtaText(
      destinationStop,
      vehicleId: etaVehicleId,
    );
    final onboardStatusParts = <String>[
      AppLocalizations.of(context).routeDetailBoarded,
      AppLocalizations.of(
        context,
      ).routeDetailDestinationValue(_displayStopName(context, destinationStop)),
    ];
    if (destinationEtaText != '--') {
      onboardStatusParts.add(destinationEtaText);
    }
    onboardStatusParts.add(
      AppLocalizations.of(
        context,
      ).routeDetailNearestStopValue(_displayStopName(context, nearestStop)),
    );
    if (nearestEtaText != '--') {
      onboardStatusParts.add(nearestEtaText);
    }

    return LiveActivityDisplayState(
      stopId: destinationStop.stopId,
      stopName: _displayStopName(context, destinationStop),
      alertStopName: _displayStopName(context, destinationStop),
      previousStopName: adjacentStops.previousStopName,
      nextStopName: adjacentStops.nextStopName,
      lineStopNames: stopLine.stopNames,
      lineCurrentStopIndex: stopLine.currentStopIndex,
      lineHighlightedStopIndex: stopLine.highlightedStopIndex,
      modeLabel: AppLocalizations.of(context).routeDetailBoarded,
      statusText: onboardStatusParts.join(' · '),
      etaSeconds: effectiveStopEtaSecondsForVehicle(
        destinationStop,
        etaVehicleId,
      ),
      etaMessage: effectiveStopEtaMessageForVehicle(
        destinationStop,
        etaVehicleId,
      ),
      vehicleId: displayVehicleId,
      progressValue: currentProgress,
      progressTotal: destinationIndex + 1,
      alertKind: _maybeIssueLiveActivityDestinationArrivalAlert(
        remainingStops: destinationIndex - nearestIndex,
        destinationDistanceMeters: _distanceToStop(destinationStop),
      ),
    );
  }

  Future<void> _syncLiveActivityForBackgroundMonitor(
    RouteDetailData detail,
    PathInfo pathInfo,
  ) async {
    // Only the route screen the user is actually looking at (top of the
    // navigation stack) may drive the Live Activity. Without this guard a
    // screen lower in the stack could keep pushing its own route data into
    // an activity started by another screen, making the Dynamic Island show
    // the wrong bus/route.
    if (!_isRouteVisible) {
      return;
    }

    final displayState = _buildLiveActivityDisplayState(detail, pathInfo);
    if (displayState == null) {
      await _stopLiveActivity();
      return;
    }

    final needsRestart =
        !_liveActivityActive ||
        !LiveActivityService.ownsActivity(_liveActivityId) ||
        _liveActivityPathId != pathInfo.pathId ||
        _liveActivityRouteKey != widget.routeKey ||
        _liveActivityProviderName != widget.provider.name;
    if (needsRestart) {
      await _startLiveActivity(pathInfo, displayState);
      return;
    }

    final updated = await LiveActivityService.updateLiveActivity(
      displayState,
      ownerActivityId: _liveActivityId,
    );
    if (!mounted) {
      return;
    }
    if (!updated) {
      // The activity was dismissed or replaced natively; restart it so the
      // user keeps getting updates for the bus they are riding.
      await _startLiveActivity(pathInfo, displayState);
      return;
    }
    if (_liveActivityStopId != displayState.stopId) {
      setState(() {
        _liveActivityStopId = displayState.stopId;
      });
    }
    await _maybeSendIOSBoardingCheckPrompt();
  }

  Future<void> _maybeSendIOSBoardingCheckPrompt() async {
    // On desktop / web, send a notification when the bus arrives at the
    // boarding stop (foreground only — no background location tracking).
    if (_isDesktop || kIsWeb) {
      if (_appIsForeground || !_backgroundTripMonitorReady) {
        await TripMonitorNotifications.cancelBoardingCheckPrompt();
        return;
      }
      if (_iosBoardingCheckPromptSent) {
        return;
      }
      final boardingStopName =
          _boardingStopName ?? _currentBoardingCandidateStop()?.stopName;
      if (boardingStopName == null || boardingStopName.trim().isEmpty) {
        return;
      }
      await TripMonitorNotifications.showBoardingCheckPrompt(
        routeName: _detail?.route.routeName ?? widget.routeNameHint ?? 'YABus',
        boardingStopName: boardingStopName,
        destinationStopName: _destinationStopName,
      );
      _iosBoardingCheckPromptSent = true;
      return;
    }

    if (!_isIOS || _appIsForeground || !_backgroundTripMonitorReady) {
      await TripMonitorNotifications.cancelBoardingCheckPrompt();
      return;
    }
    if (_liveActivityRideConfirmed) {
      await TripMonitorNotifications.cancelBoardingCheckPrompt();
      return;
    }
    if (!_liveActivityBoardingWindowOpen || _iosBoardingCheckPromptSent) {
      return;
    }
    final openedAt = _liveActivityBoardingWindowOpenedAt;
    if (openedAt == null ||
        DateTime.now().difference(openedAt) < const Duration(seconds: 45)) {
      return;
    }
    final boardingStopName =
        _boardingStopName ?? _currentBoardingCandidateStop()?.stopName;
    if (boardingStopName == null || boardingStopName.trim().isEmpty) {
      return;
    }
    await TripMonitorNotifications.showBoardingCheckPrompt(
      routeName: _detail?.route.routeName ?? widget.routeNameHint ?? 'YABus',
      boardingStopName: boardingStopName,
      destinationStopName: _destinationStopName,
    );
    _iosBoardingCheckPromptSent = true;
  }

  Future<void> _maybeRefreshBackgroundTripMonitor() async {
    if (!_isIOS ||
        !_isRouteVisible ||
        _appIsForeground ||
        _backgroundDataRefreshInFlight) {
      return;
    }

    final controller = AppControllerScope.read(context);
    if (!controller.settings.enableRouteBackgroundMonitor ||
        !_backgroundTripMonitorReady) {
      return;
    }

    final detail = _detail;
    final pathInfo = _currentPathInfo;
    if (detail == null || pathInfo == null) {
      return;
    }

    final refreshIntervalSeconds = math.max(
      controller.settings.busUpdateTime,
      10,
    );
    final now = DateTime.now();
    final lastRefreshAt = _lastBackgroundDataRefreshAt;
    if (lastRefreshAt != null &&
        now.difference(lastRefreshAt) <
            Duration(seconds: refreshIntervalSeconds)) {
      return;
    }

    _backgroundDataRefreshInFlight = true;
    _lastBackgroundDataRefreshAt = now;
    final previousDetail = _detail;
    try {
      final fetchedDetail = await controller.getRouteDetail(
        widget.routeKey,
        provider: widget.provider,
        routeIdHint: widget.routeIdHint,
        routeNameHint: widget.routeNameHint,
      );
      if (!mounted) {
        return;
      }

      final displayDetail = !fetchedDetail.hasLiveData && previousDetail != null
          ? _mergeDetailWithPreviousLiveData(fetchedDetail, previousDetail)
          : fetchedDetail;
      _syncLiveMapData(displayDetail, replaceFamilyRouteIds: true);
      _syncTabController(displayDetail);
      setState(() {
        _detail = displayDetail;
        _error = null;
        _status = fetchedDetail.hasLiveData
            ? null
            : _RouteDetailStatus.realtimeUnavailable;
      });
      _recalculateNearestStops();
      await _syncLiveActivityForBackgroundMonitor(
        displayDetail,
        _currentPathInfo ?? pathInfo,
      );
    } catch (_) {
      // Keep the existing detail and retry on the next throttled location update.
    } finally {
      _backgroundDataRefreshInFlight = false;
    }
  }

  // ignore: unused_element
  Future<void> _openStopActions(StopInfo stop) async {
    final action = await showDialog<_StopAction>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return SimpleDialog(
          title: Text(
            stop.transitName.stationDisplayForLocale(
              Localizations.localeOf(context).toLanguageTag(),
              separator: '\n',
            ),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_StopAction.favoriteBoarding),
              child: Text(l10n.routeDetailFavoriteStop),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_StopAction.favoriteStation),
              child: Text(l10n.routeDetailFavoriteStation),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }

    if (action == _StopAction.favoriteStation) {
      await _handleStationFavorite(stop);
    } else if (action == _StopAction.favoriteBoarding) {
      await _handleFavorite(stop);
    }
  }

  Future<String?> _selectFavoriteGroup(FavoriteItemType itemType) async {
    final controller = AppControllerScope.read(context);
    final compatible = controller.compatibleFavoriteGroupNames(itemType);
    String? selected;
    if (compatible.isEmpty) {
      selected = '__new__';
    } else if (compatible.length == 1) {
      selected = compatible.single;
    } else {
      selected = await _showGroupPicker(compatible);
    }
    if (!mounted || selected == null) {
      return null;
    }
    if (selected != '__new__') {
      return selected;
    }

    final draft = await showFavoriteGroupDialog(
      context,
      initialKind: switch (itemType) {
        FavoriteItemType.route => FavoriteGroupKind.route,
        FavoriteItemType.station => FavoriteGroupKind.station,
        FavoriteItemType.boarding => FavoriteGroupKind.boarding,
      },
      compatibleItemType: itemType,
    );
    if (!mounted || draft == null) {
      return null;
    }
    if (controller.favoriteGroups.containsKey(draft.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).routeDetailFavoriteGroupDuplicate,
          ),
        ),
      );
      return null;
    }
    await controller.addFavoriteGroup(draft.name, kind: draft.kind);
    return draft.name;
  }

  Future<void> _handleRouteFavorite() async {
    final route = _detail?.route;
    if (route == null || route.routeId.trim().isEmpty) {
      return;
    }
    final groupName = await _selectFavoriteGroup(FavoriteItemType.route);
    if (!mounted || groupName == null) {
      return;
    }
    try {
      await AppControllerScope.read(context).addFavoriteItem(
        FavoriteRoute(
          provider: widget.provider,
          routeKey: widget.routeKey,
          routeId: route.routeId,
          routeName: route.routeName,
          routeDescription: route.description.trim().isEmpty
              ? null
              : route.description.trim(),
        ),
        groupName: groupName,
      );
    } on FavoriteGroupFullException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).routeDetailFavoriteLimit(error.maxStops),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    _playSuccessHaptic();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).routeDetailRouteAdded(groupName),
        ),
      ),
    );
  }

  Future<void> _handleStationFavorite(StopInfo stop) async {
    final rawStopId = stop.rawStopId?.trim() ?? '';
    if (rawStopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).routeDetailStationIdMissing,
          ),
        ),
      );
      return;
    }
    final controller = AppControllerScope.read(context);
    StationPassbyData? station;
    try {
      station = await controller.repository.resolveStation(
        rawStopId,
        provider: widget.provider,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedFriendlyError(AppLocalizations.of(context), error),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (station == null) {
      // Not an error: the server answered, it just has no whole-station record
      // for this stop yet (the station tables are filled by the static sync).
      // Offer the boarding-point favorite, which never depends on that data.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).routeDetailStationNotSynced,
          ),
          action: SnackBarAction(
            label: AppLocalizations.of(context).routeDetailFavoriteStop,
            onPressed: () => unawaited(_handleFavorite(stop)),
          ),
        ),
      );
      return;
    }
    final groupName = await _selectFavoriteGroup(FavoriteItemType.station);
    if (!mounted || groupName == null) {
      return;
    }
    try {
      await controller.addFavoriteItem(
        FavoriteStation(
          provider: widget.provider,
          stationId: station.stationId,
          stationName: station.stationName,
        ),
        groupName: groupName,
      );
    } on FavoriteGroupFullException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).routeDetailFavoriteLimit(error.maxStops),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    _playSuccessHaptic();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          ).routeDetailStationAdded(station.stationName, groupName),
        ),
      ),
    );
  }

  Future<void> _handleFavorite(StopInfo stop) async {
    final controller = AppControllerScope.read(context);
    final groupName = await _selectFavoriteGroup(FavoriteItemType.boarding);
    if (!mounted || groupName == null) {
      return;
    }

    final favorite = FavoriteStop(
      provider: widget.provider,
      routeKey: widget.routeKey,
      pathId: stop.pathId,
      stopId: stop.stopId,
      routeId: _detail?.route.routeId,
      routeName: _detail?.route.routeName,
      stopName: stop.stopName,
      rawStopId: stop.rawStopId,
    );
    String selectedGroup;
    try {
      selectedGroup = await controller.addFavoriteStop(
        favorite,
        groupName: groupName,
      );
    } on FavoriteGroupFullException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).routeDetailFavoriteLimit(e.maxStops),
          ),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }

    String? assignedDestinationName;
    if (await _shouldAssignFavoriteDestination()) {
      final destination = await _pickFavoriteDestinationStop(
        pathId: stop.pathId,
      );
      if (!mounted) {
        return;
      }
      if (destination != null) {
        final didAssign = await controller.updateFavoriteDestination(
          selectedGroup,
          favorite,
          destinationPathId: destination.pathId,
          destinationStopId: destination.stopId,
          destinationStopName: destination.stopName,
        );
        if (!mounted) {
          return;
        }
        if (didAssign) {
          assignedDestinationName = destination.stopName;
        }
      }
    }

    if (!mounted) {
      return;
    }
    final message = assignedDestinationName == null
        ? AppLocalizations.of(context).routeDetailFavoriteAdded(selectedGroup)
        : AppLocalizations.of(context).routeDetailFavoriteAddedWithDestination(
            selectedGroup,
            assignedDestinationName,
          );
    _playSuccessHaptic();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _shouldAssignFavoriteDestination() async {
    final detail = _detail;
    if (detail == null || _currentPathStops.isEmpty) {
      return false;
    }

    final shouldAssign = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.routeDetailFavoriteDestinationTitle),
          content: Text(l10n.routeDetailFavoriteDestinationMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonNotNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.routeDetailSetDestinationAlert),
            ),
          ],
        );
      },
    );

    return shouldAssign == true;
  }

  Future<StopInfo?> _pickFavoriteDestinationStop({required int pathId}) async {
    final detail = _detail;
    if (detail == null) {
      return null;
    }
    final pathStops = detail.stopsByPath[pathId] ?? const <StopInfo>[];
    if (pathStops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).routeDetailNoSelectableStops,
          ),
        ),
      );
      return null;
    }

    return showModalBottomSheet<StopInfo>(
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
                final destinationStop = pathStops[index];
                return ListTile(
                  title: Text(
                    destinationStop.transitName.stationDisplayForLocale(
                      Localizations.localeOf(context).toLanguageTag(),
                      separator: '\n',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context).stopSequence(index + 1),
                  ),
                  onTap: () => Navigator.of(context).pop(destinationStop),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePinnedShortcut(StopInfo stop) async {
    final didPin = await AndroidHomeIntegration.pinStopShortcut(
      favorite: FavoriteStop(
        provider: widget.provider,
        routeKey: widget.routeKey,
        pathId: stop.pathId,
        stopId: stop.stopId,
        routeId: _detail?.route.routeId,
        routeName: _detail?.route.routeName,
        stopName: stop.stopName,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          didPin
              ? AppLocalizations.of(context).routeDetailShortcutRequested
              : AppLocalizations.of(context).shortcutUnsupported,
        ),
      ),
    );
  }

  Future<void> _handlePinnedRouteShortcut() async {
    final route = _detail?.route;
    if (route == null || route.routeId.trim().isEmpty) return;
    final didPin = await AndroidHomeIntegration.pinFavoriteShortcut(
      favorite: FavoriteRoute(
        provider: widget.provider,
        routeKey: widget.routeKey,
        routeId: route.routeId,
        routeName: route.routeName,
        routeDescription: route.description.trim().isEmpty
            ? null
            : route.description.trim(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          didPin
              ? AppLocalizations.of(context).routeDetailRouteShortcutRequested
              : AppLocalizations.of(context).shortcutUnsupported,
        ),
      ),
    );
  }

  Future<void> _handleDestinationAction(StopInfo stop) async {
    if (_isDestinationStop(stop)) {
      await _clearDestinationStop();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).routeDetailDestinationCleared,
          ),
        ),
      );
      return;
    }

    await _setDestinationStop(stop);
  }

  bool _canOpenStopInGoogleMaps(StopInfo stop) {
    return !(stop.lat == 0 && stop.lon == 0);
  }

  Uri _buildGoogleMapsStopUri(StopInfo stop) {
    return Uri.https('www.google.com', '/maps/search/', <String, String>{
      'api': '1',
      'query': '${stop.lat},${stop.lon}',
    });
  }

  Future<void> _openStopInGoogleMaps(StopInfo stop) async {
    if (!_canOpenStopInGoogleMaps(stop)) {
      return;
    }

    final didLaunch = await launchUrl(
      _buildGoogleMapsStopUri(stop),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || didLaunch) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).routeDetailGoogleMapsFailed),
      ),
    );
  }

  bool _canShowRelatedStopRoutesAction(StopInfo stop) {
    final stopName = stop.stopName.trim();
    if (stopName.isEmpty || !widget.provider.supportsLocalDatabase) {
      return false;
    }
    return AppControllerScope.read(context).isDatabaseReady(widget.provider);
  }

  String _normalizeStopRouteLookupName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  // Keys ([stopRouteMergeKey]) of the entries in the related-stop-routes sheet
  // whose ETA arrived embedded in the passby response. Read by
  // [_fetchRelatedStopLiveMaps] to skip them when requesting realtime data, and
  // by [_applyLiveMapsToRelatedStopRoutes] to leave their values alone. Only
  // one sheet is open at a time, so a single set is sufficient.
  Set<String> _relatedStopPassbyRouteKeys = const <String>{};

  Future<List<StopRouteSearchResult>> _loadRelatedStopRoutes(
    StopInfo stop,
  ) async {
    if (!_canShowRelatedStopRoutesAction(stop)) {
      return const <StopRouteSearchResult>[];
    }

    final controller = AppControllerScope.read(context);
    _relatedStopPassbyRouteKeys = const <String>{};

    // Two sources, and both are needed.
    //
    // The server passby endpoint is keyed on one TDX stop ID and returns that
    // stop's ETA per route, so it is cheap and authoritative — the client
    // avoids requesting a batch of full realtime snapshots (one per route, each
    // carrying every stop). But TDX publishes a *different* stop ID per route
    // and direction at the same physical stop (捷運南屯站(文心路) is 21746 for
    // 綠3, 21884 for 73, 24080 for 302), so passby only covers the routes
    // sharing this stop's ID — often just the route already on screen. The
    // local name-based lookup finds the sibling IDs but has no realtime data.
    // Merging keeps the ETA and the complete route list.
    //
    // The provider scopes passby to this route's authority — TDX stop IDs
    // collide across cities — and the stop name lets the repository reject a
    // mis-scoped response from servers that don't understand the scope
    // parameter yet.
    final passby = <StopRouteSearchResult>[];
    final rawStopId = stop.rawStopId;
    if (rawStopId != null) {
      try {
        passby.addAll(
          await controller.repository.getStopPassby(
            rawStopId,
            provider: widget.provider,
            expectedStopName: stop.stopName,
          ),
        );
      } catch (error) {
        debugPrint('Stop passby load error: $error');
        // Silent: the local lookup below still produces a usable list.
      }
    }

    final normalizedStopName = _normalizeStopRouteLookupName(stop.stopName);
    var local = const <StopRouteSearchResult>[];
    Object? localError;
    StackTrace? localStackTrace;
    try {
      final results = await controller.searchRoutesByStop(
        stop.stopName,
        provider: widget.provider,
      );
      local = results
          .where(
            (result) =>
                _normalizeStopRouteLookupName(result.matchedStop.stopName) ==
                normalizedStopName,
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Related stop route local lookup error: $error');
      localError = error;
      localStackTrace = stackTrace;
    }

    // Preserve the previous failure surface: a local lookup that throws with
    // nothing from passby must still reach the sheet's error state. When passby
    // did return something, don't let the local failure discard it.
    if (passby.isEmpty && localError != null) {
      Error.throwWithStackTrace(localError, localStackTrace!);
    }

    final merged = mergeStopRouteResults(passby: passby, local: local);
    _relatedStopPassbyRouteKeys = merged.passbyKeys;
    return merged.results;
  }

  List<_RelatedStopRouteEta> _buildInitialRelatedStopRouteEtas(
    List<StopRouteSearchResult> routes,
  ) {
    final items = routes
        .map(
          (result) => _RelatedStopRouteEta(
            result: result,
            liveStop: result.matchedStop,
          ),
        )
        .toList();
    items.sort(_compareRelatedStopRouteEtas);
    return items;
  }

  Future<BatchLiveStopMap> _fetchRelatedStopLiveMaps(
    List<StopRouteSearchResult> routes,
  ) async {
    // Passby entries already carry this stop's ETA in matchedStop. Only the
    // entries that came from the local name lookup — the sibling stop IDs
    // passby could not see — still need a realtime fetch. Filtering per entry
    // rather than per route matters: one route can be passby-covered on path 1
    // and locally sourced on path 0, and it must still reach the batch fetch.
    final pending = routes
        .where(
          (result) =>
              !_relatedStopPassbyRouteKeys.contains(stopRouteMergeKey(result)),
        )
        .toList(growable: false);
    if (pending.isEmpty) {
      return const <String, LiveStopMap>{};
    }

    final controller = AppControllerScope.read(context);
    BatchLiveStopMap liveMaps = const <String, LiveStopMap>{};
    try {
      liveMaps = await controller.repository.getBatchLiveStopMaps(
        pending.map((result) => result.route.routeId).toList(growable: false),
      );
    } catch (error) {
      debugPrint('Related stop route ETA load error: $error');
    }

    final missingRouteIds = pending
        .map((result) => result.route.routeId.trim())
        .where((id) => !liveMaps.containsKey(id))
        .toSet();
    if (missingRouteIds.isEmpty) {
      return liveMaps;
    }

    final fallbackEntries = await Future.wait(
      missingRouteIds.map((routeId) async {
        try {
          final liveMap = await controller.repository.getLiveStopMap(routeId);
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
    return merged;
  }

  List<_RelatedStopRouteEta> _applyLiveMapsToRelatedStopRoutes(
    List<StopRouteSearchResult> routes,
    BatchLiveStopMap liveMaps,
  ) {
    final items = routes.map((result) {
      // A passby entry's matchedStop already holds this stop's ETA. Don't let a
      // live-map hit keyed on the *requested* stop ID overwrite it: copyWith
      // replaces sec/msg/t/buses but not etas, which would leave the two out of
      // sync.
      if (_relatedStopPassbyRouteKeys.contains(stopRouteMergeKey(result))) {
        return _RelatedStopRouteEta(
          result: result,
          liveStop: result.matchedStop,
        );
      }
      final liveMap = liveMaps[result.route.routeId.trim()];
      final livePayload = liveMap?[_relatedStopRealtimeKey(result.matchedStop)];
      final liveStop = livePayload == null
          ? result.matchedStop
          : result.matchedStop.copyWith(
              sec: livePayload.sec,
              msg: livePayload.msg,
              t: livePayload.t,
              buses: livePayload.buses,
            );
      return _RelatedStopRouteEta(result: result, liveStop: liveStop);
    }).toList();

    items.sort(_compareRelatedStopRouteEtas);
    return items;
  }

  String _relatedStopRealtimeKey(StopInfo stop) {
    return '${stop.pathId}:${stop.stopId}';
  }

  /// The sheet lists every route passing this stop, both directions included,
  /// so it has the same ambiguity the nearby list had — hence the pathId, which
  /// gives 去程/返程 to fall back on when the path name is missing.
  String _relatedRouteDirectionText(StopRouteSearchResult result) {
    return localizedRouteDirectionForRoute(
      AppLocalizations.of(context),
      route: result.route,
      pathId: result.matchedStop.pathId,
    );
  }

  int _compareRelatedStopRouteEtas(
    _RelatedStopRouteEta left,
    _RelatedStopRouteEta right,
  ) {
    final leftBucket = _relatedStopEtaSortBucket(left.liveStop);
    final rightBucket = _relatedStopEtaSortBucket(right.liveStop);
    if (leftBucket != rightBucket) {
      return leftBucket.compareTo(rightBucket);
    }

    final leftSec = left.liveStop.sec;
    final rightSec = right.liveStop.sec;
    if (leftSec != null && rightSec != null && leftSec != rightSec) {
      return leftSec.compareTo(rightSec);
    }

    final leftMessageEta = _relatedStopMessageEta(left.liveStop);
    final rightMessageEta = _relatedStopMessageEta(right.liveStop);
    if (leftMessageEta != null &&
        rightMessageEta != null &&
        leftMessageEta != rightMessageEta) {
      return leftMessageEta.compareTo(rightMessageEta);
    }
    if (leftMessageEta != null) {
      return -1;
    }
    if (rightMessageEta != null) {
      return 1;
    }

    return left.result.route.routeKey.compareTo(right.result.route.routeKey);
  }

  int _relatedStopEtaSortBucket(StopInfo stop) {
    if (stop.sec != null) {
      return 0;
    }
    if (_relatedStopMessageEta(stop) != null) {
      return 1;
    }
    if (stop.msg?.trim().isNotEmpty ?? false) {
      return 2;
    }
    return 3;
  }

  int? _relatedStopMessageEta(StopInfo stop) {
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

  String _relatedStopStatusText(StopInfo stop, {bool isLoadingEta = false}) {
    final l10n = AppLocalizations.of(context);
    final message = stop.msg?.trim() ?? '';
    if (message.isNotEmpty) {
      return message;
    }

    final seconds = stop.sec;
    if (seconds == null) {
      return isLoadingEta
          ? l10n.routeDetailRealtimeLoading
          : l10n.routeDetailNoRealtime;
    }
    if (seconds <= 0) {
      return l10n.etaArriving;
    }
    if (seconds < 60) {
      return l10n.etaSeconds(seconds);
    }

    final minutes = seconds ~/ 60;
    final leftoverSeconds = seconds % 60;
    if (AppControllerScope.read(context).settings.alwaysShowSeconds &&
        leftoverSeconds > 0) {
      return l10n.routeDetailEtaApproxMinutesSeconds(minutes, leftoverSeconds);
    }
    return l10n.routeDetailEtaApproxMinutes(minutes);
  }

  Future<void> _openRelatedRouteDetail(StopRouteSearchResult result) async {
    final controller = AppControllerScope.read(context);
    final provider = busProviderFromString(result.route.sourceProvider);
    unawaited(() async {
      final autoFavorited = await controller.recordRouteSelection(
        provider: provider,
        routeKey: result.route.routeKey,
        routeName: result.route.routeName,
        source: 'route_detail_related_stop_routes',
        pathId: result.matchedStop.pathId,
        stopId: result.matchedStop.stopId,
        stopName: result.matchedStop.stopName,
      );
      if (mounted && autoFavorited != null) {
        final label = autoFavorited.stopName?.trim().isNotEmpty == true
            ? autoFavorited.stopName!.trim()
            : autoFavorited.routeName?.trim().isNotEmpty == true
            ? autoFavorited.routeName!.trim()
            : AppLocalizations.of(context).autoFavoriteFallback;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).autoFavoriteAdded(label),
            ),
          ),
        );
      }
    }());

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RouteDetailScreen(
          routeKey: result.route.routeKey,
          provider: provider,
          routeIdHint: result.route.routeId,
          routeNameHint: result.route.routeName,
          initialPathId: result.matchedStop.pathId,
          initialStopId: result.matchedStop.stopId,
          suppressAutoDestinationSelection: true,
        ),
      ),
    );
  }

  Future<void> _openRelatedStopRoutes(StopInfo stop) async {
    if (!_canShowRelatedStopRoutesAction(stop)) {
      return;
    }

    final selectedRoute = await showModalBottomSheet<StopRouteSearchResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RelatedStopRoutesSheet(
        stop: stop,
        loadRoutes: () => _loadRelatedStopRoutes(stop),
        fetchLiveMaps: _fetchRelatedStopLiveMaps,
        buildInitialItems: _buildInitialRelatedStopRouteEtas,
        applyLiveMaps: _applyLiveMapsToRelatedStopRoutes,
        statusText: _relatedStopStatusText,
        directionText: _relatedRouteDirectionText,
      ),
    );

    if (!mounted || selectedRoute == null) {
      return;
    }
    await _openRelatedRouteDetail(selectedRoute);
  }

  Future<void> _openStopTransfers(StopInfo stop) async {
    if (!_canOpenStopInGoogleMaps(stop)) {
      return;
    }
    final detail = _detail;
    if (detail == null) {
      return;
    }
    final selectedRoute = await showModalBottomSheet<StopRouteSearchResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StopTransferSheet(
        controller: AppControllerScope.read(context),
        provider: widget.provider,
        currentRouteId: detail.route.routeId,
        stop: stop,
      ),
    );
    if (!mounted || selectedRoute == null) {
      return;
    }
    await _openRelatedRouteDetail(selectedRoute);
  }

  Future<void> _openStopActionsWithShortcut(StopInfo stop) async {
    final controller = AppControllerScope.read(context);
    final showDestinationAction =
        controller.settings.enableRouteBackgroundMonitor &&
        _currentPathStops.isNotEmpty;
    final showShortcutAction = _isAndroid;
    final showGoogleMapsAction = _canOpenStopInGoogleMaps(stop);
    final showRelatedRoutesAction = _canShowRelatedStopRoutesAction(stop);
    final showTransfersAction = _canOpenStopInGoogleMaps(stop);
    final action = await showDialog<_StopAction>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return SimpleDialog(
          title: Text(
            stop.transitName.stationDisplayForLocale(
              Localizations.localeOf(context).toLanguageTag(),
              separator: '\n',
            ),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_StopAction.favoriteBoarding),
              child: Text(l10n.routeDetailFavoriteStop),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_StopAction.favoriteStation),
              child: Text(l10n.routeDetailFavoriteStation),
            ),
            if (showDestinationAction)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(_StopAction.destination),
                child: Text(
                  _isDestinationStop(stop)
                      ? l10n.routeDetailClearDestinationAlert
                      : l10n.stopActionSetDestination,
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(_StopAction.schedule),
              child: Text(l10n.stopActionSchedule),
            ),
            if (showRelatedRoutesAction)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(_StopAction.relatedRoutes),
                child: Text(l10n.stopActionRelatedRoutes),
              ),
            if (showTransfersAction)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(_StopAction.transfers),
                child: Text(l10n.stopActionTransfers),
              ),
            if (showGoogleMapsAction)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(_StopAction.googleMaps),
                child: Text(l10n.stopActionOpenGoogleMaps),
              ),
            if (showShortcutAction)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(_StopAction.shortcut),
                child: Text(l10n.commonAddToHomeScreen),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }

    if (action == _StopAction.favoriteStation) {
      await _handleStationFavorite(stop);
    } else if (action == _StopAction.favoriteBoarding) {
      await _handleFavorite(stop);
    } else if (action == _StopAction.destination) {
      await _handleDestinationAction(stop);
    } else if (action == _StopAction.schedule) {
      await _openStopScheduleDrawer(stop);
    } else if (action == _StopAction.relatedRoutes) {
      await _openRelatedStopRoutes(stop);
    } else if (action == _StopAction.transfers) {
      await _openStopTransfers(stop);
    } else if (action == _StopAction.googleMaps) {
      await _openStopInGoogleMaps(stop);
    } else if (action == _StopAction.shortcut) {
      await _handlePinnedShortcut(stop);
    }
  }

  Future<void> _openStopScheduleDrawer(StopInfo stop) async {
    final detail = _detail;
    if (detail == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _StopScheduleSheet(
          routeId: detail.route.routeId,
          routeName: detail.route.routeName,
          routeDisplayName: detail.route.transitName.displayForLocale(
            Localizations.localeOf(sheetContext).toLanguageTag(),
          ),
          provider: widget.provider,
          stop: stop,
          repository: AppControllerScope.read(context).repository,
        );
      },
    );
  }

  Widget _buildBackgroundTripMonitorDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final resolvedBoardingStop = _resolvedBoardingStop();
    final hasManualBoardingStop = _boardingStopId != null;
    final boardingName = resolvedBoardingStop == null
        ? null
        : _displayStopName(context, resolvedBoardingStop).trim();
    final boardingSubtitle = boardingName != null && boardingName.isNotEmpty
        ? l10n.routeDetailCurrentStop(boardingName)
        : l10n.routeDetailBoardingStopHint;
    final resolvedDestinationStop = _findStopById(
      _currentPathStops,
      _destinationStopId,
    );
    final destinationName = resolvedDestinationStop == null
        ? _destinationStopName?.trim()
        : _displayStopName(context, resolvedDestinationStop).trim();
    final destinationSubtitle =
        destinationName != null && destinationName.isNotEmpty
        ? l10n.routeDetailCurrentStop(destinationName)
        : l10n.routeDetailDestinationHint;

    return Drawer(
      width: math.min(MediaQuery.sizeOf(context).width * 0.88, 360),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.routeDetailBackgroundDrawerTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                l10n.routeDetailBackgroundDrawerMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                _backgroundTripMonitorPaused
                    ? Icons.play_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
              ),
              title: Text(
                _backgroundTripMonitorPaused
                    ? l10n.routeDetailResumeBackground
                    : l10n.routeDetailPauseBackground,
              ),
              subtitle: Text(
                _backgroundTripMonitorPaused
                    ? l10n.routeDetailResumeBackgroundMessage
                    : l10n.routeDetailPauseBackgroundMessage,
              ),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(
                  _setBackgroundTripMonitorPaused(
                    !_backgroundTripMonitorPaused,
                    reason: 'user',
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                resolvedBoardingStop == null
                    ? Icons.directions_bus_outlined
                    : Icons.directions_bus_rounded,
              ),
              title: Text(
                resolvedBoardingStop == null
                    ? l10n.routeDetailSetBoardingStop
                    : l10n.routeDetailChangeBoardingStop,
              ),
              subtitle: Text(boardingSubtitle),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_pickBoardingStop());
              },
            ),
            if (hasManualBoardingStop)
              ListTile(
                leading: const Icon(Icons.my_location_rounded),
                title: Text(
                  _currentBoardingCandidateStop() == null
                      ? l10n.routeDetailClearManualBoarding
                      : l10n.routeDetailReturnToCurrentLocation,
                ),
                subtitle: Text(
                  _currentBoardingCandidateStop() == null
                      ? l10n.routeDetailClearManualBoardingHint
                      : l10n.routeDetailCurrentLocationHint,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_clearBoardingStop());
                },
              ),
            ListTile(
              leading: Icon(
                _destinationStopId == null
                    ? Icons.flag_outlined
                    : Icons.flag_rounded,
              ),
              title: Text(
                _destinationStopId == null
                    ? l10n.routeDetailSetDestinationAlert
                    : l10n.routeDetailClearDestinationAlert,
              ),
              subtitle: Text(destinationSubtitle),
              onTap: () {
                Navigator.of(context).pop();
                if (_destinationStopId == null) {
                  unawaited(_pickDestinationStop());
                } else {
                  unawaited(_clearDestinationStop());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showGroupPicker(List<String> groups) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return SimpleDialog(
          title: Text(l10n.routeDetailSelectFavoriteGroup),
          children: [
            ...groups.map(
              (group) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(group),
                child: Text(group),
              ),
            ),
            const Divider(height: 1),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('__new__'),
              child: Text(l10n.routeDetailNewGroup),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openVehicleForum(String vehicleId) async {
    final didLaunch = await openTwBusForumSearch(vehicleId);
    if (!mounted || didLaunch) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).routeDetailForumFailed),
      ),
    );
  }

  Future<void> _handleVehicleAction(
    BusVehicle vehicle,
    _VehicleAction action,
  ) async {
    switch (action) {
      case _VehicleAction.twBusForum:
        await _openVehicleForum(vehicle.id);
    }
  }

  Future<void> _showVehicleOnMap(StopInfo stop, BusVehicle vehicle) async {
    _handleMapPathSelection(stop.pathId);
    final isWideLayout =
        MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;
    if (isWideLayout) {
      _requestMapVehicleFocus(vehicle.id);
      if (!_showWideMapPanel) {
        setState(() {
          _showWideMapPanel = true;
        });
      }
      return;
    }
    await _openBusMapSheet(pathId: stop.pathId, vehicleId: vehicle.id);
  }

  String _vehicleSourceLabel(BusVehicle vehicle) {
    final l10n = AppLocalizations.of(context);
    return isBackfillBusSource(vehicle.source)
        ? l10n.routeDetailVehicleBackfill
        : l10n.routeDetailVehicleRealtime;
  }

  Future<void> _showVehicleDetails(
    StopInfo stop,
    BusVehicle vehicle, {
    required bool isNearest,
  }) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final statusStyle = _vehicleStatusStyleForVehicle(
      theme,
      stop,
      vehicle,
      isNearest: isNearest,
    );
    final etaSeconds = effectiveStopEtaSecondsForVehicle(stop, vehicle.id);
    final etaMessage = effectiveStopEtaMessageForVehicle(stop, vehicle.id);
    final detailRows = <({String label, String value})>[
      (
        label: l10n.routeDetailVehicleSource,
        value: _vehicleSourceLabel(vehicle),
      ),
      (
        label: l10n.routeDetailVehicleEta,
        value: etaMessage?.trim().isNotEmpty == true
            ? etaMessage!.trim()
            : etaSeconds == null
            ? '--'
            : etaSeconds <= 0
            ? l10n.etaArriving
            : etaSeconds < 60
            ? l10n.etaSeconds(etaSeconds)
            : l10n.etaMinutes(etaSeconds ~/ 60),
      ),
      if (vehicle.note.trim().isNotEmpty)
        (label: l10n.routeDetailVehicleNotes, value: vehicle.note.trim()),
      if (vehicle.full)
        (
          label: l10n.routeDetailVehicleCondition,
          value: l10n.routeDetailVehicleFull,
        ),
      if (vehicle.carOnStop)
        (label: l10n.routeMapArrival, value: l10n.routeDetailVehicleAtStop),
      if (_isElectricVehicle(vehicle))
        (
          label: l10n.routeDetailVehicleType,
          value: l10n.routeDetailVehicleElectric,
        ),
      if (vehicle.type == '1')
        (
          label: l10n.routeDetailVehicleEquipment,
          value: l10n.routeDetailVehicleAccessible,
        ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final bottomTheme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RouteStatusPill(
                      icon: statusStyle.icon,
                      label: null,
                      backgroundColor: statusStyle.backgroundColor,
                      foregroundColor: statusStyle.foregroundColor,
                      borderColor: statusStyle.borderColor,
                      glowColor: statusStyle.glowColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.id,
                            style: bottomTheme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          TransitStationName(
                            name: stop.transitName,
                            primaryStyle: bottomTheme.textTheme.bodyMedium
                                ?.copyWith(
                                  color:
                                      bottomTheme.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final row in detailRows) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          row.label,
                          style: bottomTheme.textTheme.labelLarge?.copyWith(
                            color: bottomTheme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          row.value,
                          style: bottomTheme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _playSelectionHaptic();
                      unawaited(_showVehicleOnMap(stop, vehicle));
                    },
                    icon: const Icon(Icons.map_rounded),
                    label: Text(l10n.routeDetailViewOnMap),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _playSelectionHaptic();
                      unawaited(
                        _handleVehicleAction(
                          vehicle,
                          _VehicleAction.twBusForum,
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(l10n.routeDetailSearchForum),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _displayStopName(BuildContext context, StopInfo stop) {
    return stop.transitName.stationDisplayForLocale(
      Localizations.localeOf(context).toLanguageTag(),
    );
  }

  bool _isElectricVehicle(BusVehicle vehicle) {
    final vehicleId = vehicle.id.trim().toUpperCase();
    final note = vehicle.note.toLowerCase();
    final type = vehicle.type.toLowerCase();
    return vehicle.electric ||
        vehicleId.startsWith('E') ||
        vehicleId.endsWith('FV') ||
        vehicle.note.contains('電動') ||
        vehicle.note.contains('純電') ||
        vehicle.note.contains('電巴') ||
        note.contains('electric') ||
        note.contains('e-bus') ||
        note.contains('e_bus') ||
        type.contains('electric') ||
        type.contains('e-bus') ||
        type.contains('e_bus');
  }

  Color _blendColor(Color start, Color end, double amount) {
    return Color.lerp(start, end, amount.clamp(0.0, 1.0)) ?? end;
  }

  ({double severity, DateTime? updatedAt}) _vehicleOfflineState(
    BusVehicle vehicle,
  ) {
    return (
      severity: busOfflineSeverity(source: vehicle.source),
      updatedAt: null,
    );
  }

  bool _hasUrgentVehicleEta(
    StopInfo stop,
    BusVehicle vehicle, {
    required bool Function(int seconds) predicate,
  }) {
    if (hasSyntheticVehicleEta(stop, vehicle.id)) {
      return false;
    }
    final seconds = effectiveStopEtaSecondsForVehicle(stop, vehicle.id);
    return seconds != null && predicate(seconds);
  }

  bool _hasUrgentStopEta(
    StopInfo stop, {
    required bool Function(int seconds) predicate,
  }) {
    for (final vehicle in stop.buses) {
      if (_hasUrgentVehicleEta(stop, vehicle, predicate: predicate)) {
        return true;
      }
    }
    return false;
  }

  String _vehicleStatusTooltip(StopInfo stop) {
    final l10n = AppLocalizations.of(context);
    final ids = localizedList(l10n, stop.buses.map((vehicle) => vehicle.id));
    final flags = <String>[
      if (stop.buses.any((vehicle) => vehicle.carOnStop)) l10n.etaArriving,
      if (stop.buses.any((vehicle) => vehicle.full))
        l10n.routeDetailVehicleFullShort,
      if (stop.buses.any(_isElectricVehicle))
        l10n.routeDetailVehicleElectricShort,
      if (stop.buses.any((vehicle) => vehicle.type == '1'))
        l10n.routeDetailVehicleAccessibleShort,
    ];
    if (flags.isEmpty) {
      return ids;
    }
    return '$ids · ${flags.join(' · ')}';
  }

  _VehicleStatusStyle _vehicleStatusStyleForVehicle(
    ThemeData theme,
    StopInfo stop,
    BusVehicle vehicle, {
    required bool isNearest,
  }) {
    final seconds = effectiveStopEtaSecondsForVehicle(stop, vehicle.id);
    final hasSyntheticEta = hasSyntheticVehicleEta(stop, vehicle.id);
    final hasArrivingBus =
        vehicle.carOnStop ||
        (!hasSyntheticEta && seconds != null && seconds <= 0);
    final isLessThanOneMinute =
        !hasSyntheticEta && seconds != null && seconds > 0 && seconds < 60;
    final isUrgentEta =
        !hasSyntheticEta && seconds != null && seconds >= 60 && seconds < 180;
    final hasFullBus = vehicle.full;
    final hasElectricBus = _isElectricVehicle(vehicle);
    final hasAccessibleBus = vehicle.type == '1';
    final vehicleIcon = hasElectricBus
        ? Icons.electric_bolt_rounded
        : Icons.directions_bus_filled_rounded;

    _VehicleStatusStyle style;
    if (hasArrivingBus) {
      style = _VehicleStatusStyle(
        icon: vehicleIcon,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        borderColor: Colors.red.shade200.withValues(alpha: 0.85),
        glowColor: Colors.red.shade500.withValues(alpha: 0.38),
      );
    } else if (isLessThanOneMinute) {
      style = _VehicleStatusStyle(
        icon: hasElectricBus
            ? Icons.electric_bolt_rounded
            : Icons.timer_rounded,
        backgroundColor: Colors.deepOrange.shade600,
        foregroundColor: Colors.white,
        borderColor: Colors.orange.shade200.withValues(alpha: 0.8),
        glowColor: Colors.deepOrange.shade400.withValues(alpha: 0.32),
      );
    } else if (isUrgentEta) {
      style = _VehicleStatusStyle(
        icon: hasElectricBus
            ? Icons.electric_bolt_rounded
            : Icons.timer_rounded,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        borderColor: Colors.orange.shade200.withValues(alpha: 0.78),
        glowColor: Colors.orange.shade400.withValues(alpha: 0.28),
      );
    } else if (hasFullBus) {
      style = _VehicleStatusStyle(
        icon: hasElectricBus
            ? Icons.electric_bolt_rounded
            : Icons.groups_rounded,
        backgroundColor: Colors.brown.shade600,
        foregroundColor: Colors.white,
        borderColor: Colors.orange.shade200.withValues(alpha: 0.75),
        glowColor: Colors.brown.shade400.withValues(alpha: 0.28),
      );
    } else if (hasElectricBus) {
      style = _VehicleStatusStyle(
        icon: Icons.electric_bolt_rounded,
        backgroundColor: Colors.amber.shade500,
        foregroundColor: Colors.black87,
        borderColor: Colors.amber.shade100.withValues(alpha: 0.9),
        glowColor: Colors.amber.shade400.withValues(alpha: 0.3),
      );
    } else if (isNearest) {
      style = _VehicleStatusStyle(
        icon: Icons.gps_fixed_rounded,
        backgroundColor: Colors.cyan.shade400,
        foregroundColor: Colors.black87,
        borderColor: Colors.cyan.shade100.withValues(alpha: 0.8),
        glowColor: Colors.cyan.shade300.withValues(alpha: 0.32),
      );
    } else if (hasAccessibleBus) {
      style = _VehicleStatusStyle(
        icon: Icons.accessible_rounded,
        backgroundColor: Colors.indigo.shade500,
        foregroundColor: Colors.white,
        borderColor: Colors.indigo.shade100.withValues(alpha: 0.7),
        glowColor: Colors.indigo.shade300.withValues(alpha: 0.2),
      );
    } else {
      style = _VehicleStatusStyle(
        icon: Icons.directions_bus_rounded,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        borderColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        glowColor: theme.colorScheme.primary.withValues(alpha: 0.16),
      );
    }

    final offlineState = _vehicleOfflineState(vehicle);
    if (offlineState.severity <= 0) {
      return style;
    }

    return _VehicleStatusStyle(
      icon: offlineState.severity >= 0.65 ? Icons.wifi_off_rounded : style.icon,
      backgroundColor: _blendColor(
        style.backgroundColor,
        Colors.red.shade800,
        offlineState.severity * 0.88,
      ),
      foregroundColor: style.foregroundColor,
      borderColor: _blendColor(
        style.borderColor,
        Colors.red.shade200,
        offlineState.severity * 0.72,
      ),
      glowColor: _blendColor(
        style.glowColor,
        Colors.red.shade400.withValues(alpha: 0.34),
        offlineState.severity * 0.82,
      ),
    );
  }

  _VehicleStatusStyle _vehicleStatusStyle(
    ThemeData theme,
    StopInfo stop, {
    required bool isNearest,
  }) {
    if (stop.buses.length == 1) {
      return _vehicleStatusStyleForVehicle(
        theme,
        stop,
        stop.buses.first,
        isNearest: isNearest,
      );
    }

    final hasMultipleBuses = stop.buses.length > 1;
    final hasArrivingBus =
        stop.buses.any((vehicle) => vehicle.carOnStop) ||
        _hasUrgentStopEta(stop, predicate: (seconds) => seconds <= 0);
    final isLessThanOneMinute = _hasUrgentStopEta(
      stop,
      predicate: (seconds) => seconds > 0 && seconds < 60,
    );
    final isUrgentEta = _hasUrgentStopEta(
      stop,
      predicate: (seconds) => seconds >= 60 && seconds < 180,
    );
    final hasFullBus = stop.buses.any((vehicle) => vehicle.full);
    final hasElectricBus = stop.buses.any(_isElectricVehicle);
    final hasAccessibleBus = stop.buses.any((vehicle) => vehicle.type == '1');
    final maxOfflineSeverity = stop.buses
        .map((vehicle) => _vehicleOfflineState(vehicle).severity)
        .fold<double>(0.0, math.max);
    final vehicleIcon = hasElectricBus
        ? Icons.electric_bolt_rounded
        : Icons.directions_bus_filled_rounded;

    _VehicleStatusStyle style;
    if (hasArrivingBus) {
      style = _VehicleStatusStyle(
        icon: vehicleIcon,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        borderColor: Colors.red.shade200.withValues(alpha: 0.85),
        glowColor: Colors.red.shade500.withValues(alpha: 0.38),
        showStackedBuses: hasMultipleBuses,
      );
    } else if (isLessThanOneMinute) {
      style = _VehicleStatusStyle(
        icon: hasElectricBus
            ? Icons.electric_bolt_rounded
            : Icons.timer_rounded,
        backgroundColor: Colors.deepOrange.shade600,
        foregroundColor: Colors.white,
        borderColor: Colors.orange.shade200.withValues(alpha: 0.8),
        glowColor: Colors.deepOrange.shade400.withValues(alpha: 0.32),
        showStackedBuses: hasMultipleBuses,
      );
    } else if (isUrgentEta) {
      style = _VehicleStatusStyle(
        icon: hasElectricBus
            ? Icons.electric_bolt_rounded
            : Icons.timer_rounded,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        borderColor: Colors.orange.shade200.withValues(alpha: 0.78),
        glowColor: Colors.orange.shade400.withValues(alpha: 0.28),
        showStackedBuses: hasMultipleBuses,
      );
    } else if (hasFullBus) {
      style = _VehicleStatusStyle(
        icon: hasElectricBus
            ? Icons.electric_bolt_rounded
            : Icons.groups_rounded,
        backgroundColor: Colors.brown.shade600,
        foregroundColor: Colors.white,
        borderColor: Colors.orange.shade200.withValues(alpha: 0.75),
        glowColor: Colors.brown.shade400.withValues(alpha: 0.28),
        showStackedBuses: hasMultipleBuses,
      );
    } else if (hasElectricBus) {
      style = _VehicleStatusStyle(
        icon: Icons.electric_bolt_rounded,
        backgroundColor: Colors.amber.shade500,
        foregroundColor: Colors.black87,
        borderColor: Colors.amber.shade100.withValues(alpha: 0.9),
        glowColor: Colors.amber.shade400.withValues(alpha: 0.3),
        showStackedBuses: hasMultipleBuses,
      );
    } else if (isNearest) {
      style = _VehicleStatusStyle(
        icon: Icons.gps_fixed_rounded,
        backgroundColor: Colors.cyan.shade400,
        foregroundColor: Colors.black87,
        borderColor: Colors.cyan.shade100.withValues(alpha: 0.8),
        glowColor: Colors.cyan.shade300.withValues(alpha: 0.32),
        showStackedBuses: hasMultipleBuses,
      );
    } else if (hasMultipleBuses) {
      style = _VehicleStatusStyle(
        icon: Icons.directions_bus_rounded,
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        borderColor: theme.colorScheme.secondary.withValues(alpha: 0.45),
        glowColor: theme.colorScheme.secondary.withValues(alpha: 0.2),
        showStackedBuses: true,
      );
    } else if (hasAccessibleBus) {
      style = _VehicleStatusStyle(
        icon: Icons.accessible_rounded,
        backgroundColor: Colors.indigo.shade500,
        foregroundColor: Colors.white,
        borderColor: Colors.indigo.shade100.withValues(alpha: 0.7),
        glowColor: Colors.indigo.shade300.withValues(alpha: 0.2),
      );
    } else {
      style = _VehicleStatusStyle(
        icon: Icons.directions_bus_rounded,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        borderColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        glowColor: theme.colorScheme.primary.withValues(alpha: 0.16),
      );
    }

    if (maxOfflineSeverity <= 0) {
      return style;
    }

    return _VehicleStatusStyle(
      icon: maxOfflineSeverity >= 0.65 ? Icons.wifi_off_rounded : style.icon,
      backgroundColor: _blendColor(
        style.backgroundColor,
        Colors.red.shade800,
        maxOfflineSeverity * 0.82,
      ),
      foregroundColor: style.foregroundColor,
      borderColor: _blendColor(
        style.borderColor,
        Colors.red.shade200,
        maxOfflineSeverity * 0.7,
      ),
      glowColor: _blendColor(
        style.glowColor,
        Colors.red.shade400.withValues(alpha: 0.32),
        maxOfflineSeverity * 0.8,
      ),
      showStackedBuses: style.showStackedBuses,
    );
  }

  double _measureMaxLineWidth(
    BuildContext context,
    String text,
    TextStyle? style,
  ) {
    final textDirection = Directionality.of(context);
    var maxWidth = 0.0;
    for (final line in text.split('\n')) {
      final painter = TextPainter(
        text: TextSpan(text: line, style: style),
        maxLines: 1,
        textDirection: textDirection,
      )..layout();
      maxWidth = math.max(maxWidth, painter.width);
    }
    return maxWidth;
  }

  double _estimateRouteStatusPillWidth(
    BuildContext context, {
    required IconData icon,
    String? label,
    bool showStackedBuses = false,
  }) {
    final hasLabel = label != null && label.trim().isNotEmpty;
    final labelWidth = hasLabel
        ? _measureMaxLineWidth(
            context,
            label,
            const TextStyle(fontWeight: FontWeight.w700),
          )
        : 0.0;
    final horizontalPadding = hasLabel ? 28.0 : 20.0;
    final gap = hasLabel ? 8.0 : 0.0;
    final iconWidth = showStackedBuses ? 22.0 : 18.0;
    return horizontalPadding + iconWidth + gap + labelWidth;
  }

  Widget _buildVehicleMenuItem(BuildContext context, BusVehicle vehicle) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final details = <String>[
      if (vehicle.note.trim().isNotEmpty) vehicle.note.trim(),
      if (vehicle.full) l10n.routeDetailVehicleFull,
      if (vehicle.carOnStop) l10n.etaArriving,
      l10n.routeDetailSearchForum,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          vehicle.type == '1'
              ? Icons.accessible_rounded
              : Icons.directions_bus_rounded,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.id,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(details.join(' · '), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildTrailingStatus(
    BuildContext context,
    ThemeData theme,
    StopInfo stop, {
    required bool isNearest,
    required bool isDestination,
  }) {
    final vehicleStatus = _buildVehicleTrailingStatus(
      context,
      theme,
      stop,
      isNearest: isNearest,
    );

    if (isNearest) {
      final locationStatus = _RouteStatusPill(
        key: const ValueKey('route-detail-nearest-stop-status'),
        icon: Icons.gps_fixed_rounded,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      );
      if (vehicleStatus == null) {
        return locationStatus;
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [vehicleStatus, const SizedBox(width: 8), locationStatus],
      );
    }

    if (isDestination) {
      return _RouteStatusPill(
        icon: Icons.flag_rounded,
        label: AppLocalizations.of(context).routeDetailDestinationStop,
        backgroundColor: theme.colorScheme.tertiaryContainer,
        foregroundColor: theme.colorScheme.onTertiaryContainer,
      );
    }

    return vehicleStatus;
  }

  Widget? _buildVehicleTrailingStatus(
    BuildContext context,
    ThemeData theme,
    StopInfo stop, {
    required bool isNearest,
  }) {
    if (stop.buses.isNotEmpty) {
      final statusStyle = _vehicleStatusStyle(
        theme,
        stop,
        isNearest: isNearest,
      );
      final primaryVehicle = stop.buses.first;
      final pill = _RouteStatusPill(
        key: ValueKey(
          'route-detail-trailing-status-${stop.pathId}-${stop.stopId}',
        ),
        icon: statusStyle.icon,
        label: null,
        backgroundColor: statusStyle.backgroundColor,
        foregroundColor: statusStyle.foregroundColor,
        borderColor: statusStyle.borderColor,
        glowColor: statusStyle.glowColor,
        showStackedBuses: statusStyle.showStackedBuses,
        stackCount: stop.buses.length,
      );

      if (stop.buses.length == 1) {
        return Tooltip(
          message: _vehicleStatusTooltip(stop),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              _playSelectionHaptic();
              unawaited(
                _showVehicleDetails(stop, primaryVehicle, isNearest: isNearest),
              );
            },
            child: pill,
          ),
        );
      }

      return PopupMenuButton<BusVehicle>(
        padding: EdgeInsets.zero,
        tooltip: _vehicleStatusTooltip(stop),
        onSelected: (vehicle) {
          _playSelectionHaptic();
          unawaited(_showVehicleDetails(stop, vehicle, isNearest: isNearest));
        },
        itemBuilder: (context) {
          return [
            for (final vehicle in stop.buses)
              PopupMenuItem<BusVehicle>(
                value: vehicle,
                child: _buildVehicleMenuItem(context, vehicle),
              ),
          ];
        },
        child: pill,
      );
    }

    return null;
  }

  Widget _buildStopTile(
    BuildContext context,
    ThemeData theme,
    StopInfo stop, {
    required bool alwaysShowSeconds,
    required bool isHighlighted,
    required bool isNearest,
    required bool isDestination,
  }) {
    final l10n = AppLocalizations.of(context);
    final stopNameStyle = theme.textTheme.headlineSmall?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.primary,
      height: 1.2,
    );
    final stopName = _displayStopName(context, stop);
    final hasAlert = _stopHasAlert(stop);

    return Material(
      key: ValueKey('route-detail-stop-${stop.pathId}-${stop.stopId}'),
      color: isHighlighted
          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.45)
          : isDestination
          ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.22)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _playSelectionHaptic();
          unawaited(_openStopActionsWithShortcut(stop));
        },
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                EtaBadge(
                  stop: stop,
                  alwaysShowSeconds: alwaysShowSeconds,
                  size: 58,
                  isLoading: !_hasCompletedInitialRealtime,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final trailingStatus = _buildTrailingStatus(
                            context,
                            theme,
                            stop,
                            isNearest: isNearest,
                            isDestination: isDestination,
                          );
                          final vehicleStatusStyle = stop.buses.isEmpty
                              ? null
                              : _vehicleStatusStyle(
                                  theme,
                                  stop,
                                  isNearest: isNearest,
                                );
                          final trailingStatusWidth = switch ((
                            isNearest,
                            isDestination,
                            stop.buses.isNotEmpty,
                          )) {
                            (true, _, true) =>
                              _estimateRouteStatusPillWidth(
                                    context,
                                    icon: vehicleStatusStyle!.icon,
                                    showStackedBuses:
                                        vehicleStatusStyle.showStackedBuses,
                                  ) +
                                  8.0 +
                                  _estimateRouteStatusPillWidth(
                                    context,
                                    icon: Icons.gps_fixed_rounded,
                                  ),
                            (true, _, false) => _estimateRouteStatusPillWidth(
                              context,
                              icon: Icons.gps_fixed_rounded,
                            ),
                            (false, true, _) => _estimateRouteStatusPillWidth(
                              context,
                              icon: Icons.flag_rounded,
                              label: l10n.routeDetailDestinationStop,
                            ),
                            (false, false, true) =>
                              _estimateRouteStatusPillWidth(
                                context,
                                icon: vehicleStatusStyle!.icon,
                                label: null,
                                showStackedBuses:
                                    vehicleStatusStyle.showStackedBuses,
                              ),
                            _ => 0.0,
                          };
                          final stopNameMaxWidth = math.max(
                            0.0,
                            constraints.maxWidth -
                                trailingStatusWidth -
                                (trailingStatus == null ? 0.0 : 8.0) -
                                (hasAlert ? 16.0 : 0.0) -
                                4.0,
                          );
                          final stopNameWidth = math.min(
                            _measureMaxLineWidth(
                              context,
                              stopName,
                              stopNameStyle,
                            ),
                            math.min(stopNameMaxWidth, constraints.maxWidth),
                          );
                          final dividerLeftOffset =
                              stopNameWidth +
                              16.0 +
                              (hasAlert ? 16.0 + 6.0 : 0.0);
                          final dividerRightOffset = trailingStatus == null
                              ? 0.0
                              : trailingStatusWidth + 8.0;
                          final showDivider =
                              constraints.maxWidth -
                                  dividerLeftOffset -
                                  dividerRightOffset >=
                              24.0;

                          return SizedBox(
                            width: constraints.maxWidth,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                if (showDivider)
                                  Positioned(
                                    left: dividerLeftOffset,
                                    right: dividerRightOffset,
                                    child: Container(
                                      height: 1,
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 40,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: SizedBox(
                                          width: stopNameWidth,
                                          child: TransitStationName(
                                            name: stop.transitName,
                                            primaryStyle: stopNameStyle,
                                          ),
                                        ),
                                      ),
                                      if (hasAlert) ...[
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: _showAlertsDialog,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: _alertColorForStop(stop),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color:
                                                    theme.colorScheme.surface,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (trailingStatus != null)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: trailingStatus,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStopsPane(
    BuildContext context,
    ThemeData theme,
    AppController controller,
    RouteDetailData detail,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        if (_tabController != null)
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: detail.paths
                .map(
                  (path) => Tab(
                    child: TransitStationName(
                      name: path.transitName,
                      primaryStyle: theme.textTheme.labelLarge,
                      textAlign: TextAlign.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                    ),
                  ),
                )
                .toList(),
          ),
        Expanded(
          child: FadeTransition(
            key: const ValueKey('route-stops-fade'),
            opacity: _initialStopsOpacity,
            child: _tabController == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: CatStateCard(
                        mood: CatStateMood.sad,
                        title: l10n.routeDetailNoDirectionsTitle,
                        message: l10n.routeDetailNoDirectionsMessage,
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: detail.paths.map((path) {
                      final pathStops =
                          detail.stopsByPath[path.pathId] ?? const <StopInfo>[];
                      if (pathStops.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: CatStateCard(
                              mood: CatStateMood.sad,
                              title: l10n.routeDetailNoStopsTitle,
                              message: l10n.routeDetailNoStopsMessage,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: _scrollControllerForPath(path.pathId),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: pathStops.length + 2,
                        separatorBuilder: (_, _) => const SizedBox(height: 18),
                        itemBuilder: (context, index) {
                          if (index == 0 || index == pathStops.length + 1) {
                            return const AdBannerWidget();
                          }
                          final stop = pathStops[index - 1];
                          final stopKey = _keyForStop(path.pathId, stop.stopId);
                          final key = _stopKeys.putIfAbsent(
                            stopKey,
                            GlobalKey.new,
                          );
                          return Container(
                            key: key,
                            child: _buildStopTile(
                              context,
                              theme,
                              stop,
                              alwaysShowSeconds:
                                  controller.settings.alwaysShowSeconds,
                              isHighlighted: _isInitialStop(stop),
                              isNearest: _isNearestStop(stop),
                              isDestination: _isDestinationStop(stop),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineMapPane(
    BuildContext context,
    AppController controller,
    RouteDetailData detail,
  ) {
    final routeId = detail.route.routeId.trim();
    final currentPathId = _currentPathId;
    if (routeId.isEmpty || currentPathId == null) {
      return ColoredBox(
        color: Colors.transparent,
        child: Center(
          child: Text(AppLocalizations.of(context).routeDetailNoMapData),
        ),
      );
    }

    return RouteBusMapSheet(
      routeKey: widget.routeKey,
      provider: widget.provider,
      routeId: routeId,
      routeIdHint: widget.routeIdHint,
      routeName: detail.route.routeName,
      routeNameEn: detail.route.routeNameEn,
      paths: detail.paths,
      stopsByPath: detail.stopsByPath,
      familyRouteIds: detail.familyRouteIds,
      familyRouteIdsListenable: _liveMapFamilyRouteIds,
      liveStopsByPathListenable: _liveMapStopsByPath,
      alwaysShowSeconds: controller.settings.alwaysShowSeconds,
      selectedPathIdListenable: _selectedMapPathId,
      focusedVehicleId: _focusedMapVehicleId,
      focusedVehicleRequest: _focusedMapVehicleRequest,
      refreshIntervalSeconds: controller.settings.busUpdateTime,
      onSelectedPathChanged: _handleMapPathSelection,
      embedded: true,
    );
  }

  Widget _buildInitialLoadingBody(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;
    final hasInitialNotices =
        _alerts.isNotEmpty || _initialCancelledDepartures.isNotEmpty;
    return IgnorePointer(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasInitialNotices)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Column(
                    children: [
                      if (_alerts.isNotEmpty)
                        _buildInitialNoticeCard(
                          theme: theme,
                          icon: Icons.campaign_rounded,
                          title: l10n.routeDetailRouteNotice,
                          message: _alerts.first.title.trim().isEmpty
                              ? l10n.routeDetailNoticeUpdate
                              : _alerts.first.title.trim(),
                          additionalCount: _alerts.length - 1,
                        ),
                      if (_alerts.isNotEmpty &&
                          _initialCancelledDepartures.isNotEmpty)
                        const SizedBox(height: 8),
                      if (_initialCancelledDepartures.isNotEmpty)
                        _buildInitialNoticeCard(
                          theme: theme,
                          icon: Icons.event_busy_rounded,
                          title: l10n.routeDetailCancelledDepartures,
                          message: localizedList(
                            l10n,
                            _initialCancelledDepartures
                                .take(8)
                                .map((departure) => departure.departureTime),
                          ),
                          additionalCount:
                              _initialCancelledDepartures.length - 8,
                        ),
                    ],
                  ),
                ),
              Opacity(
                opacity: 0.7,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialNoticeCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String message,
    required int additionalCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onErrorContainer, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  additionalCount > 0
                      ? AppLocalizations.of(
                          context,
                        ).routeDetailAdditionalNotices(message, additionalCount)
                      : message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayPathName(BuildContext context, PathInfo path) {
    return path.transitName.stationDisplayForLocale(
      Localizations.localeOf(context).toLanguageTag(),
    );
  }

  String? _localizedStatus(AppLocalizations l10n) => switch (_status) {
    _RouteDetailStatus.refreshing => l10n.routeDetailStatusRefreshing,
    _RouteDetailStatus.loadingRoute => l10n.routeDetailStatusLoadingRoute,
    _RouteDetailStatus.loadingRealtime => l10n.routeDetailStatusLoadingRealtime,
    _RouteDetailStatus.realtimeUnavailable =>
      l10n.routeDetailStatusRealtimeUnavailable,
    _RouteDetailStatus.loadFailed => l10n.routeDetailStatusLoadFailed,
    _RouteDetailStatus.loadingFamily => l10n.routeDetailStatusLoadingFamily,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final detail = _detail;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = controller.settings;
    final isAmoled =
        settings.useAmoledDark && settings.themeMode != ThemeMode.light;
    final hasRouteDetailBackgroundImage = hasBackgroundImageForPage(
      settings,
      pageKey: 'route_detail',
    );
    final currentPathId = _currentPathId;
    final currentNearestStopId = currentPathId == null
        ? null
        : _nearestStopByPath[currentPathId];
    final canOpenBackgroundTripMonitorDrawer =
        settings.enableRouteBackgroundMonitor && _currentPathStops.isNotEmpty;
    final isWideLayout =
        MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;
    final canShowInlineMap =
        isWideLayout && detail != null && currentPathId != null;
    final showInlineMap = canShowInlineMap && _showWideMapPanel;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final baseBottomBarColor =
        theme.bottomAppBarTheme.color ??
        (hasRouteDetailBackgroundImage && !isAmoled
            ? theme.colorScheme.surface.withValues(
                alpha: (theme.appBarTheme.backgroundColor?.a ?? 1.0),
              )
            : theme.colorScheme.surface);
    final bottomBarColor = baseBottomBarColor.a < 0.92
        ? baseBottomBarColor.withValues(alpha: 0.92)
        : baseBottomBarColor;

    return BackgroundImageWrapper(
      pageKey: 'route_detail',
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: hasRouteDetailBackgroundImage
            ? Colors.transparent
            : null,
        endDrawer: canOpenBackgroundTripMonitorDrawer
            ? _buildBackgroundTripMonitorDrawer(context)
            : null,
        appBar: AppBar(
          title: Text(
            detail?.route.transitName.displayForLocale(
                  Localizations.localeOf(context).toLanguageTag(),
                ) ??
                widget.routeNameHint ??
                l10n.routeDetailTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (detail != null && currentPathId != null)
              IconButton(
                onPressed: () {
                  if (isWideLayout) {
                    setState(() {
                      _showWideMapPanel = !_showWideMapPanel;
                    });
                    return;
                  }
                  unawaited(_openBusMapSheet());
                },
                tooltip: isWideLayout
                    ? (showInlineMap
                          ? l10n.routeDetailHideMap
                          : l10n.routeDetailShowMap)
                    : l10n.routeMapTitle,
                icon: Icon(
                  showInlineMap ? Icons.map_rounded : Icons.map_outlined,
                ),
              ),
            if (currentPathId != null && currentNearestStopId != null)
              IconButton(
                onPressed: () => unawaited(
                  _scrollToStop(currentPathId, currentNearestStopId),
                ),
                tooltip: l10n.routeDetailJumpToNearestStop,
                icon: const Icon(Icons.gps_fixed_rounded),
              ),
            if (canOpenBackgroundTripMonitorDrawer)
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                tooltip: l10n.routeDetailBackgroundDrawerTitle,
                icon: Icon(
                  _backgroundTripMonitorPaused
                      ? Icons.notifications_paused_outlined
                      : Icons.notifications_active_outlined,
                ),
              ),
            IconButton(
              onPressed: detail == null
                  ? null
                  : () async {
                      if (_alerts.isNotEmpty) {
                        await _markCurrentRouteAlertsAsRead();
                      }
                      if (!mounted) {
                        return;
                      }
                      if (_alerts.isNotEmpty && !_alertsRead) {
                        setState(() {
                          _alertsRead = true;
                        });
                      }
                      _showRouteInfoDialog(detail);
                    },
              tooltip: l10n.routeDetailScheduleTooltip,
              icon: _alerts.isNotEmpty && !_alertsRead
                  ? const Badge(
                      smallSize: 8,
                      child: Icon(Icons.schedule_rounded),
                    )
                  : const Icon(Icons.schedule_rounded),
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: bottomBarColor,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBottomProgressIndicator(),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _remainingSeconds,
                    builder: (context, remainingSeconds, child) {
                      return Text(
                        _localizedStatus(l10n) ??
                            (remainingSeconds > 0
                                ? l10n.routeMapRefreshCountdown(
                                    remainingSeconds,
                                  )
                                : l10n.routeDetailStatusRefreshing),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        body: _isLoading && detail == null
            ? _buildInitialLoadingBody(context, theme)
            : detail == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CatStateCard(
                    mood: CatStateMood.cry,
                    title: l10n.routeDetailErrorTitle,
                    message: _error ?? l10n.routeDetailErrorMessage,
                    actionLabel: l10n.commonReload,
                    onAction: () => unawaited(_refresh()),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final canUseWideLayout =
                      constraints.maxWidth >= _wideLayoutBreakpoint;
                  final showWideMap =
                      canUseWideLayout &&
                      _showWideMapPanel &&
                      currentPathId != null;
                  final stopsPane = _buildStopsPane(
                    context,
                    theme,
                    controller,
                    detail,
                  );
                  if (!showWideMap) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: stopsPane,
                      ),
                    );
                  }

                  final maxMapPaneWidth = math.max(
                    400.0,
                    constraints.maxWidth - 420.0,
                  );
                  final mapPaneWidth = math
                      .min(
                        math.max(constraints.maxWidth * 0.55, 520),
                        maxMapPaneWidth,
                      )
                      .toDouble();
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: stopsPane),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      SizedBox(
                        width: mapPaneWidth,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: _buildInlineMapPane(
                            context,
                            controller,
                            detail,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _VehicleStatusStyle {
  const _VehicleStatusStyle({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.glowColor,
    this.showStackedBuses = false,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final Color glowColor;
  final bool showStackedBuses;
}

class _RouteStatusPill extends StatelessWidget {
  const _RouteStatusPill({
    super.key,
    required this.icon,
    this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    this.glowColor,
    this.showStackedBuses = false,
    this.stackCount,
  });

  final IconData icon;
  final String? label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Color? glowColor;
  final bool showStackedBuses;
  final int? stackCount;

  Widget _buildIcon() {
    if (!showStackedBuses) {
      return Icon(icon, size: 18, color: foregroundColor);
    }

    final count = stackCount ?? 2;
    final badgeText = count > 9 ? '9+' : '$count';

    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: foregroundColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: backgroundColor, width: 1.5),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: backgroundColor,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = label != null && label!.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: hasLabel ? 14 : 10,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: glowColor == null
            ? null
            : [BoxShadow(color: glowColor!, blurRadius: 14, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(),
          if (hasLabel) ...[
            const SizedBox(width: 8),
            Text(
              label!,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteInfoDialog extends StatefulWidget {
  const _RouteInfoDialog({
    required this.detail,
    required this.alerts,
    required this.repository,
    required this.provider,
    required this.routeKey,
    required this.onFavoriteRoute,
    this.onPinRoute,
  });

  final RouteDetailData detail;
  final List<RouteAlert> alerts;
  final BusRepository repository;
  final BusProvider provider;
  final int routeKey;
  final Future<void> Function() onFavoriteRoute;
  final Future<void> Function()? onPinRoute;

  @override
  State<_RouteInfoDialog> createState() => _RouteInfoDialogState();
}

class _RouteInfoDialogState extends State<_RouteInfoDialog> {
  List<RouteOperator>? _operators;
  List<_RouteSchedule>? _schedules;
  Set<String> _cancelledDepartures = const <String>{};
  String? _selectedScheduleRouteId;
  bool _loading = true;
  String? _error;
  final Set<String> _expandedAlertIds = <String>{};
  DateTime _selectedDate = DateTime.now();

  /// Cache of `yyyy-MM-dd` -> isHoliday, populated from the API per year.
  /// Empty for a date means: no explicit entry, fall back to the weekend rule.
  final Map<String, bool> _holidayMap = <String, bool>{};
  final Set<int> _loadedHolidayYears = <int>{};

  @override
  void initState() {
    super.initState();
    _loadData();
    _ensureHolidaysLoaded(_selectedDate.year);
  }

  Future<void> _ensureHolidaysLoaded(int year) async {
    if (_loadedHolidayYears.contains(year)) return;
    _loadedHolidayYears.add(year);
    try {
      final map = await widget.repository.fetchHolidaysForYear(year);
      if (!mounted || map.isEmpty) return;
      setState(() => _holidayMap.addAll(map));
    } catch (_) {
      // Ignore: detection falls back to the weekend rule.
    }
  }

  Future<void> _loadData() async {
    final routeId = widget.detail.route.routeId;
    try {
      final family = await widget.repository.getRouteFamily(
        widget.detail.route,
        provider: widget.provider,
      );
      final results = await Future.wait<Object>([
        widget.repository.fetchRouteOperators(routeId),
        ...family.map((route) async {
          final entries = await widget.repository.fetchRouteSchedule(
            route.routeId,
          );
          return _RouteSchedule(route: route, entries: entries);
        }),
      ]);
      if (!mounted) return;
      setState(() {
        _operators = results[0] as List<RouteOperator>;
        _schedules = results.skip(1).cast<_RouteSchedule>().toList();
        _loading = false;
      });
      unawaited(_loadCancelledDepartures());
    } catch (e) {
      debugPrint('RouteInfoDialog load error for $routeId: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = localizedFriendlyError(AppLocalizations.of(context), e);
      });
    }
  }

  Future<void> _loadCancelledDepartures() async {
    final schedules = _schedules;
    if (widget.provider != BusProvider.txg || schedules == null) {
      return;
    }
    try {
      final cancelledByRoute = await Future.wait(
        schedules.map((schedule) async {
          final departures = await widget.repository
              .fetchTaichungCancelledDepartures(
                routeId: schedule.route.routeId,
                routeName: schedule.route.routeName,
                date: _selectedDate,
              );
          return departures.map(
            (departure) =>
                '${schedule.route.routeId}:${departure.direction}:${departure.departureTime}',
          );
        }),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _cancelledDepartures = cancelledByRoute
            .expand((items) => items)
            .toSet();
      });
    } catch (_) {
      // Cancellation data is supplementary to the timetable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final route = widget.detail.route;

    return AlertDialog(
      title: Text(
        route.transitName.displayForLocale(
          Localizations.localeOf(context).toLanguageTag(),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (route.description.isNotEmpty ||
                (route.pathNameEn?.trim().isNotEmpty ?? false)) ...[
              Text(
                route.transitPathName.stationDisplayForLocale(
                  Localizations.localeOf(context).toLanguageTag(),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            Text(l10n.routeInfoActions, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _runRouteAction(widget.onFavoriteRoute),
                  icon: const Icon(Icons.favorite_border_rounded, size: 18),
                  label: Text(l10n.routeInfoFavoriteRoute),
                ),
                if (widget.onPinRoute case final onPinRoute?)
                  OutlinedButton.icon(
                    onPressed: () => _runRouteAction(onPinRoute),
                    icon: const Icon(
                      Icons.add_to_home_screen_rounded,
                      size: 18,
                    ),
                    label: Text(l10n.commonAddToHomeScreen),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (widget.alerts.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.routeDetailOperationsNotice,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final alert in widget.alerts)
                _buildExpandableAlertItem(alert, theme),
              const Divider(height: 20),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.routeInfoLoadFailed(_error!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (_operators != null && _operators!.isNotEmpty) ...[
                Text(
                  l10n.routeInfoOperators,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                for (final op in _operators!) _buildOperatorTile(op, theme),
                const Divider(height: 20),
              ],
              if (_schedules != null) ...[
                Row(
                  children: [
                    Text(
                      l10n.routeInfoFamilySchedule,
                      style: theme.textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _pickScheduleDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_formatSelectedDateLabel()),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_schedules!.length > 1) ...[
                  Text(
                    l10n.routeInfoRelatedRoutes,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.commonAll),
                        selected: _selectedScheduleRouteId == null,
                        onSelected: (_) =>
                            setState(() => _selectedScheduleRouteId = null),
                      ),
                      for (final schedule in _schedules!)
                        ChoiceChip(
                          label: Text(
                            schedule.route.transitName.displayForLocale(
                              Localizations.localeOf(context).toLanguageTag(),
                            ),
                          ),
                          selected:
                              _selectedScheduleRouteId ==
                              schedule.route.routeId,
                          onSelected: (_) => setState(
                            () => _selectedScheduleRouteId =
                                schedule.route.routeId,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                ..._buildScheduleSection(),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _shareRouteLink,
          icon: const Icon(Icons.share, size: 18),
          label: Text(l10n.routeInfoShareLink),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  void _runRouteAction(Future<void> Function() action) {
    Navigator.of(context).pop();
    unawaited(action());
  }

  static const String _appBaseUrl = 'https://busapp.avianjay.sbs';

  String _buildShareUrl() {
    final route = widget.detail.route;
    final path = AppRoutes.routeDetailPath(
      provider: widget.provider,
      routeKey: widget.routeKey,
      routeId: route.routeId,
    );
    final base = _appBaseUrl.endsWith('/')
        ? _appBaseUrl.substring(0, _appBaseUrl.length - 1)
        : _appBaseUrl;
    final suffix = path.startsWith('/') ? path : '/$path';
    return '$base$suffix';
  }

  Future<void> _shareRouteLink() async {
    final route = widget.detail.route;
    final url = _buildShareUrl();
    final routeName = route.transitName.displayForLocale(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final shareText = '$routeName\n$url';

    var shared = false;
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: shareText, subject: routeName),
      );
      shared = result.status != ShareResultStatus.unavailable;
    } catch (e) {
      debugPrint('Share route link failed, falling back to clipboard: $e');
      shared = false;
    }

    if (!shared) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).routeInfoLinkCopied),
        ),
      );
    }
  }

  Widget _buildExpandableAlertItem(RouteAlert alert, ThemeData theme) {
    final expanded = _expandedAlertIds.contains(alert.alertId);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          if (expanded) {
            _expandedAlertIds.remove(alert.alertId);
          } else {
            _expandedAlertIds.add(alert.alertId);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: alert.statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(alert.title, style: theme.textTheme.bodySmall),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            if (expanded) ...[
              if (alert.effectText.isNotEmpty || alert.causeText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 16),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      if (alert.effectText.isNotEmpty)
                        Chip(
                          label: Text(alert.effectText),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelStyle: theme.textTheme.labelSmall,
                          padding: EdgeInsets.zero,
                        ),
                      if (alert.causeText.isNotEmpty)
                        Chip(
                          label: Text(alert.causeText),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelStyle: theme.textTheme.labelSmall,
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              if (alert.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 16),
                  child: Text(
                    alert.description,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorTile(RouteOperator op, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            op.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (op.phone != null && op.phone!.isNotEmpty)
            Text(
              AppLocalizations.of(context).routeInfoPhone(op.phone!),
              style: theme.textTheme.bodySmall,
            ),
          if (op.url != null && op.url!.isNotEmpty)
            Text(
              AppLocalizations.of(context).routeInfoWebsite(op.url!),
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  String _formatSelectedDateLabel() {
    final d = _selectedDate;
    return localizedScheduleDate(
      AppLocalizations.of(context),
      d,
      isHoliday: _isHoliday(d),
    );
  }

  /// Determines whether [date] is a holiday (non-working day).
  ///
  /// Prefers the Taiwan holiday calendar fetched from the API (which handles
  /// national holidays and make-up working days). Falls back to the weekend
  /// rule (Sat/Sun = holiday) when there is no explicit entry — this keeps the
  /// behaviour compatible when the API is unavailable.
  bool _isHoliday(DateTime date) {
    final key = _dateKey(date);
    final explicit = _holidayMap[key];
    if (explicit != null) {
      return explicit;
    }
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  String _dateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  Future<void> _pickScheduleDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: AppLocalizations.of(context).scheduleChooseDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
    unawaited(_ensureHolidaysLoaded(picked.year));
    unawaited(_loadCancelledDepartures());
  }

  /// Determines whether a schedule entry is active on the selected date,
  /// based on its service-day flags (and holiday handling).
  bool _isEntryActiveOnSelectedDate(RouteScheduleEntry entry) {
    final days = entry.serviceDays;
    final date = _selectedDate;

    if (_isHoliday(date) && days['holiday'] == 1) {
      return true;
    }

    const weekdayKeys = <String>[
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun',
    ];
    final key = weekdayKeys[date.weekday - 1];
    return days[key] == 1;
  }

  List<Widget> _buildScheduleSection() {
    final theme = Theme.of(context);
    final hasAnyScheduleEntries = _schedules!.any(
      (schedule) => schedule.entries.isNotEmpty,
    );
    final schedules = _schedules!
        .where(
          (schedule) =>
              _selectedScheduleRouteId == null ||
              schedule.route.routeId == _selectedScheduleRouteId,
        )
        .map(
          (schedule) => _RouteSchedule(
            route: schedule.route,
            entries: schedule.entries
                .where(_isEntryActiveOnSelectedDate)
                .toList(growable: false),
          ),
        )
        .where((schedule) => schedule.entries.isNotEmpty)
        .toList(growable: false);

    if (schedules.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            hasAnyScheduleEntries
                ? AppLocalizations.of(context).scheduleNoServiceDay
                : AppLocalizations.of(context).scheduleUnavailable,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (final schedule in schedules) {
      if (_schedules!.length > 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              schedule.route.transitName.displayForLocale(
                Localizations.localeOf(context).toLanguageTag(),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      final byDirection = <int, List<RouteScheduleEntry>>{};
      for (final entry in schedule.entries) {
        (byDirection[entry.direction] ??= []).add(entry);
      }
      final directions = byDirection.keys.toList()..sort();
      for (final direction in directions) {
        widgets.add(
          _buildDirectionRow(
            routeId: schedule.route.routeId,
            direction: direction,
            entries: byDirection[direction]!,
            theme: theme,
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildDirectionRow({
    required String routeId,
    required int direction,
    required List<RouteScheduleEntry> entries,
    required ThemeData theme,
  }) {
    final frequencyEntries = entries.where((e) => e.isFrequency).toList();
    final departureTimes = <String, bool>{};
    for (final entry in entries) {
      if (entry.isFrequency) continue;
      final stops = entry.payload['stop_times'] as List<dynamic>? ?? [];
      if (stops.isNotEmpty) {
        final first = stops.first as Map<String, dynamic>;
        final departure = (first['departure'] as String? ?? '').trim();
        if (departure.isNotEmpty) {
          final time = _normalizeTime(departure);
          departureTimes[time] = _cancelledDepartures.contains(
            '$routeId:${direction + 1}:$time',
          );
        }
      }
    }

    final sortedTimes = departureTimes.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _directionLabel(direction),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (frequencyEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in frequencyEntries)
                    Text(entry.displayText, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          if (sortedTimes.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final time in sortedTimes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: departureTimes[time] == true
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      time,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: departureTimes[time] == true
                            ? theme.colorScheme.error
                            : null,
                        fontWeight: departureTimes[time] == true
                            ? FontWeight.w700
                            : null,
                      ),
                    ),
                  ),
              ],
            )
          else if (frequencyEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                AppLocalizations.of(context).scheduleNoDepartureTimes,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _directionLabel(int direction) {
    return localizedDirectionOrdinal(AppLocalizations.of(context), direction);
  }

  /// Normalizes a departure time string to HH:MM (drops seconds if present).
  String _normalizeTime(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw;
  }
}

class _RouteSchedule {
  const _RouteSchedule({required this.route, required this.entries});

  final RouteSummary route;
  final List<RouteScheduleEntry> entries;
}

/// Bottom sheet showing the timetabled arrival/departure times at a single
/// stop, grouped by direction and filtered by a selectable date.
class _StopScheduleSheet extends StatefulWidget {
  const _StopScheduleSheet({
    required this.routeId,
    required this.routeName,
    required this.routeDisplayName,
    required this.provider,
    required this.stop,
    required this.repository,
  });

  final String routeId;
  final String routeName;
  final String routeDisplayName;
  final BusProvider provider;
  final StopInfo stop;
  final BusRepository repository;

  @override
  State<_StopScheduleSheet> createState() => _StopScheduleSheetState();
}

class _StopScheduleSheetState extends State<_StopScheduleSheet> {
  List<RouteScheduleEntry>? _schedule;
  Set<String> _cancelledDepartures = const <String>{};
  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  final Map<String, bool> _holidayMap = <String, bool>{};
  final Set<int> _loadedHolidayYears = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
    _ensureHolidaysLoaded(_selectedDate.year);
  }

  Future<void> _load() async {
    try {
      final schedule = await widget.repository.fetchStopEstimatedTimes(
        widget.routeId,
      );
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _loading = false;
      });
      unawaited(_loadCancelledDepartures());
    } catch (e) {
      debugPrint('StopScheduleSheet load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = localizedFriendlyError(AppLocalizations.of(context), e);
      });
    }
  }

  Future<void> _loadCancelledDepartures() async {
    if (widget.provider != BusProvider.txg) {
      return;
    }
    try {
      final departures = await widget.repository
          .fetchTaichungCancelledDepartures(
            routeId: widget.routeId,
            routeName: widget.routeName,
            date: _selectedDate,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _cancelledDepartures = departures
            .map(
              (departure) =>
                  '${departure.direction}:${departure.departureTime}',
            )
            .toSet();
      });
    } catch (_) {
      // Cancellation data is supplementary to the timetable.
    }
  }

  Future<void> _ensureHolidaysLoaded(int year) async {
    if (_loadedHolidayYears.contains(year)) return;
    _loadedHolidayYears.add(year);
    try {
      final map = await widget.repository.fetchHolidaysForYear(year);
      if (!mounted || map.isEmpty) return;
      setState(() => _holidayMap.addAll(map));
    } catch (_) {
      // Falls back to the weekend rule.
    }
  }

  bool _isHoliday(DateTime date) {
    final key = _dateKey(date);
    final explicit = _holidayMap[key];
    if (explicit != null) return explicit;
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  String _dateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  String _formatSelectedDateLabel() {
    final d = _selectedDate;
    return localizedScheduleDate(
      AppLocalizations.of(context),
      d,
      isHoliday: _isHoliday(d),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: AppLocalizations.of(context).scheduleChooseDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
    unawaited(_ensureHolidaysLoaded(picked.year));
    unawaited(_loadCancelledDepartures());
  }

  bool _isEntryActiveOnSelectedDate(RouteScheduleEntry entry) {
    final days = entry.serviceDays;
    final date = _selectedDate;
    if (_isHoliday(date) && days['holiday'] == 1) return true;
    const weekdayKeys = <String>[
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun',
    ];
    return days[weekdayKeys[date.weekday - 1]] == 1;
  }

  /// Extracts the stop time (arrival, fallback departure) for [widget.stop]
  /// from a timetable entry. Matches by stop id first, then stop sequence.
  String? _stopTimeForEntry(RouteScheduleEntry entry) {
    final stops = entry.payload['stop_times'] as List<dynamic>? ?? const [];
    final targetId = widget.stop.stopId.toString();
    final targetSeq = widget.stop.sequence;
    Map<String, dynamic>? matched;
    for (final raw in stops) {
      if (raw is! Map<String, dynamic>) continue;
      final sid = (raw['stopid'] ?? '').toString();
      if (sid.isNotEmpty && sid == targetId) {
        matched = raw;
        break;
      }
    }
    matched ??= () {
      for (final raw in stops) {
        if (raw is Map<String, dynamic> && raw['seq'] == targetSeq) {
          return raw;
        }
      }
      return null;
    }();
    if (matched == null) return null;
    final arrival = (matched['arrival'] as String? ?? '').trim();
    final departure = (matched['departure'] as String? ?? '').trim();
    final time = arrival.isNotEmpty ? arrival : departure;
    return time.isEmpty ? null : _normalizeTime(time);
  }

  /// Whether [entry] has estimated (extrapolated) stop times rather than
  /// authoritative timetable data.
  bool _isEntryEstimated(RouteScheduleEntry entry) {
    return entry.isFrequency &&
        (entry.payload['has_estimated_stops'] as bool? ?? false);
  }

  bool _isCancelledDeparture(RouteScheduleEntry entry) {
    if (entry.isFrequency) {
      return false;
    }
    final stops = entry.payload['stop_times'] as List<dynamic>? ?? const [];
    if (stops.isEmpty || stops.first is! Map<String, dynamic>) {
      return false;
    }
    final first = stops.first as Map<String, dynamic>;
    final departure = (first['departure'] as String? ?? '').trim();
    if (departure.isEmpty) {
      return false;
    }
    return _cancelledDepartures.contains(
      '${entry.direction + 1}:${_normalizeTime(departure)}',
    );
  }

  String _normalizeTime(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TransitStationName(
                name: widget.stop.transitName,
                primaryStyle: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.stopScheduleSubtitle(widget.routeDisplayName),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.stopScheduleDisclaimer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_formatSelectedDateLabel()),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(child: _buildBody(theme, scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme, ScrollController scrollController) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null) {
      return Center(
        child: Text(
          l10n.routeInfoLoadFailed(_error!),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }
    final schedule = _schedule ?? const [];
    final timetableEntries = schedule
        .where((e) => !e.isFrequency)
        .where(_isEntryActiveOnSelectedDate)
        .where((entry) => !_isCancelledDeparture(entry))
        .toList();
    final frequencyEntries = schedule
        .where((e) => e.isFrequency)
        .where(_isEntryActiveOnSelectedDate)
        .toList();

    if (timetableEntries.isEmpty && frequencyEntries.isEmpty) {
      return Center(
        child: Text(
          schedule.isEmpty
              ? l10n.stopScheduleNoTimetable
              : l10n.scheduleNoServiceDay,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // The stop was opened from a specific path/direction, so we only show the
    // times for the direction(s) this stop actually belongs to. A timetable
    // entry is relevant only if THIS stop appears in its stop_times — entries
    // for the opposite direction (where this stop doesn't exist) are skipped.
    final stopTimes = <String, bool>{}; // time -> isEstimated
    final relevantDirections = <int>{};
    for (final entry in timetableEntries) {
      final time = _stopTimeForEntry(entry);
      if (time != null) {
        stopTimes[time] = false;
        relevantDirections.add(entry.direction);
      }
    }

    // Frequency entries may now carry estimated per-stop times (from the
    // stop-estimated-times API endpoint).  Extract stop times from those
    // that have them.
    final estimatedFrequencyEntries = <RouteScheduleEntry>[];
    final plainFrequencyEntries = <RouteScheduleEntry>[];
    for (final entry in frequencyEntries) {
      if (relevantDirections.isNotEmpty &&
          !relevantDirections.contains(entry.direction)) {
        continue;
      }
      if (_isEntryEstimated(entry)) {
        estimatedFrequencyEntries.add(entry);
      } else {
        plainFrequencyEntries.add(entry);
      }
    }

    // Collect estimated times from frequency entries with extrapolated stops.
    for (final entry in estimatedFrequencyEntries) {
      final time = _stopTimeForEntry(entry);
      if (time != null) {
        stopTimes[time] = true;
        relevantDirections.add(entry.direction);
      }
    }

    if (stopTimes.isEmpty && plainFrequencyEntries.isEmpty) {
      return Center(
        child: Text(
          l10n.stopScheduleNoStopTimes,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final sortedTimes = stopTimes.keys.toList()..sort();

    return ListView(
      controller: scrollController,
      children: [
        if (plainFrequencyEntries.isNotEmpty) ...[
          Text(
            l10n.stopScheduleFrequency,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in plainFrequencyEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(entry.displayText, style: theme.textTheme.bodyMedium),
            ),
          if (sortedTimes.isNotEmpty) const SizedBox(height: 12),
        ],
        if (sortedTimes.isNotEmpty) ...[
          Row(
            children: [
              Text(
                l10n.stopScheduleEstimatedArrival,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (stopTimes.values.any((e) => e)) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.stopScheduleIncludesEstimates,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final time in sortedTimes)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: stopTimes[time] == true
                        ? theme.colorScheme.tertiaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(time, style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
          if (stopTimes.values.any((e) => e)) ...[
            const SizedBox(height: 8),
            Text(
              l10n.stopScheduleEstimateFootnote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _RelatedStopRouteEta {
  const _RelatedStopRouteEta({required this.result, required this.liveStop});

  final StopRouteSearchResult result;
  final StopInfo liveStop;
}

class _RelatedStopRoutesSheet extends StatefulWidget {
  const _RelatedStopRoutesSheet({
    required this.stop,
    required this.loadRoutes,
    required this.fetchLiveMaps,
    required this.buildInitialItems,
    required this.applyLiveMaps,
    required this.statusText,
    required this.directionText,
  });

  final StopInfo stop;
  final Future<List<StopRouteSearchResult>> Function() loadRoutes;
  final Future<BatchLiveStopMap> Function(List<StopRouteSearchResult>)
  fetchLiveMaps;
  final List<_RelatedStopRouteEta> Function(List<StopRouteSearchResult>)
  buildInitialItems;
  final List<_RelatedStopRouteEta> Function(
    List<StopRouteSearchResult>,
    BatchLiveStopMap,
  )
  applyLiveMaps;
  final String Function(StopInfo stop, {bool isLoadingEta}) statusText;
  final String Function(StopRouteSearchResult result) directionText;

  @override
  State<_RelatedStopRoutesSheet> createState() =>
      _RelatedStopRoutesSheetState();
}

class _RelatedStopRoutesSheetState extends State<_RelatedStopRoutesSheet> {
  List<StopRouteSearchResult>? _routes;
  List<_RelatedStopRouteEta> _items = const <_RelatedStopRouteEta>[];
  Object? _error;
  bool _loadingEtas = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final routes = await widget.loadRoutes();
      if (!mounted) {
        return;
      }
      setState(() {
        _routes = routes;
        _items = widget.buildInitialItems(routes);
        _loadingEtas = routes.isNotEmpty;
      });
      if (routes.isEmpty) {
        return;
      }
      final liveMaps = await widget.fetchLiveMaps(routes);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = widget.applyLiveMaps(routes, liveMaps);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loadingEtas = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    Widget content;
    if (_routes == null && _error == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null && (_routes == null || _routes!.isEmpty)) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l10n.relatedRoutesLoadFailed,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    } else if (_items.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l10n.relatedRoutesEmpty(
              widget.stop.transitName.stationDisplayForLocale(
                Localizations.localeOf(context).toLanguageTag(),
              ),
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    } else {
      content = ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _items[index];
          final result = item.result;
          final route = result.route;
          final direction = widget.directionText(result);
          final subtitleParts = <String>[
            widget.statusText(item.liveStop, isLoadingEta: _loadingEtas),
            if (direction.isNotEmpty) direction,
          ];
          return ListTile(
            leading: EtaBadge(
              stop: item.liveStop,
              alwaysShowSeconds: AppControllerScope.read(
                context,
              ).settings.alwaysShowSeconds,
              size: 52,
            ),
            title: Text(
              route.transitName.displayForLocale(
                Localizations.localeOf(context).toLanguageTag(),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: subtitleParts.isEmpty
                ? null
                : Text(subtitleParts.join(' · ')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(result),
          );
        },
      );
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                l10n.relatedRoutesTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TransitStationName(
                name: widget.stop.transitName,
                primaryStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_loadingEtas) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

enum _StopAction {
  favoriteStation,
  favoriteBoarding,
  destination,
  schedule,
  relatedRoutes,
  transfers,
  googleMaps,
  shortcut,
}

enum _VehicleAction { twBusForum }
