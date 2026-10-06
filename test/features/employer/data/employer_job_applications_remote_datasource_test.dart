import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/employer_job_applications_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _html = '''
<h1>Backend Engineer</h1>
<div class="candidate-card p-4">
  <h5 class="fw-bold text-slate-900 mb-0">Alex</h5>
  <div class="text-slate-500 small"><i class="fas fa-envelope me-1 text-slate-400"></i>alex@example.com</div>
  <div class="fw-bold text-slate-800">2 yr(s)</div>
  <span class="app-status-badge status-applied">Applied</span>
  <a href="/employer/employer/applications/5/">Review Submission</a>
</div>
''';

void main() {
  test('getApplications parses a real 200 response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _html);
    final datasource = EmployerJobApplicationsRemoteDataSource(ApiClient.forTesting(dio));

    final page = await datasource.getApplications(68);

    expect(page.jobTitle, 'Backend Engineer');
    expect(page.applications.single.applicantName, 'Alex');
  });
}
