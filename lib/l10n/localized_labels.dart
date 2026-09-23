import '../core/account_sync_models.dart';
import '../core/app_update_service.dart';
import '../core/friendly_error.dart';
import '../core/models.dart';
import '../core/rail_time.dart';
import '../core/route_direction_label.dart';
import '../core/transit_name.dart';
import 'app_localizations.dart';

String localizedFriendlyError(AppLocalizations l10n, Object? error) {
  return friendlyErrorMessage(
    error,
    fallback: l10n.errorGeneric,
    networkFallback: l10n.errorNetwork,
    timeoutFallback: l10n.errorTimeout,
    rateLimitedFallback: l10n.errorRateLimited,
    preserveCjkMessage: l10n.localeName.startsWith('zh'),
  );
}

String localizedRailWeekday(AppLocalizations l10n, int weekday) =>
    switch (weekday) {
      1 => l10n.scheduleWeekdayMon,
      2 => l10n.scheduleWeekdayTue,
      3 => l10n.scheduleWeekdayWed,
      4 => l10n.scheduleWeekdayThu,
      5 => l10n.scheduleWeekdayFri,
      6 => l10n.scheduleWeekdaySat,
      7 => l10n.scheduleWeekdaySun,
      _ => '',
    };

String localizedRailDuration(
  AppLocalizations l10n,
  String departure,
  String arrival,
) {
  final base = DateTime(2000);
  final departureTime = parseRailClockTime(departure, base);
  final arrivalTime = parseRailClockTime(arrival, base);
  if (departureTime == null || arrivalTime == null) {
    return '';
  }
  final minutes = arrivalTime.difference(departureTime).inMinutes;
  if (minutes <= 0) {
    return '';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return hours == 0
      ? l10n.railDurationMinutes(remainingMinutes)
      : l10n.railDurationHoursMinutes(hours, remainingMinutes);
}

String localizedFavoriteItemType(
  AppLocalizations l10n,
  FavoriteItemType type,
) => switch (type) {
  FavoriteItemType.route => l10n.favoriteTypeRoute,
  FavoriteItemType.station => l10n.favoriteTypeStation,
  FavoriteItemType.boarding => l10n.favoriteTypeBoarding,
};

String localizedFavoriteGroupKind(
  AppLocalizations l10n,
  FavoriteGroupKind kind,
) => switch (kind) {
  FavoriteGroupKind.route => l10n.favoriteTypeRoute,
  FavoriteGroupKind.station => l10n.favoriteTypeStation,
  FavoriteGroupKind.boarding => l10n.favoriteTypeBoarding,
  FavoriteGroupKind.mixed => l10n.favoriteGroupKindMixed,
};

String localizedDatabaseAutoUpdateMode(
  AppLocalizations l10n,
  DatabaseAutoUpdateMode mode,
) => switch (mode) {
  DatabaseAutoUpdateMode.off => l10n.databaseAutoUpdateOff,
  DatabaseAutoUpdateMode.checkPopup => l10n.databaseAutoUpdatePopup,
  DatabaseAutoUpdateMode.checkNotify => l10n.databaseAutoUpdateNotify,
  DatabaseAutoUpdateMode.always => l10n.databaseAutoUpdateAlways,
  DatabaseAutoUpdateMode.wifiOnly => l10n.databaseAutoUpdateWifi,
  DatabaseAutoUpdateMode.cellularOnly => l10n.databaseAutoUpdateCellular,
};

String localizedDatabaseAutoUpdateModeDescription(
  AppLocalizations l10n,
  DatabaseAutoUpdateMode mode,
) => switch (mode) {
  DatabaseAutoUpdateMode.off => l10n.databaseAutoUpdateOffDescription,
  DatabaseAutoUpdateMode.checkPopup => l10n.databaseAutoUpdatePopupDescription,
  DatabaseAutoUpdateMode.checkNotify =>
    l10n.databaseAutoUpdateNotifyDescription,
  DatabaseAutoUpdateMode.always => l10n.databaseAutoUpdateAlwaysDescription,
  DatabaseAutoUpdateMode.wifiOnly => l10n.databaseAutoUpdateWifiDescription,
  DatabaseAutoUpdateMode.cellularOnly =>
    l10n.databaseAutoUpdateCellularDescription,
};

String localizedBusProvider(AppLocalizations l10n, BusProvider provider) =>
    switch (provider) {
      BusProvider.kee => l10n.regionKeelung,
      BusProvider.tpe => l10n.regionTaipei,
      BusProvider.nwt => l10n.regionNewTaipei,
      BusProvider.inter => l10n.regionIntercity,
      BusProvider.tao => l10n.regionTaoyuan,
      BusProvider.hsz => l10n.regionHsinchuCity,
      BusProvider.hsq => l10n.regionHsinchuCounty,
      BusProvider.mia => l10n.regionMiaoli,
      BusProvider.txg => l10n.regionTaichung,
      BusProvider.cha => l10n.regionChanghua,
      BusProvider.nan => l10n.regionNantou,
      BusProvider.yun => l10n.regionYunlin,
      BusProvider.cyi => l10n.regionChiayiCity,
      BusProvider.cyq => l10n.regionChiayiCounty,
      BusProvider.tnn => l10n.regionTainan,
      BusProvider.khh => l10n.regionKaohsiung,
      BusProvider.pif => l10n.regionPingtung,
      BusProvider.ila => l10n.regionYilan,
      BusProvider.hua => l10n.regionHualien,
      BusProvider.ttt => l10n.regionTaitung,
      BusProvider.pen => l10n.regionPenghu,
      BusProvider.kin => l10n.regionKinmen,
      BusProvider.lie => l10n.regionLienchiang,
    };

String localizedAccountSyncNamespace(
  AppLocalizations l10n,
  AccountSyncNamespace namespace,
) => switch (namespace) {
  AccountSyncNamespace.favorites => l10n.accountSyncNamespaceFavorites,
  AccountSyncNamespace.preferences => l10n.accountSyncNamespacePreferences,
};

String localizedAppUpdateChannel(
  AppLocalizations l10n,
  AppUpdateChannel channel,
) => switch (channel) {
  AppUpdateChannel.developer => l10n.updateChannelDeveloper,
  AppUpdateChannel.nightly => l10n.updateChannelNightly,
  AppUpdateChannel.release => l10n.updateChannelRelease,
};

String localizedAppUpdateChannelDescription(
  AppLocalizations l10n,
  AppUpdateChannel channel,
) => switch (channel) {
  AppUpdateChannel.developer => l10n.updateChannelDeveloperDescription,
  AppUpdateChannel.nightly => l10n.updateChannelNightlyDescription,
  AppUpdateChannel.release => l10n.updateChannelReleaseDescription,
};

String localizedAppUpdateCheckMode(
  AppLocalizations l10n,
  AppUpdateCheckMode mode,
) => switch (mode) {
  AppUpdateCheckMode.off => l10n.updateCheckOff,
  AppUpdateCheckMode.notify => l10n.updateCheckNotify,
  AppUpdateCheckMode.popup => l10n.updateCheckPopup,
};

String localizedAppUpdateCheckModeDescription(
  AppLocalizations l10n,
  AppUpdateCheckMode mode,
) => switch (mode) {
  AppUpdateCheckMode.off => l10n.updateCheckOffDescription,
  AppUpdateCheckMode.notify => l10n.updateCheckNotifyDescription,
  AppUpdateCheckMode.popup => l10n.updateCheckPopupDescription,
};

String localizedAppUpdateResult(
  AppLocalizations l10n,
  AppUpdateCheckResult result,
) => switch (result.status) {
  AppUpdateStatus.updateAvailable => l10n.appUpdateAvailableResult(
    result.update?.latestDisplayLabel ?? '',
  ),
  AppUpdateStatus.upToDate => l10n.appUpdateUpToDateResult,
  AppUpdateStatus.unavailable => l10n.appUpdateUnavailableResult,
};

String localizedList(AppLocalizations l10n, Iterable<String> values) {
  return values.join(l10n.localeName.startsWith('zh') ? '、' : ', ');
}

String localizedBusStatus(AppLocalizations l10n, BusStatusDescriptor status) =>
    switch (status.code) {
      0 => l10n.busStatusNormal,
      1 => l10n.busStatusAccident,
      2 => l10n.busStatusBreakdown,
      3 => l10n.busStatusTraffic,
      4 => l10n.busStatusEmergency,
      5 => l10n.busStatusRefueling,
      90 => l10n.busStatusUnclear,
      91 => l10n.busStatusDirectionUnclear,
      98 => l10n.busStatusOffRoute,
      99 => l10n.busStatusNotInService,
      100 => l10n.busStatusFull,
      101 => l10n.busStatusChartered,
      null => l10n.busStatusUnknown,
      final code => l10n.busStatusUnknownCode(code),
    };

String localizedRelativeTimestamp(AppLocalizations l10n, DateTime value) {
  final elapsed = DateTime.now().difference(value.toLocal());
  final seconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  if (seconds < 60) {
    return l10n.relativeSecondsAgo(seconds);
  }
  if (elapsed.inMinutes < 60) {
    return l10n.relativeMinutesAgo(elapsed.inMinutes);
  }
  if (elapsed.inHours < 24) {
    return l10n.relativeHoursAgo(elapsed.inHours);
  }
  return l10n.relativeDaysAgo(elapsed.inDays);
}

String localizedDistance(AppLocalizations l10n, double meters) {
  if (meters < 1000) {
    return l10n.distanceMetersValue(meters.round());
  }
  return l10n.distanceKilometersValue((meters / 1000).toStringAsFixed(1));
}

String localizedDirectionOrdinal(AppLocalizations l10n, int? pathId) =>
    switch (pathId) {
      null => '',
      0 => l10n.directionOutbound,
      1 => l10n.directionInbound,
      final id => l10n.directionNumber(id),
    };

String localizedRouteDirection(
  AppLocalizations l10n, {
  required String? pathName,
  int? pathId,
  String? routeName,
}) {
  if (!isMeaningfulPathName(pathName, routeName: routeName)) {
    return localizedDirectionOrdinal(l10n, pathId);
  }
  final destination = pathName!.trim();
  if (l10n.localeName.startsWith('zh') && destination.startsWith('往')) {
    return destination;
  }
  return l10n.directionTo(destination);
}

String localizedRouteDirectionForRoute(
  AppLocalizations l10n, {
  required RouteSummary route,
  required int? pathId,
}) {
  final zh = isMeaningfulPathName(route.description, routeName: route.routeName)
      ? routeDirectionLabel(
          pathName: route.description,
          pathId: pathId,
          routeName: route.routeName,
        )
      : null;
  final en =
      isMeaningfulPathName(route.pathNameEn, routeName: route.routeNameEn)
      ? route.pathNameEn
      : null;
  final fallback = localizedDirectionOrdinal(l10n, pathId);
  return TransitName(
    zh: zh,
    en: en,
    stableId: fallback.isEmpty ? '${route.routeId}:${pathId ?? ''}' : fallback,
  ).stationDisplayForLocale(l10n.localeName);
}

String localizedScheduleDate(
  AppLocalizations l10n,
  DateTime date, {
  required bool isHoliday,
}) {
  final weekday = switch (date.weekday) {
    DateTime.monday => l10n.scheduleWeekdayMon,
    DateTime.tuesday => l10n.scheduleWeekdayTue,
    DateTime.wednesday => l10n.scheduleWeekdayWed,
    DateTime.thursday => l10n.scheduleWeekdayThu,
    DateTime.friday => l10n.scheduleWeekdayFri,
    DateTime.saturday => l10n.scheduleWeekdaySat,
    _ => l10n.scheduleWeekdaySun,
  };
  return isHoliday
      ? l10n.scheduleHolidayDateLabel(date.month, date.day, weekday)
      : l10n.scheduleDateLabel(date.month, date.day, weekday);
}
