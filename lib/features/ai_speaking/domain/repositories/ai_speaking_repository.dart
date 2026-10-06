import '../../../../core/utils/result.dart';
import '../entities/speaking_analysis_result.dart';

abstract class AiSpeakingRepository {
  /// Mirrors `analyzeRecording()`'s exact request fields
  /// (`static/activities/js/speaking.js:366-388`):
  /// `audio` (the recorded file), `duration_seconds`, `pause_count`,
  /// `client_transcript` (always empty — see
  /// `AiSpeakingRemoteDataSource`'s doc comment for why), `language`, and
  /// `reference_text` (the topic prompt).
  Future<Result<SpeakingAnalysisResult>> analyze({
    required int exerciseId,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  });
}
