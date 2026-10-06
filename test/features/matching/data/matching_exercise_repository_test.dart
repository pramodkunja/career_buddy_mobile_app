import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/matching/data/datasources/matching_exercise_remote_datasource.dart';
import 'package:career_buddy_lms/features/matching/data/repositories/matching_exercise_repository_impl.dart';
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
  {"id": 1, "text": "q", "type": "matching", "options": {}, "correct": "", "explanation": "", "left": "ASAP", "right": "As soon as possible"}
]</script>
</body></html>
''';

MatchingExerciseRepositoryImpl _repoReturning({
  required int statusCode,
  required String body,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return MatchingExerciseRepositoryImpl(MatchingExerciseRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  group('MatchingExerciseRepositoryImpl.getMatchingExercise', () {
    test('returns Success with parsed data on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: _exercisePageHtml, headers: _htmlHeaders);

      final result = await repo.getMatchingExercise(7, title: 'Abbreviations', order: 1);

      expect(result, isA<Success>());
      expect((result as Success).value.pairs, hasLength(1));
    });

    test('returns Failed with UnauthorizedFailure for an anonymous request', () async {
      final repo = _repoReturning(statusCode: 401, body: '', headers: _htmlHeaders);
      final result = await repo.getMatchingExercise(7, title: 'T', order: 1);
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
    });

    test('returns Failed with NotFoundFailure for a missing exercise', () async {
      final repo = _repoReturning(statusCode: 404, body: '', headers: _htmlHeaders);
      final result = await repo.getMatchingExercise(999999, title: 'T', order: 1);
      expect((result as Failed).failure, isA<NotFoundFailure>());
    });
  });

  group('MatchingExerciseRepositoryImpl.submitMatchingExercise', () {
    test('returns Success with the result, and encodes matches as position-keyed correct/wrong answers', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'status': 'ok', 'score': 1, 'max_score': 2, 'percentage': 50, 'attempt': 1}),
        headers: _jsonHeaders,
      );

      final result = await repo.submitMatchingExercise(7, score: 1, maxScore: 2, matches: {1: 1, 2: 1});

      expect(result, isA<Success>());
      expect((result as Success).value.score, 1);
    });

    test('returns Failed with ForbiddenFailure for a locked activity', () async {
      final repo = _repoReturning(statusCode: 403, body: '', headers: _htmlHeaders);
      final result = await repo.submitMatchingExercise(7, score: 0, maxScore: 1, matches: const {});
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });
  });
}
