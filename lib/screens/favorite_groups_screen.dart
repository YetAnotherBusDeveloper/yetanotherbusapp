import 'package:flutter/material.dart';

import '../app/bus_app.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import '../widgets/app_dropdown.dart';

class FavoriteGroupDraft {
  const FavoriteGroupDraft({required this.name, required this.kind});

  final String name;
  final FavoriteGroupKind kind;
}

Future<FavoriteGroupDraft?> showFavoriteGroupDialog(
  BuildContext context, {
  FavoriteGroupKind initialKind = FavoriteGroupKind.boarding,
  FavoriteItemType? compatibleItemType,
}) async {
  final textController = TextEditingController();
  final l10n = AppLocalizations.of(context);
  var selectedKind = initialKind;
  final selectableKinds = compatibleItemType == null
      ? FavoriteGroupKind.values
      : FavoriteGroupKind.values
            .where((kind) => kind.acceptsType(compatibleItemType))
            .toList(growable: false);
  final result = await showDialog<FavoriteGroupDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(l10n.favoriteGroupAddTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.favoriteGroupNameLabel,
                  hintText: l10n.favoriteGroupNameHint,
                ),
              ),
              const SizedBox(height: 16),
              AppDropdownFormField<FavoriteGroupKind>(
                initialValue: selectedKind,
                decoration: InputDecoration(
                  labelText: l10n.favoriteGroupCategoryLabel,
                ),
                items: selectableKinds
                    .map(
                      (kind) => DropdownMenuItem(
                        value: kind,
                        child: Text(localizedFavoriteGroupKind(l10n, kind)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (kind) {
                  if (kind != null) {
                    setState(() => selectedKind = kind);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = textController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.of(
                  context,
                ).pop(FavoriteGroupDraft(name: name, kind: selectedKind));
              },
              child: Text(l10n.favoriteGroupAddAction),
            ),
          ],
        );
      },
    ),
  );
  textController.dispose();
  return result;
}

class FavoriteGroupsScreen extends StatelessWidget {
  const FavoriteGroupsScreen({super.key});

  Future<void> _showAddGroupDialog(BuildContext context) async {
    final controller = AppControllerScope.read(context);
    final l10n = AppLocalizations.of(context);
    final draft = await showFavoriteGroupDialog(context);
    if (draft == null) {
      return;
    }
    if (controller.favoriteGroups.containsKey(draft.name)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.favoriteGroupDuplicate)));
      }
      return;
    }
    await controller.addFavoriteGroup(draft.name, kind: draft.kind);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final groups = controller.favoriteGroupNames;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favoriteGroupsTitle),
        actions: [
          IconButton(
            tooltip: l10n.favoriteGroupAddAction,
            onPressed: () => _showAddGroupDialog(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: groups.isEmpty
          ? Center(child: Text(l10n.favoriteGroupsEmpty))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final count = controller.favoriteGroups[group]?.length ?? 0;
                    final kind = controller.favoriteGroupKind(group);
                    return Dismissible(
                      key: ValueKey(group),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      confirmDismiss: (_) async {
                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(l10n.favoriteGroupDeleteTitle),
                              content: Text(
                                l10n.favoriteGroupDeletePrompt(group),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(l10n.commonCancel),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text(l10n.commonDelete),
                                ),
                              ],
                            );
                          },
                        );
                        return shouldDelete ?? false;
                      },
                      onDismissed: (_) async {
                        await controller.deleteFavoriteGroup(group);
                      },
                      child: Card(
                        child: ListTile(
                          title: Text(group),
                          subtitle: Text(
                            l10n.favoriteGroupSummary(
                              localizedFavoriteGroupKind(l10n, kind),
                              count,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
