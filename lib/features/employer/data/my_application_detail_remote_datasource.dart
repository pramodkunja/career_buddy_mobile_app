import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/my_application_detail.dart';
import 'my_application_detail_html_parser.dart';

/// `jobs_app.views.my_application_detail` — GET only, read-only.
class MyApplicationDetailRemoteDataSource {
  MyApplicationDetailRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<MyApplicationDetail> getApplicationDetail(int applicationId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.myApplicationDetail(applicationId),
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      return parseMyApplicationDetailHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
