import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/public_job_detail_remote_datasource.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/public_job_detail.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _minimalDetailHtml = '''
<h3 class="fw-bold mb-0">Backend Engineer</h3>
<span class="text-muted">Acme Corp</span>
<h5 class="fw-bold mb-3">Job Description</h5>
<p>Join our team.</p>
<h5 class="fw-bold mt-4 mb-3">Requirements</h5>
<p>None listed.</p>
''';

const _submission = PublicJobApplicationSubmission(
  name: 'Alex Kumar',
  email: 'alex@example.com',
  phoneE164: '+919876543210',
);

void main() {
  group('getJobDetail', () {
    test('parses a real 200 response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _minimalDetailHtml);
      final datasource = PublicJobDetailRemoteDataSource(ApiClient.forTesting(dio));

      final detail = await datasource.getJobDetail(68);

      expect(detail.title, 'Backend Engineer');
    });
  });

  group('apply', () {
    test('completes without throwing on a real 302 (redirect-on-success)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = PublicJobDetailRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.apply(68, _submission), completes);
    });

    test('throws ValidationException with the duplicate-application flash message on a 200', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<div class="alert alert-danger alert-dismissible fade show toast-message" role="alert">'
              '<i class="fas fa-exclamation-circle me-2"></i>'
              'You have already applied for this job.'
              '<button type="button" class="btn-close"></button></div>',
        );
      final datasource = PublicJobDetailRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.apply(68, _submission),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('already applied'))),
      );
    });

    test('throws ValidationException with a per-field error on a 200', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<div class="text-danger small mt-1"><ul class="errorlist"><li>This field is required.</li></ul></div>',
        );
      final datasource = PublicJobDetailRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.apply(68, _submission),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('required'))),
      );
    });
  });
}
