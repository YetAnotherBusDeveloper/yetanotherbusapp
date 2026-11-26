import 'package:flutter/material.dart';

import '../app/bus_app.dart';
import '../l10n/app_localizations.dart';

class AdDensitySetting extends StatelessWidget {
  const AdDensitySetting({super.key});

  static const _assets = [
    'assets/cat_unshock.jpg',
    'assets/cat_shock.jpg',
    'assets/cat_cringe.jpg',
    'assets/cat_scared.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final settings = controller.settings;
    final density = settings.adDensity;
    final l10n = AppLocalizations.of(context);
    final message = switch (density) {
      1 => l10n.adDensityThanksOne,
      2 => l10n.adDensityThanksTwo,
      3 => l10n.adDensityThanksThree,
      _ => l10n.adDensityThanksFour,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.adDensityTitle),
            subtitle: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Image.asset(
                      _assets[density - 1],
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  TextSpan(text: ' $message'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (var level = 1; level <= 4; level++)
                ButtonSegment(value: level, label: Text('$level')),
            ],
            selected: {density},
            onSelectionChanged: settings.enableAds
                ? (selection) => controller.updateAdDensity(selection.single)
                : null,
          ),
        ],
      ),
    );
  }
}
