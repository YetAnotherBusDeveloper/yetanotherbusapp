import 'dart:async';

import 'package:flutter/material.dart';

import '../app/bus_app.dart';
import '../l10n/app_localizations.dart';
import '../widgets/announcement_content.dart';
import '../widgets/announcement_reaction_bar.dart';

class AnnouncementDetailPage extends StatefulWidget {
  const AnnouncementDetailPage({required this.announcementId, super.key});

  final String announcementId;

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppControllerScope.read(context).ensureAnnouncementsLoaded());
    });
  }

  Future<void> _refresh() {
    return AppControllerScope.read(context).refreshAnnouncements(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final announcement = controller.findAnnouncementById(widget.announcementId);
        final loading = controller.announcementsLoading;
        final error = controller.announcementsError;

        return Scaffold(
          appBar: AppBar(
            title: Text(announcement?.title ?? l10n.announcementsTitle),
            actions: [
              IconButton(
                tooltip: l10n.commonRefresh,
                onPressed: loading ? null : _refresh,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: announcement == null && loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: announcement == null
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.announcementNotFound,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        if (error != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            l10n.localeName.startsWith('zh')
                                                ? error
                                                : l10n.errorGeneric,
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        FilledButton.tonalIcon(
                                          onPressed: _refresh,
                                          icon: const Icon(Icons.refresh_rounded),
                                          label: Text(
                                            l10n.announcementResync,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (error != null) ...[
                                          Card(
                                            color: theme.colorScheme.errorContainer,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Text(
                                                l10n.localeName.startsWith('zh')
                                                    ? error
                                                    : l10n.errorGeneric,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        AnnouncementContent(
                                          announcement: announcement,
                                        ),
                                        const Divider(height: 24),
                                        AnnouncementReactionBar(
                                          announcement: announcement,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
