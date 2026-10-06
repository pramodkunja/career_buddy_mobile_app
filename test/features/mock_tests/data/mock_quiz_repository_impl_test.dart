import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/mock_tests/data/datasources/mock_quiz_remote_datasource.dart';
import 'package:career_buddy_lms/features/mock_tests/data/repositories/mock_quiz_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

MockQuizRepositoryImpl _repoReturning({required int statusCode, required String body}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return MockQuizRepositoryImpl(
    MockQuizRemoteDataSource(
      ApiClient.forTesting(dio),
      questionsPath: '/activities/oop-quiz/questions/',
      submitPath: '/activities/oop-quiz/submit/',
    ),
  );
}

void main() {
  group('MockQuizRepositoryImpl.getQuestions', () {
    test('returns Success with the parsed question list', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({
          'questions': [
            {'id': 1, 'q': 'Q1', 'options': ['a', 'b', 'c', 'd'], 'difficulty': '', 'topic': ''},
          ],
        }),
      );

      final result = await repo.getQuestions();

      expect(result, isA<Success>());
      expect((result as Success).value, hasLength(1));
    });

    test('returns Failed with ServerFailure on a 500', () async {
      final repo = _repoReturning(statusCode: 500, body: '');
      final result = await repo.getQuestions();
      expect((result as Failed).failure, isA<ServerFailure>());
    });

    test('returns Failed with NetworkFailure-mapped exception surfaced as a typed Failure on malformed JSON', () async {
      final repo = _repoReturning(statusCode: 200, body: 'not json at all {{{');
      final result = await repo.getQuestions();
      expect(result, isA<Failed>());
    });
  });

  group('MockQuizRepositoryImpl.submitAnswers', () {
    test('returns Success with the server-graded result', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'score': 10, 'total': 50, 'results': <String, dynamic>{}}),
      );

      final result = await repo.submitAnswers({1: 0, 2: -1});

      expect(result, isA<Success>());
      expect((result as Success).value.score, 10);
    });

    test('returns Failed on a network-layer error', () async {
      final repo = _repoReturning(statusCode: 503, body: '');
      final result = await repo.submitAnswers({1: -1});
      expect(result, isA<Failed>());
    });
  });
}
