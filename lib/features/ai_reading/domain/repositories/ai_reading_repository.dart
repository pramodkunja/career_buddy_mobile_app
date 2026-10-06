import '../../../../core/utils/result.dart';
import '../entities/reading_analysis_result.dart';

abstract class AiReadingRepository {
  /// Mirrors `analyzeReading()`'s exact request fields
  /// (`static/activities/js/reading.js:1048-1056`): `text`,
  /// `client_transcript` (both always empty — see
  /// `AiReadingRemoteDataSource`'s doc comment for why), `reference_text`
  /// (the passage), `duration_seconds`, `pause_count`, `language`, and
  /// `audio` (the recorded file).
  Future<Result<ReadingAnalysisResult>> analyze({
    required int exerciseId,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  });
}
