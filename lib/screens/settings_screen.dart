import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/ad_density_setting.dart';
import '../widgets/ad_banner_widget.dart';
import '../core/ad_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/bus_app.dart';
import '../core/android_trip_monitor.dart';
import '../core/app_build_info.dart';
import '../core/app_routes.dart';
import '../core/app_controller.dart';
import '../core/models.dart';
import '../core/wear_os_integration.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import '../widgets/app_update_dialog.dart';
import 'account_screen.dart';
import 'database_settings_screen.dart';
import 'personalization_screen.dart';
import '../widgets/background_image_wrapper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _favoriteWidgetRefreshOptions = <int>[0, 15, 30, 60, 120, 180];
  static final _discordCommunityUri = Uri.parse('https://dc.avianjay.sbs/');
  static final _instagramUri = Uri.parse('https://www.instagram.com/yabus.tw/');
  static final _contributorGithubUris = <String, Uri>{
    'AvianJay': Uri.parse('https://github.com/AvianJay'),
    'itouSouta': Uri.parse('https://github.com/itousouta15'),
    'Axoled': Uri.parse('https://github.com/Axoled-Student'),
    'Steven0925': Uri.parse('https://github.com/Steven0925'),
  };

  late Future<WearOsSyncStatus> _wearSyncStatusFuture;
  int _adToggleCount = 0;
  bool _adToggleLocked = false;
  bool _adToggleConfirmed = false;

  @override
  void initState() {
    super.initState();
    _wearSyncStatusFuture = WearOsIntegration.getStatus();
    _loadAdToggleLockState();
  }

  Future<void> _loadAdToggleLockState() async {
    final locked = await AdService.instance.isAdToggleLocked();
    if (mounted) {
      setState(() => _adToggleLocked = locked);
    }
  }

  String _favoriteWidgetRefreshLabel(AppLocalizations l10n, int minutes) {
    if (minutes <= 0) {
      return l10n.updateCheckOff;
    }
    return l10n.minutesValue(minutes);
  }

  Future<void> _checkAppUpdate(
    BuildContext context,
    AppController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await controller.checkForAppUpdate();
    if (!context.mounted) {
      return;
    }

    if (result.hasUpdate) {
      await showAppUpdateDialog(
        context,
        controller: controller,
        result: result,
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          localizedAppUpdateResult(AppLocalizations.of(context), result),
        ),
      ),
    );
  }

  Future<void> _toggleSmartRouteNotifications(
    BuildContext context,
    AppController controller,
    bool value,
  ) async {
    if (!value) {
      await controller.updateEnableSmartRouteNotifications(false);
      return;
    }

    final granted = await AndroidTripMonitor.requestNotificationPermission();
    if (!context.mounted) {
      return;
    }
    if (!granted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.smartNotificationPermissionRequired)),
      );
      return;
    }
    await controller.updateEnableSmartRouteNotifications(true);
  }

  Future<void> _handleAdToggle(
    BuildContext context,
    AppController controller,
    bool value,
  ) async {
    final l10n = AppLocalizations.of(context);
    _adToggleCount++;

    // Lock after 5 toggles.
    if (_adToggleCount > 5) {
      await AdService.instance.lockAdToggle();
      await controller.updateEnableAds(true);
      if (!context.mounted) return;
      setState(() => _adToggleLocked = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adsLockedMessage.trim())));
      return;
    }

    // Turning ads on → no confirmation needed.
    if (value) {
      await controller.updateEnableAds(true);
      return;
    }

    // Turning ads off → ask for confirmation.
    final confirmed = _adToggleConfirmed
        ? true
        : await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(l10n.adsDisableTitle),
                  content: Text(l10n.adsDisableDescription),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(l10n.adsKeepEnabled),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(l10n.adsDisableConfirm),
                    ),
                  ],
                ),
              ) ??
              false;
    if (confirmed == true) {
      _adToggleConfirmed = true;
      await controller.updateEnableAds(false);
    }
  }

  Future<void> _openDiscordCommunity(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final opened = await launchUrl(
      _discordCommunityUri,
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted || opened) {
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(l10n.discordOpenFailed)));
  }

  Future<void> _openContributorGithub(
    BuildContext context,
    String name,
    Uri uri,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || opened) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.githubOpenFailed(name))),
    );
  }

  Future<void> _openInstagram(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final opened = await launchUrl(
      _instagramUri,
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted || opened) {
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(l10n.instagramOpenFailed)));
  }

  Widget _buildAboutChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
  }) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributorChip(
    BuildContext context,
    ThemeData theme,
    String name,
    Uri uri,
  ) {
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openContributorGithub(context, name, uri),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            name,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final buildInfo = controller.buildInfo;
    final theme = Theme.of(context);
    final hasSettingsBackgroundImage = hasBackgroundImageForPage(
      controller.settings,
      pageKey: 'settings',
    );
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final supportsRouteBackgroundMonitor = isAndroid || isIOS;
    final authSession = controller.authSession;
    // final databaseProviders = controller.selectedProviders
    //     .map((provider) => provider.label)
    //     .join('、');

    return BackgroundImageWrapper(
      pageKey: 'settings',
      child: Scaffold(
        backgroundColor: hasSettingsBackgroundImage ? Colors.transparent : null,
        appBar: AppBar(title: Text(l10n.settingsTitle)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appearanceSectionTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AppLanguage>(
                          isExpanded: true,
                          initialValue: controller.settings.language,
                          decoration: InputDecoration(
                            labelText: l10n.languageLabel,
                          ),
                          items: AppLanguage.values
                              .map(
                                (language) => DropdownMenuItem(
                                  value: language,
                                  child: Text(switch (language) {
                                    AppLanguage.system => l10n.languageSystem,
                                    AppLanguage.traditionalChinese =>
                                      l10n.languageTraditionalChinese,
                                    AppLanguage.english => l10n.languageEnglish,
                                  }),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              controller.updateLanguage(value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${l10n.interfaceScaleLabel}: '
                          '${l10n.interfaceScaleValue((controller.settings.interfaceScale * 100).round())}',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.interfaceScaleDescription,
                          style: theme.textTheme.bodySmall,
                        ),
                        Slider(
                          min: AppSettings.minInterfaceScale,
                          max: AppSettings.maxInterfaceScale,
                          divisions: 5,
                          value: controller.settings.interfaceScale,
                          label: l10n.interfaceScaleValue(
                            (controller.settings.interfaceScale * 100).round(),
                          ),
                          semanticFormatterCallback: (value) =>
                              l10n.interfaceScaleValue((value * 100).round()),
                          onChanged: controller.updateInterfaceScale,
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<ThemeMode>(
                          isExpanded: true,
                          initialValue: controller.settings.themeMode,
                          decoration: InputDecoration(
                            labelText: l10n.themeModeLabel,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: ThemeMode.system,
                              child: Text(l10n.themeModeSystem),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text(l10n.themeModeLight),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: Text(l10n.themeModeDark),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              controller.updateThemeMode(value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.compactModeTitle),
                          subtitle: Text(l10n.compactModeDescription),
                          value: controller.settings.enableCompactMode,
                          onChanged: controller.updateEnableCompactMode,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.showWeatherTitle),
                          subtitle: Text(l10n.showWeatherDescription),
                          value: controller.settings.showWeatherInAppBar,
                          onChanged: controller.updateShowWeatherInAppBar,
                        ),
                        if (isAndroid || isIOS) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<MobileMapProvider>(
                            isExpanded: true,
                            initialValue: controller.settings.mobileMapProvider,
                            decoration: InputDecoration(
                              labelText: l10n.mapProviderLabel,
                            ),
                            items: MobileMapProvider.values
                                .map(
                                  (provider) =>
                                      DropdownMenuItem<MobileMapProvider>(
                                        value: provider,
                                        child: Text(provider.label),
                                      ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                controller.updateMobileMapProvider(value);
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.palette_outlined),
                          title: Text(l10n.personalizationTitle),
                          subtitle: Text(l10n.personalizationDescription),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: '/personalization',
                                ),
                                builder: (_) => const PersonalizationScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text(l10n.accountTitle),
                      subtitle: Text(
                        authSession == null
                            ? l10n.accountSignedOut
                            : l10n.accountSignedInAs(
                                authSession.displayName.isEmpty
                                    ? authSession.provider
                                    : authSession.displayName,
                              ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            settings: const RouteSettings(
                              name: AppRoutes.account,
                            ),
                            builder: (_) => const AccountScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (isAndroid) ...[
                  const SizedBox(height: 12),
                  FutureBuilder<WearOsSyncStatus>(
                    future: _wearSyncStatusFuture,
                    builder: (context, snapshot) {
                      final status = snapshot.data;
                      if (snapshot.connectionState == ConnectionState.waiting ||
                          (status == null || !status.hasConnectedNodes)) {
                        return const SizedBox.shrink();
                      }

                      final groupNames = controller.favoriteGroupNames;
                      final hasFavorites = groupNames.isNotEmpty;
                      final selectedIds = controller
                          .settings
                          .wearSelectedFavoriteIds
                          .toSet();

                      // Get all available favorite IDs across all groups
                      final availableIds = <String>[];
                      for (final favorites
                          in controller.favoriteGroups.values) {
                        for (final fav in favorites) {
                          availableIds.add(fav.stableKey);
                        }
                      }
                      final availableSet = availableIds.toSet();

                      String? selectedValue;
                      if (selectedIds.isEmpty) {
                        selectedValue = null;
                      } else if (setEquals(selectedIds, availableSet)) {
                        selectedValue = '__all__';
                      } else {
                        // Check if it matches any specific group
                        for (final groupName in groupNames) {
                          final groupStableKeys =
                              controller.favoriteGroups[groupName]
                                  ?.map((e) => e.stableKey)
                                  .toSet() ??
                              const <String>{};
                          if (groupStableKeys.isNotEmpty &&
                              setEquals(selectedIds, groupStableKeys)) {
                            selectedValue = groupName;
                            break;
                          }
                        }
                      }

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wear OS',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                status.connectedNodeCount > 1
                                    ? l10n.wearConnectedWatches(
                                        localizedList(
                                          l10n,
                                          status.connectedNodeNames,
                                        ),
                                        status.connectedNodeCount,
                                      )
                                    : l10n.wearConnectedWatch(
                                        localizedList(
                                          l10n,
                                          status.connectedNodeNames,
                                        ),
                                      ),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.wearSyncTitle),
                                subtitle: Text(l10n.wearSyncDescription),
                                value: controller.settings.wearSyncEnabled,
                                onChanged: controller.updateWearSyncEnabled,
                              ),
                              if (controller.settings.wearSyncEnabled) ...[
                                if (!hasFavorites)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      l10n.wearNoFavorites,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  )
                                else ...[
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: selectedValue,
                                    decoration: InputDecoration(
                                      labelText: l10n.wearSyncCategory,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: '__all__',
                                        child: Text(l10n.wearAllCategories),
                                      ),
                                      ...groupNames.map(
                                        (groupName) => DropdownMenuItem(
                                          value: groupName,
                                          child: Text(groupName),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == '__all__') {
                                        controller
                                            .updateWearSelectedFavoriteIds(
                                              availableIds,
                                            );
                                      } else if (value != null) {
                                        final keys =
                                            controller.favoriteGroups[value]
                                                ?.map((e) => e.stableKey)
                                                .toList() ??
                                            const <String>[];
                                        controller
                                            .updateWearSelectedFavoriteIds(
                                              keys,
                                            );
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (!kIsWeb) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.databaseDownloadsTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.databaseCurrentRegion(
                              controller.settings.provider.label,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.databaseStartupUpdate(
                              localizedDatabaseAutoUpdateMode(
                                l10n,
                                controller.settings.databaseAutoUpdateMode,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (controller.hasPendingDatabaseUpdates) ...[
                            const SizedBox(height: 4),
                            Text(
                              l10n.databasePendingRegions(
                                controller.pendingDatabaseUpdates.length,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: const RouteSettings(
                                    name: AppRoutes.databaseSettings,
                                  ),
                                  builder: (_) =>
                                      const DatabaseSettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.storage_rounded),
                            label: Text(l10n.databaseOpenPage),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.usageAndUpdatesTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.alwaysShowSecondsTitle),
                          subtitle: Text(
                            l10n.alwaysShowSecondsDescription,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          value: controller.settings.alwaysShowSeconds,
                          onChanged: controller.updateAlwaysShowSeconds,
                        ),
                        if (isAndroid || isIOS)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.hapticFeedbackTitle),
                            subtitle: Text(l10n.hapticFeedbackDescription),
                            value: controller.settings.enableHapticFeedback,
                            onChanged: controller.updateEnableHapticFeedback,
                          ),
                        if (!kIsWeb &&
                            defaultTargetPlatform == TargetPlatform.android)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.showAdsTitle),
                            subtitle: _adToggleLocked
                                ? Text.rich(
                                    TextSpan(
                                      children: [
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: Image.asset(
                                            "assets/cat_laugh.png",
                                            width: 20,
                                            height: 20,
                                          ),
                                        ),
                                        TextSpan(text: l10n.adsLockedMessage),
                                      ],
                                    ),
                                  )
                                : controller.settings.enableAds
                                ? Text(l10n.adsEnabledDescription)
                                : Text.rich(
                                    TextSpan(
                                      children: [
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: Image.asset(
                                            [
                                              "assets/cat_cry.png",
                                              "assets/cat_sad.png",
                                            ][Random().nextInt(2)],
                                            width: 20,
                                            height: 20,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              ' ${[l10n.adsPleaOne, l10n.adsPleaTwo, l10n.adsPleaThree, l10n.adsPleaFour][Random().nextInt(4)]}',
                                        ),
                                      ],
                                    ),
                                  ),
                            value: _adToggleLocked
                                ? true
                                : controller.settings.enableAds,
                            onChanged: _adToggleLocked
                                ? null
                                : (value) => _handleAdToggle(
                                    context,
                                    controller,
                                    value,
                                  ),
                          ),
                        if (!kIsWeb &&
                            defaultTargetPlatform == TargetPlatform.android)
                          const AdDensitySetting(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.smartRecommendationsTitle),
                          subtitle: Text(l10n.smartRecommendationsDescription),
                          value: controller.settings.enableSmartRecommendations,
                          onChanged:
                              controller.updateEnableSmartRecommendations,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.autoFavoriteTitle),
                          subtitle: Text(l10n.autoFavoriteDescription),
                          value: controller
                              .settings
                              .enableAutoFavoriteFrequentStops,
                          onChanged:
                              controller.updateEnableAutoFavoriteFrequentStops,
                        ),
                        if (isAndroid)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.smartNotificationTitle),
                            subtitle: Text(l10n.smartNotificationDescription),
                            value: controller
                                .settings
                                .enableSmartRouteNotifications,
                            onChanged: (value) =>
                                _toggleSmartRouteNotifications(
                                  context,
                                  controller,
                                  value,
                                ),
                          ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.keepScreenAwakeTitle),
                          subtitle: Text(l10n.keepScreenAwakeDescription),
                          value:
                              controller.settings.keepScreenAwakeOnRouteDetail,
                          onChanged:
                              controller.updateKeepScreenAwakeOnRouteDetail,
                        ),
                        if (supportsRouteBackgroundMonitor)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.backgroundTripTitle),
                            subtitle: Text(
                              isIOS
                                  ? l10n.backgroundTripIosDescription
                                  : l10n.backgroundTripDescription,
                            ),
                            value: controller
                                .settings
                                .enableRouteBackgroundMonitor,
                            onChanged: (value) {
                              controller.updateEnableRouteBackgroundMonitor(
                                value,
                              );
                            },
                          ),
                        if (isAndroid) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: controller
                                .settings
                                .favoriteWidgetAutoRefreshMinutes,
                            decoration: InputDecoration(
                              labelText: l10n.favoriteWidgetRefreshLabel,
                              helperText: l10n.favoriteWidgetRefreshHelper,
                            ),
                            items: _favoriteWidgetRefreshOptions
                                .map(
                                  (minutes) => DropdownMenuItem(
                                    value: minutes,
                                    child: Text(
                                      _favoriteWidgetRefreshLabel(
                                        l10n,
                                        minutes,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                controller
                                    .updateFavoriteWidgetAutoRefreshMinutes(
                                      value,
                                    );
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          l10n.normalUpdateInterval(
                            controller.settings.busUpdateTime,
                          ),
                        ),
                        Slider(
                          min: 5,
                          max: 60,
                          divisions: 11,
                          value: controller.settings.busUpdateTime.toDouble(),
                          label: l10n.secondsValue(
                            controller.settings.busUpdateTime,
                          ),
                          onChanged: (value) {
                            controller.updateBusUpdateTime(value.round());
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.retryInterval(
                            controller.settings.busErrorUpdateTime,
                          ),
                        ),
                        Slider(
                          min: 1,
                          max: 15,
                          divisions: 14,
                          value: controller.settings.busErrorUpdateTime
                              .toDouble(),
                          label: l10n.secondsValue(
                            controller.settings.busErrorUpdateTime,
                          ),
                          onChanged: (value) {
                            controller.updateBusErrorUpdateTime(value.round());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (!kIsWeb && !AppBuildInfo.isAabBuild) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.appUpdatesTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<AppUpdateChannel>(
                            isExpanded: true,
                            initialValue: controller.settings.appUpdateChannel,
                            decoration: InputDecoration(
                              labelText: l10n.updateChannelLabel,
                            ),
                            items: AppUpdateChannel.values
                                .map(
                                  (channel) => DropdownMenuItem(
                                    value: channel,
                                    child: Text(
                                      localizedAppUpdateChannel(l10n, channel),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                controller.updateAppUpdateChannel(value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<AppUpdateCheckMode>(
                            isExpanded: true,
                            initialValue:
                                controller.settings.appUpdateCheckMode,
                            decoration: InputDecoration(
                              labelText: l10n.updateCheckOnLaunchLabel,
                            ),
                            items: AppUpdateCheckMode.values
                                .map(
                                  (mode) => DropdownMenuItem(
                                    value: mode,
                                    child: Text(
                                      localizedAppUpdateCheckMode(l10n, mode),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                controller.updateAppUpdateCheckMode(value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            localizedAppUpdateChannelDescription(
                              l10n,
                              controller.settings.appUpdateChannel,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            localizedAppUpdateCheckModeDescription(
                              l10n,
                              controller.settings.appUpdateCheckMode,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: controller.checkingAppUpdate
                                ? null
                                : () => _checkAppUpdate(context, controller),
                            icon: controller.checkingAppUpdate
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.system_update_alt_rounded),
                            label: Text(
                              controller.checkingAppUpdate
                                  ? l10n.appUpdateChecking
                                  : l10n.appUpdateCheckNow,
                            ),
                          ),
                          if (controller.lastAppUpdateResult
                              case final result?) ...[
                            const SizedBox(height: 12),
                            Text(
                              l10n.appUpdateRecentResult(
                                localizedAppUpdateResult(l10n, result),
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.historyPrivacyTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.searchHistoryLimit(
                            controller.settings.maxHistory,
                          ),
                        ),
                        Slider(
                          min: 0,
                          max: 30,
                          divisions: 30,
                          value: controller.settings.maxHistory.toDouble(),
                          label: l10n.itemsValue(
                            controller.settings.maxHistory,
                          ),
                          onChanged: (value) {
                            controller.updateMaxHistory(value.round());
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.smartRoutesCount(
                            controller.routeUsageProfiles.length,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.routeSelectionsCount(
                            controller.recordedRouteSelections,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: controller.clearHistory,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: Text(l10n.clearSearchHistory),
                            ),
                            OutlinedButton.icon(
                              onPressed: controller.clearRouteUsageProfiles,
                              icon: const Icon(Icons.psychology_alt_outlined),
                              label: Text(l10n.clearSmartHistory),
                            ),
                            OutlinedButton.icon(
                              onPressed: controller.clearRouteSelectionHistory,
                              icon: const Icon(Icons.route_outlined),
                              label: Text(l10n.clearRouteSelectionHistory),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.gavel_outlined),
                          title: Text(l10n.termsOfService),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.termsOfService);
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: Text(l10n.privacyPolicy),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.privacyPolicy);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.onboardingSettingsTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await controller.setOnboardingCompleted(false);
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: Text(l10n.restartOnboarding),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aboutTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 85,
                              height: 85,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                'assets/branding/icon.svg',
                                width: 45,
                                height: 45,
                                semanticsLabel: 'YABus',
                                colorFilter: ColorFilter.mode(
                                  theme.colorScheme.onPrimaryContainer,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'YABus',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'YetAnotherBusApp',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildAboutChip(
                                        theme,
                                        icon: Icons.sell_outlined,
                                        label: buildInfo.displayVersion,
                                      ),
                                      _buildAboutChip(
                                        theme,
                                        icon: Icons.commit_rounded,
                                        label: buildInfo.shortGitSha,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        Text(
                          l10n.contributorsTitle,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final contributor
                                in _contributorGithubUris.entries)
                              _buildContributorChip(
                                context,
                                theme,
                                contributor.key,
                                contributor.value,
                              ),
                          ],
                        ),
                        const Divider(height: 32),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const FaIcon(
                            FontAwesomeIcons.discord,
                            size: 22,
                          ),
                          title: Text(l10n.communityTitle),
                          subtitle: Text(l10n.communityDescription),
                          trailing: const Icon(Icons.open_in_new_rounded),
                          onTap: () => _openDiscordCommunity(context),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const FaIcon(
                            FontAwesomeIcons.instagram,
                            size: 22,
                          ),
                          title: const Text('Instagram'),
                          subtitle: const Text('@yabus.tw'),
                          trailing: const Icon(Icons.open_in_new_rounded),
                          onTap: () => _openInstagram(context),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.feedback_outlined),
                          title: Text(l10n.feedbackTitle),
                          subtitle: Text(l10n.feedbackDescription),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.feedback);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const AdBannerWidget(minimumDensity: 4, isInline: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// SettingsScreen
