import 'package:flutter/material.dart';

import '../app/bus_app.dart';

class AdDensitySetting extends StatelessWidget {
  const AdDensitySetting({super.key});

  static const _assets = [
    'assets/cat_unshock.jpg',
    'assets/cat_shock.jpg',
    'assets/cat_cringe.jpg',
    'assets/cat_scared.jpg',
  ];
  static const _messages = [
    '感謝支持',
    '哇 感謝你的支持<3',
    '謝謝謝謝謝謝謝謝謝謝',
    '哥們你真的很愛看廣告嗎 那很謝謝你了',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final settings = controller.settings;
    final density = settings.adDensity;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('廣告濃度'),
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
                  TextSpan(text: ' ${_messages[density - 1]}'),
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
