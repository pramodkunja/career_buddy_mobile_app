import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/ai_speaking/data/datasources/ai_speaking_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

/// Captures the outgoing request so a test can assert on its headers/body —
/// see `MockQuizRemoteDataSource`'s equivalent in
/// `test/features/mock_tests/data/mock_quiz_remote_datasource_test.dart`.
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

AiSpeakingRemoteDataSource _dataSource({required int statusCode, required String body, HttpClientAdapter? adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AiSpeakingRemoteDataSource(ApiClient.forTesting(dio));
}

void main() {
  late String audioFilePath;

  setUpAll(() async {
    final file = File('${Directory.systemTemp.path}/ai_speaking_datasource_test.m4a');
    await file.writeAsBytes([0, 1, 2, 3]);
    audioFilePath = file.path;
  });

  group('AiSpeakingRemoteDataSource.analyze', () {
    test('parses the result on a successful ("success": true) response', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({
          'success': true,
          'data': {
            'transcript': 'Hello there.',
            'issues': <dynamic>[],
            'improved_passage': 'Hello there.',
            'feedback': 'Nice.',
            'scores': {'fluency': 80},
            'score_25': 18,
            'duration_seconds': 12,
            'pause_count': 1,
          },
        }),
      );

      final result = await ds.analyze(
        exerciseId: 7,
        audioFilePath: audioFilePath,
        durationSeconds: 12,
        pauseCount: 1,
        language: 'english',
        referenceText: 'Describe your day.',
      );

      expect(result.transcript, 'Hello there.');
      expect(result.score25, 18);
    });

    test('a rejected submission comes back as HTTP 200 with "success": false, still surfaced as a failure', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'success': false, 'error': 'No meaningful speech was detected.'}),
      );

      await expectLater(
        ds.analyze(
          exerciseId: 7,
          audioFilePath: audioFilePath,
          durationSeconds: 1,
          pauseCount: 0,
          language: 'english',
          referenceText: 'Describe your day.',
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'No meaningful speech was detected.')),
      );
    });

    test('a "success": false response with no "error" string falls back to a generic message', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'success': false}));

      await expectLater(
        ds.analyze(
          exerciseId: 7,
          audioFilePath: audioFilePath,
          durationSeconds: 1,
          pauseCount: 0,
          language: 'english',
          referenceText: 'Describe your day.',
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Speaking analysis failed.')),
      );
    });

    test('throws UnexpectedResponseException when the body is not a JSON object', () async {
      final ds = _dataSource(statusCode: 200, body: '"just a string"');
      await expectLater(
        ds.analyze(
          exerciseId: 7,
          audioFilePath: audioFilePath,
          durationSeconds: 1,
          pauseCount: 0,
          language: 'english',
          referenceText: 'Describe your day.',
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
          durationSeconds: 1,
          pauseCount: 0,
          language: 'english',
          referenceText: 'Describe your day.',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('sends an X-CSRFToken header — unlike the csrf_exempt mock-quiz family, analyze_speaking is not exempt', () async {
      final adapter = _CapturingHttpClientAdapter(
        statusCode: 200,
        body: jsonEncode({
          'success': true,
          'data': {
            'transcript': 'Hi',
            'issues': <dynamic>[],
            'improved_passage': 'Hi',
            'feedback': null,
            'scores': <String, dynamic>{},
            'score_25': 0,
            'duration_seconds': 1,
            'pause_count': 0,
          },
        }),
      );
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(
        exerciseId: 7,
        audioFilePath: audioFilePath,
        durationSeconds: 1,
        pauseCount: 0,
        language: 'vietnam',
        referenceText: 'Describe your day.',
      );

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isTrue);
    });

    test('sends the request as multipart form data with every documented field', () async {
      final adapter = _CapturingHttpClientAdapter(
        statusCode: 200,
        body: jsonEncode({
          'success': true,
          'data': {
            'transcript': 'Hi',
            'issues': <dynamic>[],
            'improved_passage': 'Hi',
            'feedback': null,
            'scores': <String, dynamic>{},
            'score_25': 0,
            'duration_seconds': 1,
            'pause_count': 0,
          },
        }),
      );
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(
        exerciseId: 7,
        audioFilePath: audioFilePath,
        durationSeconds: 12.5,
        pauseCount: 2,
        language: 'arabic',
        referenceText: 'Describe your day.',
      );

      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['duration_seconds'], '12.5');
      expect(fields['pause_count'], '2');
      expect(fields['client_transcript'], '');
      expect(fields['language'], 'arabic');
      expect(fields['reference_text'], 'Describe your day.');
      expect(sent.files, hasLength(1));
      expect(sent.files.single.key, 'audio');
      expect(sent.files.single.value.filename, 'recording.m4a');
    });
  });
}
