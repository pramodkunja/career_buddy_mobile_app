import 'dart:convert';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/data/datasources/amcat_remote_datasource.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/data/repositories/amcat_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client_adapter.dart';

const _jsonHeaders = {
  'content-type': ['application/json'],
};

AmcatRepositoryImpl _repoReturning({required int statusCode, required String body}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: _jsonHeaders)
    ..interceptors.add(ApiExceptionsInterceptor());
  return AmcatRepositoryImpl(
    AmcatRemoteDataSource(
      ApiClient.forTesting(dio),
      questionsPath: '/activities/amcat/questions/',
      submitPath: '/activities/amcat/submit/',
    ),
  );
}

void main() {
  group('AmcatRepositoryImpl.getSections', () {
    test('returns Success with the parsed section list', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({
          'sections': [
            {'key': 'quant', 'name': 'Quantitative Ability', 'timeSec': 1080, 'type': 'mcq', 'questions': <Map<String, dynamic>>[]},
          ],
        }),
      );

      final result = await repo.getSections();

      expect(result, isA<Success>());
      expect((result as Success).value, hasLength(1));
    });

    test('returns Failed with ServerFailure on a 500', () async {
      final repo = _repoReturning(statusCode: 500, body: '');
      final result = await repo.getSections();
      expect((result as Failed).failure, isA<ServerFailure>());
    });
  });

  group('AmcatRepositoryImpl.submit', () {
    test('returns Success with the server-graded result', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: jsonEncode({'score': 10, 'total': 153, 'sections': <String, dynamic>{}, 'results': <String, dynamic>{}}),
      );

      final result = await repo.submit({1: 0, 2: -1});

      expect(result, isA<Success>());
      expect((result as Success).value.score, 10);
    });

    test('returns Failed on a network-layer error', () async {
      final repo = _repoReturning(statusCode: 503, body: '');
      final result = await repo.submit({1: -1});
      expect(result, isA<Failed>());
    });
  });
}
