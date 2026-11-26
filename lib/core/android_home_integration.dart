import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

class AndroidHomeIntegration {
  AndroidHomeIntegration._();

  static const _channel = MethodChannel(
    'tw.avianjay.taiwanbus.flutter/home_integration',
  );

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> pinFavoriteShortcut({
    required FavoriteItem favorite,
  }) async {
    if (!_isAndroid) {
      return false;
    }

    final result = await _channel.invokeMethod<bool>(
      'pinFavoriteShortcut',
      favorite.toJson(),
    );
    return result ?? false;
  }

  static Future<bool> pinStopShortcut({required FavoriteStop favorite}) =>
      pinFavoriteShortcut(favorite: favorite);

  static Future<void> refreshFavoriteWidgets() async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('refreshFavoriteWidgets');
  }

  static Future<void> updateFavoriteWidgetAutoRefreshMinutes(
    int minutes,
  ) async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('setFavoriteWidgetAutoRefreshMinutes', {
      'minutes': minutes,
    });
  }

  /// Whether this platform has a background check that reads the reminder
  /// plan. Elsewhere there is nobody to read one, so none is written.
  static bool get supportsSmartRouteNotifications => _isAndroid;

  static Future<void> syncSmartRouteNotifications(bool enabled) async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('setSmartRouteNotificationsEnabled', {
      'enabled': enabled,
    });
  }

  /// The reminders the background check has shown, as the JSON it logs
  /// them in, or null where there is no such check or it cannot be asked.
  static Future<String?> loadSmartRouteReminderLog() async {
    if (!_isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('getSmartRouteReminderLog');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Has the background check forget which reminders it has shown. That
  /// record is part of what the app has learned about the rider, so it goes
  /// when the rest of it does.
  static Future<void> forgetSmartRouteReminders() async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('forgetSmartRouteReminders');
  }

  static Future<void> setApplicationInForeground(bool value) async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('setApplicationInForeground', {
      'appInForeground': value,
    });
  }
}
