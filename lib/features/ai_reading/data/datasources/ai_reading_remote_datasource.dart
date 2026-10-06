import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/reading_analysis_result.dart';
import '../models/reading_analysis_result_model.dart';

/// `POST /activities/exercise/<id>/analyze/reading/`
/// (`activities/views.py:1916-1969`) — see `ApiEndpoints.analyzeReading`'s
/// doc comment. `@login_required @require_POST`, **not** `@csrf_exempt`,
/// so this reads the `csrftoken` cookie and sends it as `X-CSRFToken`,
/// mirroring `AiSpeakingRemoteDataSource`.
///
/// `text`/`client_transcript` are deliberately sent as empty strings —
/// same reasoning as `AiSpeakingRemoteDataSource`: the web's live browser
/// transcript (`transcriptFinal`/`transcriptInterim`, from
/// `SpeechRecognition`) has no Flutter equivalent, and
/// `ReadingAgent.run()`'s `choose_best_transcript([text, client_transcript,
/// stt_text], reference_text)` prefers the server's own Sarvam
/// speech-to-text (`stt_text`) whenever it succeeds — the client fields are
/// a fallback only, not the primary source, so omitting them does not
/// change the authoritative result in the normal case.
class AiReadingRemoteDataSource {
  AiReadingRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<ReadingAnalysisResult> analyze({
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
        'audio': await MultipartFile.fromFile(audioFilePath, filename: 'reading.m4a'),
        'text': '',
        'client_transcript': '',
        'reference_text': referenceText,
        'duration_seconds': durationSeconds.toString(),
        'pause_count': pauseCount.toString(),
        'language': language,
      });
      final response = await _apiClient.dio.post(
        ApiEndpoints.analyzeReading(exerciseId),
        data: formData,
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) throw const UnexpectedResponseException();

      // Same contract as analyzeSpeaking: a rejected submission (e.g. too
      // short, or too dissimilar from the passage — a reading-specific
      // <25% similarity check, `ReadingAgent.run()`) still comes back as
      // HTTP 200 — the body's own `"success"` field is authoritative.
      final success = body['success'];
      if (success != true) {
        final message = body['error'] is String ? body['error'] as String : 'Reading analysis failed.';
        throw ValidationException(const {}, message);
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return ReadingAnalysisResultParsing.fromJson(data);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }
}
