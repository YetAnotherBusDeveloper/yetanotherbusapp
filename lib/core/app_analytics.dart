import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_bootstrap.dart';
import 'models.dart';

class AppAnalytics {
  /// Creates the analytics facade without starting any platform work.
  AppAnalytics.deferred({Future<FirebaseAnalytics?> Function()? initializer})
    : _initializer = initializer ?? _initializeFirebaseAnalytics;

  final Future<FirebaseAnalytics?> Function() _initializer;
  FirebaseAnalytics? _analytics;
  final _DeferredAnalyticsObserver _observer = _DeferredAnalyticsObserver();
  Future<void>? _initializationFuture;

  FirebaseAnalytics? get analytics => _analytics;
  NavigatorObserver get observer => _observer;

  /// Call after the first frame. Concurrent callers share the same startup.
  Future<void> start() => _initializationFuture ??= _start();

  Future<void> _start() async {
    try {
      final analytics = await _initializer();
      if (analytics == null) return;
      _analytics = analytics;
      _observer.enable(analytics);
    } catch (_) {
      // Analytics must never prevent the app from starting or being used.
    }
  }

  bool get isEnabled => analytics != null;

  Future<void> logSearchExecuted({
    required int queryLength,
    required int resultsCount,
    required int providerCount,
    required int localProviderCount,
    required int remoteProviderCount,
  }) {
    return _logEvent('search_executed', {
      'query_length': queryLength,
      'results_count': resultsCount,
      'provider_count': providerCount,
      'local_provider_count': localProviderCount,
      'remote_provider_count': remoteProviderCount,
    });
  }

  Future<void> logSearchFailed({
    required int queryLength,
    required int providerCount,
  }) {
    return _logEvent('search_failed', {
      'query_length': queryLength,
      'provider_count': providerCount,
    });
  }

  Future<void> logRouteSelected({
    required BusProvider provider,
    required int routeKey,
    required String source,
  }) {
    return _logEvent('route_selected', {
      'provider': provider.name,
      'source': source,
    });
  }

  Future<void> logRouteVisit({
    required BusProvider provider,
    required int routeKey,
  }) {
    return _logEvent('route_visit_recorded', {
      'provider': provider.name,
    });
  }

  Future<void> logProviderChanged({
    required BusProvider provider,
    required int selectedCount,
  }) {
    return _logEvent('provider_changed', {
      'provider': provider.name,
      'selected_count': selectedCount,
    });
  }

  Future<void> logSelectedProvidersChanged({
    required BusProvider currentProvider,
    required int selectedCount,
  }) {
    return _logEvent('selected_providers_changed', {
      'provider': currentProvider.name,
      'selected_count': selectedCount,
    });
  }

  Future<void> logThemeModeChanged(ThemeMode themeMode) {
    return _logEvent('theme_mode_changed', {
      'theme_mode': themeMode.name,
    });
  }

  Future<void> logAmoledPreferenceChanged(bool enabled) {
    return _logEvent('amoled_theme_changed', {
      'enabled': enabled,
    });
  }

  Future<void> logSeedColorChanged({required bool usesCustomColor}) {
    return _logEvent('seed_color_changed', {
      'uses_custom_color': usesCustomColor,
    });
  }

  Future<void> logPageBackgroundChanged({
    required String pageKey,
    required bool hasImage,
  }) {
    return _logEvent('page_background_changed', {
      'page_key': pageKey,
      'has_image': hasImage,
    });
  }

  Future<void> logBackgroundImagesApplied({required int pageCount}) {
    return _logEvent('background_images_applied', {
      'page_count': pageCount,
    });
  }

  Future<void> logBackgroundImagesCleared() {
    return _logEvent('background_images_cleared');
  }

  Future<void> logFavoriteGroupCreated({required int groupCount}) {
    return _logEvent('favorite_group_created', {
      'group_count': groupCount,
    });
  }

  Future<void> logFavoriteGroupDeleted({required int groupCount}) {
    return _logEvent('favorite_group_deleted', {
      'group_count': groupCount,
    });
  }

  Future<void> logFavoriteStopSaved({
    required BusProvider provider,
    required int routeKey,
    required bool replacedExisting,
    required bool hasDestination,
  }) {
    return _logEvent('favorite_stop_saved', {
      'provider': provider.name,
      'replaced_existing': replacedExisting,
      'has_destination': hasDestination,
    });
  }

  Future<void> logFavoriteStopRemoved({
    required BusProvider provider,
    required int routeKey,
    required bool hadDestination,
  }) {
    return _logEvent('favorite_stop_removed', {
      'provider': provider.name,
      'had_destination': hadDestination,
    });
  }

  Future<void> logBusMapOpened({
    required BusProvider provider,
    required String source,
  }) {
    return _logEvent('bus_map_opened', {
      'provider': provider.name,
      'source': source,
    });
  }

  Future<void> logBusMapCityChanged({required BusProvider provider}) {
    return _logEvent('bus_map_city_changed', {'provider': provider.name});
  }

  Future<void> logBusMapFilterToggled({required bool favoritesOnly}) {
    return _logEvent('bus_map_filter_toggled', {
      'favorites_only': favoritesOnly,
    });
  }

  Future<void> logDatabasesDownloaded({
    required int providerCount,
    required bool includesCurrentProvider,
  }) {
    return _logEvent('databases_downloaded', {
      'provider_count': providerCount,
      'includes_current_provider': includesCurrentProvider,
    });
  }

  Future<void> logAppUpdateChecked({
    required String channel,
    required String status,
  }) {
    return _logEvent('app_update_checked', {
      'channel': channel,
      'status': status,
    });
  }

  Future<void> _logEvent(
    String name, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) async {
    // Keep initialization off the interaction path, even when callers await
    // their analytics event (for example while changing settings).
    if (analytics == null) {
      final initialization = _initializationFuture;
      if (initialization != null) {
        unawaited(initialization.then((_) => _sendEvent(name, parameters)));
      }
      return;
    }
    await _sendEvent(name, parameters);
  }

  Future<void> _sendEvent(String name, Map<String, Object?> parameters) async {
    final analytics = this.analytics;
    if (analytics == null) {
      return;
    }

    try {
      await analytics.logEvent(
        name: name,
        parameters: _normalizeParameters(parameters),
      );
    } catch (_) {
      unawaited(Future<void>.value());
    }
  }

  Map<String, Object> _normalizeParameters(Map<String, Object?> parameters) {
    final normalized = <String, Object>{};
    for (final entry in parameters.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is bool) {
        normalized[entry.key] = value ? 1 : 0;
      } else if (value is num || value is String) {
        normalized[entry.key] = value;
      } else {
        normalized[entry.key] = value.toString();
      }
    }
    return normalized;
  }

  static Future<AppAnalytics> initialize() async {
    final analytics = AppAnalytics.deferred();
    await analytics.start();
    return analytics;
  }

  static Future<FirebaseAnalytics?> _initializeFirebaseAnalytics() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }

    try {
      final bootstrap = await FirebaseBootstrap.initialize();
      if (!bootstrap.firebaseReady) return null;
      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(true);
      await analytics.logAppOpen();
      return analytics;
    } catch (_) {
      return null;
    }
  }
}

/// Stays attached to the navigator while Firebase starts in the background.
/// Retains the current page so its first screen view is not lost.
class _DeferredAnalyticsObserver extends NavigatorObserver {
  FirebaseAnalyticsObserver? _delegate;
  Route<dynamic>? _currentPage;

  void enable(FirebaseAnalytics analytics) {
    _delegate = FirebaseAnalyticsObserver(analytics: analytics);
    final page = _currentPage;
    if (page != null) _delegate!.didPush(page, null);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _currentPage = route;
    _delegate?.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route == _currentPage) {
      _currentPage = previousRoute is PageRoute ? previousRoute : null;
    }
    _delegate?.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute) {
      _currentPage = newRoute;
    } else if (oldRoute == _currentPage) {
      _currentPage = null;
    }
    _delegate?.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route == _currentPage) {
      _currentPage = previousRoute is PageRoute ? previousRoute : null;
    }
    _delegate?.didRemove(route, previousRoute);
  }
}
