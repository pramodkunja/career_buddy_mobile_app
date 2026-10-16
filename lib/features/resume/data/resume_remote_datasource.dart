import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/level_common_suggestions.dart';
import '../domain/entities/manual_resume_draft.dart';
import '../domain/entities/manual_resume_page_preview_outcome.dart';
import '../domain/entities/manual_resume_pdf_outcome.dart';
import '../domain/entities/manual_resume_preview_outcome.dart';
import '../domain/entities/resume_analysis.dart';
import '../domain/entities/resume_history_item.dart';
import '../domain/entities/resume_role.dart';
import '../domain/repositories/resume_repository.dart'
    show ResumeParseQuota, ResumeRoleSelection;
import 'manual_resume_page_preview_parser.dart';
import 'manual_resume_pdf_parser.dart';
import 'manual_resume_preview_parser.dart';
import 'manual_resume_preview_payload.dart';
import 'resume_html_parser.dart';
import 'resume_role_parser.dart';

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
      final message =
          parseResumeBuilderError(html) ??
          'Could not analyze this resume. Please try again.';
      throw ValidationException({
        'file': [message],
      }, message);
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
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
      final message =
          parseFlashedErrorMessage(html) ??
          'Could not re-analyze this resume. Please try again.';
      throw ValidationException({
        'resume': [message],
      }, message);
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
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
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  /// Django's CSRF cookie is only set on a response to a GET of a page
  /// that renders `{% csrf_token %}` — primes it from the upload page
  /// itself if nothing has set it yet this session.
  Future<void> _ensureCsrfCookie() async {
    if (await _apiClient.readCookie('csrftoken') != null) return;
    await _apiClient.dio.get(ApiEndpoints.resumeBuilderHome);
  }

  /// A dedicated GET of `resume_builder_home` purely to read the Free-plan
  /// usage badge — deliberately **not** reusing [_ensureCsrfCookie], which
  /// only fires conditionally (skipped whenever a CSRF cookie already
  /// exists from any earlier request this session) and must keep that
  /// behavior unchanged. This call always fires, so the count is always
  /// current — e.g. right after an analysis just changed it — regardless
  /// of cookie state. Best-effort: any failure (network, unexpected
  /// response shape) simply returns `null`, exactly like a page the
  /// parser couldn't find the badge on; this must never surface as an
  /// error to the upload screen.
  Future<ResumeParseQuota?> getParseQuota() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.resumeBuilderHome,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      return parseResumeParsesLeft(response.data ?? '');
    } catch (_) {
      return null;
    }
  }

  /// `manual_resume_roles` (Phase 22's "Option B" catalog). Unlike every
  /// other method here, this endpoint is **not** `@login_required` and
  /// returns real JSON — confirmed directly (`ApiEndpoints.manualResumeRoles`'s
  /// doc comment) — so no CSRF priming and no HTML parsing are involved.
  Future<List<ResumeRole>> getRoles() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.manualResumeRoles,
      );
      return parseManualResumeRoles(response.data);
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  /// Same endpoint as [getRoles], fetched again for its top-level
  /// `level_common` (Phase 26) — deliberately a separate request rather
  /// than changing [getRoles]'s return shape, so the already-tested Role
  /// Picker path is completely unaffected.
  Future<Map<String, LevelCommonSuggestions>>
  getLevelCommonSuggestions() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.manualResumeRoles,
      );
      return parseLevelCommon(response.data);
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  /// `manual_resume_views.preview_api` (Phase 27) — unlike [getRoles], this
  /// POST endpoint is standard-CSRF-protected (confirmed directly: no
  /// `@csrf_exempt`), so it reuses the exact same `_ensureCsrfCookie()` +
  /// `X-CSRFToken` priming as [uploadAndAnalyze]/[reanalyze]. Sent as a raw
  /// JSON body (`Content-Type: application/json`), matching `_read_state()`'s
  /// own `request.content_type == 'application/json'` branch — confirmed
  /// directly this is a different content-type than every other POST here
  /// (which all post `multipart/form-data`). `validateStatus: (_) => true`
  /// (same convention as every other method here) since a 400/429 response
  /// here is a normal, meaningful, well-formed body
  /// ([ManualResumePreviewRejected]) — never an exception on its own.
  Future<ManualResumePreviewOutcome> previewManualResume(
    ManualResumeDraft draft,
  ) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.manualResumePreview,
        data: toManualResumePreviewPayload(draft),
        options: Options(
          contentType: 'application/json',
          headers: {'X-CSRFToken': csrfToken ?? ''},
          validateStatus: (_) => true,
        ),
      );

      final outcome = parseManualResumePreviewResponse(response.data);
      if (outcome == null) throw const UnexpectedResponseException();
      return outcome;
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  /// `manual_resume_views.preview_pages_api` (Phase 28) — same request
  /// shape as [previewManualResume] (same `normalize_state()` payload, same
  /// CSRF priming, same `_prepare()`-shared rate-limit/size budget,
  /// confirmed directly) — this endpoint just renders the result to page
  /// images instead of the structured JSON document.
  Future<ManualResumePagePreviewOutcome> getManualResumePagePreview(
    ManualResumeDraft draft,
  ) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.manualResumePages,
        data: toManualResumePreviewPayload(draft),
        options: Options(
          contentType: 'application/json',
          headers: {'X-CSRFToken': csrfToken ?? ''},
          validateStatus: (_) => true,
        ),
      );

      final outcome = parseManualResumePagePreviewResponse(response.data);
      if (outcome == null) throw const UnexpectedResponseException();
      return outcome;
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  /// `manual_resume_views.pdf_download` (Phase 28). Requested as
  /// `ResponseType.bytes` since a genuine success is raw PDF bytes, never
  /// JSON (confirmed directly this app never attempts to parse PDF bytes
  /// as JSON on success) — but a rejection (validation/rate-limit/
  /// unreadable-payload/PDF-render-failure) is still delivered through the
  /// *same* bytes channel (Dio applies the requested `responseType` to
  /// error bodies too), so [parseManualResumePdfResponse] itself decides
  /// which shape it actually received, by content-type + the real `%PDF-`
  /// signature, not by HTTP status code alone.
  Future<ManualResumePdfOutcome> generateManualResumePdf(
    ManualResumeDraft draft,
  ) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post<List<int>>(
        ApiEndpoints.manualResumePdf,
        data: toManualResumePreviewPayload(draft),
        options: Options(
          contentType: 'application/json',
          headers: {'X-CSRFToken': csrfToken ?? ''},
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );

      final outcome = parseManualResumePdfResponse(
        bytes: response.data ?? const [],
        contentType: response.headers.value('content-type'),
        contentDisposition: response.headers.value('content-disposition'),
        xResumeFilenameHeader: response.headers.value('x-resume-filename'),
      );
      if (outcome == null) throw const UnexpectedResponseException();
      return outcome;
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  /// Sets `request.session['rb_role']` via `resume_builder_home`'s own
  /// `?role=&dept=&track=` query parameters (confirmed directly,
  /// `career_app/views.py`'s `_remember_target_role`) — the exact
  /// mechanism the real landing page's role-picker modal uses. Confirms
  /// success by checking the response actually echoes this selection back
  /// (`parseTargetRoleBadge`) rather than assuming a 200 status means the
  /// role was saved: an anonymous/expired session is redirected to the
  /// login page by this same view's own `@login_required` before the
  /// badge could ever render, which this treats as [UnauthorizedException]
  /// — the same failure an unrelated unexpected-page-shape would also
  /// produce, since both mean "the selection was not confirmed."
  Future<ResumeRoleSelection> selectTargetRole({
    required String role,
    required String dept,
    required String track,
  }) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.resumeBuilderHome,
        queryParameters: {'role': role, 'dept': dept, 'track': track},
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      final echoed = parseTargetRoleBadge(response.data ?? '');
      if (echoed == null || echoed.role != role || echoed.dept != dept) {
        throw const UnauthorizedException();
      }
      return echoed;
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }
}
