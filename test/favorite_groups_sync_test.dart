import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taiwanbus_flutter/core/account_sync_models.dart';
import 'package:taiwanbus_flutter/core/account_sync_service.dart';
import 'package:taiwanbus_flutter/core/app_analytics.dart';
import 'package:taiwanbus_flutter/core/app_build_info.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/app_launch_service.dart';
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('account sync preserves a newly created empty favorite group', () async {
    final buildInfo = AppBuildInfo(
      version: '1.0.0',
      buildNumber: '1',
      gitSha: 'test',
      defaultUpdateChannel: AppUpdateChannel.release,
    );
    final storage = StorageService();
    await storage.saveAccountSyncLocalState(
      'test-account',
      const AccountSyncLocalState(
        syncEnabled: null,
        favorites: AccountSyncNamespaceLocalState(),
        preferences: AccountSyncNamespaceLocalState(
          lastSuccessfulSyncAtMs: 1,
          lastSyncedServerRevision: 1,
        ),
      ),
    );
    final syncService = _FakeAccountSyncService();
    final controller = AppController(
      repository: BusRepository(),
      storage: storage,
      analytics: await AppAnalytics.initialize(),
      buildInfo: buildInfo,
      appUpdateService: AppUpdateService(buildInfo: buildInfo),
      appUpdateInstaller: createAppUpdateInstaller(),
      authService: _FakeAuthService(),
      accountSyncService: syncService,
    );
    addTearDown(controller.dispose);

    await controller.addFavoriteGroup('New group');
    await controller.completeAuthCallback(
      const AppLaunchAction(
        target: AppLaunchTarget.authCallback,
        authToken: 'test-token',
        authAccountId: 'test-account',
        authDeviceId: 'test-device',
        authRole: 'user',
        authProvider: 'test',
        authDisplayName: 'Test User',
      ),
    );

    await controller.syncAllAccountData();

    expect(syncService.favoritePayload, {
      'groupKinds': {'New group': 'boarding'},
      'groups': {'New group': <dynamic>[]},
    });
    expect(syncService.favoriteSchemaVersion, 2);
    expect(syncService.favoriteRestoreCount, 0);
    expect(controller.favoriteGroupNames, ['Old group', 'New group']);
    expect(controller.favoritesInGroup('Old group'), hasLength(1));
    expect(controller.favoritesInGroup('New group'), isEmpty);
  });

  test(
    'typed favorite groups enforce type, duplicate, and total limits',
    () async {
      final storage = StorageService();
      final controller = AppController(
        repository: BusRepository(),
        storage: storage,
        analytics: await AppAnalytics.initialize(),
        buildInfo: AppBuildInfo(
          version: '1.0.0',
          buildNumber: '1',
          gitSha: 'test',
          defaultUpdateChannel: AppUpdateChannel.release,
        ),
        appUpdateService: AppUpdateService(
          buildInfo: AppBuildInfo(
            version: '1.0.0',
            buildNumber: '1',
            gitSha: 'test',
            defaultUpdateChannel: AppUpdateChannel.release,
          ),
        ),
        appUpdateInstaller: createAppUpdateInstaller(),
        authService: _FakeAuthService(),
        accountSyncService: _FakeAccountSyncService(),
      );
      addTearDown(controller.dispose);

      await controller.addFavoriteGroup(
        'Routes',
        kind: FavoriteGroupKind.route,
      );
      await controller.addFavoriteGroup('Mixed', kind: FavoriteGroupKind.mixed);

      const station = FavoriteStation(
        provider: BusProvider.tpe,
        stationId: 'TPE-STATION',
        stationName: '臺北車站',
      );
      expect(
        controller.addFavoriteItem(station, groupName: 'Routes'),
        throwsA(isA<FavoriteGroupTypeMismatchException>()),
      );

      for (var index = 0; index < 25; index += 1) {
        await controller.addFavoriteItem(
          FavoriteRoute(
            provider: BusProvider.tpe,
            routeKey: index,
            routeId: 'TPE-$index',
            routeName: '$index',
          ),
          groupName: 'Routes',
        );
      }
      await controller.addFavoriteItem(
        const FavoriteRoute(
          provider: BusProvider.tpe,
          routeKey: 0,
          routeId: 'TPE-0',
          routeName: 'updated',
        ),
        groupName: 'Routes',
      );

      expect(controller.favoritesInGroup('Routes'), hasLength(25));
      expect(
        (controller.favoritesInGroup('Routes').first as FavoriteRoute)
            .routeName,
        'updated',
      );
      expect(
        controller.addFavoriteItem(station, groupName: 'Mixed'),
        throwsA(isA<FavoriteGroupFullException>()),
      );
    },
  );

  test(
    'route history sync is opt-in, preserves other devices, and removes its own bucket when disabled',
    () async {
      final storage = StorageService();
      final syncService = _FakeAccountSyncService(
        remotePreferences: const {
          'routeHistory': {
            'version': 1,
            'devices': {
              'remote-device': {
                'modifiedAtMs': 2,
                'history': [
                  {
                    'provider': 'nwt',
                    'routeKey': 99,
                    'routeName': '遠端路線',
                    'timestampMs': 2,
                  },
                  {
                    'provider': 7,
                    'routeKey': 100,
                    'routeName': '損壞資料',
                    'timestampMs': 3,
                  },
                ],
                'routeUsageProfiles': [
                  {
                    'provider': 'nwt',
                    'routeKey': 100,
                    'routeName': 7,
                    'totalOpens': 1,
                    'lastOpenedAtMs': 3,
                  },
                ],
              },
            },
          },
        },
      );
      final buildInfo = AppBuildInfo(
        version: '1.0.0',
        buildNumber: '1',
        gitSha: 'test',
        defaultUpdateChannel: AppUpdateChannel.release,
      );
      final controller = AppController(
        repository: BusRepository(),
        storage: storage,
        analytics: await AppAnalytics.initialize(),
        buildInfo: buildInfo,
        appUpdateService: AppUpdateService(buildInfo: buildInfo),
        appUpdateInstaller: createAppUpdateInstaller(),
        authService: _FakeAuthService(),
        accountSyncService: syncService,
      );
      addTearDown(controller.dispose);

      await controller.completeAuthCallback(
        const AppLaunchAction(
          target: AppLaunchTarget.authCallback,
          authToken: 'test-token',
          authAccountId: 'test-account',
          authDeviceId: 'test-device',
          authRole: 'user',
          authProvider: 'test',
          authDisplayName: 'Test User',
        ),
      );
      expect(controller.routeHistorySyncEnabled, isFalse);

      await controller.addHistoryEntry(
        const RouteSummary(
          sourceProvider: 'nwt',
          hashMd5: '',
          routeKey: 12,
          routeId: '12',
          routeName: '本機路線',
          officialRouteName: '本機路線',
          description: '',
          category: '',
          sequence: 0,
          rtrip: 0,
        ),
        provider: BusProvider.nwt,
        pathId: 0,
        pathName: '往市區',
      );
      await controller.setRouteHistorySyncEnabled(true);
      await controller.recordRouteSelection(
        provider: BusProvider.nwt,
        routeKey: 12,
        routeName: '本機路線',
        selectedAt: DateTime.now(),
        pathId: 0,
      );
      await controller.recordRouteSelection(
        provider: BusProvider.nwt,
        routeKey: 12,
        routeName: '本機路線',
        selectedAt: DateTime.now(),
        pathId: 1,
      );
      expect(
        controller.routeUsageProfiles.map((profile) => profile.pathId),
        containsAll(<int?>[0, 1]),
      );
      expect(syncService.preferencePayload, isNull);

      await controller.setAccountSyncEnabled(true);

      final enabledDevices =
          (syncService.preferencePayload!['routeHistory'] as Map)['devices']
              as Map;
      expect(
        (syncService.preferencePayload!['routeHistory'] as Map)['version'],
        2,
      );
      expect(
        enabledDevices.keys,
        containsAll(['remote-device', 'test-device']),
      );
      expect(
        controller.history.map((entry) => entry.routeKey),
        containsAll([12, 99]),
      );

      await controller.setRouteHistorySyncEnabled(false);

      final disabledDevices =
          (syncService.preferencePayload!['routeHistory'] as Map)['devices']
              as Map;
      expect(disabledDevices.keys, contains('remote-device'));
      expect(disabledDevices.keys, isNot(contains('test-device')));
      expect(controller.routeHistorySyncEnabled, isFalse);
      final localState = await storage.loadAccountSyncLocalState(
        'test-account',
      );
      expect(localState.routeHistoryDevicePayload, isNotNull);

      await controller.setRouteHistorySyncEnabled(true);
      final reenabledDevices =
          (syncService.preferencePayload!['routeHistory'] as Map)['devices']
              as Map;
      final ownProfiles =
          (reenabledDevices['test-device'] as Map)['routeUsageProfiles']
              as List;
      expect(ownProfiles, hasLength(2));
      expect(
        ownProfiles.map((profile) => (profile as Map)['totalSelections']),
        everyElement(1),
      );
      expect(
        ownProfiles.map((profile) => (profile as Map)['pathId']),
        containsAll([0, 1]),
      );

      await controller.setAccountSyncEnabled(false);
      syncService.failPreferenceWrites = true;
      await expectLater(
        controller.setRouteHistorySyncEnabled(false),
        throwsStateError,
      );
      expect(controller.routeHistorySyncEnabled, isFalse);
      final pendingState = await storage.loadAccountSyncLocalState(
        'test-account',
      );
      expect(pendingState.routeHistoryDeletionPending, isTrue);

      syncService.failPreferenceWrites = false;
      await controller.setRouteHistorySyncEnabled(false);
      final optOutDevices =
          (syncService.preferencePayload!['routeHistory'] as Map)['devices']
              as Map;
      expect(optOutDevices.keys, isNot(contains('test-device')));
      expect(controller.routeHistorySyncEnabled, isFalse);
      final deletedState = await storage.loadAccountSyncLocalState(
        'test-account',
      );
      expect(deletedState.routeHistoryDeletionPending, isFalse);

      await controller.logoutAuth();
      expect(controller.history.map((entry) => entry.routeKey), [12]);
    },
  );
}

class _FakeAuthService extends AuthService {
  AuthSession? _fakeSession;

  @override
  AuthSession? get session => _fakeSession;

  @override
  Future<void> completeCallback({
    required String token,
    required String accountId,
    required String deviceId,
    required String role,
    required String provider,
    required String displayName,
  }) async {
    _fakeSession = AuthSession(
      token: token,
      accountId: accountId,
      deviceId: deviceId,
      role: role,
      provider: provider,
      displayName: displayName,
    );
  }

  @override
  Future<AuthAccount> fetchAccount() async {
    return const AuthAccount(
      accountId: 'test-account',
      deviceId: 'test-device',
      role: 'user',
      device: null,
      identities: [],
    );
  }
}

class _FakeAccountSyncService extends AccountSyncService {
  _FakeAccountSyncService({this.remotePreferences = const {}});

  static const _oldFavorite = {
    'provider': 'tpe',
    'routeKey': 123,
    'pathId': 0,
    'stopId': 456,
  };

  Map<String, dynamic>? favoritePayload;
  Map<String, dynamic>? preferencePayload;
  int? favoriteSchemaVersion;
  int favoriteRestoreCount = 0;
  bool failPreferenceWrites = false;
  final Map<String, dynamic> remotePreferences;

  @override
  Future<AccountSyncSummary> fetchSummary() async {
    return AccountSyncSummary(
      serverTime: DateTime.utc(2026, 7, 14),
      documents: {
        AccountSyncNamespace.favorites: _document(
          AccountSyncNamespace.favorites,
          payload: const {
            'groups': {
              'Old group': [_oldFavorite],
            },
          },
        ),
        AccountSyncNamespace.preferences: _document(
          AccountSyncNamespace.preferences,
          payload: remotePreferences,
        ),
      },
    );
  }

  @override
  Future<AccountSyncDocument> fetchDocument(
    AccountSyncNamespace namespace,
  ) async {
    if (namespace == AccountSyncNamespace.favorites) {
      favoriteRestoreCount += 1;
    }
    return _document(namespace, payload: const {'groups': {}});
  }

  @override
  Future<AccountSyncWriteResult> upsertDocument({
    required AccountSyncNamespace namespace,
    required Map<String, dynamic> payload,
    required DateTime clientModifiedAt,
    required int schemaVersion,
    AccountSyncConflictPolicy conflictPolicy = AccountSyncConflictPolicy.abort,
    int? baseRevision,
    String? baseEtag,
  }) async {
    if (namespace == AccountSyncNamespace.favorites) {
      favoritePayload = payload;
      favoriteSchemaVersion = schemaVersion;
    } else {
      if (failPreferenceWrites) {
        throw StateError('preference write failed');
      }
      preferencePayload = payload;
    }
    final documentPayload = namespace == AccountSyncNamespace.favorites
        ? {
            'groupKinds': {
              'Old group': 'boarding',
              ...((payload['groupKinds'] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              )),
            },
            'groups': {
              'Old group': [_oldFavorite],
              ...((payload['groups'] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              )),
            },
          }
        : payload;
    return AccountSyncWriteResult(
      status: 'updated',
      conflictPolicy: conflictPolicy,
      document: _document(namespace, payload: documentPayload),
    );
  }

  AccountSyncDocument _document(
    AccountSyncNamespace namespace, {
    required Map<String, dynamic> payload,
  }) {
    final timestamp = DateTime.utc(2026, 7, 14);
    return AccountSyncDocument(
      namespace: namespace,
      hasData: true,
      schemaVersion: namespace == AccountSyncNamespace.favorites ? 2 : 1,
      revision: 1,
      etag: 'test-etag',
      updatedAt: timestamp,
      lastSyncedAt: timestamp,
      lastClientModifiedAt: timestamp,
      payloadSizeBytes: 1,
      payload: payload,
    );
  }
}
