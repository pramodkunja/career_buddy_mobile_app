import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/employer_candidate_search.dart';
import 'employer_candidate_search_html_parser.dart';

/// `jobs_app.views.search_candidates` — GET only. Unlike
/// `all_applications`/`job_applications`, an empty query still returns
/// every candidate (`search_registered_candidates('', '', '')`,
/// `jobs_app/views.py:1077-1082`) — there's no distinct "nothing searched
/// yet" server state, just whatever the current query params produce.
class EmployerCandidateSearchRemoteDataSource {
  EmployerCandidateSearchRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<EmployerCandidateSearchResult>> search({
    String query = '',
    String location = '',
    String experience = '',
  }) async {
    try {
      final params = <String, String>{
        if (query.isNotEmpty) 'q': query,
        if (location.isNotEmpty) 'location': location,
        if (experience.isNotEmpty) 'experience': experience,
      };
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.employerSearchCandidates,
        queryParameters: params.isEmpty ? null : params,
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      return parseEmployerCandidateSearchHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jobs_app.views.download_candidates_csv` — see
  /// `ApiEndpoints.employerCandidatesDownloadCsv`'s doc comment for the
  /// exact contract, including the "blank `q` ⇒ header-only CSV" behavior
  /// this intentionally does NOT work around.
  Future<List<int>> downloadCsvBytes({
    String query = '',
    String location = '',
    String experience = '',
  }) async {
    try {
      final params = <String, String>{
        if (query.isNotEmpty) 'q': query,
        if (location.isNotEmpty) 'location': location,
        if (experience.isNotEmpty) 'experience': experience,
      };
      final response = await _apiClient.dio.get<List<int>>(
        ApiEndpoints.employerCandidatesDownloadCsv,
        queryParameters: params.isEmpty ? null : params,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
