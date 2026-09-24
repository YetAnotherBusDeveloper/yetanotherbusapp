import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/widgets/app_dropdown.dart';

void main() {
  testWidgets('dropdown fields share the polished menu treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDropdownFormField<int>(
            initialValue: 1,
            decoration: const InputDecoration(labelText: '選項'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('第一項')),
              DropdownMenuItem(value: 2, child: Text('第二項')),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final dropdown = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    expect(dropdown.borderRadius, BorderRadius.circular(18));
    expect(dropdown.menuMaxHeight, 360);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    await tester.tap(find.text('第一項'));
    await tester.pumpAndSettle();
    expect(find.text('第二項'), findsOneWidget);
  });
}
