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
import '../widgets/app_dropdown.dart';
import '../widgets/app_update_dialog.dart';
import 'account_screen.dart';
import 'database_settings_screen.dart';
import 'personalization_screen.dart';
import '../widgets/background_image_wrapper.dart';

enum _SettingsCategory {
  appearance,
  wearOs,
  usage,
  appUpdates,
  history,
  onboarding,
  about,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _favoriteWidgetRefreshOptions = <int>[0, 15, 30, 60, 120, 180];
  // Keep the base Chinese locale available to Flutter as a fallback, while
  // offering the more specific Traditional Chinese locale in the picker.
  static final _fallbackOnlyLocales = <Locale>{const Locale('zh')};
  static final _discordCommunityUri = Uri.parse('https://dc.avianjay.sbs/');
  static final _instagramUri = Uri.parse('https://www.instagram.com/yabus.tw/');
  static final _contributorGithubUris = <String, Uri>{
    'AvianJay': Uri.parse('https://github.com/AvianJay'),
    'itouSouta': Uri.parse('https://github.com/itousouta15'),
    'Axoled': Uri.parse('https://github.com/Axoled-Student'),
    'Steven0925': Uri.parse('https://github.com/Steven0925'),
  };

  final _pageStorageBucket = PageStorageBucket();
  _SettingsCategory? _selectedCategory;
  late Future<WearOsSyncStatus> _wearSyncStatusFuture;
  int _adToggleCount = 0;
  bool _adToggleLocked = false;
  bool _adToggleConfirmed = false;

  bool get _compactMode =>
      AppControllerScope.of(context).settings.enableCompactMode;

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
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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

  void _openCategory(_SettingsCategory category) {
    setState(() => _selectedCategory = category);
  }

  void _returnToCategories() {
    setState(() => _selectedCategory = null);
  }

  String _categoryTitle(AppLocalizations l10n, _SettingsCategory category) =>
      switch (category) {
        _SettingsCategory.appearance => l10n.appearanceSectionTitle,
        _SettingsCategory.wearOs => 'Wear OS',
        _SettingsCategory.usage => l10n.usageAndUpdatesTitle,
        _SettingsCategory.appUpdates => l10n.appUpdatesTitle,
        _SettingsCategory.history => l10n.historyPrivacyTitle,
        _SettingsCategory.onboarding => l10n.onboardingSettingsTitle,
        _SettingsCategory.about => l10n.aboutTitle,
      };

  Widget _buildCategoryTile({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    String? compactDescription,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _compactMode ? 0 : 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: _buildSettingSubtitle(
          description,
          compactDescription: compactDescription,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  List<Widget> _buildCategories(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final authSession = controller.authSession;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return [
      _buildCategoryTile(
        icon: Icons.palette_outlined,
        title: l10n.appearanceSectionTitle,
        description: l10n.settingsAppearanceDescription,
        onTap: () => _openCategory(_SettingsCategory.appearance),
      ),
      _buildCategoryTile(
        icon: Icons.account_circle_outlined,
        title: l10n.accountTitle,
        description: authSession == null
            ? l10n.accountSignedOut
            : l10n.accountSignedInAs(
                authSession.displayName.isEmpty
                    ? authSession.provider
                    : authSession.displayName,
              ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: AppRoutes.account),
            builder: (_) => const AccountScreen(),
          ),
        ),
      ),
      if (isAndroid)
        FutureBuilder<WearOsSyncStatus>(
          future: _wearSyncStatusFuture,
          builder: (context, snapshot) {
            final status = snapshot.data;
            if (status == null || !status.hasConnectedNodes) {
              return const SizedBox.shrink();
            }
            return _buildCategoryTile(
              icon: Icons.watch_outlined,
              title: 'Wear OS',
              description: l10n.wearSyncDescription,
              compactDescription: l10n.wearSyncDescriptionCompact,
              onTap: () => _openCategory(_SettingsCategory.wearOs),
            );
          },
        ),
      if (!kIsWeb)
        _buildCategoryTile(
          icon: Icons.storage_rounded,
          title: l10n.databaseDownloadsTitle,
          description: [
            l10n.databaseCurrentRegion(controller.settings.provider.label),
            l10n.databaseStartupUpdate(
              localizedDatabaseAutoUpdateMode(
                l10n,
                controller.settings.databaseAutoUpdateMode,
              ),
            ),
            if (controller.hasPendingDatabaseUpdates)
              l10n.databasePendingRegions(
                controller.pendingDatabaseUpdates.length,
              ),
          ].join('\n'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: AppRoutes.databaseSettings),
              builder: (_) => const DatabaseSettingsScreen(),
            ),
          ),
        ),
      _buildCategoryTile(
        icon: Icons.tune_rounded,
        title: l10n.usageAndUpdatesTitle,
        description: l10n.settingsUsageDescription,
        onTap: () => _openCategory(_SettingsCategory.usage),
      ),
      if (!kIsWeb && !AppBuildInfo.isAabBuild)
        _buildCategoryTile(
          icon: Icons.system_update_alt_rounded,
          title: l10n.appUpdatesTitle,
          description: l10n.settingsUpdatesDescription,
          onTap: () => _openCategory(_SettingsCategory.appUpdates),
        ),
      _buildCategoryTile(
        icon: Icons.privacy_tip_outlined,
        title: l10n.historyPrivacyTitle,
        description: l10n.settingsHistoryDescription,
        onTap: () => _openCategory(_SettingsCategory.history),
      ),
      _buildCategoryTile(
        icon: Icons.restart_alt_rounded,
        title: l10n.onboardingSettingsTitle,
        description: l10n.settingsOnboardingDescription,
        onTap: () => _openCategory(_SettingsCategory.onboarding),
      ),
      _buildCategoryTile(
        icon: Icons.info_outline_rounded,
        title: l10n.aboutTitle,
        description: l10n.settingsAboutDescription,
        onTap: () => _openCategory(_SettingsCategory.about),
      ),
    ];
  }

  Widget _buildCategory(BuildContext context, _SettingsCategory category) =>
      switch (category) {
        _SettingsCategory.appearance => _buildAppearance(context),
        _SettingsCategory.wearOs => _buildWearOs(context),
        _SettingsCategory.usage => _buildUsage(context),
        _SettingsCategory.appUpdates => _buildAppUpdates(context),
        _SettingsCategory.history => _buildHistory(context),
        _SettingsCategory.onboarding => _buildOnboarding(context),
        _SettingsCategory.about => _buildAbout(context),
      };

  Widget _buildSettingSubtitle(
    String description, {
    String? compactDescription,
  }) => Text(_compactMode ? compactDescription ?? description : description);

  Widget _buildSettingDescription(
    String description, {
    String? compactDescription,
  }) => Padding(
    padding: EdgeInsets.only(
      top: _compactMode ? 4 : 8,
      bottom: _compactMode ? 6 : 12,
    ),
    child: Text(
      _compactMode ? compactDescription ?? description : description,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: _compactMode ? 1.3 : 1.6,
      ),
    ),
  );

  Widget _buildHistoryAction({
    required IconData icon,
    required String label,
    required String description,
    required String compactDescription,
    required VoidCallback onPressed,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
      _buildSettingDescription(
        description,
        compactDescription: compactDescription,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final category = _selectedCategory;
    final isDialog = ModalRoute.of(context) is PopupRoute;
    final hasSettingsBackgroundImage = hasBackgroundImageForPage(
      controller.settings,
      pageKey: 'settings',
    );

    return PopScope<void>(
      // Scrim clicks and Escape dismiss the dialog. Category back is handled
      // by the app bar there, and by system back on full-page settings.
      canPop: isDialog || category == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedCategory != null) {
          _returnToCategories();
        }
      },
      child: BackgroundImageWrapper(
        pageKey: 'settings',
        child: Scaffold(
          backgroundColor: hasSettingsBackgroundImage
              ? Colors.transparent
              : null,
          appBar: AppBar(
            title: Text(
              category == null
                  ? l10n.settingsTitle
                  : _categoryTitle(l10n, category),
            ),
            leading: category == null
                ? null
                : BackButton(onPressed: _returnToCategories),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: PageStorage(
                bucket: _pageStorageBucket,
                child: ListView(
                  key: PageStorageKey(category?.name ?? 'categories'),
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    if (category == null)
                      ..._buildCategories(context)
                    else
                      ListTileTheme(
                        data: ListTileThemeData(
                          minVerticalPadding: _compactMode ? 4 : 12,
                          subtitleTextStyle: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: _compactMode ? 1.3 : 1.6,
                              ),
                        ),
                        child: _buildCategory(context, category),
                      ),
                    const AdBannerWidget(minimumDensity: 4, isInline: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppearance(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final selectableLocales = AppLocalizations.supportedLocales
        .where((locale) => !_fallbackOnlyLocales.contains(locale))
        .toList(growable: false);
    final selectedLanguage = controller.settings.language;
    final theme = Theme.of(context);
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppDropdownFormField<Locale?>(
              isExpanded: true,
              initialValue: controller.settings.language,
              decoration: InputDecoration(labelText: l10n.languageLabel),
              items: [
                DropdownMenuItem<Locale?>(
                  value: null,
                  child: Text(l10n.languageSystem),
                ),
                ...selectableLocales.map(
                  (locale) => DropdownMenuItem<Locale?>(
                    value: locale,
                    child: Text(lookupAppLocalizations(locale).languageName),
                  ),
                ),
                // Keep an existing fallback-locale preference
                // selectable until the user chooses another one.
                if (selectedLanguage != null &&
                    _fallbackOnlyLocales.contains(selectedLanguage))
                  DropdownMenuItem<Locale?>(
                    value: selectedLanguage,
                    child: Text(
                      lookupAppLocalizations(selectedLanguage).languageName,
                    ),
                  ),
              ],
              onChanged: controller.updateLanguage,
            ),
            _buildSettingDescription(
              l10n.languageDescription,
              compactDescription: l10n.languageDescriptionCompact,
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.interfaceScaleLabel}: '
              '${l10n.interfaceScaleValue((controller.settings.interfaceScale * 100).round())}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              _compactMode
                  ? l10n.interfaceScaleDescriptionCompact
                  : l10n.interfaceScaleDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: _compactMode ? 1.3 : 1.6,
              ),
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
            AppDropdownFormField<ThemeMode>(
              isExpanded: true,
              initialValue: controller.settings.themeMode,
              decoration: InputDecoration(labelText: l10n.themeModeLabel),
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
            _buildSettingDescription(
              l10n.themeModeDescription,
              compactDescription: l10n.themeModeDescriptionCompact,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.compactModeTitle),
              subtitle: _buildSettingSubtitle(l10n.compactModeDescription),
              value: controller.settings.enableCompactMode,
              onChanged: controller.updateEnableCompactMode,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showWeatherTitle),
              subtitle: _buildSettingSubtitle(
                l10n.showWeatherDescription,
                compactDescription: l10n.showWeatherDescriptionCompact,
              ),
              value: controller.settings.showWeatherInAppBar,
              onChanged: controller.updateShowWeatherInAppBar,
            ),
            if (isAndroid || isIOS) ...[
              const SizedBox(height: 12),
              AppDropdownFormField<MobileMapProvider>(
                isExpanded: true,
                initialValue: controller.settings.mobileMapProvider,
                decoration: InputDecoration(labelText: l10n.mapProviderLabel),
                items: MobileMapProvider.values
                    .map(
                      (provider) => DropdownMenuItem<MobileMapProvider>(
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
              _buildSettingDescription(
                l10n.mapProviderDescription,
                compactDescription: l10n.mapProviderDescriptionCompact,
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.personalizationTitle),
              subtitle: _buildSettingSubtitle(
                l10n.personalizationDescription,
                compactDescription: l10n.personalizationDescriptionCompact,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: '/personalization'),
                    builder: (_) => const PersonalizationScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWearOs(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<WearOsSyncStatus>(
      future: _wearSyncStatusFuture,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting ||
            (status == null || !status.hasConnectedNodes)) {
          return const SizedBox.shrink();
        }

        final groupNames = controller.favoriteGroupNames;
        final hasFavorites = groupNames.isNotEmpty;
        final selectedIds = controller.settings.wearSelectedFavoriteIds.toSet();

        // Get all available favorite IDs across all groups
        final availableIds = <String>[];
        for (final favorites in controller.favoriteGroups.values) {
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
                  status.connectedNodeCount > 1
                      ? l10n.wearConnectedWatches(
                          localizedList(l10n, status.connectedNodeNames),
                          status.connectedNodeCount,
                        )
                      : l10n.wearConnectedWatch(
                          localizedList(l10n, status.connectedNodeNames),
                        ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.wearSyncTitle),
                  subtitle: _buildSettingSubtitle(
                    l10n.wearSyncDescription,
                    compactDescription: l10n.wearSyncDescriptionCompact,
                  ),
                  value: controller.settings.wearSyncEnabled,
                  onChanged: controller.updateWearSyncEnabled,
                ),
                if (controller.settings.wearSyncEnabled) ...[
                  if (!hasFavorites)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.wearNoFavorites,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    AppDropdownFormField<String>(
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
                          controller.updateWearSelectedFavoriteIds(
                            availableIds,
                          );
                        } else if (value != null) {
                          final keys =
                              controller.favoriteGroups[value]
                                  ?.map((e) => e.stableKey)
                                  .toList() ??
                              const <String>[];
                          controller.updateWearSelectedFavoriteIds(keys);
                        }
                      },
                    ),
                    _buildSettingDescription(
                      l10n.wearSyncCategoryDescription,
                      compactDescription:
                          l10n.wearSyncCategoryDescriptionCompact,
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsage(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final supportsRouteBackgroundMonitor = isAndroid || isIOS;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.alwaysShowSecondsTitle),
              subtitle: _buildSettingSubtitle(
                l10n.alwaysShowSecondsDescription,
                compactDescription: l10n.alwaysShowSecondsDescriptionCompact,
              ),
              value: controller.settings.alwaysShowSeconds,
              onChanged: controller.updateAlwaysShowSeconds,
            ),
            if (isAndroid || isIOS)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.hapticFeedbackTitle),
                subtitle: _buildSettingSubtitle(
                  l10n.hapticFeedbackDescription,
                  compactDescription: l10n.hapticFeedbackDescriptionCompact,
                ),
                value: controller.settings.enableHapticFeedback,
                onChanged: controller.updateEnableHapticFeedback,
              ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.showAdsTitle),
                subtitle: _compactMode
                    ? Text(
                        _adToggleLocked
                            ? l10n.adsLockedMessageCompact
                            : controller.settings.enableAds
                            ? l10n.adsEnabledDescriptionCompact
                            : l10n.adsDisabledStatus,
                      )
                    : _adToggleLocked
                    ? Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
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
                              alignment: PlaceholderAlignment.middle,
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
                value: _adToggleLocked ? true : controller.settings.enableAds,
                onChanged: _adToggleLocked
                    ? null
                    : (value) => _handleAdToggle(context, controller, value),
              ),
            // 廣告濃度只在廣告開啟時才有意義，關閉廣告時整項隱藏。
            if (!kIsWeb &&
                defaultTargetPlatform == TargetPlatform.android &&
                controller.settings.enableAds)
              const AdDensitySetting(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.smartRecommendationsTitle),
              subtitle: _buildSettingSubtitle(
                l10n.smartRecommendationsDescription,
                compactDescription: l10n.smartRecommendationsDescriptionCompact,
              ),
              value: controller.settings.enableSmartRecommendations,
              onChanged: controller.updateEnableSmartRecommendations,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.autoFavoriteTitle),
              subtitle: _buildSettingSubtitle(
                l10n.autoFavoriteDescription,
                compactDescription: l10n.autoFavoriteDescriptionCompact,
              ),
              value: controller.settings.enableAutoFavoriteFrequentStops,
              onChanged: controller.updateEnableAutoFavoriteFrequentStops,
            ),
            if (isAndroid)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.smartNotificationTitle),
                subtitle: _buildSettingSubtitle(
                  l10n.smartNotificationDescription,
                  compactDescription: l10n.smartNotificationDescriptionCompact,
                ),
                value: controller.settings.enableSmartRouteNotifications,
                onChanged: (value) =>
                    _toggleSmartRouteNotifications(context, controller, value),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.keepScreenAwakeTitle),
              subtitle: _buildSettingSubtitle(
                l10n.keepScreenAwakeDescription,
                compactDescription: l10n.keepScreenAwakeDescriptionCompact,
              ),
              value: controller.settings.keepScreenAwakeOnRouteDetail,
              onChanged: controller.updateKeepScreenAwakeOnRouteDetail,
            ),
            if (supportsRouteBackgroundMonitor)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.backgroundTripTitle),
                subtitle: _buildSettingSubtitle(
                  isIOS
                      ? l10n.backgroundTripIosDescription
                      : l10n.backgroundTripDescription,
                  compactDescription: isIOS
                      ? l10n.backgroundTripIosDescriptionCompact
                      : l10n.backgroundTripDescriptionCompact,
                ),
                value: controller.settings.enableRouteBackgroundMonitor,
                onChanged: (value) {
                  controller.updateEnableRouteBackgroundMonitor(value);
                },
              ),
            if (isAndroid) ...[
              const SizedBox(height: 12),
              AppDropdownFormField<int>(
                isExpanded: true,
                initialValue:
                    controller.settings.favoriteWidgetAutoRefreshMinutes,
                decoration: InputDecoration(
                  labelText: l10n.favoriteWidgetRefreshLabel,
                ),
                items: _favoriteWidgetRefreshOptions
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text(_favoriteWidgetRefreshLabel(l10n, minutes)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.updateFavoriteWidgetAutoRefreshMinutes(value);
                  }
                },
              ),
              _buildSettingDescription(
                l10n.favoriteWidgetRefreshHelper,
                compactDescription: l10n.favoriteWidgetRefreshHelperCompact,
              ),
            ],
            const SizedBox(height: 8),
            Text(l10n.normalUpdateInterval(controller.settings.busUpdateTime)),
            _buildSettingDescription(
              l10n.normalUpdateIntervalDescription,
              compactDescription: l10n.normalUpdateIntervalDescriptionCompact,
            ),
            Slider(
              min: 5,
              max: 60,
              divisions: 11,
              value: controller.settings.busUpdateTime.toDouble(),
              label: l10n.secondsValue(controller.settings.busUpdateTime),
              onChanged: (value) {
                controller.updateBusUpdateTime(value.round());
              },
            ),
            const SizedBox(height: 8),
            Text(l10n.retryInterval(controller.settings.busErrorUpdateTime)),
            _buildSettingDescription(
              l10n.retryIntervalDescription,
              compactDescription: l10n.retryIntervalDescriptionCompact,
            ),
            Slider(
              min: 1,
              max: 15,
              divisions: 14,
              value: controller.settings.busErrorUpdateTime.toDouble(),
              label: l10n.secondsValue(controller.settings.busErrorUpdateTime),
              onChanged: (value) {
                controller.updateBusErrorUpdateTime(value.round());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppUpdates(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppDropdownFormField<AppUpdateChannel>(
              isExpanded: true,
              initialValue: controller.settings.appUpdateChannel,
              decoration: InputDecoration(labelText: l10n.updateChannelLabel),
              items: AppUpdateChannel.values
                  .map(
                    (channel) => DropdownMenuItem(
                      value: channel,
                      child: Text(localizedAppUpdateChannel(l10n, channel)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  controller.updateAppUpdateChannel(value);
                }
              },
            ),
            _buildSettingDescription(
              localizedAppUpdateChannelDescription(
                l10n,
                controller.settings.appUpdateChannel,
                compact: _compactMode,
              ),
            ),
            const SizedBox(height: 12),
            AppDropdownFormField<AppUpdateCheckMode>(
              isExpanded: true,
              initialValue: controller.settings.appUpdateCheckMode,
              decoration: InputDecoration(
                labelText: l10n.updateCheckOnLaunchLabel,
              ),
              items: AppUpdateCheckMode.values
                  .map(
                    (mode) => DropdownMenuItem(
                      value: mode,
                      child: Text(localizedAppUpdateCheckMode(l10n, mode)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  controller.updateAppUpdateCheckMode(value);
                }
              },
            ),
            _buildSettingDescription(
              localizedAppUpdateCheckModeDescription(
                l10n,
                controller.settings.appUpdateCheckMode,
                compact: _compactMode,
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingDescription(
              l10n.appUpdateManualCheckDescription,
              compactDescription: l10n.appUpdateManualCheckDescriptionCompact,
            ),
            FilledButton.icon(
              onPressed: controller.checkingAppUpdate
                  ? null
                  : () => _checkAppUpdate(context, controller),
              icon: controller.checkingAppUpdate
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt_rounded),
              label: Text(
                controller.checkingAppUpdate
                    ? l10n.appUpdateChecking
                    : l10n.appUpdateCheckNow,
              ),
            ),
            if (controller.lastAppUpdateResult case final result?) ...[
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
    );
  }

  Widget _buildHistory(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.searchHistoryLimit(controller.settings.maxHistory)),
            _buildSettingDescription(
              l10n.searchHistoryLimitDescription,
              compactDescription: l10n.searchHistoryLimitDescriptionCompact,
            ),
            Slider(
              min: 0,
              max: 30,
              divisions: 30,
              value: controller.settings.maxHistory.toDouble(),
              label: l10n.itemsValue(controller.settings.maxHistory),
              onChanged: (value) {
                controller.updateMaxHistory(value.round());
              },
            ),
            const SizedBox(height: 8),
            Text(l10n.smartRoutesCount(controller.routeUsageProfiles.length)),
            const SizedBox(height: 4),
            Text(l10n.routeSelectionsCount(controller.recordedRouteSelections)),
            const SizedBox(height: 12),
            _buildHistoryAction(
              onPressed: controller.clearHistory,
              icon: Icons.delete_outline_rounded,
              label: l10n.clearSearchHistory,
              description: l10n.clearSearchHistoryDescription,
              compactDescription: l10n.clearSearchHistoryDescriptionCompact,
            ),
            _buildHistoryAction(
              onPressed: controller.clearRouteUsageProfiles,
              icon: Icons.psychology_alt_outlined,
              label: l10n.clearSmartHistory,
              description: l10n.clearSmartHistoryDescription,
              compactDescription: l10n.clearSmartHistoryDescriptionCompact,
            ),
            _buildHistoryAction(
              onPressed: controller.clearRouteSelectionHistory,
              icon: Icons.route_outlined,
              label: l10n.clearRouteSelectionHistory,
              description: l10n.clearRouteSelectionHistoryDescription,
              compactDescription:
                  l10n.clearRouteSelectionHistoryDescriptionCompact,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel_outlined),
              title: Text(l10n.termsOfService),
              subtitle: _buildSettingSubtitle(
                l10n.termsOfServiceDescription,
                compactDescription: l10n.termsOfServiceDescriptionCompact,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.termsOfService);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              subtitle: _buildSettingSubtitle(
                l10n.privacyPolicyDescription,
                compactDescription: l10n.privacyPolicyDescriptionCompact,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.privacyPolicy);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboarding(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingDescription(
              l10n.restartOnboardingDescription,
              compactDescription: l10n.restartOnboardingDescriptionCompact,
            ),
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
    );
  }

  Widget _buildAbout(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final buildInfo = controller.buildInfo;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            const Divider(height: 32),
            Text(l10n.contributorsTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final contributor in _contributorGithubUris.entries)
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
              leading: const FaIcon(FontAwesomeIcons.discord, size: 22),
              title: Text(l10n.communityTitle),
              subtitle: _buildSettingSubtitle(l10n.communityDescription),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _openDiscordCommunity(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(FontAwesomeIcons.instagram, size: 22),
              title: const Text('Instagram'),
              subtitle: const Text('@yabus.tw'),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _openInstagram(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.feedback_outlined),
              title: Text(l10n.feedbackTitle),
              subtitle: _buildSettingSubtitle(l10n.feedbackDescription),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.feedback);
              },
            ),
          ],
        ),
      ),
    );
  }
}
