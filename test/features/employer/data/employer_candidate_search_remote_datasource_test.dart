import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/employer/data/employer_candidate_search_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _html = '''
<div class="candidate-card p-4">
  <h5 class="fw-bold mb-1">Jordan Lee
  </h5>
  <p class="text-muted small mb-0"><i class="fas fa-map-marker-alt me-1"></i> Remote</p>
  <p class="small text-muted mb-2">Experience: <strong>Fresher</strong></p>
  <a href="mailto:jordan@example.com" class="text-muted me-3"><i class="fas fa-envelope"></i></a>
</div>
''';

void main() {
  test('search parses a real 200 response even with no filters given', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: _html);
    final datasource = EmployerCandidateSearchRemoteDataSource(ApiClient.forTesting(dio));

    final results = await datasource.search();

    expect(results.single.name, 'Jordan Lee');
  });
}
