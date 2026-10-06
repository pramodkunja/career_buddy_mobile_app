import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/employer_profile_remote_datasource.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_profile_form.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _minimalFormHtml = '''
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
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<div class="text-danger small mt-1"><ul class="errorlist"><li>Invalid GSTIN format. Must be 99AAAAA9999A1Z9.</li></ul></div>',
        );
      final datasource = EmployerProfileRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.updateProfile(_submission, isCreate: false),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('Invalid GSTIN'))),
      );
    });
  });
}
