import 'dart:convert';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/ai_listening/data/datasources/ai_listening_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};
const _htmlHeaders = {
  'content-type': ['text/html'],
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

AiListeningRemoteDataSource _dataSource({required int statusCode, required String body, HttpClientAdapter? adapter, Map<String, List<String>>? headers}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers ?? _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AiListeningRemoteDataSource(ApiClient.forTesting(dio));
}

const _listeningPageHtml = '''
<html><body>
<script type="application/json" id="listening-config">
{"analyzeEndpoint": "/activities/exercise/7/analyze/listening/", "lessonsPath": "/activities/exercise/7/", "attemptToken": "abc123"}
</script>
</body></html>
''';

Map<String, dynamic> _successBody({int score25 = 18, int match = 70}) => {
  'success': true,
  'data': {
    'text': 'Hello there.',
    'issues': <dynamic>[],
    'improved_passage': 'Hello there.',
    'feedback': 'Nice.',
    'quick_tip': 'tip',
    'scores': {'fluency': 80},
    'score_25': score25,
    'content_match_percent': match,
  },
};

void main() {
  group('AiListeningRemoteDataSource.fetchAttemptToken', () {
    test('extracts the attempt token from the exercise_detail HTML page', () async {
      final ds = _dataSource(statusCode: 200, body: _listeningPageHtml, headers: _htmlHeaders);
      final token = await ds.fetchAttemptToken(7);
      expect(token, 'abc123');
    });

    test('throws ValidationException when the page has no listening-config blob (e.g. locked-activity redirect)', () async {
      final ds = _dataSource(statusCode: 200, body: '<html><body>Activities</body></html>', headers: _htmlHeaders);
      await expectLater(ds.fetchAttemptToken(7), throwsA(isA<ValidationException>()));
    });

    test('a server error while fetching the page maps to a typed AppException', () async {
      final ds = _dataSource(statusCode: 500, body: '', headers: _htmlHeaders);
      await expectLater(ds.fetchAttemptToken(7), throwsA(isA<ServerException>()));
    });

    test('a 401 while fetching the page maps to UnauthorizedException', () async {
      final ds = _dataSource(statusCode: 401, body: '', headers: _htmlHeaders);
      await expectLater(ds.fetchAttemptToken(7), throwsA(isA<UnauthorizedException>()));
    });
  });

  group('AiListeningRemoteDataSource.analyze', () {
    test('parses the result on a successful ("success": true) response, score_25/content_match_percent from "data"', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode(_successBody(score25: 18, match: 70)));

      final result = await ds.analyze(
        exerciseId: 7,
        text: 'My summary of the story here.',
        referenceText: 'The story text.',
        durationSeconds: 15,
        pauseCount: 1,
        attemptToken: 'abc123',
        language: 'english',
      );

      expect(result.text, 'Hello there.');
      expect(result.score25, 18);
      expect(result.contentMatchPercent, 70);
    });

    test('a rejected submission (200, "success": false) is surfaced as a failure', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'success': false, 'error': 'Please provide a longer listening response.'}),
      );

      await expectLater(
        ds.analyze(
          exerciseId: 7,
          text: 'too short',
          referenceText: 'story',
          durationSeconds: 5,
          pauseCount: 0,
          attemptToken: 'abc123',
          language: 'english',
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Please provide a longer listening response.')),
      );
    });

    test('a missing/reused attempt_token returns HTTP 409, mapped as a typed AppException', () async {
      final ds = _dataSource(
        statusCode: 409,
        body: jsonEncode({'success': false, 'error': 'This attempt has already been evaluated.'}),
      );

      await expectLater(
        ds.analyze(
          exerciseId: 7,
          text: 'a valid enough summary text here',
          referenceText: 'story',
          durationSeconds: 10,
          pauseCount: 0,
          attemptToken: 'reused-token',
          language: 'english',
        ),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('throws UnexpectedResponseException when the body is not a JSON object', () async {
      final ds = _dataSource(statusCode: 200, body: '"just a string"');
      await expectLater(
        ds.analyze(
          exerciseId: 7,
          text: 'a valid enough summary text here',
          referenceText: 'story',
          durationSeconds: 10,
          pauseCount: 0,
          attemptToken: 'abc123',
          language: 'english',
        ),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('sends an X-CSRFToken header — analyze_listening is not csrf_exempt', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode(_successBody()));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(
        exerciseId: 7,
        text: 'a valid enough summary text here',
        referenceText: 'story',
        durationSeconds: 10,
        pauseCount: 0,
        attemptToken: 'abc123',
        language: 'vietnam',
      );

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isTrue);
    });

    test('sends text/reference_text/duration_seconds/pause_count/attempt_token/language as multipart fields', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode(_successBody()));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(
        exerciseId: 7,
        text: 'a valid enough summary text here',
        referenceText: 'The reference story.',
        durationSeconds: 12,
        pauseCount: 2,
        attemptToken: 'abc123',
        language: 'arabic',
      );

      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['text'], 'a valid enough summary text here');
      expect(fields['reference_text'], 'The reference story.');
      expect(fields['duration_seconds'], '12');
      expect(fields['pause_count'], '2');
      expect(fields['attempt_token'], 'abc123');
      expect(fields['language'], 'arabic');
    });
  });
}
