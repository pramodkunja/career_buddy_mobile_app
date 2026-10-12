import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/employer_profile_remote_datasource.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_profile_form.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _minimalFormHtml = '''
<button type="button" id="toggleEditBtn" class="btn btn-outline-primary">Edit Profile</button>
<input type="text" name="company_name" value="New Co" class="form-control" id="id_company_name">
<input type="text" name="industry" value="Retail" class="form-control" id="id_industry">
<select name="company_size" id="id_company_size"><option value="" selected>---------</option></select>
<input type="hidden" name="hr_contact" value="9876500000" id="id_hr_contact">
''';

const _submission = EmployerProfileSubmission(
  companyName: 'New Co',
  companyWebsite: '',
  industry: 'Retail',
  companySize: '',
  location: '',
  description: '',
  companyAddress: '',
  companyGst: '',
  companyPanTin: '',
  hrContactE164: '9876500000',
  hrMail: 'hr@example.com',
);

void main() {
  group('getProfileForm', () {
    test('parses a real 200 response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _minimalFormHtml);
      final datasource = EmployerProfileRemoteDataSource(ApiClient.forTesting(dio));

      final data = await datasource.getProfileForm(isCreate: true);

      expect(data.companyName, 'New Co');
      expect(data.industry, 'Retail');
    });
  });

  group('updateProfile', () {
    test('completes without throwing on a real 302 (redirect-on-success)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = EmployerProfileRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.updateProfile(_submission, isCreate: false), completes);
    });

    test('throws ValidationException on a 200 (form re-rendered with errors)', () async {
      // A validation-failure 200 re-renders the SAME `profile_form.html`
      // template (both views share it) with the error injected, so a
      // realistic fixture still contains the form's own distinctive markup
      // — unlike an expired-session's login-page redirect (see the
      // regression test below), which `isEmployerProfileFormHtml` now
      // exists to distinguish.
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '$_minimalFormHtml<div class="text-danger small mt-1"><ul class="errorlist">'
              '<li>Invalid GSTIN format. Must be 99AAAAA9999A1Z9.</li></ul></div>',
        );
      final datasource = EmployerProfileRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.updateProfile(_submission, isCreate: false),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('Invalid GSTIN'))),
      );
    });

    test(
      'REGRESSION (the confirmed Phase 2 defect): a 302 redirect to the employer login page must NOT be '
      'reported as success — the edit was never saved, the session had simply already expired',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = FakeHttpClientAdapter(
            statusCode: 302,
            body: '',
            headers: {
              'location': ['/employer/accounts/employer/login/?next=/employer/employer/profile/edit/'],
            },
          );
        final datasource = EmployerProfileRemoteDataSource(ApiClient.forTesting(dio));

        await expectLater(
          datasource.updateProfile(_submission, isCreate: false),
          throwsA(isA<UnauthorizedException>()),
        );
      },
    );

    test(
      'REGRESSION: a 200 that is not the real profile form at all is treated as an expired/unexpected '
      'session, not guessed at as a validation message',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: '<h1>Something else entirely</h1>');
        final datasource = EmployerProfileRemoteDataSource(ApiClient.forTesting(dio));

        await expectLater(
          datasource.updateProfile(_submission, isCreate: false),
          throwsA(isA<UnauthorizedException>()),
        );
      },
    );
  });

  group('getProfileForm — session expiry', () {
    test(
      'REGRESSION (the confirmed Phase 2 defect): an expired session\'s login-page HTML (still a 200, '
      "since Dio follows the redirect) must NOT be parsed as a blank company profile form — it must throw",
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = FakeHttpClientAdapter(
            statusCode: 200,
            body: '<form id="login-form"><input name="username"><input name="password"></form>',
          );
        final datasource = EmployerProfileRemoteDataSource(ApiClient.forTesting(dio));

        await expectLater(datasource.getProfileForm(isCreate: false), throwsA(isA<UnauthorizedException>()));
      },
    );
  });
}
