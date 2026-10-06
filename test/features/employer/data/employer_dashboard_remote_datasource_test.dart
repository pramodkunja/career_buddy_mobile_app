import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/employer_dashboard_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  group('deleteJob', () {
    test('completes without throwing on a real 302 (redirect-on-success)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = EmployerDashboardRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.deleteJob(68), completes);
    });

    test('throws on a 404 (a job outside the caller\'s own/seeded jobs)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 404, body: '');
      final datasource = EmployerDashboardRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.deleteJob(999), throwsA(isA<ServerException>()));
    });
  });
}
