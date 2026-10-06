import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/roleplay/data/datasources/roleplay_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

/// Captures the outgoing request so a test can assert on its headers/body —
/// same pattern as `AiSpeakingRemoteDataSource`'s own datasource test.
class _CapturingHttpClientAdapter implements HttpClientAdapter {
  _CapturingHttpClientAdapter({required this.statusCode, this.body = ''});

  final int statusCode;
  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    lastRequest = options;
    return ResponseBody.fromString(body, statusCode, headers: _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
}

RoleplayRemoteDataSource _dataSource({required int statusCode, required String body, HttpClientAdapter? adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return RoleplayRemoteDataSource(ApiClient.forTesting(dio));
}

void main() {
  late String audioFilePath;

  setUpAll(() async {
    final file = File('${Directory.systemTemp.path}/roleplay_datasource_test.m4a');
    await file.writeAsBytes([0, 1, 2, 3]);
    audioFilePath = file.path;
  });

  group('RoleplayRemoteDataSource.generatePractice', () {
    test('parses the result on a normal 200 response (no "success" key on this endpoint)', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({
          'topic': 'storytelling',
          'used_prompt': 'a rainy day',
          'result': {
            'title': 'A Rainy Day',
            'content_heading': 'Short story',
            'content': 'Once upon a time...',
            'follow_ups': ['Who is the main character?', 'What happened?', 'What is the lesson?'],
            'coach_tip': 'Answer in 1 or 2 clear sentences.',
          },
        }),
      );

      final content = await ds.generatePractice(topicSlug: 'storytelling', prompt: 'a rainy day', language: 'english');

      expect(content.usedPrompt, 'a rainy day');
      expect(content.title, 'A Rainy Day');
      expect(content.contentHeading, 'Short story');
      expect(content.content, 'Once upon a time...');
      expect(content.followUps, hasLength(3));
      expect(content.coachTip, 'Answer in 1 or 2 clear sentences.');
    });

    test('throws UnexpectedResponseException when "result" is missing', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'topic': 'storytelling', 'used_prompt': 'x'}));

      await expectLater(
        ds.generatePractice(topicSlug: 'storytelling', prompt: 'x', language: 'english'),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('throws UnexpectedResponseException when the body is not a JSON object', () async {
      final ds = _dataSource(statusCode: 200, body: '"just a string"');
      await expectLater(
        ds.generatePractice(topicSlug: 'storytelling', prompt: 'x', language: 'english'),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a 403 (plan denied) maps to ForbiddenException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 403, body: jsonEncode({'success': false, 'error': 'locked'}));
      await expectLater(
        ds.generatePractice(topicSlug: 'roleplay', prompt: 'x', language: 'english'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('a 400 (unknown topic / missing second character) maps via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 400, body: jsonEncode({'error': 'Unknown topic'}));
      await expectLater(
        ds.generatePractice(topicSlug: 'nonsense', prompt: 'x', language: 'english'),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('sends an X-CSRFToken header and every documented field', () async {
      final adapter = _CapturingHttpClientAdapter(
        statusCode: 200,
        body: jsonEncode({
          'topic': 'roleplay',
          'used_prompt': 'student and teacher',
          'result': {
            'title': 'Scene',
            'content_heading': 'Roleplay scene',
            'content': 'A scene.',
            'follow_ups': ['Q1', 'Q2'],
            'coach_tip': 'Tip.',
          },
        }),
      );
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.generatePractice(topicSlug: 'roleplay', prompt: 'student and teacher', language: 'vietnam');

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isTrue);
      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['topic'], 'roleplay');
      expect(fields['prompt'], 'student and teacher');
      expect(fields['language'], 'vietnam');
    });
  });

  group('RoleplayRemoteDataSource.analyze', () {
    test('parses the result on a successful ("success": true) response', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({
          'success': true,
          'data': {
            'transcript': 'My answer.',
            'issues': <dynamic>[],
            'improved_passage': 'My answer.',
            'feedback': 'Nice work.',
            'quick_tip': 'Speak slower.',
            'scores': {'overall': 70, 'fluency': 75, 'grammar': 80, 'clarity': 65},
            'duration_seconds': 42,
            'pause_count': 0,
          },
        }),
      );

      final result = await ds.analyze(
        topicLabel: 'roleplay',
        audioFilePath: audioFilePath,
        durationSeconds: 42,
        pauseCount: 0,
        language: 'english',
        referenceText: 'Roleplay scene: student and teacher.',
      );

      expect(result.transcript, 'My answer.');
      expect(result.feedback, 'Nice work.');
      expect(result.quickTip, 'Speak slower.');
      expect(result.scores['overall'], 70);
    });

    test('a rejected submission comes back as HTTP 200 with "success": false, still surfaced as a failure', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'success': false, 'error': 'No meaningful speech was detected.'}));

      await expectLater(
        ds.analyze(
          topicLabel: 'roleplay',
          audioFilePath: audioFilePath,
          durationSeconds: 1,
          pauseCount: 0,
          language: 'english',
          referenceText: 'ref',
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'No meaningful speech was detected.')),
      );
    });

    test('a "success": false response with no "error" string falls back to a generic message', () async {
      final ds = _dataSource(statusCode: 200, body: jsonEncode({'success': false}));

      await expectLater(
        ds.analyze(
          topicLabel: 'roleplay',
          audioFilePath: audioFilePath,
          durationSeconds: 1,
          pauseCount: 0,
          language: 'english',
          referenceText: 'ref',
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Roleplay analysis failed.')),
      );
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSource(statusCode: 500, body: '');
      await expectLater(
        ds.analyze(
          topicLabel: 'roleplay',
          audioFilePath: audioFilePath,
          durationSeconds: 1,
          pauseCount: 0,
          language: 'english',
          referenceText: 'ref',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('sends the request as multipart form data with every documented field, including topicLabel as "topic"', () async {
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
            'duration_seconds': 1,
            'pause_count': 0,
          },
        }),
      );
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.analyze(
        topicLabel: 'a rainy day',
        audioFilePath: audioFilePath,
        durationSeconds: 12.5,
        pauseCount: 2,
        language: 'arabic',
        referenceText: 'Describe your day.',
      );

      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isTrue);
      final sent = adapter.lastRequest!.data as FormData;
      final fields = {for (final entry in sent.fields) entry.key: entry.value};
      expect(fields['topic'], 'a rainy day');
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
