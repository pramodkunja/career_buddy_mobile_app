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

      final result = await repo.submitMcqExercise(56, score: 1, maxScore: 1, answers: {123: 'b'});

      expect(result, isA<Success>());
      expect((result as Success).value.score, 1);
    });

    test('returns Failed with ForbiddenFailure for an unauthorized activity', () async {
      final repo = _repoReturning(statusCode: 403, body: '', headers: _htmlHeaders);
      final result = await repo.submitMcqExercise(56, score: 0, maxScore: 1, answers: const {});
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });
  });
}
