import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/ai_reading/data/datasources/ai_reading_remote_datasource.dart';
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

AiReadingRemoteDataSource _dataSource({required int statusCode, required String body, HttpClientAdapter? adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AiReadingRemoteDataSource(ApiClient.forTesting(dio));
}

Map<String, dynamic> _successBody({int score25 = 20}) => {
  'success': true,
  'data': {
    'text': 'Reference passage.',
    'issues': <dynamic>[],
    'improved_passage': 'Reference passage.',
    'feedback': 'Nice.',
    'quick_tip': 'Keep it steady.',
    'scores': {'accuracy': 80},
    'score_25': score25,
  },
  'score_25': score25,
};

void main() {
  late String audioFilePath;

  setUpAll(() async {
    final file = File('${Directory.systemTemp.path}/ai_reading_datasource_test.m4a');
    await file.writeAsBytes([0, 1, 2, 3]);
    audioFilePath = file.path;
  });

  group('AiReadingRemoteDataSource.analyze', () {
    test('parses the result on a successful ("success": true) response', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode(_successBody(score25: 20)));

      final result = await ds.analyze(
        exerciseId: 7,
        audioFilePath: audioFilePath,
        durationSeconds: 15,
        pauseCount: 1,
        language: 'english',
        referenceText: 'The passage text.',
      );

      expect(result.text, 'Reference passage.');
      expect(result.score25, 20);
    });

    test('a rejected submission comes back as HTTP 200 with "success": false, still surfaced as a failure', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({
          'success': false,
          'error': 'Your reading does not seem to match the passage. Please try again and read the passage provided.',
        }),
      );

      await expectLater(
        ds.analyze(
          exerciseId: 7,
          audioFilePath: audioFilePath,
          durationSeconds: 5,
          pauseCount: 0,
          language: 'english',
          referenceText: 'The passage text.',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Your reading does not seem to match the passage. Please try again and read the passage provided.',
          ),
        ),
      );
    });

    test('a "success": false response with no "error" string falls back to a generic message', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'success': false}));

      await expectLater(
        ds.analyze(
          exerciseId: 7,
          audioFilePath: audioFilePath,
          durationSeconds: 5,
          pauseCount: 0,
          language: 'english',
          referenceText: 'The passage text.',
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Reading analysis failed.')),
      );
    });

    test('throws UnexpectedResponseException when the body is not a JSON object', () async {
      final ds = _dataSource(statusCode: 200, body: '"just a string"');
      await expectLater(
        ds.analyze(
          exerciseId: 7,
          audioFilePath: audioFilePath,
          durationSeconds: 5,
          pauseCount: 0,
          language: 'english',
          referenceText: 'The passage text.',
        ),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');
      await expectLater(
        ds.analyze(
          exerciseId: 7,
          audioFilePath: audioFilePath,
          durationSeconds: 5,
          pauseCount: 0,
          language: 'english',
          referenceText: 'The passage text.',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('sends an X-CSRFToken header — analyze_reading is not csrf_exempt', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode(_successBody()));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(
        exerciseId: 7,
        audioFilePath: audioFilePath,
        durationSeconds: 5,
        pauseCount: 0,
        language: 'vietnam',
        referenceText: 'The passage text.',
      );

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isTrue);
    });

    test('sends the request as multipart form data with every documented field, text/client_transcript always empty', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode(_successBody()));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(
        exerciseId: 7,
        audioFilePath: audioFilePath,
        durationSeconds: 12.5,
        pauseCount: 2,
        language: 'arabic',
        referenceText: 'The passage text.',
      );

      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['text'], '');
      expect(fields['client_transcript'], '');
      expect(fields['reference_text'], 'The passage text.');
      expect(fields['duration_seconds'], '12.5');
      expect(fields['pause_count'], '2');
      expect(fields['language'], 'arabic');
      expect(sent.files, hasLength(1));
      expect(sent.files.single.key, 'audio');
      expect(sent.files.single.value.filename, 'reading.m4a');
    });
  });
}
