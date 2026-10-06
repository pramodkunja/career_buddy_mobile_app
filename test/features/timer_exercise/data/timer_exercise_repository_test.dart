import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/timer_exercise/data/datasources/timer_exercise_remote_datasource.dart';
import 'package:career_buddy_lms/features/timer_exercise/data/repositories/timer_exercise_repository_impl.dart';
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
  {"id": 1, "text": "Describe your morning routine.", "correct": "", "explanation": ""}
]</script>
</body></html>
''';

TimerExerciseRepositoryImpl _repoReturning({required int statusCode, required String body, Map<String, List<String>>? headers}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return TimerExerciseRepositoryImpl(TimerExerciseRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  group('TimerExerciseRepositoryImpl.getTimerExercise', () {
    test('returns Success with parsed data on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: _exercisePageHtml, headers: _htmlHeaders);

      final result = await repo.getTimerExercise(7, title: 'Timed Activity', order: 1);

      expect(result, isA<Success>());
      expect((result as Success).value.tasks, hasLength(1));
    });

    test('returns Failed with UnauthorizedFailure for an anonymous request', () async {
      final repo = _repoReturning(statusCode: 401, body: '', headers: _htmlHeaders);
      final result = await repo.getTimerExercise(7, title: 'T', order: 1);
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
    });

    test('returns Failed with NotFoundFailure for a missing exercise', () async {
      final repo = _repoReturning(statusCode: 404, body: '', headers: _htmlHeaders);
      final result = await repo.getTimerExercise(999999, title: 'T', order: 1);
      expect((result as Failed).failure, isA<NotFoundFailure>());
    });
  });

  group('TimerExerciseRepositoryImpl.submitTimerExercise', () {
    test('returns Success, encoding answers as position-keyed strings', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'status': 'ok', 'score': 2, 'max_score': 3, 'percentage': 67, 'attempt': 1}),
        headers: _jsonHeaders,
      );

      final result = await repo.submitTimerExercise(7, score: 2, maxScore: 3, answers: {1: 'I woke up and made coffee.'});

      expect(result, isA<Success>());
      final success = result as Success;
      expect(success.value.score, 2);
      expect(success.value.maxScore, 3);
    });

    test('returns Failed with ForbiddenFailure for a locked activity', () async {
      final repo = _repoReturning(statusCode: 403, body: '', headers: _htmlHeaders);
      final result = await repo.submitTimerExercise(7, score: 0, maxScore: 3, answers: const {});
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });
  });
}
