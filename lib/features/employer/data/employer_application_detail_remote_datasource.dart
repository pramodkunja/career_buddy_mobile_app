import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/employer_application_detail.dart';
import 'employer_application_detail_html_parser.dart';

/// `jobs_app.views.application_detail` — plain server-rendered HTML, no
/// JSON API. Same conventions as `EmployerDashboardRemoteDataSource`: GET
/// relies on Dio's default `followRedirects: true` so `response.realUri`
/// reflects wherever the server actually landed (e.g. the employer login
/// page if the session expired); POST follows the same CSRF/302-success
/// pattern used by every other mutating call in this app.
class EmployerApplicationDetailRemoteDataSource {
  EmployerApplicationDetailRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<EmployerApplicationDetail> getApplicationDetail(int applicationId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.employerApplicationDetail(applicationId),
        options: Options(responseType: ResponseType.plain),
      );

      final finalPath = response.realUri.path;
      if (finalPath.contains('employer/login')) {
        throw const UnauthorizedException();
      }
      return parseEmployerApplicationDetailHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `ApplicationStatusForm` (`jobs_app/forms.py:225-232`) — `status`/
  /// `employer_notes` only; a real status change triggers a real,
  /// candidate-facing notification email server-side
  /// (`notify_candidate_status_change`, `jobs_app/views.py:697-700`), so
  /// this call is genuinely consequential, not a read-only convenience.
  Future<void> updateStatus({
    required int applicationId,
    required String status,
    required String employerNotes,
  }) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.employerApplicationDetail(applicationId),
        data: {
          'status': status,
          'employer_notes': employerNotes,
          'csrfmiddlewaretoken': csrfToken ?? '',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      // The view 302s back to this same URL on success (`jobs_app/views.py
      // :703`) — same redirect-on-success convention used throughout this
      // app.
      if (response.statusCode == 302) return;
      if (response.statusCode == 200) {
        const message = 'Could not update the application — please check the status and try again.';
        throw const ValidationException({'status': [message]}, message);
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
