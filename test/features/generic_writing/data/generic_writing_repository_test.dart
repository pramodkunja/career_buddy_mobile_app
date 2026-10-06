import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/generic_writing/data/datasources/generic_writing_remote_datasource.dart';
import 'package:career_buddy_lms/features/generic_writing/data/repositories/generic_writing_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _htmlHeaders = {
  'content-type': ['text/html'],
};
const _jsonHeaders = {
  'content-type': ['application/json'],
};

const _exercisePageHtml = '''
<html><body>
<script type="application/json" id="questions-data">[
  {"id": 1, "text": "Describe the outcome.", "correct": "", "explanation": "Aim for 80-120 words."}
]</script>
</body></html>
''';

GenericWritingRepositoryImpl _repoReturning({required int statusCode, required String body, Map<String, List<String>>? headers}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return GenericWritingRepositoryImpl(GenericWritingRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  group('GenericWritingRepositoryImpl.getGenericWritingExercise', () {
    test('returns Success with parsed data on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: _exercisePageHtml, headers: _htmlHeaders);

      final result = await repo.getGenericWritingExercise(7, title: 'Negotiation Outcome Reflection', order: 1);

      expect(result, isA<Success>());
      expect((result as Success).value.prompts, hasLength(1));
    });

    test('returns Failed with UnauthorizedFailure for an anonymous request', () async {
      final repo = _repoReturning(statusCode: 401, body: '', headers: _htmlHeaders);
      final result = await repo.getGenericWritingExercise(7, title: 'T', order: 1);
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
    });

    test('returns Failed with NotFoundFailure for a missing exercise', () async {
      final repo = _repoReturning(statusCode: 404, body: '', headers: _htmlHeaders);
      final result = await repo.getGenericWritingExercise(999999, title: 'T', order: 1);
      expect((result as Failed).failure, isA<NotFoundFailure>());
    });
  });

  group('GenericWritingRepositoryImpl.submitGenericWritingExercise', () {
    test('returns Success, encoding answers as position-keyed strings', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'status': 'ok', 'score': 78, 'max_score': 100, 'percentage': 78, 'attempt': 1}),
        headers: _jsonHeaders,
      );

      final result = await repo.submitGenericWritingExercise(
        7,
        score: 78,
        maxScore: 100,
        answers: {1: 'We reached an agreement on pricing.', 2: 'We used "We would be willing to..."'},
      );

      expect(result, isA<Success>());
      expect((result as Success).value.score, 78);
    });

    test('returns Failed with ForbiddenFailure for a locked activity', () async {
      final repo = _repoReturning(statusCode: 403, body: '', headers: _htmlHeaders);
      final result = await repo.submitGenericWritingExercise(7, score: 0, maxScore: 100, answers: const {});
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });
  });
}
