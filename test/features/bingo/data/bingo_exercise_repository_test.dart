import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/bingo/data/datasources/bingo_exercise_remote_datasource.dart';
import 'package:career_buddy_lms/features/bingo/data/repositories/bingo_exercise_repository_impl.dart';
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
<script type="application/json" id="bingo-data">[
  {"word": "ASAP", "definition": "As soon as possible"}
]</script>
</body></html>
''';

BingoExerciseRepositoryImpl _repoReturning({
  required int statusCode,
  required String body,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return BingoExerciseRepositoryImpl(BingoExerciseRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  group('BingoExerciseRepositoryImpl.getBingoExercise', () {
    test('returns Success with parsed data on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: _exercisePageHtml, headers: _htmlHeaders);

      final result = await repo.getBingoExercise(7, title: 'Vocab Bingo', order: 1);

      expect(result, isA<Success>());
      expect((result as Success).value.cards, hasLength(1));
    });

    test('returns Failed with UnauthorizedFailure for an anonymous request', () async {
      final repo = _repoReturning(statusCode: 401, body: '', headers: _htmlHeaders);
      final result = await repo.getBingoExercise(7, title: 'T', order: 1);
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
    });

    test('returns Failed with NotFoundFailure for a missing exercise', () async {
      final repo = _repoReturning(statusCode: 404, body: '', headers: _htmlHeaders);
      final result = await repo.getBingoExercise(999999, title: 'T', order: 1);
      expect((result as Failed).failure, isA<NotFoundFailure>());
    });
  });

  group('BingoExerciseRepositoryImpl.submitBingoExercise', () {
    test('returns Success, encoding answers as w<n>-keyed target/chosen pairs', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'status': 'ok', 'score': 1, 'max_score': 2, 'percentage': 50, 'attempt': 1}),
        headers: _jsonHeaders,
      );

      final result = await repo.submitBingoExercise(
        7,
        score: 1,
        maxScore: 2,
        answers: {1: (target: 'ASAP', chosen: 'ASAP'), 2: (target: 'FYI', chosen: 'ASAP')},
      );

      expect(result, isA<Success>());
      expect((result as Success).value.score, 1);
    });

    test('returns Failed with ForbiddenFailure for a locked activity', () async {
      final repo = _repoReturning(statusCode: 403, body: '', headers: _htmlHeaders);
      final result = await repo.submitBingoExercise(7, score: 0, maxScore: 1, answers: const {});
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });
  });
}
