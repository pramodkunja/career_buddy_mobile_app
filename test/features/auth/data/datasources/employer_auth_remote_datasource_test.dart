import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/auth/data/datasources/employer_auth_remote_datasource.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/employer_registration_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client_adapter.dart';

/// Phase 14 — `EmployerAuthRemoteDataSource.login`/`register` previously
/// reported one hardcoded generic message for every 200 (failed) response;
/// these tests prove the real, specific Django error is now scraped
/// instead, using fixtures modeled directly on `templates/employer_login/
/// login.html:84-99` and `templates/employer_login/signup.html`'s real
/// markup. No datasource-level test existed for this class before this
/// phase.
EmployerRegistrationData _buildRegistrationData() => const EmployerRegistrationData(
  username: 'acme_hr',
  password: 'Aa1!aaaa',
  passwordConfirm: 'Aa1!aaaa',
  email: 'hr@acme.test',
  firstName: 'Jane',
  lastName: 'Doe',
  companyName: 'Acme Corp',
  industry: 'it_software',
  hrContactE164: '+919876543210',
  hrMail: 'hr@acme.test',
);

void main() {
  group('EmployerAuthRemoteDataSource.login', () {
    test('scrapes the student-account-used-on-employer-portal message from the form-error block', () async {
      const html = '''
<div class="alert alert-danger" style="border-radius: 12px; font-size: 0.85rem; padding: 12px;">
    <div>
        <i class="fas fa-exclamation-circle me-2"></i>
        Student accounts cannot log in through the employer portal.
    </div>
</div>
''';
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: html);
      final datasource = EmployerAuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.login(usernameOrEmail: 'student1', password: 'secret'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Student accounts cannot log in through the employer portal.',
          ),
        ),
      );
    });

    test('falls back to the generic message when the form-error block is absent (never a guess)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: '<html><body>Something else</body></html>');
      final datasource = EmployerAuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.login(usernameOrEmail: 'user', password: 'wrong'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Invalid username or password, or this account cannot sign in through the employer portal.',
          ),
        ),
      );
    });
  });

  group('EmployerAuthRemoteDataSource.register', () {
    test('scrapes the unverified-email message from its field-error block', () async {
      const html = '''
<div class="invalid-feedback d-block">Verify this email address with the OTP to continue.</div>
''';
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: html);
      final datasource = EmployerAuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.register(_buildRegistrationData()),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Verify this email address with the OTP to continue.',
          ),
        ),
      );
    });

    test('falls back to the generic message when no recognizable field error is present (never a guess)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: '<html><body>Something else</body></html>');
      final datasource = EmployerAuthRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.register(_buildRegistrationData()),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Registration failed — please check your details (including both email OTP '
                'verifications) and try again.',
          ),
        ),
      );
    });
  });
}
