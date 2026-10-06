import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/roleplay_analysis_result.dart';
import '../../domain/entities/roleplay_generated_content.dart';
import '../models/roleplay_analysis_result_model.dart';
import '../models/roleplay_generated_content_model.dart';

/// Calls the 2 real Roleplay Workshop JSON endpoints — see
/// `ApiEndpoints.roleplayPractice`/`ApiEndpoints.analyzeRoleplay`'s doc
/// comments for the full contract, confirmed directly against
/// `activities/views.py`.
class RoleplayRemoteDataSource {
  RoleplayRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `POST /roleplay/practice/`. Neither a 400 (unknown topic / roleplay
  /// prompt missing a second character) nor a 403 (plan-gated, access
  /// denied) response reaches the parsing code below — both are non-2xx
  /// statuses Dio/`ApiExceptionsInterceptor` already converts into an
  /// `AppException` (400 -> `UnexpectedResponseException`, 403 ->
  /// `ForbiddenException`) before this method's `try` body would see them,
  /// exactly like every other endpoint in this app. Only a 200 response
  /// (always `{"topic", "used_prompt", "result": {...}}` on this endpoint —
  /// confirmed by reading the view, there is no 200 error shape) is parsed
  /// here.
  Future<RoleplayGeneratedContent> generatePractice({
    required String topicSlug,
    required String prompt,
    required String language,
  }) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({'topic': topicSlug, 'prompt': prompt, 'language': language});
      final response = await _apiClient.dio.post(
        ApiEndpoints.roleplayPractice,
        data: formData,
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return RoleplayGeneratedContentParsing.fromResponseJson(body);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }

  /// `POST /roleplay/analyze/`. Unlike [generatePractice], this endpoint is
  /// never plan-gated (confirmed: `analyze_roleplay` calls no
  /// `_can_access_workshop` check at all) and always responds 200 —
  /// `BaseAgent.safe_run`'s own `{"success", "data", "error", "meta"}`
  /// envelope is what's authoritative, the same pattern
  /// `AiSpeakingRemoteDataSource.analyze` already uses for
  /// `analyze_speaking` (same underlying `SpeakingAgent` class).
  ///
  /// [audioFilePath] is uploaded as `audio`, letting the server run its own
  /// Sarvam speech-to-text — the same substitution `AiSpeakingRemoteDataSource`
  /// already makes for `analyze_speaking`, since there is no Flutter
  /// equivalent of the web's live Web Speech API transcript. `client_transcript`
  /// is therefore always sent empty, exactly like `AiSpeakingRemoteDataSource`.
  ///
  /// [topicLabel] is the request's `topic` field — but note this is
  /// deliberately **not** the topic slug (unlike [generatePractice]'s own
  /// `topic` field). Read directly from `roleplay.html`'s JS
  /// (`formData.append("topic", promptInput.value || "{{ active_topic }}")`):
  /// on this specific call, the web sends the free-text scenario prompt the
  /// user typed (falling back to the slug only if that was empty) — it is
  /// used purely as this attempt's `ScoreRecord.label` server-side, with no
  /// effect on scoring.
  Future<RoleplayAnalysisResult> analyze({
    required String topicLabel,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({
        'topic': topicLabel,
        'audio': await MultipartFile.fromFile(audioFilePath, filename: 'recording.m4a'),
        'duration_seconds': durationSeconds.toString(),
        'pause_count': pauseCount.toString(),
        'client_transcript': '',
        'language': language,
        'reference_text': referenceText,
      });
      final response = await _apiClient.dio.post(
        ApiEndpoints.analyzeRoleplay,
        data: formData,
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) throw const UnexpectedResponseException();

      final success = body['success'];
      if (success != true) {
        final message = body['error'] is String ? body['error'] as String : 'Roleplay analysis failed.';
        throw ValidationException(const {}, message);
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return RoleplayAnalysisResultParsing.fromJson(data);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }
}
