import '../../../../core/utils/result.dart';
import '../entities/listening_analysis_result.dart';

abstract class AiListeningRepository {
  /// Fetches a fresh, single-use anti-replay `attempt_token` by requesting
  /// the existing `exercise_detail` HTML page and reading it out of the
  /// embedded `<script type="application/json" id="listening-config">`
  /// blob — the only place the server produces one; there is no JSON
  /// endpoint for it. See `AiListeningRemoteDataSource.fetchAttemptToken`.
  Future<Result<String>> fetchAttemptToken(int exerciseId);

  /// Mirrors `analyzeText()`'s exact request fields
  /// (`static/activities/js/listening.js:556-563`): `text`,
  /// `reference_text` (the story), `duration_seconds`, `pause_count`,
  /// `attempt_token`, `language`.
  Future<Result<ListeningAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String referenceText,
    required int durationSeconds,
    required int pauseCount,
    required String attemptToken,
    required String language,
  });
}
