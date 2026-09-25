import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taiwanbus_flutter/core/weather_service.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/widgets/weather_app_bar_title.dart';

void main() {
  testWidgets('reports overflow only after weather data is available', (
    tester,
  ) async {
    var overflowCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 152,
              child: WeatherAppBarTitle(
                title: 'YABus',
                titleWidth: 96,
                enabledOverride: true,
                serviceOverride: _WeatherServiceStub(),
                locationOverride: _position,
                onOverflow: () => overflowCount++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(overflowCount, 0);
    await tester.pump();
    await tester.pump();
    expect(overflowCount, 1);

    // Rebuilding the same overflowing layout must not repeatedly notify the
    // parent and schedule redundant app-bar rebuilds.
    await tester.pump();
    expect(overflowCount, 1);
    expect(find.text('31°C'), findsNothing);
  });

  testWidgets('keeps the callback quiet when title and weather fit', (
    tester,
  ) async {
    var overflowCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: WeatherAppBarTitle(
                title: 'YABus',
                titleWidth: 96,
                enabledOverride: true,
                serviceOverride: _WeatherServiceStub(),
                locationOverride: _position,
                onOverflow: () => overflowCount++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(overflowCount, 0);
    expect(find.text('31°C'), findsOneWidget);
  });
}

Future<Position?> _position() async => Position(
  latitude: 24.11,
  longitude: 120.68,
  timestamp: DateTime.utc(2026, 9, 22),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _WeatherServiceStub extends WeatherService {
  @override
  Future<WeatherSnapshot> fetchCurrent({
    required double latitude,
    required double longitude,
    bool force = false,
  }) async {
    return WeatherSnapshot(
      temperatureC: 31,
      condition: '晴',
      fetchedAt: DateTime.utc(2026, 9, 22),
    );
  }
}
