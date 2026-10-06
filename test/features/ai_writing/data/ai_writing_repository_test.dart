import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_writing/data/datasources/ai_writing_remote_datasource.dart';
import 'package:career_buddy_lms/features/ai_writing/data/repositories/ai_writing_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

const _validBody = {
  'success': true,
  'data': {
    'text': 'Hello there.',
    'issues': <dynamic>[],
    'improved_passage': 'Hello there.',
    'feedback': 'Nice.',
    'quick_tip': 'Read it once more.',
    'scores': {'grammar': 80},
  },
  'score_25': 18,
};

AiWritingRepositoryImpl _repoReturning({
  required int statusCode,
  required String body,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AiWritingRepositoryImpl(AiWritingRemoteDataSource(ApiClient.forTesting(dio)));
}

Future<Result<dynamic>> analyze(AiWritingRepositoryImpl repo) => repo.analyze(
  exerciseId: 7,
  text: 'a' * 600,
  language: 'english',
  referenceText: 'Describe your day.',
);

void main() {
  group('AiWritingRepositoryImpl.analyze', () {
    test('returns Success with the parsed result on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: jsonEncode(_validBody), headers: _jsonHeaders);

      final result = await analyze(repo);

      expect(result, isA<Success>());
      expect((result as Success).value.score25, 18);
    });

    test('returns Failed with ValidationFailure carrying the server\'s message for a rejected submission', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'success': false, 'error': 'Please keep your writing within 900 characters before analyzing. Spaces are not counted.'}),
        headers: _jsonHeaders,
      );

      final result = await analyze(repo);

      expect(result, isA<Failed>());
      final failure = (result as Failed).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Please keep your writing within 900 characters before analyzing. Spaces are not counted.');
    });

    test('returns Failed with ForbiddenFailure for a locked activity (403)', () async {
      final repo = _repoReturning(statusCode: 403, body: '');
      final result = await analyze(repo);
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });

    test('returns Failed with UnauthorizedFailure for an anonymous request', () async {
      final repo = _repoReturning(statusCode: 401, body: '');
      final result = await analyze(repo);
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
    });

    test('returns Failed with ServerFailure on a 500', () async {
      final repo = _repoReturning(statusCode: 500, body: '');
      final result = await analyze(repo);
      expect((result as Failed).failure, isA<ServerFailure>());
    });
  });
}
