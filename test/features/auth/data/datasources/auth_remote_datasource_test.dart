import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client_adapter.dart';

/// Current-task production-login investigation — regression test for the
/// logout() validateStatus fix. The real Django logout view responds `302`
/// on success (same redirect-on-success convention `login()` already
/// handles), confirmed live against production by every account this task
/// exercised. Before this fix, `logout()` never overrode Dio's default
/// 200-299 `validateStatus`, so that real 302 was thrown as a DioException
/// and surfaced to the user as "Something unexpected happened" immediately
/// after a genuinely successful logout.
void main() {
  test('logout() does not throw on a real 302 (redirect-on-success) response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
    final client = ApiClient.forTesting(dio);
    final datasource = AuthRemoteDataSource(client);

    await expectLater(datasource.logout(), completes);
  });

  test('logout() still throws for a genuine server error (5xx)', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 500, body: '');
    final client = ApiClient.forTesting(dio);
    final datasource = AuthRemoteDataSource(client);

    await expectLater(datasource.logout(), throwsA(isA<Exception>()));
  });
}
