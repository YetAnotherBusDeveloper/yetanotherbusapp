import 'package:flutter/material.dart';

import '../core/announcement_models.dart';
import '../l10n/app_localizations.dart';
import 'announcement_content.dart';

enum AnnouncementPopupResult { later, dismissForever, viewDetails }

Future<AnnouncementPopupResult> showAnnouncementPopupDialog(
  BuildContext context, {
  required AppAnnouncement announcement,
}) async {
  final result = await showDialog<AnnouncementPopupResult>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      return AlertDialog(
        title: Text(announcement.title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: AnnouncementContent(announcement: announcement, compact: true),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(AnnouncementPopupResult.later),
            child: Text(l10n.commonLater),
          ),
          if (announcement.behavior.popup == AnnouncementRepeatBehavior.forever)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                AnnouncementPopupResult.dismissForever,
              ),
              child: Text(l10n.announcementDismissForever),
            ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(AnnouncementPopupResult.viewDetails),
            child: Text(l10n.announcementViewDetails),
          ),
        ],
      );
    },
  );
  return result ?? AnnouncementPopupResult.later;
}
