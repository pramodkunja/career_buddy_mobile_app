import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/my_application_detail_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _html = '''
<span class="badge mb-3">Application #9</span>
<h1 class="fw-bold mb-1">Backend Engineer</h1>
<p class="mb-4">Career Buddy Partner</p>
<span class="badge px-3 py-2 rounded-pill bg-primary-subtle text-primary border border-primary-subtle">Applied</span>
<div>Applied on</div><div>1 Oct 2026, 08:00</div>
<div>Last updated</div><div>1 Oct 2026, 08:00</div>
<div>Applied as</div><div>Jordan Lee &middot; jordan@example.com</div>
<div>Job type</div><div>Internship &middot; Fresher</div>
''';

void main() {
  test('getApplicationDetail parses a real 200 response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _html);
    final datasource = MyApplicationDetailRemoteDataSource(ApiClient.forTesting(dio));

    final detail = await datasource.getApplicationDetail(9);

    expect(detail.jobTitle, 'Backend Engineer');
    expect(detail.status, 'applied');
  });
}
