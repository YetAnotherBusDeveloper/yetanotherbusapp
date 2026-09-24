import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/ad_banner_widget.dart';
import '../app/bus_app.dart';
import '../core/app_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import '../widgets/app_dropdown.dart';

class DatabaseSettingsScreen extends StatelessWidget {
  const DatabaseSettingsScreen({super.key});

  Future<void> _checkDatabaseUpdates(
    BuildContext context,
    AppController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final updates = await controller.checkDatabaseUpdates();
      if (!context.mounted) {
        return;
      }

      final availableUpdates = updates.entries
          .where((entry) => entry.value != null)
          .toList();
      if (availableUpdates.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.databaseUpToDate)));
        return;
      }

      final lines = availableUpdates
          .map(
            (entry) => l10n.databaseUpdateAvailable(
              localizedBusProvider(l10n, entry.key),
              entry.value!,
            ),
          )
          .join('\n');
      messenger.showSnackBar(SnackBar(content: Text(lines)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.databaseCheckFailed(localizedFriendlyError(l10n, error)),
          ),
        ),
      );
    }
  }

  Future<void> _downloadProviders(
    BuildContext context,
    AppController controller, {
    required Iterable<BusProvider> providers,
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final targets = providers.toSet().toList();
    if (targets.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.databaseNoUpdatesAvailable)),
      );
      return;
    }

    try {
      await controller.downloadProviderDatabases(targets);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.databaseDownloadFailed(localizedFriendlyError(l10n, error)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final supportsDesktopDiscordPresence =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.databaseDownloadsTitle)),
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
                        l10n.databaseStartupUpdateTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      AppDropdownFormField<DatabaseAutoUpdateMode>(
                        isExpanded: true,
                        initialValue:
                            controller.settings.databaseAutoUpdateMode,
                        decoration: InputDecoration(
                          labelText: l10n.databaseAutoUpdateModeLabel,
                        ),
                        items: DatabaseAutoUpdateMode.values
                            .map(
                              (mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(
                                  localizedDatabaseAutoUpdateMode(l10n, mode),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            controller.updateDatabaseAutoUpdateMode(value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localizedDatabaseAutoUpdateModeDescription(
                          l10n,
                          controller.settings.databaseAutoUpdateMode,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (controller.hasPendingDatabaseUpdates) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.databasePendingRegions(
                                  controller.pendingDatabaseUpdates.length,
                                ),
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                controller.pendingDatabaseUpdates.entries
                                    .map(
                                      (entry) => l10n.databaseRegionVersion(
                                        localizedBusProvider(l10n, entry.key),
                                        entry.value,
                                      ),
                                    )
                                    .join(
                                      l10n.localeName.startsWith('zh')
                                          ? '、'
                                          : ', ',
                                    ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: controller.downloadingDatabase
                                ? null
                                : () => _checkDatabaseUpdates(
                                    context,
                                    controller,
                                  ),
                            icon: const Icon(Icons.cloud_sync_outlined),
                            label: Text(l10n.databaseCheckNow),
                          ),
                          FilledButton.icon(
                            onPressed:
                                controller.downloadingDatabase ||
                                    !controller.hasPendingDatabaseUpdates
                                ? null
                                : () => _downloadProviders(
                                    context,
                                    controller,
                                    providers:
                                        controller.pendingDatabaseUpdates.keys,
                                    successMessage:
                                        l10n.databaseAllUpdatesDownloaded,
                                  ),
                            icon: controller.downloadingDatabase
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded),
                            label: Text(l10n.databaseDownloadUpdates),
                          ),
                        ],
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
                        l10n.databaseRouteDatabaseTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      // Text(
                      //   '這份資料庫保存所有路線與方向資料，會在下載任一地區資料庫時一併更新。',
                      //   style: theme.textTheme.bodyMedium,
                      // ),
                      const SizedBox(height: 12),
                      FutureBuilder<bool>(
                        future: controller.isRouteMetadataDatabaseReady(),
                        builder: (context, snapshot) {
                          final ready = snapshot.data ?? false;
                          return Row(
                            children: [
                              Chip(
                                avatar: Icon(
                                  ready
                                      ? Icons.alt_route_rounded
                                      : Icons.cloud_off_outlined,
                                ),
                                label: Text(
                                  ready
                                      ? l10n.databaseDownloaded
                                      : l10n.databaseNotDownloadedYet,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Expanded(
                              //   child: Text(
                              //     '檔名：routes_metadata_v1.sqlite',
                              //     style: theme.textTheme.bodySmall,
                              //   ),
                              // ),
                            ],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.databaseDataSourceTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      AppDropdownFormField<BusProvider>(
                        isExpanded: true,
                        initialValue: controller.settings.provider,
                        decoration: InputDecoration(
                          labelText: l10n.databaseDefaultRegionLabel,
                        ),
                        items: downloadableBusProviders()
                            .map(
                              (provider) => DropdownMenuItem(
                                value: provider,
                                child: Text(
                                  localizedBusProvider(l10n, provider),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            controller.updateProvider(value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.databaseSelectLocalRegions,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: downloadableBusProviders().map((provider) {
                          return FilterChip(
                            label: Text(localizedBusProvider(l10n, provider)),
                            selected: controller.selectedProviders.contains(
                              provider,
                            ),
                            onSelected: (value) {
                              controller.toggleSelectedProvider(
                                provider,
                                value,
                              );
                            },
                            avatar: controller.isDatabaseReady(provider)
                                ? const Icon(
                                    Icons.download_done_rounded,
                                    size: 18,
                                  )
                                : const Icon(Icons.cloud_outlined, size: 18),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: controller.downloadingDatabase
                            ? null
                            : () => _downloadProviders(
                                context,
                                controller,
                                providers: controller.selectedProviders,
                                successMessage:
                                    l10n.databaseSelectedRegionsDownloaded,
                              ),
                        icon: controller.downloadingDatabase
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_for_offline_outlined),
                        label: Text(l10n.databaseDownloadSelectedRegions),
                      ),
                      if (supportsDesktopDiscordPresence) ...[
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 18),
                        Text(
                          l10n.databaseDiscordPresenceSection,
                          style: theme.textTheme.titleMedium,
                        ),
                        // const SizedBox(height: 8),
                        // Text(
                        //   '桌面版可把目前操作內容同步到 Discord 狀態，下面可以控制顯示哪些欄位。',
                        //   style: theme.textTheme.bodyMedium,
                        // ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.databaseDiscordPresenceTitle),
                          subtitle: Text(
                            l10n.databaseDiscordPresenceDescription,
                          ),
                          value:
                              controller.settings.desktopDiscordPresenceEnabled,
                          onChanged:
                              controller.updateDesktopDiscordPresenceEnabled,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: Text(l10n.databasePresenceCurrentPage),
                              selected:
                                  controller.settings.desktopDiscordShowScreen,
                              onSelected:
                                  controller
                                      .settings
                                      .desktopDiscordPresenceEnabled
                                  ? controller.updateDesktopDiscordShowScreen
                                  : null,
                            ),
                            FilterChip(
                              label: Text(l10n.databasePresenceRegion),
                              selected: controller
                                  .settings
                                  .desktopDiscordShowProvider,
                              onSelected:
                                  controller
                                      .settings
                                      .desktopDiscordPresenceEnabled
                                  ? controller.updateDesktopDiscordShowProvider
                                  : null,
                            ),
                            FilterChip(
                              label: Text(l10n.databasePresenceRouteName),
                              selected: controller
                                  .settings
                                  .desktopDiscordShowRouteName,
                              onSelected:
                                  controller
                                      .settings
                                      .desktopDiscordPresenceEnabled
                                  ? controller.updateDesktopDiscordShowRouteName
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...controller.selectedProviders.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  localizedBusProvider(l10n, provider),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              if (controller.pendingDatabaseUpdates[provider]
                                  case final version?)
                                Chip(
                                  avatar: const Icon(
                                    Icons.system_update_alt_rounded,
                                  ),
                                  label: Text(
                                    l10n.databaseVersionAvailable(version),
                                  ),
                                )
                              else
                                Chip(
                                  avatar: Icon(
                                    controller.isDatabaseReady(provider)
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.cloud_off_outlined,
                                  ),
                                  label: Text(
                                    controller.isDatabaseReady(provider)
                                        ? l10n.databaseDownloaded
                                        : l10n.databaseNotDownloaded,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<int?>(
                            future: controller.localVersionForProvider(
                              provider,
                            ),
                            builder: (context, snapshot) {
                              final version = snapshot.data;
                              return Text(
                                version == null || version == 0
                                    ? l10n.databaseLocalVersionNotDownloaded
                                    : l10n.databaseLocalVersion(version),
                                style: theme.textTheme.bodyMedium,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: controller.downloadingDatabase
                                    ? null
                                    : () => _downloadProviders(
                                        context,
                                        controller,
                                        providers: [provider],
                                        successMessage: l10n
                                            .databaseRegionUpdated(
                                              localizedBusProvider(
                                                l10n,
                                                provider,
                                              ),
                                            ),
                                      ),
                                icon: const Icon(Icons.download_rounded),
                                label: Text(
                                  controller.isDatabaseReady(provider)
                                      ? l10n.databaseRedownload
                                      : l10n.commonDownload,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: controller.downloadingDatabase
                                    ? null
                                    : () async {
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        try {
                                          await controller
                                              .deleteProviderDatabase(provider);
                                          if (!context.mounted) {
                                            return;
                                          }
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.databaseRegionDeleted(
                                                  localizedBusProvider(
                                                    l10n,
                                                    provider,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        } catch (error) {
                                          if (!context.mounted) {
                                            return;
                                          }
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.databaseDeleteFailed(
                                                  localizedFriendlyError(
                                                    l10n,
                                                    error,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: Text(l10n.commonDelete),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const AdBannerWidget(minimumDensity: 4, isInline: true),
            ],
          ),
        ),
      ),
    );
  }
}
