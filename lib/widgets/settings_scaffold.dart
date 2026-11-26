import 'package:flutter/material.dart';

import '../app/bus_app.dart';
import 'background_image_wrapper.dart';

/// Shares the settings background beneath themed translucent surfaces.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({required this.appBar, required this.body, super.key});

  final PreferredSizeWidget appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final settings = AppControllerScope.of(context).settings;
    return BackgroundImageWrapper(
      pageKey: 'settings',
      child: Scaffold(
        backgroundColor:
            hasBackgroundImageForPage(settings, pageKey: 'settings')
            ? Colors.transparent
            : null,
        appBar: appBar,
        body: body,
      ),
    );
  }
}
