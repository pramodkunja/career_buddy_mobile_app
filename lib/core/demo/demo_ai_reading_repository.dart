import '../../features/ai_reading/domain/entities/reading_analysis_result.dart';
import '../../features/ai_reading/domain/entities/reading_issue.dart';
import '../../features/ai_reading/domain/repositories/ai_reading_repository.dart';
import '../utils/result.dart';
import 'demo_progress_store.dart';

/// `AiReadingRepository` that returns a realistic, hardcoded
/// [ReadingAnalysisResult] after a short simulated delay instead of calling
/// the real `analyze_reading` endpoint — purely for local UI/flow testing.
/// Never claims to be server-authoritative and is never wired into
/// production/API code paths; see `demo_mode.dart`.
class DemoAiReadingRepository implements AiReadingRepository {
  @override
  Future<Result<ReadingAnalysisResult>> analyze({
    required int exerciseId,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    const score25 = 22;
    DemoProgressStore.instance.recordAttempt(exerciseId, score: score25, maxScore: 25);

    return Success(
      ReadingAnalysisResult(
        text: referenceText.isEmpty ? 'This is a demo of the reference passage you read aloud.' : referenceText,
        issues: const [
          ReadingIssue(
            phrase: 'schedule',
            type: 'Pronunciation',
            message: 'This word was slightly mispronounced.',
            suggestion: 'SHED-yool',
          ),
        ],
        improvedPassage: 'This is a demo of the passage read with corrected pronunciation and pacing.',
        feedback: 'Clear and steady reading overall, with just one word to work on.',
        quickTip: 'Slow down slightly on longer words to improve pronunciation accuracy.',
        scores: const {'accuracy': 86, 'pronunciation': 84, 'relevance': 95, 'overall': 88},
        score25: score25,
      ),
    );
  }
}
