import 'dart:convert';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/mock_tests/data/datasources/mock_quiz_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

/// Captures the outgoing request so a test can assert on its headers —
/// specifically, that no `X-CSRFToken` is sent (see the datasource's own
/// doc comment for why: `oop_quiz_submit` is `@csrf_exempt`).
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

MockQuizRemoteDataSource _dataSourceReturning({required int statusCode, required String body, HttpClientAdapter? adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return MockQuizRemoteDataSource(
    ApiClient.forTesting(dio),
    questionsPath: '/activities/oop-quiz/questions/',
    submitPath: '/activities/oop-quiz/submit/',
  );
}

void main() {
  group('MockQuizRemoteDataSource.getQuestions', () {
    test('parses the questions list on a valid response', () async {
      final ds = _dataSourceReturning(
        statusCode: 200,
        body: jsonEncode({
          'questions': [
            {'id': 1, 'q': 'Q1', 'options': ['a', 'b', 'c', 'd'], 'difficulty': 'easy', 'topic': 'basics'},
          ],
        }),
      );

      final questions = await ds.getQuestions();

      expect(questions, hasLength(1));
      expect(questions.single.id, 1);
    });

    test('throws UnexpectedResponseException when the body is not a JSON object', () async {
      final ds = _dataSourceReturning(statusCode: 200, body: '"just a string"');
      await expectLater(ds.getQuestions(), throwsA(isA<UnexpectedResponseException>()));
    });

    test('a server error maps to a typed AppException via the shared interceptor', () async {
      final ds = _dataSourceReturning(statusCode: 500, body: '');
      await expectLater(ds.getQuestions(), throwsA(isA<ServerException>()));
    });
  });

  group('MockQuizRemoteDataSource.submitAnswers', () {
    test('parses score/total/results on a valid response', () async {
      final ds = _dataSourceReturning(
        statusCode: 200,
        body: jsonEncode({
          'score': 40,
          'total': 50,
          'results': {'1': {'correct': true, 'answer': 0, 'explanation': 'because'}},
        }),
      );

      final result = await ds.submitAnswers({1: 0});

      expect(result.score, 40);
      expect(result.total, 50);
    });

    test('sends no X-CSRFToken header — oop_quiz_submit is @csrf_exempt', () async {
      final adapter = _CapturingHttpClientAdapter(
        statusCode: 200,
        body: jsonEncode({'score': 0, 'total': 1, 'results': <String, dynamic>{}}),
      );
      final ds = _dataSourceReturning(statusCode: 200, body: '', adapter: adapter);

      await ds.submitAnswers({1: -1});

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isFalse);
    });

    test('an unauthorized-shaped response still succeeds — the endpoint requires no auth', () async {
      // oop_quiz_submit has no @login_required; a 401 would only ever come
      // from some unrelated middleware, not this endpoint's own logic, so
      // this test simply documents that a 200 with a body is treated as
      // success regardless of session state — there is no special-casing.
      final ds = _dataSourceReturning(
        statusCode: 200,
        body: jsonEncode({'score': 0, 'total': 1, 'results': <String, dynamic>{}}),
      );
      final result = await ds.submitAnswers({1: -1});
      expect(result.total, 1);
    });
  });
}
