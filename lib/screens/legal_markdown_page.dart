import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import '../widgets/app_content_transition.dart';
import '../widgets/markdown_content_view.dart';

class LegalMarkdownPage extends StatefulWidget {
  const LegalMarkdownPage({
    required this.title,
    required this.loadDocument,
    super.key,
  });

  final String title;
  final Future<String> Function() loadDocument;

  @override
  State<LegalMarkdownPage> createState() => _LegalMarkdownPageState();
}

class _LegalMarkdownPageState extends State<LegalMarkdownPage> {
  String? _content;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await widget.loadDocument();
      if (!mounted) {
        return;
      }
      setState(() {
        _content = content;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = localizedFriendlyError(AppLocalizations.of(context), error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _loading ? null : _loadDocument,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AppContentTransition(
        state: (_content == null, _content == null && _loading),
        child: _loading && _content == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDocument,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (_error case final error?)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Card(
                              color: theme.colorScheme.errorContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.legalDocumentUpdateFailed,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(error),
                                    const SizedBox(height: 12),
                                    FilledButton.tonalIcon(
                                      onPressed: _loadDocument,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: Text(l10n.commonRetry),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_content case final content?)
                      MarkdownContentView(markdown: content)
                    else if (!_loading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: FilledButton.tonalIcon(
                            onPressed: _loadDocument,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l10n.legalDocumentReload),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
