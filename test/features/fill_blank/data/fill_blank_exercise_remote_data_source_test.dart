import 'dart:convert';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/fill_blank/data/datasources/fill_blank_exercise_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _htmlHeaders = {
  'content-type': ['text/html'],
};
const _jsonHeaders = {
  'content-type': ['application/json'],
};

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
    return ResponseBody.fromString(body, statusCode, headers: const {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

FillBlankExerciseRemoteDataSource _dataSource({
  required int statusCode,
  required String body,
  HttpClientAdapter? adapter,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter =
        adapter ?? FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers ?? _htmlHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return FillBlankExerciseRemoteDataSource(ApiClient.forTesting(dio));
}

const _exercisePageHtml = '''
<html><body>
<script type="application/json" id="questions-data">[
  {"id": 1, "text": "Please find the report ___ to this email.", "type": "fill_blank", "options": {}, "correct": "attached", "explanation": ""},
  {"id": 2, "text": "Could you please touch ___?", "type": "fill_blank", "options": {}, "correct": "base", "explanation": ""}
]</script>
</body></html>
''';

void main() {
  group('FillBlankExerciseRemoteDataSource.getFillBlankExercise', () {
    test('extracts questions from the exercise_detail HTML page', () async {
      final ds = _dataSource(statusCode: 200, body: _exercisePageHtml, headers: _htmlHeaders);

      final exercise = await ds.getFillBlankExercise(7, title: 'Vocabulary Fill in the Blank', order: 1);

      expect(exercise.id, 7);
      expect(exercise.title, 'Vocabulary Fill in the Blank');
      expect(exercise.questions, hasLength(2));
      expect(exercise.questions[0].correctAnswer, 'attached');
    });

    test('throws ValidationException when the page has no questions-data blob (e.g. locked-activity redirect)', () async {
      final ds = _dataSource(statusCode: 200, body: '<html><body>Activities</body></html>', headers: _htmlHeaders);
      await expectLater(
        ds.getFillBlankExercise(7, title: 'T', order: 1),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws UnexpectedResponseException when the question list is present but empty', () async {
      const html = '<script type="application/json" id="questions-data">[]</script>';
      final ds = _dataSource(statusCode: 200, body: html, headers: _htmlHeaders);
      await expectLater(
        ds.getFillBlankExercise(7, title: 'T', order: 1),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a 401 while fetching the page maps to UnauthorizedException', () async {
      final ds = _dataSource(statusCode: 401, body: '', headers: _htmlHeaders);
      await expectLater(ds.getFillBlankExercise(7, title: 'T', order: 1), throwsA(isA<UnauthorizedException>()));
    });

    test('a server error while fetching the page maps to a typed AppException', () async {
      final ds = _dataSource(statusCode: 500, body: '', headers: _htmlHeaders);
      await expectLater(ds.getFillBlankExercise(7, title: 'T', order: 1), throwsA(isA<ServerException>()));
    });
  });

  group('FillBlankExerciseRemoteDataSource.submit', () {
    test('parses the submission result on a successful response', () async {
      final ds = _dataSource(
        statusCode: 200,
        body: jsonEncode({'status': 'ok', 'score': 1, 'max_score': 2, 'percentage': 50, 'attempt': 1}),
        headers: _jsonHeaders,
      );

      final result = await ds.submit(
        7,
        score: 1,
        maxScore: 2,
        answers: {
          '1': {'given': 'attached', 'correct': 'attached', 'result': 'correct'},
        },
      );

      expect(result.score, 1);
      expect(result.attemptNumber, 1);
    });

    test('sends an X-CSRFToken header — submit_exercise is not csrf_exempt', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode({'status': 'ok', 'attempt': 1}));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.submit(7, score: 1, maxScore: 2, answers: const {});

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.headers.containsKey('X-CSRFToken'), isTrue);
    });

    test('sends score/max_score/answers as the JSON body', () async {
      final adapter = _CapturingHttpClientAdapter(statusCode: 200, body: jsonEncode({'status': 'ok', 'attempt': 1}));
      final ds = _dataSource(statusCode: 200, body: '', adapter: adapter);

      await ds.submit(
        7,
        score: 1,
        maxScore: 2,
        answers: {
          '1': {'given': 'attached', 'correct': 'attached', 'result': 'correct'},
          '2': {'given': 'wrong', 'correct': 'base', 'result': 'wrong'},
        },
      );

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['score'], 1);
      expect(sent['max_score'], 2);
      expect(sent['answers'], {
        '1': {'given': 'attached', 'correct': 'attached', 'result': 'correct'},
        '2': {'given': 'wrong', 'correct': 'base', 'result': 'wrong'},
      });
    });

    test('a 403 (locked activity) maps to ForbiddenException', () async {
      final ds = _dataSource(statusCode: 403, body: '');
      await expectLater(ds.submit(7, score: 1, maxScore: 1, answers: const {}), throwsA(isA<ForbiddenException>()));
    });
  });
}
