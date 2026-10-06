import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/employer_all_applications.dart';
import 'employer_all_applications_html_parser.dart';

/// `jobs_app.views.all_applications` — GET only, server-filtered by
/// `?q=`/`?status=`/`?source=` (all optional, all empty means "everything").
class EmployerAllApplicationsRemoteDataSource {
  EmployerAllApplicationsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<EmployerAllApplicationsPage> getApplications({
    String query = '',
    String statusFilter = '',
    String sourceFilter = '',
  }) async {
    try {
      final params = <String, String>{
        if (query.isNotEmpty) 'q': query,
        if (statusFilter.isNotEmpty) 'status': statusFilter,
        if (sourceFilter.isNotEmpty) 'source': sourceFilter,
      };
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.employerAllApplications,
        queryParameters: params.isEmpty ? null : params,
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      return parseEmployerAllApplicationsHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
