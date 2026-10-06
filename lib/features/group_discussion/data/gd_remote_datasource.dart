import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/gd_report.dart';
import '../domain/entities/gd_session_summary.dart';
import '../domain/entities/gd_started_session.dart';
import 'gd_report_html_parser.dart';

/// `GD_app.views` — see `ApiEndpoints`'s Group Discussion doc comments for
/// each path's full, source-confirmed contract. The live discussion itself
/// is **not** here — that's `GdWebSocketService`; this datasource only
/// covers the 3 plain-HTTP calls (create a session, list past sessions,
/// read a past session's report).
class GdRemoteDataSource {
  GdRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `GD_app:create_session`. Primes the `csrftoken` cookie with a GET of
  /// [ApiEndpoints.gdHome] first (same technique as
  /// `ResumeRemoteDataSource`/`RoleplayRemoteDataSource`'s CSRF priming),
  /// then follows the exact 302-redirect-carries-the-answer shape
  /// `EmployerAuthRemoteDataSource.login` already established for a Django
  /// view that never returns JSON: `followRedirects: false` +
  /// `validateStatus: (_) => true` so the `Location` header itself (not a
  /// followed body) is what's read.
  Future<GdStartedSession> createSession(String topic) async {
    try {
      await _apiClient.dio.get(ApiEndpoints.gdHome);
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post(
        ApiEndpoints.gdCreateSession,
        data: {'topic': topic, 'csrfmiddlewaretoken': csrfToken ?? ''},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode != 302) {
        // `validateStatus: (_) => true` above means a genuine server error
        // here would otherwise sail past `ApiExceptionsInterceptor`
        // entirely (it never sees a "bad" response to map) — map it
        // explicitly here instead, same reasoning as
        // `EmployerAuthRemoteDataSource.login`'s own `else throw
        // ServerException(...)` fallback for this exact
        // followRedirects-off / validateStatus-always-true shape.
        final statusCode = response.statusCode;
        if (statusCode != null && statusCode >= 500) throw ServerException(statusCode);
        throw const UnexpectedResponseException();
      }

      final location = response.headers.value('location') ?? '';
      if (location.contains('/activities/') && location.contains('locked=1')) {
        throw const ForbiddenException('Group Discussion is not available on your current plan.');
      }
      final match = RegExp(r'/gd/room/(\d+)/').firstMatch(location);
      if (match == null) throw const UnexpectedResponseException();
      return GdStartedSession(sessionId: int.parse(match.group(1)!), topic: topic);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `GD_app:api_sessions`.
  Future<List<GdSessionSummary>> getSessions() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(ApiEndpoints.gdApiSessions);
      final sessions = response.data?['sessions'];
      if (sessions is! List) throw const UnexpectedResponseException();
      return sessions.map((e) => GdSessionSummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `GD_app:session_report`.
  Future<GdReport?> getSessionReport(int sessionId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.gdSessionReport(sessionId),
        options: Options(responseType: ResponseType.plain),
      );
      return parseGdReportHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
