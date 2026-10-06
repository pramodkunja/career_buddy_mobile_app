import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/resume_analysis.dart';
import '../domain/entities/resume_history_item.dart';
import 'resume_html_parser.dart';

/// `career_app.views` — Resume Parsing / ATS. Plain server-rendered HTML
/// throughout, no JSON API (see `ApiEndpoints`'s doc comment on these
/// paths). Every call here reads the response as raw HTML
/// (`ResponseType.plain`) and hands it to `resume_html_parser.dart` —
/// the same legitimate reuse-of-an-already-fetched-page technique already
/// established elsewhere in this app.
class ResumeRemoteDataSource {
  ResumeRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `resume_job_match` (`career_app/views.py:718-818`) — uploads [file]
  /// as multipart field `file` (the only field `resume_builder.html`'s
  /// own form actually submits; it has no job-description input despite
  /// the view accepting one, see `ResumeAnalysisResult.isAtsOnly`'s doc
  /// comment) and returns the result inline in the same 200 response —
  /// never a redirect, so `followRedirects` doesn't matter here.
  Future<ResumeAnalysisResult> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  }) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final formData = FormData.fromMap({
        'csrfmiddlewaretoken': csrfToken ?? '',
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _apiClient.dio.post<String>(
        ApiEndpoints.resumeJobMatch,
        data: formData,
        options: Options(
          headers: {'X-CSRFToken': csrfToken ?? ''},
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );

      final html = response.data ?? '';
      if (isResumeMatchResultHtml(html)) {
        return parseResumeMatchResultHtml(html);
      }
      final message = parseResumeBuilderError(html) ?? 'Could not analyze this resume. Please try again.';
      throw ValidationException({
        'file': [message],
      }, message);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `resume_reanalyze` (`career_app/views.py:844-896`), `@require_POST` —
  /// re-runs analysis on a resume already stored server-side; no file to
  /// re-upload. On failure the view sets a Django flash message and
  /// redirects to `resume_history` (`career_app/views.py:858-860`) rather
  /// than re-rendering inline — Dio's default `followRedirects: true`
  /// lands this call on that redirected page, so failure is detected by
  /// the *absence* of the result page's own markers, with the flashed
  /// message read back out of it.
  Future<ResumeAnalysisResult> reanalyze(int resumeId) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post<String>(
        ApiEndpoints.resumeReanalyze(resumeId),
        data: FormData.fromMap({'csrfmiddlewaretoken': csrfToken ?? ''}),
        options: Options(
          headers: {'X-CSRFToken': csrfToken ?? ''},
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );

      final html = response.data ?? '';
      if (isResumeMatchResultHtml(html)) {
        return parseResumeMatchResultHtml(html);
      }
      final message = parseFlashedErrorMessage(html) ?? 'Could not re-analyze this resume. Please try again.';
      throw ValidationException({
        'resume': [message],
      }, message);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `resume_history` (`career_app/views.py:821-841`).
  Future<List<ResumeHistoryItem>> getHistory() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.resumeHistory,
        options: Options(responseType: ResponseType.plain),
      );
      return parseResumeHistoryHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// Django's CSRF cookie is only set on a response to a GET of a page
  /// that renders `{% csrf_token %}` — primes it from the upload page
  /// itself if nothing has set it yet this session.
  Future<void> _ensureCsrfCookie() async {
    if (await _apiClient.readCookie('csrftoken') != null) return;
    await _apiClient.dio.get(ApiEndpoints.resumeBuilderHome);
  }
}
