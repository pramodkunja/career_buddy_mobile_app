import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_listening/data/datasources/ai_listening_remote_datasource.dart';
import 'package:career_buddy_lms/features/ai_listening/data/repositories/ai_listening_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};
const _htmlHeaders = {
  'content-type': ['text/html'],
};

const _listeningPageHtml = '''
<script type="application/json" id="listening-config">
{"analyzeEndpoint": "/x", "lessonsPath": "/y", "attemptToken": "tok-1"}
</script>
''';

const _validBody = {
  'success': true,
  'data': {
    'text': 'Hello there.',
    'issues': <dynamic>[],
    'improved_passage': 'Hello there.',
    'feedback': 'Nice.',
    'quick_tip': 'tip',
    'scores': {'fluency': 80},
    'score_25': 18,
    'content_match_percent': 70,
  },
};

AiListeningRepositoryImpl _repoReturning({
  required int statusCode,
  required String body,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AiListeningRepositoryImpl(AiListeningRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  group('AiListeningRepositoryImpl.fetchAttemptToken', () {
    test('returns Success with the extracted token', () async {
      final repo = _repoReturning(statusCode: 200, body: _listeningPageHtml, headers: _htmlHeaders);
      final result = await repo.fetchAttemptToken(7);
      expect(result, isA<Success>());
      expect((result as Success).value, 'tok-1');
    });

    test('returns Failed with UnauthorizedFailure for an anonymous request', () async {
      final repo = _repoReturning(statusCode: 401, body: '', headers: _htmlHeaders);
      final result = await repo.fetchAttemptToken(7);
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
    });
  });

  group('AiListeningRepositoryImpl.analyze', () {
    Future<Result<dynamic>> analyze(AiListeningRepositoryImpl repo) => repo.analyze(
      exerciseId: 7,
      text: 'a valid enough summary text here',
      referenceText: 'story',
      durationSeconds: 10,
      pauseCount: 0,
      attemptToken: 'tok-1',
      language: 'english',
    );

    test('returns Success with the parsed result on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: jsonEncode(_validBody), headers: _jsonHeaders);
      final result = await analyze(repo);
      expect(result, isA<Success>());
      expect((result as Success).value.score25, 18);
    });

    test('returns Failed with ValidationFailure carrying the server\'s message for a rejected submission', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'success': false, 'error': 'Please provide a longer listening response.'}),
        headers: _jsonHeaders,
      );
      final result = await analyze(repo);
      final failure = (result as Failed).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Please provide a longer listening response.');
    });

    test('a 409 (missing/reused token) returns Failed', () async {
      final repo = _repoReturning(statusCode: 409, body: '', headers: _jsonHeaders);
      final result = await analyze(repo);
      expect(result, isA<Failed>());
    });

    test('returns Failed with ServerFailure on a 500', () async {
      final repo = _repoReturning(statusCode: 500, body: '', headers: _jsonHeaders);
      final result = await analyze(repo);
      expect((result as Failed).failure, isA<ServerFailure>());
    });
  });
}
