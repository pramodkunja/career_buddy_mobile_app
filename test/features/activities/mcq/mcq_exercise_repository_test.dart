import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/data/datasources/mcq_exercise_remote_datasource.dart';
import 'package:career_buddy_lms/features/activities/data/repositories/mcq_exercise_repository_impl.dart';
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
<h2 class="text-white mb-0">Vocabulary Quiz</h2>
<script type="application/json" id="questions-data">[
  {"id": 123, "text": "Which word fits?", "type": "mcq", "options": {"a": "attach", "b": "attached"}, "correct": "b", "explanation": "Past participle."}
]</script>
</body></html>
''';

McqExerciseRepositoryImpl _repoReturning({
  required int statusCode,
  required String body,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return McqExerciseRepositoryImpl(McqExerciseRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  group('McqExerciseRepositoryImpl.getMcqExercise', () {
    test('returns Success with parsed data on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: _exercisePageHtml, headers: _htmlHeaders);

      final result = await repo.getMcqExercise(56);

      expect(result, isA<Success>());
      final exercise = (result as Success).value;
      expect(exercise.id, 56);
      expect(exercise.title, 'Vocabulary Quiz');
      expect(exercise.questions.single.correctAnswer, 'b');
    });

    test('returns Failed with UnauthorizedFailure for an anonymous request', () async {
      final repo = _repoReturning(statusCode: 401, body: '', headers: _htmlHeaders);

      final result = await repo.getMcqExercise(56);

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
    });

    test('returns Failed with ForbiddenFailure for a locked activity', () async {
      final repo = _repoReturning(statusCode: 403, body: '', headers: _htmlHeaders);
      final result = await repo.getMcqExercise(56);
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });

    test('returns Failed with NotFoundFailure for a missing exercise', () async {
      final repo = _repoReturning(statusCode: 404, body: '', headers: _htmlHeaders);
      final result = await repo.getMcqExercise(999999);
      expect((result as Failed).failure, isA<NotFoundFailure>());
    });

    test('returns Failed with ServerFailure on a 500', () async {
      final repo = _repoReturning(statusCode: 500, body: '', headers: _htmlHeaders);
      final result = await repo.getMcqExercise(56);
      expect((result as Failed).failure, isA<ServerFailure>());
    });
  });

  group('McqExerciseRepositoryImpl.submitMcqExercise', () {
    test('returns Success echoing the server\'s recorded score', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'status': 'ok', 'score': 1, 'max_score': 1, 'percentage': 100, 'attempt': 1}),
        headers: _jsonHeaders,
      );

      final result = await repo.submitMcqExercise(56, score: 1, maxScore: 1, questionOrder: const [123], answers: {123: 'b'});

      expect(result, isA<Success>());
      expect((result as Success).value.score, 1);
    });

    test('returns Failed with ForbiddenFailure for an unauthorized activity', () async {
      final repo = _repoReturning(statusCode: 403, body: '', headers: _htmlHeaders);
      final result = await repo.submitMcqExercise(56, score: 0, maxScore: 1, questionOrder: const [], answers: const {});
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });

    group('REGRESSION (Phase 16)', () {
      test(
        'keys the outgoing "answers" by 1-based question position (never the database id), each value a '
        '{"chosen": letter} map — matching activities/grading.py\'s mcq branch exactly',
        () async {
          RequestOptions? captured;
          final dio = Dio(BaseOptions(baseUrl: 'http://test'))
            ..httpClientAdapter = FakeHttpClientAdapter(
              statusCode: 200,
              body: jsonEncode({'status': 'ok', 'score': 2, 'max_score': 3, 'percentage': 67, 'attempt': 1}),
              headers: _jsonHeaders,
              onRequest: (o) => captured = o,
            )
            ..interceptors.add(ApiExceptionsInterceptor());
          final repo = McqExerciseRepositoryImpl(McqExerciseRemoteDataSource(ApiClient.forTesting(dio)));

          // Deliberately non-sequential, out-of-order database ids — the
          // 3rd question in the exercise's real order has the *smallest*
          // id, proving the fix keys by position-in-questionOrder, not by
          // sorting or otherwise guessing from the id values themselves.
          await repo.submitMcqExercise(
            56,
            score: 2,
            maxScore: 3,
            questionOrder: const [740, 12, 305],
            answers: const {740: 'b', 12: 'a', 305: 'd'},
          );

          final sentAnswers = (captured!.data as Map<String, dynamic>)['answers'] as Map<String, dynamic>;
          expect(sentAnswers, {
            '1': {'chosen': 'b'},
            '2': {'chosen': 'a'},
            '3': {'chosen': 'd'},
          });
        },
      );

      test('omits a position entirely when that question was never answered, rather than sending a null/empty guess', () async {
        RequestOptions? captured;
        final dio = Dio(BaseOptions(baseUrl: 'http://test'))
          ..httpClientAdapter = FakeHttpClientAdapter(
            statusCode: 200,
            body: jsonEncode({'status': 'ok', 'score': 1, 'max_score': 2, 'percentage': 50, 'attempt': 1}),
            headers: _jsonHeaders,
            onRequest: (o) => captured = o,
          )
          ..interceptors.add(ApiExceptionsInterceptor());
        final repo = McqExerciseRepositoryImpl(McqExerciseRemoteDataSource(ApiClient.forTesting(dio)));

        await repo.submitMcqExercise(
          56,
          score: 1,
          maxScore: 2,
          questionOrder: const [11, 22],
          answers: const {11: 'c'}, // question 22 (position 2) was never answered
        );

        final sentAnswers = (captured!.data as Map<String, dynamic>)['answers'] as Map<String, dynamic>;
        expect(sentAnswers, {
          '1': {'chosen': 'c'},
        });
      });
    });
  });
}
