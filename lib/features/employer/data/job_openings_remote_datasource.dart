import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/job_openings.dart';
import 'job_openings_html_parser.dart';

/// `jobs_app.views.job_openings` — GET only.
class JobOpeningsRemoteDataSource {
  JobOpeningsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<JobOpeningsPage> getJobOpenings() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jobOpenings,
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      return parseJobOpeningsHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
