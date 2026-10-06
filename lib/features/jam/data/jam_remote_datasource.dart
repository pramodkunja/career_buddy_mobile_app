import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/jam_assessment.dart';
import '../domain/entities/jam_history_profile.dart';
import '../domain/entities/jam_session_result.dart';
import '../domain/entities/jam_session_start.dart';
import '../domain/entities/jam_topic.dart';
import 'jam_html_parser.dart';

/// `jam_app.views` — JAM ("Just A Minute"). Server-rendered HTML for every
/// call here except [saveAudio] (see `ApiEndpoints`'s doc comment on these
/// paths for the full contract of each). HTML calls use
/// `ResponseType.plain` and hand the raw body to `jam_html_parser.dart` —
/// the same reuse-of-an-already-fetched-page technique `ResumeRemoteDataSource`
/// already established for Resume Parsing/ATS.
class JamRemoteDataSource {
  JamRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `jam:topics`.
  Future<List<JamTopic>> getTopics() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jamTopics,
        options: Options(responseType: ResponseType.plain),
      );
      return parseJamTopicsHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:jam_session` ([topicId] `null`) / `jam:jam_session_topic`
  /// ([topicId] set) — both GET, neither `@csrf_exempt` needed since
  /// neither is a POST. Rendering `session.html` also primes the
  /// `csrftoken` cookie (`{% csrf_token %}` is printed into the page's own
  /// inline script, `session.html:194`) for the later [saveAudio] POST.
  Future<JamSessionStart> startSession({int? topicId}) async {
    try {
      final path = topicId == null ? ApiEndpoints.jamSessionStart : ApiEndpoints.jamSessionStartWithTopic(topicId);
      final response = await _apiClient.dio.get<String>(path, options: Options(responseType: ResponseType.plain));
      final html = response.data ?? '';
      final parsed = parseJamSessionStartHtml(html);
      if (parsed == null) {
        throw const ValidationException({}, 'No topics are available right now. Please try again later.');
      }
      return parsed;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:save_audio`. [transcript] is always sent as an empty string by
  /// this client — the web's own transcript comes from the browser's Web
  /// Speech API, which has no Flutter/mobile equivalent; the server already
  /// falls back to its own Sarvam STT transcription of the uploaded
  /// [audioFilePath] whenever `transcript` arrives empty and
  /// `SARVAM_API_KEY` is configured (`save_audio`, `jam_app/views.py:
  /// 214-220`, re-verified directly against source), so omitting a client
  /// transcript does not change the authoritative result in the normal
  /// case — the same reasoning already documented for
  /// `AiSpeakingRemoteDataSource.analyze`'s `client_transcript`.
  Future<void> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  }) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({
        'session_id': sessionId.toString(),
        'duration': durationSeconds.toString(),
        'transcript': transcript,
        'language': language,
        if (audioFilePath != null)
          'audio': await MultipartFile.fromFile(audioFilePath, filename: 'session_$sessionId.m4a'),
      });
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.jamSaveAudio,
        data: formData,
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );

      // A non-2xx (the `session_id` not found case, HTTP 404) already threw
      // a `DioException` above, mapped to `NotFoundException` by the shared
      // interceptor — this only needs to guard the 2xx-but-unexpected-body
      // shape.
      final body = response.data;
      if (body?['status'] != 'ok') throw const UnexpectedResponseException();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:complete_session` — a GET that redirects to `jam:session_detail`
  /// (see `ApiEndpoints.jamCompleteSession`'s doc comment). Dio's default
  /// `followRedirects: true` lands this call's response directly on the
  /// final `session_detail.html` page.
  Future<JamSessionResult> completeSession(int sessionId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jamCompleteSession(sessionId),
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data ?? '';
      final parsed = parseJamSessionResultHtml(html, sessionId);
      if (parsed == null) throw const UnexpectedResponseException();
      return parsed;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:history` — used only to derive Assessment eligibility client-side
  /// (see `ApiEndpoints.jamHistory`'s doc comment and
  /// `computeJamAssessmentEligibility`).
  Future<List<JamPracticeSessionSummary>> getHistory() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jamHistory,
        options: Options(responseType: ResponseType.plain),
      );
      return parseJamHistoryHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:start_assessment` — GET, redirects to stage 1's `session.html`
  /// on success (see `ApiEndpoints.jamAssessmentStart`'s doc comment for
  /// the full contract, including the ineligible-redirect-to-dashboard
  /// case handled defensively here).
  Future<JamSessionStart> startAssessment() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jamAssessmentStart,
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data ?? '';
      final parsed = parseJamAssessmentStageHtml(html);
      if (parsed == null) {
        throw const ValidationException(
          {},
          'Complete one Easy, one Medium, and one Hard practice session before starting the assessment.',
        );
      }
      return parsed;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:complete_session` for a session known (client-side) to be one
  /// stage of the Assessment flow — same endpoint/redirect-following as
  /// [completeSession], but parses the 3-way outcome described on
  /// [JamAssessmentStageOutcome] instead of assuming a normal
  /// `session_detail.html` landing (see `ApiEndpoints.jamCompleteSession`'s
  /// doc comment for why these are two separate parses of the same URL).
  Future<JamAssessmentStageOutcome> completeAssessmentStage(int sessionId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jamCompleteSession(sessionId),
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data ?? '';

      final finalResult = parseJamAssessmentResultHtml(html);
      if (finalResult != null) return JamAssessmentFinished(finalResult);

      final nextStage = parseJamAssessmentStageHtml(html);
      if (nextStage != null) return JamAssessmentNextStage(nextStage);

      throw const UnexpectedResponseException();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:history` — the full page (both tabs), for the History screen.
  /// Separate from [getHistory] (eligibility-only) rather than changing
  /// that method's return shape — see `JamAssessmentRepository`'s doc
  /// comment for the same reasoning applied one level up.
  Future<JamHistoryPage> getHistoryPage() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jamHistory,
        options: Options(responseType: ResponseType.plain),
      );
      return parseJamHistoryPageHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:session_detail` — pure read, for revisiting a past,
  /// already-completed session from History. Deliberately **not**
  /// [completeSession]/`jam:complete_session`, which mutates the session
  /// (marks it completed, regenerates AI feedback) — calling that on an
  /// already-completed session would silently overwrite its real feedback
  /// every time someone viewed it from History.
  Future<JamSessionResult> getSessionDetail(int sessionId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jamSessionDetail(sessionId),
        options: Options(responseType: ResponseType.plain),
      );
      final parsed = parseJamSessionResultHtml(response.data ?? '', sessionId);
      if (parsed == null) throw const UnexpectedResponseException();
      return parsed;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:assessment_result` — revisiting a past, already-completed
  /// assessment from History.
  Future<JamAssessmentResult> getAssessmentResult(int assessmentId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jamAssessmentResult(assessmentId),
        options: Options(responseType: ResponseType.plain),
      );
      final parsed = parseJamAssessmentResultHtml(response.data ?? '');
      if (parsed == null) throw const UnexpectedResponseException();
      return parsed;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:delete_session` — see `ApiEndpoints.jamDeleteSession`'s doc
  /// comment.
  Future<void> deleteSession(int sessionId) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({'csrfmiddlewaretoken': csrfToken ?? ''});
      final response = await _apiClient.dio.post(
        ApiEndpoints.jamDeleteSession(sessionId),
        data: formData,
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

  /// `jam:delete_assessment` — see `ApiEndpoints.jamDeleteAssessment`'s
  /// doc comment.
  Future<void> deleteAssessment(int assessmentId) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({'csrfmiddlewaretoken': csrfToken ?? ''});
      final response = await _apiClient.dio.post(
        ApiEndpoints.jamDeleteAssessment(assessmentId),
        data: formData,
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

  /// `jam:reset_progress` — see `ApiEndpoints.jamResetProgress`'s doc
  /// comment. Destructive; the caller (`JamProfileController.resetProgress`)
  /// is responsible for confirming with the user first.
  Future<void> resetProgress() async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({'csrfmiddlewaretoken': csrfToken ?? ''});
      final response = await _apiClient.dio.post(
        ApiEndpoints.jamResetProgress,
        data: formData,
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

  /// `jam:profile` GET — see `ApiEndpoints.jamProfile`'s doc comment.
  Future<JamProfile> getProfile() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.jamProfile,
        options: Options(responseType: ResponseType.plain),
      );
      return parseJamProfileHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `jam:profile` POST — see `ApiEndpoints.jamProfile`'s doc comment for
  /// why a failed validation is indistinguishable from a silent no-op on
  /// the real web (reproduced as-is here: a 200 without a redirect is
  /// surfaced as a generic "could not save" failure, since there is no
  /// real field-level error to extract).
  Future<void> updateProfile(JamProfileUpdate data) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({
        'first_name': data.firstName,
        'last_name': data.lastName,
        'email': data.email,
        'bio': data.bio,
        'csrfmiddlewaretoken': csrfToken ?? '',
      });
      final response = await _apiClient.dio.post(
        ApiEndpoints.jamProfile,
        data: formData,
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );
      if (response.statusCode == 302) return;
      if (response.statusCode == 200) {
        throw const ValidationException({}, 'Could not save your profile — please check your details and try again.');
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
