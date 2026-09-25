import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../widgets/ad_banner_widget.dart';
import '../app/bus_app.dart';
import '../core/app_routes.dart';
import '../core/account_sync_models.dart';
import '../core/app_controller.dart';
import '../core/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _requestedInitialRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialRefresh) {
      return;
    }
    final controller = AppControllerScope.of(context);
    if (!controller.isAuthenticated) {
      return;
    }
    _requestedInitialRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _refreshAccount(controller, quiet: true);
    });
  }

  Future<void> _startAuthLogin(
    AppController controller,
    String provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final opened = await controller.startAuthLogin(provider);
      if (!mounted || opened) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountLoginPageOpenFailed)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      // is 429?
      if (error.toString().contains('Too Many Requests') ||
          error.toString().contains('429')) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorRateLimited)),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.accountLoginFailed(localizedFriendlyError(l10n, error)),
          ),
        ),
      );
    }
  }

  Future<void> _startAuthLink(AppController controller, String provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final opened = await controller.startAuthLink(provider);
      if (!mounted || opened) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountLinkPageOpenFailed)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error.toString().contains('Too Many Requests') ||
          error.toString().contains('429')) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorRateLimited)),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.accountLinkFailed(localizedFriendlyError(l10n, error)),
          ),
        ),
      );
    }
  }

  Future<void> _refreshAccount(
    AppController controller, {
    bool quiet = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await controller.refreshAuthAccount();
    } catch (error) {
      if (!mounted || quiet) {
        return;
      }
      if (error.toString().contains('Too Many Requests') ||
          error.toString().contains('429')) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorRateLimited)),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.accountRefreshFailed(localizedFriendlyError(l10n, error)),
          ),
        ),
      );
    }
  }

  Future<void> _toggleSync(AppController controller, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await controller.setAccountSyncEnabled(enabled, syncNow: enabled);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? l10n.accountAutoSyncEnabled
                : l10n.accountAutoSyncDisabled,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error.toString().contains('Too Many Requests') ||
          error.toString().contains('429')) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorRateLimited)),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.accountSyncSettingsFailed(
              localizedFriendlyError(l10n, error),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleRouteHistorySync(
    AppController controller,
    bool enabled,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.accountRouteHistoryPromptTitle),
          content: Text(l10n.accountRouteHistoryPromptDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.accountEnableSync),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.setRouteHistorySyncEnabled(enabled);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? l10n.accountRouteHistoryEnabled
                : l10n.accountRouteHistoryDisabled,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.accountRouteHistoryUpdateFailed(
              localizedFriendlyError(l10n, error),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _manualSync(AppController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await controller.syncAllAccountData();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountSyncComplete)),
      );
    } catch (error) {
      if (error is AccountSyncConflictException) {
        await _showSyncConflictDialog(controller, error);
        return;
      }
      if (!mounted) {
        return;
      }
      if (error.toString().contains('Too Many Requests') ||
          error.toString().contains('429')) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorRateLimited)),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.accountSyncFailed(localizedFriendlyError(l10n, error)),
          ),
        ),
      );
    }
  }

  Future<void> _showSyncConflictDialog(
    AppController controller,
    AccountSyncConflictException conflict,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final namespace = conflict.namespace;
    final action = await showDialog<_SyncConflictAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.accountSyncConflictTitle),
          content: Text(
            l10n.localeName.startsWith('zh') &&
                    conflict.message.trim().isNotEmpty
                ? conflict.message
                : l10n.accountSyncConflictFallback(
                    localizedAccountSyncNamespace(l10n, namespace),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_SyncConflictAction.cancel),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_SyncConflictAction.useCloud),
              child: Text(l10n.accountUseCloud),
            ),
            if (conflict.canMerge)
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_SyncConflictAction.merge),
                child: Text(l10n.accountTryMerge),
              ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_SyncConflictAction.overwriteCloud),
              child: Text(l10n.accountOverwriteCloud),
            ),
          ],
        );
      },
    );
    if (!mounted || action == null || action == _SyncConflictAction.cancel) {
      return;
    }

    try {
      switch (action) {
        case _SyncConflictAction.cancel:
          return;
        case _SyncConflictAction.useCloud:
          await controller.restoreAccountNamespace(namespace);
        case _SyncConflictAction.merge:
          await controller.syncAccountNamespace(
            namespace,
            conflictPolicy: AccountSyncConflictPolicy.merge,
          );
        case _SyncConflictAction.overwriteCloud:
          await controller.syncAccountNamespace(
            namespace,
            conflictPolicy: namespace == AccountSyncNamespace.preferences
                ? AccountSyncConflictPolicy.clientWins
                : AccountSyncConflictPolicy.clientWins,
          );
      }
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountSyncComplete)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.accountSyncConflictFailed(
              localizedFriendlyError(l10n, error),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _logout(AppController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await controller.logoutAuth();
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.accountLoggedOut)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final session = controller.authSession;
    final account = controller.authAccount;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const SizedBox(height: 12),
              if (!controller.isAuthenticated) ...[
                _IntroCard(
                  isAuthenticated: controller.isAuthenticated,
                  displayName:
                      account?.displayName ?? session?.displayName ?? '',
                ),
                _AuthActionsCard(
                  title: l10n.accountSignIn,
                  description: l10n.accountSignInDescription,
                  busy: controller.authBusy,
                  onDiscord: () => _startAuthLogin(controller, 'discord'),
                  onGoogle: () => _startAuthLogin(controller, 'google'),
                ),
              ] else ...[
                _LinkedProvidersCard(
                  account: account,
                  session: session,
                  loading: controller.authAccountLoading,
                  busy: controller.authBusy,
                  onDiscordLink: () => _startAuthLink(controller, 'discord'),
                  onGoogleLink: () => _startAuthLink(controller, 'google'),
                ),
                const SizedBox(height: 12),
                const _SocialCard(),
                const SizedBox(height: 12),
                _SyncCard(
                  enabled: controller.accountSyncEnabled,
                  routeHistoryEnabled: controller.routeHistorySyncEnabled,
                  routeHistoryDeletionPending:
                      controller.routeHistoryDeletionPending,
                  busy: controller.accountSyncBusy,
                  lastSyncAt: controller.lastAccountSyncAt,
                  onChanged: (value) => _toggleSync(controller, value),
                  onRouteHistoryChanged: (value) =>
                      _toggleRouteHistorySync(controller, value),
                  onSyncNow: () => _manualSync(controller),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: controller.authBusy
                            ? null
                            : () => _logout(controller),
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(l10n.accountLogout),
                      ),
                    ),
                  ),
                ),
              ],
              const AdBannerWidget(minimumDensity: 4, isInline: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialCard extends StatelessWidget {
  const _SocialCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
        leading: const CircleAvatar(child: Icon(Icons.share_location_rounded)),
        title: const Text('社交與位置分享'),
        subtitle: const Text('主動分享目前位置給朋友，不會背景追蹤，也不會自動上傳座標。'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.social),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.isAuthenticated, required this.displayName});

  final bool isAuthenticated;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = isAuthenticated
        ? l10n.accountSignedIn
        : l10n.accountSignedOut;
    final subtitle = isAuthenticated
        ? (displayName.trim().isEmpty
              ? l10n.accountDefaultDisplayName
              : displayName)
        : l10n.accountContinueDescription;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              child: Icon(
                isAuthenticated
                    ? Icons.verified_user_outlined
                    : Icons.account_circle_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedProvidersCard extends StatelessWidget {
  const _LinkedProvidersCard({
    required this.account,
    required this.session,
    required this.loading,
    required this.busy,
    required this.onDiscordLink,
    required this.onGoogleLink,
  });

  final AuthAccount? account;
  final AuthSession? session;
  final bool loading;
  final bool busy;
  final VoidCallback onDiscordLink;
  final VoidCallback onGoogleLink;

  @override
  Widget build(BuildContext context) {
    final identities = account?.identities ?? const <AuthIdentity>[];
    final fallbackProvider = session?.provider ?? '';
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.accountSignedIn, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (loading && identities.isEmpty)
              const LinearProgressIndicator()
            else if (identities.isEmpty && fallbackProvider.isNotEmpty)
              _ProviderTile(
                provider: fallbackProvider,
                label: session?.displayName ?? '',
                detail: l10n.accountLoadedFromCurrentToken,
              )
            else if (identities.isEmpty)
              Text(l10n.accountNoLinkedProviders)
            else
              for (final identity in identities)
                _ProviderTile(
                  provider: identity.provider,
                  label: identity.label,
                  detail: identity.email.isEmpty
                      ? identity.providerUserId
                      : identity.email,
                ),
            if (!(loading && identities.isEmpty)) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (!(account?.hasDiscord ?? false)) ...[
                    OutlinedButton.icon(
                      onPressed: busy ? null : onDiscordLink,
                      icon: const FaIcon(FontAwesomeIcons.discord, size: 16),
                      label: Text(
                        l10n.accountLinkProvider(l10n.accountProviderDiscord),
                      ),
                    ),
                  ],
                  if (!(account?.hasGoogle ?? false)) ...[
                    OutlinedButton.icon(
                      onPressed: busy ? null : onGoogleLink,
                      icon: const FaIcon(FontAwesomeIcons.google, size: 16),
                      label: Text(
                        l10n.accountLinkProvider(l10n.accountProviderGoogle),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.enabled,
    required this.routeHistoryEnabled,
    required this.routeHistoryDeletionPending,
    required this.busy,
    required this.lastSyncAt,
    required this.onChanged,
    required this.onRouteHistoryChanged,
    required this.onSyncNow,
  });

  final bool enabled;
  final bool routeHistoryEnabled;
  final bool routeHistoryDeletionPending;
  final bool busy;
  final DateTime? lastSyncAt;
  final ValueChanged<bool> onChanged;
  final ValueChanged<bool> onRouteHistoryChanged;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.accountCloudSync, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: busy ? null : onChanged,
              title: Text(l10n.accountEnableCloudSync),
              subtitle: Text(
                enabled
                    ? l10n.accountLastSync(
                        _formatDateTime(l10n, lastSyncAt),
                      )
                    : l10n.accountSyncDisabled,
              ),
            ),
            const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: routeHistoryEnabled,
              onChanged: busy ? null : onRouteHistoryChanged,
              secondary: const Icon(Icons.history_rounded),
              title: Text(l10n.accountSyncRouteHistory),
              subtitle: Text(
                routeHistoryDeletionPending
                    ? l10n.accountRouteHistoryDeletionPending
                    : routeHistoryEnabled
                    ? enabled
                          ? l10n.accountRouteHistorySyncDescription
                          : l10n.accountRouteHistoryWaitingForCloudSync
                    : l10n.accountRouteHistoryOptional,
              ),
            ),
            if (busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onSyncNow,
              icon: const Icon(Icons.sync_rounded),
              label: Text(l10n.accountSyncNow),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthActionsCard extends StatelessWidget {
  const _AuthActionsCard({
    required this.title,
    required this.description,
    required this.busy,
    required this.onDiscord,
    required this.onGoogle,
  });

  final String title;
  final String description;
  final bool busy;
  final VoidCallback onDiscord;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : onDiscord,
                  icon: const FaIcon(FontAwesomeIcons.discord, size: 18),
                  label: Text(
                    l10n.accountContinueWithProvider(
                      l10n.accountProviderDiscord,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onGoogle,
                  icon: const FaIcon(FontAwesomeIcons.google, size: 18),
                  label: Text(
                    l10n.accountContinueWithProvider(
                      l10n.accountProviderGoogle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(AppLocalizations l10n, DateTime? value) {
  if (value == null) {
    return l10n.accountNeverSynced;
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

enum _SyncConflictAction { cancel, useCloud, merge, overwriteCloud }

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.label,
    required this.detail,
  });

  final String provider;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: _providerIcon(provider)),
      title: Text(
        label.trim().isEmpty ? _providerName(l10n, provider) : label,
      ),
      subtitle: Text(
        detail.trim().isEmpty ? _providerName(l10n, provider) : detail,
      ),
    );
  }
}

Widget _providerIcon(String provider) {
  switch (provider) {
    case 'discord':
      return const FaIcon(FontAwesomeIcons.discord, size: 18);
    case 'google':
      return const FaIcon(FontAwesomeIcons.google, size: 18);
    default:
      return const Icon(Icons.link_rounded, size: 18);
  }
}

String _providerName(AppLocalizations l10n, String provider) {
  switch (provider) {
    case 'discord':
      return l10n.accountProviderDiscord;
    case 'google':
      return l10n.accountProviderGoogle;
    default:
      return provider.trim().isEmpty ? l10n.accountProviderOAuth : provider;
  }
}
