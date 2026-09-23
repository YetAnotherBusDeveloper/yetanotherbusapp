import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../app/bus_app.dart';
import '../core/announcement_models.dart';
import '../core/app_routes.dart';
import '../l10n/app_localizations.dart';

/// A Discord-style reaction bar: a wrap of emoji count chips plus an add
/// button. Tapping a chip toggles the signed-in user's reaction; the add
/// button opens an emoji picker. Anonymous users see the counts but are
/// prompted to log in when they try to react.
class AnnouncementReactionBar extends StatelessWidget {
  const AnnouncementReactionBar({required this.announcement, super.key});

  final AppAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final reaction in announcement.reactions)
          FilterChip(
            label: Text(
              l10n.announcementReactionCount(reaction.emoji, reaction.count),
            ),
            selected: announcement.myReactions.contains(reaction.emoji),
            showCheckmark: false,
            onSelected: (_) => _toggle(context, reaction.emoji),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_reaction_outlined, size: 18),
          label: Text(l10n.announcementReaction),
          tooltip: l10n.announcementAddReaction,
          onPressed: () => _openPicker(context),
        ),
        if (announcement.reactions.isEmpty)
          Text(
            l10n.announcementFirstReaction,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!_ensureLoggedIn(context)) {
      return;
    }
    final theme = Theme.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                Navigator.of(sheetContext).pop(emoji.emoji);
              },
              config: Config(
                height: 320,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: theme.colorScheme.surface,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: theme.colorScheme.surface,
                  iconColorSelected: theme.colorScheme.primary,
                  indicatorColor: theme.colorScheme.primary,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected != null && selected.isNotEmpty && context.mounted) {
      await _toggle(context, selected);
    }
  }

  Future<void> _toggle(BuildContext context, String emoji) async {
    if (!_ensureLoggedIn(context)) {
      return;
    }
    final controller = AppControllerScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await controller.toggleAnnouncementReaction(announcement.id, emoji);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.announcementReactionUpdateFailed)),
      );
    }
  }

  bool _ensureLoggedIn(BuildContext context) {
    final controller = AppControllerScope.read(context);
    if (controller.isAuthenticated) {
      return true;
    }
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.announcementReactionSignInRequired),
        action: SnackBarAction(
          label: l10n.accountSignIn,
          onPressed: () => navigator.pushNamed(AppRoutes.account),
        ),
      ),
    );
    return false;
  }
}
