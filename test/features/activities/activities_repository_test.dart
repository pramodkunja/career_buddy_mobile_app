import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/data/datasources/activities_remote_datasource.dart';
import 'package:career_buddy_lms/features/activities/data/repositories/activities_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client_adapter.dart';

const _htmlHeaders = {
  'content-type': ['text/html'],
};

const _validDetailHtml = '''
<div class="activity-detail-page">
  <h1 class="activity-hero-title">Business Vocabulary Building Games</h1>
  <p class="activity-hero-objective">Build core business vocabulary.</p>
</div>
''';

ActivitiesRepositoryImpl _repoReturning({
  required int statusCode,
  required String body,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return ActivitiesRepositoryImpl(ActivitiesRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  group('ActivitiesRepositoryImpl.getActivityList', () {
    test('returns Failed with UnauthorizedFailure when the session has expired (a login-redirect page)', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: '<html><body><form id="login-form"><input name="username"></form></body></html>',
        headers: _htmlHeaders,
      );

      final result = await repo.getActivityList();

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
    });
  });

  group('ActivitiesRepositoryImpl.getActivityDetail', () {
    test('returns Success with parsed data on a valid response', () async {
      final repo = _repoReturning(statusCode: 200, body: _validDetailHtml, headers: _htmlHeaders);

      final result = await repo.getActivityDetail(12);

      expect(result, isA<Success>());
      expect((result as Success).value.title, 'Business Vocabulary Building Games');
    });

    test('returns Failed with ForbiddenFailure for a locked activity (redirect to the upgrade page)', () async {
      final repo = _repoReturning(
        statusCode: 302,
        body: '',
        headers: {
          'location': ['/activities/?locked=1'],
        },
      );

      final result = await repo.getActivityDetail(1);

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<ForbiddenFailure>());
    });
  });

  group('ActivitiesRepositoryImpl.getSubActivityDetail', () {
    test('returns Failed with NotFoundFailure for an invalid id', () async {
      final repo = _repoReturning(statusCode: 404, body: '');

      final result = await repo.getSubActivityDetail(12, 999999);

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<NotFoundFailure>());
    });
  });

  group('ActivitiesRepositoryImpl.markSubComplete', () {
    test('returns Success on a 302 (the web form\'s own redirect-on-success)', () async {
      final repo = _repoReturning(statusCode: 302, body: '');

      final result = await repo.markSubComplete(34);

      expect(result, isA<Success>());
    });

    test('returns Failed with NotFoundFailure for an invalid id', () async {
      final repo = _repoReturning(statusCode: 404, body: '');

      final result = await repo.markSubComplete(999999);

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<NotFoundFailure>());
    });
  });
}
