import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_endpoints.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/presentation/providers/amcat_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiEndpoints.cocubesQuestions/cocubesSubmit build the expected paths, distinct from AMCAT\'s', () {
    expect(ApiEndpoints.cocubesQuestions, '/activities/cocubes/questions/');
    expect(ApiEndpoints.cocubesSubmit, '/activities/cocubes/submit/');
    expect(ApiEndpoints.cocubesQuestions, isNot(ApiEndpoints.amcatQuestions));
    expect(ApiEndpoints.cocubesSubmit, isNot(ApiEndpoints.amcatSubmit));
  });

  test('cocubesRemoteDataSourceProvider is pointed at the CoCubes endpoint pair, independent of AMCAT\'s', () {
    final container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(ApiClient.forTesting(Dio()))]);
    addTearDown(container.dispose);

    final cocubesDataSource = container.read(cocubesRemoteDataSourceProvider);
    expect(cocubesDataSource.questionsPath, '/activities/cocubes/questions/');
    expect(cocubesDataSource.submitPath, '/activities/cocubes/submit/');

    final amcatDataSource = container.read(amcatRemoteDataSourceProvider);
    expect(amcatDataSource.questionsPath, '/activities/amcat/questions/');
    expect(identical(cocubesDataSource, amcatDataSource), isFalse);
  });
}
