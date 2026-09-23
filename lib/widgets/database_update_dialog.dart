import 'package:flutter/material.dart';

import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';

Future<bool> showDatabaseUpdateDialog(
  BuildContext context, {
  required Map<BusProvider, int> updates,
}) async {
  final l10n = AppLocalizations.of(context);
  final sortedEntries = updates.entries.toList()
    ..sort(
      (left, right) => localizedBusProvider(
        l10n,
        left.key,
      ).compareTo(localizedBusProvider(l10n, right.key)),
    );

  final shouldUpdate =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.databaseUpdatesDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.databaseUpdatesDialogDescription),
                const SizedBox(height: 12),
                ...sortedEntries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(localizedBusProvider(l10n, entry.key)),
                        ),
                        Text(l10n.databaseVersion(entry.value)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonLater),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.databaseUpdateNow),
              ),
            ],
          );
        },
      ) ??
      false;

  return shouldUpdate;
}
