import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwanbus_flutter/core/auth_token_store.dart';
import 'package:taiwanbus_flutter/core/feedback_service.dart';
import 'package:taiwanbus_flutter/core/feedback_models.dart';

void main() {
  tearDown(() {
    AuthTokenStore.token = null;
  });

  test('submitFeedback posts payload and parses success response', () async {
    AuthTokenStore.token = 'test-token';
    final service = FeedbackService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/feedback');
        expect(
          request.headers['Authorization'] ?? request.headers['authorization'],
          'Bearer test-token',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Bug report');
        expect(body['content'], 'Something broke');
        expect(body.keys, unorderedEquals(['title', 'content']));
        return http.Response(
          jsonEncode({
            'ok': true,
            'feedback_id': '12345',
            'created_at': 1716000000,
          }),
          201,
        );
      }),
    );

    final result = await service.submitFeedback(
      title: 'Bug report',
      content: 'Something broke',
    );

    expect(result.feedbackId, '12345');
    expect(result.createdAt, 1716000000);
  });

  test(
    'submitFeedback sends trimmed optional details and explicit diagnostics',
    () async {
      const diagnostics = FeedbackDiagnostics(
        appVersion: '1.2.3',
        buildNumber: '45',
        commitHash: 'abcdef0',
        platform: 'web',
        locale: 'zh-TW',
        screenWidth: 390,
        screenHeight: 844,
        textScale: 1.2,
        brightness: 'dark',
      );
      final service = FeedbackService(
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'title': 'Bug',
            'content': 'Details',
            'category': 'data',
            'route_context': 'Taipei 307',
            'contact': 'user@example.test',
            'diagnostics': {
              'app_version': '1.2.3',
              'build_number': '45',
              'commit_hash': 'abcdef0',
              'platform': 'web',
              'locale': 'zh-TW',
              'screen_width': 390,
              'screen_height': 844,
              'text_scale': 1.2,
              'brightness': 'dark',
            },
          });
          return http.Response('{"feedback_id":"1","created_at":1}', 201);
        }),
      );
      addTearDown(service.dispose);
      await service.submitFeedback(
        title: ' Bug ',
        content: ' Details ',
        category: FeedbackCategory.data,
        routeContext: ' Taipei 307 ',
        contact: ' user@example.test ',
        diagnostics: diagnostics,
      );
    },
  );

  test('blank optional fields are omitted', () async {
    final service = FeedbackService(
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {'title': 'A', 'content': 'B'});
        return http.Response('{"feedback_id":"1","created_at":1}', 201);
      }),
    );
    addTearDown(service.dispose);
    await service.submitFeedback(
      title: 'A',
      content: 'B',
      routeContext: '  ',
      contact: '\n',
    );
  });

  test(
    'optional fields reject overlong values before making a request',
    () async {
      var requests = 0;
      final service = FeedbackService(
        client: MockClient((request) async {
          requests++;
          return http.Response('{}', 201);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.submitFeedback(
          title: 'A',
          content: 'B',
          routeContext: 'x' * 201,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.submitFeedback(title: 'A', content: 'B', contact: 'x' * 201),
        throwsArgumentError,
      );
      expect(requests, 0);
      await service.submitFeedback(
        title: 'A',
        content: 'B',
        routeContext: 'x' * 200,
        contact: 'x' * 200,
      );
      expect(requests, 1);
    },
  );

  test('submitFeedback surfaces rate-limit details', () async {
    final service = FeedbackService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'Feedback submissions are limited to 1 per minute.',
          }),
          429,
          headers: {'retry-after': '42'},
        );
      }),
    );

    expect(
      () => service.submitFeedback(title: 'A', content: 'B'),
      throwsA(
        isA<FeedbackRateLimitException>()
            .having((error) => error.message, 'message', '你已受到速率限制。')
            .having(
              (error) => error.retryAfterSeconds,
              'retryAfterSeconds',
              42,
            ),
      ),
    );
  });
}
