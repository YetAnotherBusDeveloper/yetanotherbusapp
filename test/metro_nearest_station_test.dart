import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/account_sync_service.dart';
import 'package:taiwanbus_flutter/core/app_analytics.dart';
import 'package:taiwanbus_flutter/core/app_build_info.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';
import 'package:taiwanbus_flutter/core/transit_repository.dart';
import 'package:taiwanbus_flutter/core/user_location.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/screens/metro_dashboard_screen.dart';
import 'package:taiwanbus_flutter/widgets/transit_station_map.dart';

const _taipei = MetroSystem(
  system: 'TRTC',
  city: 'Taipei',
  name: 'Taipei Metro',
  nameEn: 'Taipei Metro',
);
const _kaohsiung = MetroSystem(
  system: 'KRTC',
  city: 'Kaohsiung',
  name: 'Kaohsiung Metro',
  nameEn: 'Kaohsiung Metro',
);

MetroLine _line(String id) => MetroLine(
  lineId: id,
  lineNo: id,
  name: 'Line $id',
  nameEn: '',
  color: '#FF6600',
);

MetroStation _station(String id, double lat, double lon) => MetroStation(
  stationId: id,
  name: 'Station $id',
  nameEn: 'Station $id',
  // The stations API does not reliably provide line membership.
  lineId: '',
  lat: lat,
  lon: lon,
);

MetroStationOfLine _sequence(String line, List<String> ids) =>
    MetroStationOfLine(
      lineId: line,
      direction: 0,
      stations: [
        for (var i = 0; i < ids.length; i++)
          MetroStationSequence(
            stationId: ids[i],
            name: 'Station ${ids[i]}',
            nameEn: 'Station ${ids[i]}',
            sequence: i + 1,
          ),
      ],
    );

class _MetroRepository extends TransitRepository {
  final failedSystems = <String>{};
  final stationRequests = <String>[];
  final etaRequests = <String>[];
  bool missingCoordinates = false;

  @override
  Future<List<MetroSystem>> getMetroSystems() async => [_taipei, _kaohsiung];

  @override
  Future<List<MetroLine>> getMetroLines(String system) async =>
      system == 'TRTC' ? [_line('T')] : [_line('R'), _line('O')];

  @override
  Future<List<MetroStation>> getMetroStations(String system) async {
    stationRequests.add(system);
    if (failedSystems.contains(system)) {
      throw StateError('Station data unavailable');
    }
    final stations = system == 'TRTC'
        ? [_station('T1', 25.04, 121.51), _station('T2', 25.05, 121.52)]
        : [
            _station('R1', 22.66, 120.31),
            _station('R2', 22.67, 120.32),
            _station('O1', 22.64, 120.29),
            _station('O2', 22.63, 120.30),
          ];
    return missingCoordinates
        ? stations.map((station) => _station(station.stationId, 0, 0)).toList()
        : stations;
  }

  @override
  Future<List<MetroStationOfLine>> getMetroStationOfLine(String system) async =>
      system == 'TRTC'
      ? [
          _sequence('T', ['T1', 'T2']),
        ]
      : [
          _sequence('R', ['R1', 'R2']),
          _sequence('O', ['O1', 'O2']),
        ];

  @override
  Future<MetroEtaResponse> getMetroLineEta(String system, String lineId) async {
    etaRequests.add('$system/$lineId');
    return const MetroEtaResponse(
      source: 'liveboard',
      currentTime: '',
      entries: [],
    );
  }
}

Position _position({double latitude = 22.6301, double longitude = 120.3001}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime(2026, 11, 3),
      altitude: 0,
      altitudeAccuracy: 0,
      accuracy: 10,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppController controller;
  late _MetroRepository repository;
  late HttpOverrides? previousHttpOverrides;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _TileHttpOverrides();
    controller = await _buildController();
    repository = _MetroRepository();
  });

  tearDown(() {
    controller.dispose();
    HttpOverrides.global = previousHttpOverrides;
  });

  Future<void> pumpMetro(
    WidgetTester tester, {
    Future<Position> Function()? positionResolver,
  }) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppControllerScope(
          controller: controller,
          child: MetroScreen(
            isActive: false,
            showAdBanner: false,
            repository: repository,
            positionResolver: positionResolver ?? () async => _position(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder locateButton() => find.byKey(const ValueKey('metro_locate_nearest'));

  String selectedSystem(WidgetTester tester) =>
      (tester
                  .widgetList<ChoiceChip>(find.byType(ChoiceChip))
                  .singleWhere((chip) => chip.selected)
                  .label
              as Text)
          .data!;

  testMetroWidgets('location is requested only after an explicit tap', (
    tester,
  ) async {
    var locationCalls = 0;
    await pumpMetro(
      tester,
      positionResolver: () async {
        locationCalls++;
        return _position();
      },
    );

    expect(locationCalls, 0);
    expect(selectedSystem(tester), 'Taipei Metro');
    expect(tester.widget<FilledButton>(locateButton()).onPressed, isNotNull);

    await tester.tap(locateButton());
    await tester.pumpAndSettle();

    expect(locationCalls, 1);
    expect(selectedSystem(tester), 'Kaohsiung Metro');
    final map = tester.widget<TransitStationMap>(
      find.byType(TransitStationMap),
    );
    expect(map.selectedPointId, 'O2');
    expect(map.points.map((point) => point.id), ['O1', 'O2']);
    expect(repository.etaRequests.last, 'KRTC/O');
    expect(repository.stationRequests, containsAll(['TRTC', 'KRTC']));
    expect(find.textContaining('Nearest station: Station O2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testMetroWidgets(
    'a later manual system selection wins over a pending location',
    (tester) async {
      final position = Completer<Position>();
      await pumpMetro(tester, positionResolver: () => position.future);

      await tester.tap(locateButton());
      await tester.pump();
      expect(tester.widget<FilledButton>(locateButton()).onPressed, isNull);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Kaohsiung Metro'));
      await tester.pumpAndSettle();
      position.complete(_position(latitude: 25.0401, longitude: 121.5101));
      await tester.pumpAndSettle();

      expect(selectedSystem(tester), 'Kaohsiung Metro');
      expect(repository.etaRequests.last, 'KRTC/R');
      expect(find.byType(TransitStationMap), findsNothing);
      expect(tester.widget<FilledButton>(locateButton()).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testMetroWidgets(
    'partial data failure keeps usable results and explains scope',
    (tester) async {
      await pumpMetro(tester);
      repository.failedSystems.add('TRTC');

      await tester.tap(locateButton());
      await tester.pumpAndSettle();

      expect(selectedSystem(tester), 'Kaohsiung Metro');
      expect(
        tester
            .widget<TransitStationMap>(find.byType(TransitStationMap))
            .selectedPointId,
        'O2',
      );
      expect(
        find.textContaining('Some metro systems could not be checked.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testMetroWidgets(
    'total data failure preserves the current selection and can retry',
    (tester) async {
      await pumpMetro(tester);
      repository.failedSystems.addAll(['TRTC', 'KRTC']);

      await tester.tap(locateButton());
      await tester.pumpAndSettle();

      expect(selectedSystem(tester), 'Taipei Metro');
      expect(
        find.text('Could not load metro stations. Please try again.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(locateButton()).onPressed, isNotNull);

      repository.failedSystems.clear();
      await tester.tap(locateButton());
      await tester.pumpAndSettle();
      expect(selectedSystem(tester), 'Kaohsiung Metro');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testMetroWidgets(
    'missing coordinates do not silently select the first station',
    (tester) async {
      await pumpMetro(tester);
      repository.missingCoordinates = true;

      await tester.tap(locateButton());
      await tester.pumpAndSettle();

      expect(selectedSystem(tester), 'Taipei Metro');
      expect(find.text('No nearby station found.'), findsOneWidget);
      expect(find.byType(TransitStationMap), findsNothing);
      expect(repository.etaRequests, ['TRTC/T']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final failure in [
    (
      error: const LocationFailure('定位服務尚未開啟。', serviceDisabled: true),
      message: 'Location services are turned off.',
    ),
    (
      error: const LocationFailure('沒有取得定位權限。', permissionDenied: true),
      message: 'Location permission was not granted.',
    ),
    (
      error: const LocationFailure('沒有取得定位權限。', deniedForever: true),
      message: 'Location permission was not granted.',
    ),
    (
      error: const LocationFailure('目前無法取得定位，請稍後再試。'),
      message:
          'Your location is unavailable right now. Please try again later.',
    ),
  ]) {
    testMetroWidgets('reports location failure: ${failure.error} '
        '(permanent: ${failure.error.deniedForever})', (tester) async {
      await pumpMetro(
        tester,
        positionResolver: () async => throw failure.error,
      );
      final initialRequests = repository.stationRequests.length;

      await tester.tap(locateButton());
      await tester.pumpAndSettle();

      expect(find.text(failure.message), findsOneWidget);
      expect(selectedSystem(tester), 'Taipei Metro');
      expect(repository.stationRequests.length, initialRequests);
      expect(tester.widget<FilledButton>(locateButton()).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testMetroWidgets('disposing while locating ignores the late result', (
    tester,
  ) async {
    final position = Completer<Position>();
    await pumpMetro(tester, positionResolver: () => position.future);
    await tester.tap(locateButton());
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    position.complete(_position());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.stationRequests, ['TRTC']);
  });
}

void testMetroWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(
    description,
    callback,
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}

Future<AppController> _buildController() async {
  const buildInfo = AppBuildInfo(
    version: '1.0.0',
    buildNumber: '1',
    gitSha: 'test',
    defaultUpdateChannel: AppUpdateChannel.release,
  );
  final client = MockClient((_) async => http.Response('{}', 200));
  final controller = AppController(
    repository: BusRepository(client: client),
    storage: StorageService(),
    analytics: await AppAnalytics.initialize(),
    buildInfo: buildInfo,
    appUpdateService: AppUpdateService(buildInfo: buildInfo, client: client),
    appUpdateInstaller: createAppUpdateInstaller(),
    authService: AuthService(),
    accountSyncService: AccountSyncService(client: client),
  );
  await controller.updateDesktopDiscordPresenceEnabled(false);
  return controller;
}

// Keep the real map widget in the integration tests without requesting tiles.
final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _TileHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TileHttpClient();
}

class _TileHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _TileRequest();

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TileRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _TileHeaders();

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  Future<HttpClientResponse> close() async => _TileResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TileHeaders implements HttpHeaders {
  @override
  void forEach(void Function(String name, List<String> values) action) {
    action('content-type', ['image/png']);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TileResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final HttpHeaders headers = _TileHeaders();

  @override
  int get statusCode => HttpStatus.ok;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _transparentPng.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_transparentPng).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
