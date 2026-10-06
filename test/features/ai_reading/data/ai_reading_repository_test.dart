import 'dart:convert';
import 'dart:io';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_reading/data/datasources/ai_reading_remote_datasource.dart';
import 'package:career_buddy_lms/features/ai_reading/data/repositories/ai_reading_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

const _validBody = {
  'success': true,
  'data': {
    'text': 'Reference passage.',
    'issues': <dynamic>[],
    'improved_passage': 'Reference passage.',
    'feedback': 'Nice.',
    'quick_tip': 'Keep it steady.',
    'scores': {'accuracy': 80},
    'score_25': 20,
  },
  'score_25': 20,
};

AiReadingRepositoryImpl _repoReturning({
  required int statusCode,
  required String body,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AiReadingRepositoryImpl(AiReadingRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  late String audioFilePath;

  setUpAll(() async {
    final file = File('${Directory.systemTemp.path}/ai_reading_repository_test.m4a');
    await file.writeAsBytes([0, 1, 2, 3]);
    audioFilePath = file.path;
  });

  Future<Result<dynamic>> analyze(AiReadingRepositoryImpl repo) => repo.analyze(
    exerciseId: 7,
    audioFilePath: audioFilePath,
    durationSeconds: 10,
    pauseCount: 0,
    language: 'english',
    referenceText: 'The passage text.',
  );

  group('AiReadingRepositoryImpl.analyze', () {
    test('returns Success with the parsed result on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: jsonEncode(_validBody), headers: _jsonHeaders);
      final result = await analyze(repo);
      expect(result, isA<Success>());
      expect((result as Success).value.score25, 20);
    });

    test('returns Failed with ValidationFailure carrying the server\'s message for a rejected submission', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'success': false, 'error': 'Please provide a longer reading response.'}),
        headers: _jsonHeaders,
      );
      final result = await analyze(repo);
      final failure = (result as Failed).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Please provide a longer reading response.');
    });

    test('returns Failed with UnauthorizedFailure for an anonymous request', () async {
      final repo = _repoReturning(statusCode: 401, body: '');
      final result = await analyze(repo);
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
    });

    test('returns Failed with ServerFailure on a 500', () async {
      final repo = _repoReturning(statusCode: 500, body: '');
      final result = await analyze(repo);
      expect((result as Failed).failure, isA<ServerFailure>());
    });
  });
}
