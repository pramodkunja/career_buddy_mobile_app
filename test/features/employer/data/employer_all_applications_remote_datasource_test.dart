import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/employer_all_applications_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _html = '''
<div class="application-card p-4">
  <div class="fw-bold fs-5 text-slate-900">Alex</div>
  <div class="text-slate-500 small"><i class="fas fa-envelope me-1 text-slate-400"></i>alex@example.com</div>
  <span class="job-tag"><i class="fas fa-briefcase me-1"></i> QA Engineer</span>
  <div class="small text-slate-500"><strong>Applied:</strong> 1 Oct 2026, 09:00</div>
  <span class="app-status-badge status-applied">Applied</span>
  <a href="/employer/employer/applications/5/">Review Submission</a>
</div>
''';

void main() {
  test('getApplications parses a real 200 response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _html);
    final datasource = EmployerAllApplicationsRemoteDataSource(ApiClient.forTesting(dio));

    final page = await datasource.getApplications();

    expect(page.applications.single.applicantName, 'Alex');
    expect(page.applications.single.jobTitle, 'QA Engineer');
  });
}
