import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwanbus_flutter/app/bus_app.dart';
import 'package:taiwanbus_flutter/core/account_sync_service.dart';
import 'package:taiwanbus_flutter/core/app_analytics.dart';
import 'package:taiwanbus_flutter/core/app_build_info.dart';
import 'package:taiwanbus_flutter/core/app_controller.dart';
import 'package:taiwanbus_flutter/core/app_update_installer.dart';
import 'package:taiwanbus_flutter/core/app_update_service.dart';
import 'package:taiwanbus_flutter/core/auth_service.dart';
import 'package:taiwanbus_flutter/core/bus_repository.dart';
import 'package:taiwanbus_flutter/core/feedback_service.dart';
import 'package:taiwanbus_flutter/core/models.dart';
import 'package:taiwanbus_flutter/core/storage_service.dart';
import 'package:taiwanbus_flutter/l10n/app_localizations.dart';
import 'package:taiwanbus_flutter/screens/feedback_screen.dart';

const _buildInfo = AppBuildInfo(
  version: '1.2.3',
  buildNumber: '45',
  gitSha: 'abcdef0',
  defaultUpdateChannel: AppUpdateChannel.release,
);

class _Controller extends AppController {
  _Controller({this.signedIn = true})
    : super(
        repository: BusRepository(),
        storage: StorageService(),
        analytics: AppAnalytics.deferred(),
        buildInfo: _buildInfo,
        appUpdateService: AppUpdateService(buildInfo: _buildInfo),
        appUpdateInstaller: createAppUpdateInstaller(),
        authService: AuthService(),
        accountSyncService: AccountSyncService(),
      );

  final bool signedIn;
  @override
  bool get isAuthenticated => signedIn;
}

void main() {
  Future<void> open(
    WidgetTester tester,
    FeedbackService service, {
    bool signedIn = true,
  }) async {
    final controller = _Controller(signedIn: signedIn);
    addTearDown(controller.dispose);
    addTearDown(service.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppControllerScope(
                    controller: controller,
                    child: FeedbackScreen(feedbackService: service),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> fillRequired(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Arrival issue');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Bus did not arrive',
    );
    tester.testTextInput.hide();
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.ensureVisible(find.text('更多資訊（選填）'));
    await tester.tap(find.text('更多資訊（選填）'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('送出回饋'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('送出回饋'));
    await tester.pumpAndSettle();
  }

  testWidgets('signed-out users still need to sign in', (tester) async {
    await open(
      tester,
      FeedbackService(
        client: MockClient((_) async => http.Response('{}', 500)),
      ),
      signedIn: false,
    );
    expect(find.text('請先登入'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('optional information is not required or sent by default', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await open(
      tester,
      FeedbackService(
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"feedback_id":"1","created_at":1}', 201);
        }),
      ),
    );
    await fillRequired(tester);
    await submit(tester);
    expect(sent, {'title': 'Arrival issue', 'content': 'Bus did not arrive'});
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('selected details and previewed diagnostics reach the API', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await open(
      tester,
      FeedbackService(
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"feedback_id":"1","created_at":1}', 201);
        }),
      ),
    );
    await fillRequired(tester);
    await expand(tester);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交通資料錯誤').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), ' Taipei 307 ');
    await tester.enterText(
      find.byType(TextFormField).at(3),
      ' rider@example.test ',
    );
    tester.testTextInput.hide();
    final toggle = find.byType(SwitchListTile);
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.textContaining('App 版本: 1.2.3+45'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Collapsing the section must retain the explicitly chosen values.
    await expand(tester);
    await submit(tester);
    expect(sent!['category'], 'data');
    expect(sent!['route_context'], 'Taipei 307');
    expect(sent!['contact'], 'rider@example.test');
    expect(sent!['diagnostics'], {
      'app_version': '1.2.3',
      'build_number': '45',
      'commit_hash': 'abcdef0',
      'platform': 'android',
      'locale': 'zh-TW',
      'screen_width': 390,
      'screen_height': 844,
      'text_scale': 1.0,
      'brightness': 'light',
    });
  });

  testWidgets('turning diagnostics off removes it from submission', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await open(
      tester,
      FeedbackService(
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"feedback_id":"1","created_at":1}', 201);
        }),
      ),
    );
    await fillRequired(tester);
    await expand(tester);
    final toggle = find.byType(SwitchListTile);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);
    await submit(tester);
    expect(sent!.containsKey('diagnostics'), isFalse);
  });

  testWidgets('failed submissions retain optional input for retry', (
    tester,
  ) async {
    var attempts = 0;
    await open(
      tester,
      FeedbackService(
        client: MockClient((request) async {
          attempts++;
          expect(jsonDecode(request.body)['contact'], 'rider@example.test');
          return attempts == 1
              ? http.Response('{}', 500)
              : http.Response('{"feedback_id":"1","created_at":1}', 201);
        }),
      ),
    );
    await fillRequired(tester);
    await expand(tester);
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'rider@example.test',
    );
    tester.testTextInput.hide();
    await submit(tester);
    expect(find.text('rider@example.test'), findsOneWidget);
    await submit(tester);
    expect(attempts, 2);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets(
    'leaving during submission does not access disposed form fields',
    (tester) async {
      final pending = Completer<http.Response>();
      await open(
        tester,
        FeedbackService(client: MockClient((_) => pending.future)),
      );
      await fillRequired(tester);
      await tester.ensureVisible(find.text('送出回饋'));
      await tester.tap(find.text('送出回饋'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      pending.complete(
        http.Response('{"feedback_id":"1","created_at":1}', 201),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
