import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:career_buddy_lms/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client_adapter.dart';

/// A minimal but structurally real slice of `templates/dashboard.html` —
/// just enough markup for `isDashboardHtml`/the stats row to parse
/// successfully. See `dashboard_remote_datasource_test.dart` for the fuller
/// fixture covering every section.
const _validDashboardHtml = '''
<div class="dashboard-welcome"></div>
<div class="stat-card stat-card-blue"><div class="stat-card-value">5</div></div>
<div class="stat-card stat-card-green"><div class="stat-card-value">1</div></div>
<div class="stat-card stat-card-orange"><div class="stat-card-value">1</div></div>
<div class="stat-card stat-card-purple"><div class="stat-card-value">10</div></div>
''';

DashboardRepositoryImpl _repoReturning({
  required int statusCode,
  required String body,
  Map<String, List<String>>? headers,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return DashboardRepositoryImpl(DashboardRemoteDataSource(ApiClient.forTesting(dio)));
}

void main() {
  group('DashboardRepositoryImpl.getDashboard', () {
    test('returns Success with parsed data on a valid response', () async {
      final repo = _repoReturning(
        statusCode: 200,
        body: _validDashboardHtml,
        headers: {
          'content-type': ['text/html'],
        },
      );

      final result = await repo.getDashboard();

      expect(result, isA<Success>());
      expect((result as Success).value.stats.completedCount, 1);
    });

    test('returns Failed with a ServerFailure when the live page 500s', () async {
      final repo = _repoReturning(statusCode: 500, body: '');

      final result = await repo.getDashboard();

      expect(result, isA<Failed>());
      expect((result as Failed).failure, isA<ServerFailure>());
    });
  });
}
