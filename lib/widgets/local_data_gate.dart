import 'package:flutter/material.dart';

import '../app/bus_app.dart';
import '../core/app_controller.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';

/// An unloaded collection is not an empty collection. Keep management screens
/// out of their empty state until their authoritative local bundle is ready.
class LocalDataGate extends StatefulWidget {
  const LocalDataGate({required this.domain, required this.title, required this.child, super.key});
  final AppLocalData domain;
  final String title;
  final Widget child;

  @override
  State<LocalDataGate> createState() => _LocalDataGateState();
}

class _LocalDataGateState extends State<LocalDataGate> {
  AppController? _controller;
  AppLocalData? _domain;
  Future<void>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppControllerScope.of(context);
    if (_controller != controller || _domain != widget.domain) {
      _controller = controller;
      _domain = widget.domain;
      _load = controller.ensureLocalData(widget.domain);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    if (controller.isLocalDataReady(widget.domain)) return widget.child;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<void>(
        future: _load,
        builder: (context, snapshot) {
          if (!snapshot.hasError) return const Center(child: CircularProgressIndicator());
          final l10n = AppLocalizations.of(context);
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(localizedFriendlyError(l10n, snapshot.error!), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => setState(() {
                _load = controller.ensureLocalData(widget.domain);
              }), child: Text(l10n.commonRetry)),
            ]),
          ));
        },
      ),
    );
  }
}
