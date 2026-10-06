import 'dart:convert';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/ai_writing/data/datasources/ai_writing_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

class _CapturingHttpClientAdapter implements HttpClientAdapter {
  _CapturingHttpClientAdapter({required this.statusCode, this.body = ''});

  final int statusCode;
  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(body, statusCode, headers: _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
}

AiWritingRemoteDataSource _dataSource({required int statusCode, required String body, HttpClientAdapter? adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AiWritingRemoteDataSource(ApiClient.forTesting(dio));
}

Map<String, dynamic> _successBody({int score25 = 18}) => {
  'success': true,
  'data': {
    'text': 'Hello there.',
    'issues': <dynamic>[],
    'improved_passage': 'Hello there.',
    'feedback': 'Nice.',
    'quick_tip': 'Read it once more.',
    'scores': {'grammar': 80},
  },
  'score_25': score25,
};

void main() {
  group('AiWritingRemoteDataSource.analyze', () {
    test('parses the result on a successful ("success": true) response, score_25 from the top level', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode(_successBody(score25: 18)));

      final result = await ds.analyze(
        exerciseId: 7,
        text: 'a' * 600,
        language: 'english',
        referenceText: 'Describe your day.',
      );

      expect(result.text, 'Hello there.');
      expect(result.score25, 18);
      expect(result.quickTip, 'Read it once more.');
    });

    test('a rejected submission comes back as HTTP 200 with "success": false, still surfaced as a failure', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'success': false, 'error': 'Please write at least 500 characters before analyzing. Spaces are not counted.'}),
      );

      await expectLater(
        ds.analyze(exerciseId: 7, text: 'too short', language: 'english', referenceText: 'Topic'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Please write at least 500 characters before analyzing. Spaces are not counted.',
          ),
        ),
      );
    });

    test('a "success": false response with no "error" string falls back to a generic message', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'success': false}));

      await expectLater(
        ds.analyze(exerciseId: 7, text: 'a' * 600, language: 'english', referenceText: 'Topic'),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Writing analysis failed.')),
      );
    });

    test('throws UnexpectedResponseException when the body is not a JSON object', () async {
      final ds = _dataSource(statusCode: 200, body: '"just a string"');
      await expectLater(
        ds.analyze(exerciseId: 7, text: 'a' * 600, language: 'english', referenceText: 'Topic'),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a 403 (module access denied) maps to ForbiddenException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 403, body: '');
      await expectLater(
        ds.analyze(exerciseId: 7, text: 'a' * 600, language: 'english', referenceText: 'Topic'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');
      await expectLater(
        ds.analyze(exerciseId: 7, text: 'a' * 600, language: 'english', referenceText: 'Topic'),
        throwsA(isA<ServerException>()),
      );
    });

    test('sends an X-CSRFToken header — analyze_writing is not csrf_exempt', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode(_successBody()));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(exerciseId: 7, text: 'a' * 600, language: 'vietnam', referenceText: 'Topic');

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isTrue);
    });

    test('sends text/language/reference_text as multipart fields, and omits previous_improved_passage when null', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode(_successBody()));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(exerciseId: 7, text: 'a' * 600, language: 'arabic', referenceText: 'My topic');

      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['text'], 'a' * 600);
      expect(fields['language'], 'arabic');
      expect(fields['reference_text'], 'My topic');
      expect(fields.containsKey('previous_improved_passage'), isFalse);
      expect(fields.containsKey('module'), isFalse); // confirmed unused by the view, not sent
    });

    test('sends previous_improved_passage only when non-null and non-empty', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode(_successBody()));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(
        exerciseId: 7,
        text: 'a' * 600,
        language: 'english',
        referenceText: 'My topic',
        previousImprovedPassage: 'A prior improved passage.',
      );

      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['previous_improved_passage'], 'A prior improved passage.');
    });

    test('omits previous_improved_passage when it is an empty string', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode(_successBody()));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(exerciseId: 7, text: 'a' * 600, language: 'english', referenceText: 'Topic', previousImprovedPassage: '');

      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields.containsKey('previous_improved_passage'), isFalse);
    });
  });
}
