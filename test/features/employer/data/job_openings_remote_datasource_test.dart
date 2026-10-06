import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/job_openings_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _html = '''
<div class="job-card-col" data-seeded="false">
  <h6 class="fw-bold mb-0 text-truncate text-slate-900" title="QA Engineer">QA Engineer</h6>
  <a href="/employer/jobs/5/" class="apply-btn d-block text-center text-decoration-none">View Job Description</a>
</div>
''';

void main() {
  test('getJobOpenings parses a real 200 response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _html);
    final datasource = JobOpeningsRemoteDataSource(ApiClient.forTesting(dio));

    final page = await datasource.getJobOpenings();

    expect(page.jobs.single.title, 'QA Engineer');
    expect(page.jobs.single.jobId, 5);
  });
}
