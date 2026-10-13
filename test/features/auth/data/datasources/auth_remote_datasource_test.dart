import 'package:career_buddy_lms/core/errors/exceptions.dart';
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
  group('REGRESSION (Phase 14) — login() surfaces the real Django error', () {
    test('scrapes the employer-account-used-on-student-portal message from the form-error block', () async {
      const html = '''
<form method="post">
    <div class="alert alert-danger py-2 rounded-3 small mb-4"
        style="border: 1px solid #fecaca; background: #fef2f2; color: #dc2626;">
        <div>
            <i class="fas fa-exclamation-circle me-1"></i>
            Employer accounts cannot log in through the student portal.
        </div>
    </div>
</form>
''';
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: html);
      final datasource = AuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.login(usernameOrEmail: 'hr@acme.test', password: 'secret'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Employer accounts cannot log in through the student portal.',
          ),
        ),
      );
    });

    test('scrapes the lockout message from the shared flashed-message container when form.errors is empty', () async {
      const html = '''
<div class="messages-container">
    <div class="alert alert-danger alert-dismissible fade show toast-message" role="alert">
        <i class="fas fa-exclamation-circle me-2"></i>
        Too many failed login attempts. Please try again in a few minutes.
    </div>
</div>
<form method="post"></form>
''';
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: html);
      final datasource = AuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.login(usernameOrEmail: 'user', password: 'wrong'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Too many failed login attempts. Please try again in a few minutes.',
          ),
        ),
      );
    });

    test('falls back to the generic message when neither known pattern matches (never a guess)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: '<html><body>Something else entirely</body></html>');
      final datasource = AuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.login(usernameOrEmail: 'user', password: 'wrong'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Invalid username or password, or this account cannot sign in here.',
          ),
        ),
      );
    });
  });

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
