import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/employer_dashboard_summary.dart';
import 'employer_dashboard_html_parser.dart';

/// `jobs_app.views.employer_dashboard` — plain server-rendered HTML, no
/// JSON API (see `ApiEndpoints.employerDashboard`'s doc comment). Dio's
/// default `followRedirects: true` is relied on here (unlike the login
/// datasources, which deliberately turn it off to *detect* a redirect):
/// this call needs to land on whatever page the server actually decided to
/// send the session to and read its final path, exactly like a browser
/// would.
class EmployerDashboardRemoteDataSource {
  EmployerDashboardRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<EmployerDashboardSummary> getDashboard() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.employerDashboard,
        options: Options(responseType: ResponseType.plain),
      );

      final finalPath = response.realUri.path;
      if (finalPath.contains('employer/login')) {
        throw const UnauthorizedException();
      }
      if (finalPath.contains('profile/create')) {
        throw const EmployerProfileIncompleteException();
      }
      return parseEmployerDashboardHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jobs_app.views.job_delete` — POST-only; 302s back to
  /// [ApiEndpoints.employerDashboard] whether or not anything was actually
  /// deleted (no distinct failure response exists to detect — a 404 is the
  /// only real failure mode, for a `pk` outside the caller's own jobs/
  /// seeded jobs).
  Future<void> deleteJob(int jobId) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.employerJobDelete(jobId),
        data: FormData.fromMap({'csrfmiddlewaretoken': csrfToken ?? ''}),
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );
      if (response.statusCode == 302) return;
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
