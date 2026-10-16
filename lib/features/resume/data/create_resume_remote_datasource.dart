import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/create_resume_draft_summary.dart';
import '../domain/entities/create_resume_outcomes.dart';
import '../domain/entities/create_resume_state.dart';
import 'create_resume_page_preview_parser.dart';
import 'create_resume_pdf_parser.dart';
import 'create_resume_preview_parser.dart';

/// `career_app.create_resume_views` — Phase 39. Standard Django CSRF
/// applies to every POST here (no `@csrf_exempt`, confirmed directly), so
/// every call primes the `csrftoken` cookie first, same convention as
/// [ResumeRemoteDataSource]'s own manual-resume calls. Reuses
/// [ApiEndpoints.resumeBuilderHome] purely to set that cookie (a CSRF
/// cookie is domain-wide, not path-specific) — no response content from
/// that page is read here, exactly as already established for the Manual
/// builder's own priming call.
class CreateResumeRemoteDataSource {
  CreateResumeRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<void> _ensureCsrfCookie() async {
    if (await _apiClient.readCookie('csrftoken') != null) return;
    await _apiClient.dio.get(ApiEndpoints.resumeBuilderHome);
  }

  Future<Map<String, String>> _csrfHeaders() async {
    await _ensureCsrfCookie();
    final token = await _apiClient.readCookie('csrftoken');
    return {'X-CSRFToken': token ?? ''};
  }

  /// `preview_api` — unlike every other call below, a 400/429 here still
  /// means "unreadable payload"/"rate limited" (confirmed directly,
  /// `_read()`/`_limited()` run before `normalize()`), never a validation
  /// rejection; `validateStatus: true` lets [parseCreateResumePreviewResponse]
  /// read whichever shape actually came back instead of this throwing.
  Future<CreateResumePreviewOutcome> preview(
    CreateResumeFormState state,
  ) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.createResumePreview,
        data: state.toRequestJson(),
        options: Options(
          contentType: 'application/json',
          headers: await _csrfHeaders(),
          validateStatus: (_) => true,
        ),
      );
      final outcome = parseCreateResumePreviewResponse(response.data);
      if (outcome == null) throw const UnexpectedResponseException();
      return outcome;
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  Future<CreateResumePagePreviewOutcome> pagePreview(
    CreateResumeFormState state,
  ) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.createResumePages,
        data: state.toRequestJson(),
        options: Options(
          contentType: 'application/json',
          headers: await _csrfHeaders(),
          validateStatus: (_) => true,
        ),
      );
      final outcome = parseCreateResumePagePreviewResponse(response.data);
      if (outcome == null) throw const UnexpectedResponseException();
      return outcome;
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  /// Requested as `ResponseType.bytes` since a genuine success is raw PDF
  /// bytes, never JSON — but a rejection is still delivered through the
  /// same bytes channel (Dio applies the requested `responseType` to error
  /// bodies too), so [parseCreateResumePdfResponse] decides which shape it
  /// actually received.
  Future<CreateResumePdfOutcome> generatePdf(
    CreateResumeFormState state,
  ) async {
    try {
      final response = await _apiClient.dio.post<List<int>>(
        ApiEndpoints.createResumePdf,
        data: state.toRequestJson(),
        options: Options(
          contentType: 'application/json',
          headers: await _csrfHeaders(),
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );
      final outcome = parseCreateResumePdfResponse(
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

  /// `drafts_list` — `@login_required`. No `validateStatus` override: a 401
  /// (session expired) is left to the existing global interceptor to map to
  /// [UnauthorizedException]/`UnauthorizedFailure`, the same generic
  /// "please sign in again" message every other authenticated endpoint in
  /// this app already surfaces, rather than re-parsing this endpoint's own
  /// `_json_login_required` message specially.
  Future<List<CreateResumeDraftSummary>> listDrafts() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.createResumeDrafts,
      );
      final rawDrafts = response.data?['drafts'];
      if (rawDrafts is! List) throw const UnexpectedResponseException();
      return rawDrafts
          .whereType<Map<String, dynamic>>()
          .map(CreateResumeDraftSummary.fromJson)
          .toList();
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  Future<CreateResumeFormState> loadDraft(int id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.createResumeDraft(id),
      );
      final data = response.data?['data'];
      final draft = response.data?['draft'];
      if (data is! Map<String, dynamic> || draft is! Map<String, dynamic>) {
        throw const UnexpectedResponseException();
      }
      return CreateResumeFormState.fromDraftData(
        data,
        draftId: draft['id'] as int?,
      );
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  /// `draft_save` — `{id, data}`; `id` omitted (not merely `null`) creates
  /// a new draft, confirmed directly (`raw.get('id')` — a present `null`
  /// and an absent key behave identically in Python, so sending `null`
  /// here is equally correct, simpler than conditionally omitting the key).
  /// `validateStatus: true` so the one genuinely meaningful 400 this
  /// endpoint can return — the `ResumeDraft.MAX_PER_USER` (20) limit,
  /// confirmed directly — surfaces its real server message via
  /// [ValidationException] instead of a generic fallback; any other 400
  /// here would mean this app sent a malformed payload, a real bug, so it
  /// still falls through to [UnexpectedResponseException].
  Future<int> saveDraft(CreateResumeFormState state) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.createResumeDraftSave,
        data: {'id': state.draftId, 'data': state.toRequestJson()},
        options: Options(
          contentType: 'application/json',
          headers: await _csrfHeaders(),
          validateStatus: (status) =>
              status != null && (status == 200 || status == 400),
        ),
      );
      if (response.statusCode == 400) {
        final errors = response.data?['errors'];
        final message =
            errors is List && errors.isNotEmpty && errors.first is Map
            ? (errors.first as Map)['message'] as String?
            : null;
        throw ValidationException(
          const {},
          message ?? 'The resume could not be saved. Please try again.',
        );
      }
      final draft = response.data?['draft'];
      final id = draft is Map<String, dynamic> ? draft['id'] : null;
      if (id is! int) throw const UnexpectedResponseException();
      return id;
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }

  Future<void> deleteDraft(int id) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.createResumeDraftDelete(id),
        options: Options(headers: await _csrfHeaders()),
      );
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : const UnexpectedResponseException();
    }
  }
}
