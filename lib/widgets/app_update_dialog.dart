import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_build_info.dart';
import '../core/app_controller.dart';
import '../core/app_update_service.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppController controller,
  required AppUpdateCheckResult result,
}) async {
  final update = result.update;
  if (update == null) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _AppUpdateDialog(controller: controller, update: update);
    },
  );
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.controller, required this.update});

  final AppController controller;
  final AppUpdateInfo update;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _installing = false;
  double? _progress;
  String _statusMessage = '';

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).appUpdateDownloadLinkCopied,
        ),
      ),
    );
  }

  Future<void> _openMarkdownLink(String? href) async {
    if (href == null) {
      return;
    }

    final uri = Uri.tryParse(href);
    if (uri == null) {
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).linkOpenFailed)),
    );
  }

  String? _buildChangelogMarkdown(AppLocalizations l10n) {
    final notes = widget.update.notes?.trim();
    final detailsUrl = widget.update.detailsUrl?.trim();
    final sections = <String>[];

    if (widget.update.channel == AppUpdateChannel.nightly) {
      sections.add(_buildNightlyCommitMarkdown(l10n));
    }

    if (detailsUrl != null && detailsUrl.isNotEmpty) {
      final rangeLabel =
          '${widget.update.currentDisplayLabel}...${widget.update.latestDisplayLabel}';
      sections.add(l10n.appUpdateFullChangesMarkdown(rangeLabel, detailsUrl));
    }

    if (notes != null && notes.isNotEmpty) {
      sections.add(notes);
    }

    if (sections.isEmpty) {
      return null;
    }
    return sections.join('\n\n');
  }

  String _buildNightlyCommitMarkdown(AppLocalizations l10n) {
    final commitHash = widget.update.latestVersionLabel;
    final commitUrl = Uri.https(
      'github.com',
      '/${AppBuildInfo.repoOwner}/${AppBuildInfo.repoName}/commit/$commitHash',
    );
    return l10n.appUpdateCommitMarkdown(
      widget.update.latestDisplayLabel,
      commitUrl.toString(),
    );
  }

  String _localizedUpdateTitle(AppLocalizations l10n) {
    return switch (widget.update.channel) {
      AppUpdateChannel.nightly => l10n.appUpdateNightlyDialogTitle,
      AppUpdateChannel.release => l10n.appUpdateReleaseDialogTitle(
        widget.update.latestDisplayLabel,
      ),
      AppUpdateChannel.developer => l10n.appUpdatesTitle,
    };
  }

  String _localizedInstallerMessage(
    AppLocalizations l10n,
    String message,
  ) {
    const failurePrefix = '下載或安裝更新失敗：';
    if (message.startsWith(failurePrefix)) {
      return l10n.appUpdateInstallFailed(message.substring(failurePrefix.length));
    }

    return switch (message) {
      '下載更新中…' => l10n.appUpdateDownloading,
      '整理安裝檔中…' => l10n.appUpdatePreparingInstaller,
      '啓動安裝程式…' => l10n.appUpdateLaunchingInstaller,
      '準備關閉 App 並啓動安裝程式…' =>
        l10n.appUpdatePreparingDesktopInstaller,
      '這個平台不支援 app 內安裝更新。' =>
        l10n.appUpdateInstallUnsupported,
      '請先允許這個 app 安裝未知應用程式，再重新點一次更新。' =>
        l10n.appUpdateInstallPermissionRequired,
      '安裝程式已啓動。' => l10n.appUpdateInstallerLaunched,
      '即將關閉 App 並啓動安裝程式。' =>
        l10n.appUpdateDesktopInstallerScheduled,
      _ => message,
    };
  }

  Future<void> _installUpdate() async {
    if (_installing) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    setState(() {
      _installing = true;
      _progress = 0;
      _statusMessage = l10n.appUpdatePreparing;
    });

    final messenger = ScaffoldMessenger.of(context);
    final installResult = await widget.controller.installAppUpdate(
      widget.update,
      onProgress: (progress, message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _progress = progress;
          _statusMessage = _localizedInstallerMessage(l10n, message);
        });
      },
    );

    if (!mounted) {
      return;
    }

    if (installResult.didLaunchInstaller &&
        _shouldExitAfterSchedulingInstaller) {
      Navigator.of(context).pop();
      await widget.controller.appUpdateInstaller.exitAfterLaunchingInstaller();
      await SystemNavigator.pop();
      return;
    }

    setState(() {
      _installing = false;
      _progress = null;
      _statusMessage = '';
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(_localizedInstallerMessage(l10n, installResult.message)),
      ),
    );

    if (installResult.didLaunchInstaller) {
      Navigator.of(context).pop();
    }
  }

  bool get _shouldExitAfterSchedulingInstaller =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canInstallInApp =
        widget.controller.appUpdateInstaller.supportsInAppInstall;
    final changelogMarkdown = _buildChangelogMarkdown(l10n);

    return AlertDialog(
      title: Text(_localizedUpdateTitle(l10n)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.update.channel == AppUpdateChannel.nightly)
                Text(
                  l10n.appUpdateNightlySummary(
                    widget.update.latestDisplayLabel,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                l10n.appUpdateCurrentVersion(
                  widget.update.currentDisplayLabel,
                ),
              ),
              Text(
                l10n.appUpdateLatestVersion(widget.update.latestDisplayLabel),
              ),
              if (_installing) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(_statusMessage),
              ],
              if (changelogMarkdown != null) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.appUpdateContentsTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                MarkdownBody(
                  data: changelogMarkdown,
                  onTapLink: (text, href, title) => _openMarkdownLink(href),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _installing
              ? null
              : () => _copyLink(widget.update.downloadUrl),
          child: Text(
            canInstallInApp
                ? l10n.appUpdateCopyDownloadLink
                : l10n.appUpdateDownloadLink,
          ),
        ),
        TextButton(
          onPressed: _installing ? null : () => Navigator.of(context).pop(),
          child: Text(canInstallInApp ? l10n.commonLater : l10n.commonClose),
        ),
        if (canInstallInApp)
          FilledButton(
            onPressed: _installing ? null : _installUpdate,
            child: Text(l10n.appUpdateDownloadAndInstall),
          ),
      ],
    );
  }
}
