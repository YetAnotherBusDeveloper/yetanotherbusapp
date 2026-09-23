import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/transit_repository.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/screens/metro_dashboard_screen.dart';

MetroStationSequence _station(String id, String name, int sequence) {
  return MetroStationSequence(
    stationId: id,
    name: name,
    nameEn: name,
    sequence: sequence,
  );
}

void main() {
  testWidgets('switches between outbound and return metro directions', (
    tester,
  ) async {
    final directions = [
      MetroStationOfLine(
        lineId: 'R',
        direction: 0,
        stations: [_station('R02', '象山', 1), _station('R28', '淡水', 2)],
      ),
      MetroStationOfLine(
        lineId: 'R',
        direction: 1,
        stations: [_station('R28', '淡水', 1), _station('R02', '象山', 2)],
      ),
    ];
    var selectedDirection = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MetroDirectionSelector(
              directions: directions,
              selectedDirection: selectedDirection,
              onChanged: (direction) {
                setState(() => selectedDirection = direction);
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('往 淡水'), findsOneWidget);
    expect(find.text('往 象山'), findsOneWidget);
    expect(find.textContaining('去程'), findsNothing);
    expect(find.textContaining('返程'), findsNothing);
    expect(find.text('行駛方向'), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.byType(FilledButton), findsNWidgets(2));

    await tester.tap(find.text('往 象山'));
    await tester.pump();

    expect(selectedDirection, 1);
  });
}
