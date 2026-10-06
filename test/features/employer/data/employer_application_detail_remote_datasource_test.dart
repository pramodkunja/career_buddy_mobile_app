import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/employer_application_detail_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _minimalDetailHtml = '''
<h2 class="fw-extrabold text-slate-900 mb-1" style="font-size: 2rem;">Alex Kumar</h2>
<span class="badge mb-2"><i class="fas fa-briefcase me-2"></i> Applicant for Backend Engineer</span>
<span><i class="fas fa-envelope me-1.5 text-slate-400"></i> alex@example.com</span>
<span><i class="fas fa-phone me-1.5 text-slate-400"></i> 9123456780</span>
<div class="info-label">Experience</div><div class="info-value">0 Year(s)</div>
<div class="info-label">Current Company</div><div class="info-value">N/A</div>
<div class="info-label">Current Salary</div><div class="info-value">N/A</div>
<div class="info-label">Expected Salary</div><div class="info-value">N/A</div>
<select name="status" id="id_status"><option value="applied" selected>Applied</option></select>
<textarea name="employer_notes" id="id_employer_notes"></textarea>
<small class="text-slate-500">Applied on 1 Oct 2026, 08:00</small>
''';

void main() {
  group('getApplicationDetail', () {
    test('parses a real 200 response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _minimalDetailHtml);
      final datasource = EmployerApplicationDetailRemoteDataSource(ApiClient.forTesting(dio));

      final detail = await datasource.getApplicationDetail(42);

      expect(detail.applicantName, 'Alex Kumar');
      expect(detail.status, 'applied');
    });
  });

  group('updateStatus', () {
    test('completes without throwing on a real 302 (redirect-on-success)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = EmployerApplicationDetailRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.updateStatus(applicationId: 42, status: 'reviewing', employerNotes: 'test'),
        completes,
      );
    });

    test('throws ValidationException on a 200 (form re-rendered with errors)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: '<html></html>');
      final datasource = EmployerApplicationDetailRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.updateStatus(applicationId: 42, status: 'reviewing', employerNotes: 'test'),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
