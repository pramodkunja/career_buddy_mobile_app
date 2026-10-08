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

  group('downloadCsvBytes', () {
    test('returns the raw CSV bytes on a successful response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: 'Name,Email\r\nJordan Lee,jordan@example.com\r\n');
      final datasource = EmployerCandidateSearchRemoteDataSource(ApiClient.forTesting(dio));

      final bytes = await datasource.downloadCsvBytes(query: 'python');

      expect(String.fromCharCodes(bytes), contains('Jordan Lee'));
    });

    test('sends only the non-empty q/location/experience params, same as search', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: '', onRequest: (o) => captured = o);
      final datasource = EmployerCandidateSearchRemoteDataSource(ApiClient.forTesting(dio));

      await datasource.downloadCsvBytes(query: 'python', location: '', experience: '3-5');

      expect(captured!.queryParameters, {'q': 'python', 'experience': '3-5'});
    });
  });
}
