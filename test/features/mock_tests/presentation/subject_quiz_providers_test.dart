import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_endpoints.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/providers/mock_test_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiEndpoints subject quiz URLs', () {
    test('quizQuestions/quizSubmit build the expected per-subject paths', () {
      expect(ApiEndpoints.quizQuestions('dsa'), '/activities/quiz/dsa/questions/');
      expect(ApiEndpoints.quizSubmit('dsa'), '/activities/quiz/dsa/submit/');
      expect(ApiEndpoints.quizQuestions('python'), '/activities/quiz/python/questions/');
    });
  });

  group('subjectQuizRemoteDataSourceProvider', () {
    test('constructs a datasource pointed at that subject\'s own endpoint pair', () {
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(ApiClient.forTesting(Dio()))],
      );
      addTearDown(container.dispose);

      final dsaDataSource = container.read(subjectQuizRemoteDataSourceProvider('dsa'));
      expect(dsaDataSource.questionsPath, '/activities/quiz/dsa/questions/');
      expect(dsaDataSource.submitPath, '/activities/quiz/dsa/submit/');

      final pythonDataSource = container.read(subjectQuizRemoteDataSourceProvider('python'));
      expect(pythonDataSource.questionsPath, '/activities/quiz/python/questions/');
    });

    test('two subjects resolve to two independent datasource instances', () {
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(ApiClient.forTesting(Dio()))],
      );
      addTearDown(container.dispose);

      final dsa = container.read(subjectQuizRemoteDataSourceProvider('dsa'));
      final python = container.read(subjectQuizRemoteDataSourceProvider('python'));
      expect(identical(dsa, python), isFalse);
    });
  });
}
