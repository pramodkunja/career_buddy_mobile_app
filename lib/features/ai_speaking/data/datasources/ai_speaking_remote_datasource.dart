import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/speaking_analysis_result.dart';
import '../models/speaking_analysis_result_model.dart';

/// `POST /activities/exercise/<id>/analyze/speaking/`
/// (`activities/views.py:1629-1685`) — see `ApiEndpoints.analyzeSpeaking`'s
/// doc comment for the full contract. Unlike the mock-quiz family, this
/// endpoint is **not** `@csrf_exempt`, so — mirroring
/// `McqExerciseRemoteDataSource.submitMcqExercise`/
/// `ActivitiesRemoteDataSource.markSubComplete` — this reads the
/// already-set `csrftoken` cookie and sends it as `X-CSRFToken`.
///
/// [clientTranscript] is always sent as an empty string. The web's own
/// `SpeakingAgent.run` (`activities/agents/speaking.py:20-41`) only ever
/// uses it as a **fallback** when server-side transcription
/// (`transcribe_with_sarvam`, run against the uploaded [audioFilePath]
/// itself) fails or is unavailable — `choose_best_transcript([stt_text,
/// client_transcript], ...)` prefers `stt_text` whenever it's non-empty.
/// The client transcript on web comes from the browser's Web Speech API,
/// which has no Flutter/mobile equivalent without a dedicated
/// speech-to-text package; since it is not the primary transcription
/// source, omitting it does not change the authoritative result in the
/// normal case (server STT succeeds) and only removes a *fallback* in the
/// rare case server STT itself fails — documented as a known limitation,
/// not silently dropped.
class AiSpeakingRemoteDataSource {
  AiSpeakingRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<SpeakingAnalysisResult> analyze({
    required int exerciseId,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(audioFilePath, filename: 'recording.m4a'),
        'duration_seconds': durationSeconds.toString(),
        'pause_count': pauseCount.toString(),
        'client_transcript': '',
        'language': language,
        'reference_text': referenceText,
      });
      final response = await _apiClient.dio.post(
        ApiEndpoints.analyzeSpeaking(exerciseId),
        data: formData,
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) throw const UnexpectedResponseException();

      // Unlike every other endpoint in this app, a rejected submission
      // (e.g. no meaningful speech detected) still comes back as HTTP 200
      // — `BaseAgent.safe_run`/the view both return `JsonResponse(result)`
      // with no status override — so `"success"` in the body, not the
      // HTTP status, is what's authoritative here.
      final success = body['success'];
      if (success != true) {
        final message = body['error'] is String ? body['error'] as String : 'Speaking analysis failed.';
        throw ValidationException(const {}, message);
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return SpeakingAnalysisResultParsing.fromJson(data);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }
}
