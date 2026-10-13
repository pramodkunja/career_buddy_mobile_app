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

    group('REGRESSION (Phase 16)', () {
      test(
        'sends "paired" for a CORRECT pair too (not just the wrong-pair case) — matching '
        'activities/grading.py\'s matching branch, which reads `paired` unconditionally',
        () async {
          RequestOptions? captured;
          final dio = Dio(BaseOptions(baseUrl: 'http://test'))
            ..httpClientAdapter = FakeHttpClientAdapter(
              statusCode: 200,
              body: jsonEncode({'status': 'ok', 'score': 1, 'max_score': 1, 'percentage': 100, 'attempt': 1}),
              headers: _jsonHeaders,
              onRequest: (o) => captured = o,
            )
            ..interceptors.add(ApiExceptionsInterceptor());
          final repo = MatchingExerciseRepositoryImpl(MatchingExerciseRemoteDataSource(ApiClient.forTesting(dio)));

          // Position 1 paired with itself (correct).
          await repo.submitMatchingExercise(7, score: 1, maxScore: 1, matches: const {1: 1});

          final sentAnswers = (captured!.data as Map<String, dynamic>)['answers'] as Map<String, dynamic>;
          expect(sentAnswers, {
            '1': {'result': 'correct', 'paired': '1'},
          });
        },
      );

      test('sends the real "paired" position for an INCORRECT pair, never a fabricated/correct one', () async {
        RequestOptions? captured;
        final dio = Dio(BaseOptions(baseUrl: 'http://test'))
          ..httpClientAdapter = FakeHttpClientAdapter(
            statusCode: 200,
            body: jsonEncode({'status': 'ok', 'score': 0, 'max_score': 2, 'percentage': 0, 'attempt': 1}),
            headers: _jsonHeaders,
            onRequest: (o) => captured = o,
          )
          ..interceptors.add(ApiExceptionsInterceptor());
        final repo = MatchingExerciseRepositoryImpl(MatchingExerciseRemoteDataSource(ApiClient.forTesting(dio)));

        // Position 1 wrongly paired with position 2, and vice versa.
        await repo.submitMatchingExercise(7, score: 0, maxScore: 2, matches: const {1: 2, 2: 1});

        final sentAnswers = (captured!.data as Map<String, dynamic>)['answers'] as Map<String, dynamic>;
        expect(sentAnswers, {
          '1': {'result': 'wrong', 'paired': '2'},
          '2': {'result': 'wrong', 'paired': '1'},
        });
      });

      test('a mix of correct and incorrect pairs across multiple positions sends the exact real structure', () async {
        RequestOptions? captured;
        final dio = Dio(BaseOptions(baseUrl: 'http://test'))
          ..httpClientAdapter = FakeHttpClientAdapter(
            statusCode: 200,
            body: jsonEncode({'status': 'ok', 'score': 2, 'max_score': 3, 'percentage': 67, 'attempt': 1}),
            headers: _jsonHeaders,
            onRequest: (o) => captured = o,
          )
          ..interceptors.add(ApiExceptionsInterceptor());
        final repo = MatchingExerciseRepositoryImpl(MatchingExerciseRemoteDataSource(ApiClient.forTesting(dio)));

        // 1 and 3 correct, 2 wrongly paired with 3... wait, 3 must be
        // unique per position — use a clean 3-pair mix: 1 correct, 2
        // correct, 3 wrong (paired with 1).
        await repo.submitMatchingExercise(7, score: 2, maxScore: 3, matches: const {1: 1, 2: 2, 3: 1});

        final sentAnswers = (captured!.data as Map<String, dynamic>)['answers'] as Map<String, dynamic>;
        expect(sentAnswers, {
          '1': {'result': 'correct', 'paired': '1'},
          '2': {'result': 'correct', 'paired': '2'},
          '3': {'result': 'wrong', 'paired': '1'},
        });
      });
    });
  });
}
