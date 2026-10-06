import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/employer_job_applications.dart';
import 'employer_job_applications_html_parser.dart';

/// `jobs_app.views.job_applications` — GET only, server-filtered by
/// `?status=` (empty/omitted means "all"). Live-verified against a real
/// job with 4 real applications.
class EmployerJobApplicationsRemoteDataSource {
  EmployerJobApplicationsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<EmployerJobApplicationsPage> getApplications(int jobId, {String statusFilter = ''}) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.employerJobApplications(jobId),
        queryParameters: statusFilter.isEmpty ? null : {'status': statusFilter},
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      return parseEmployerJobApplicationsHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
