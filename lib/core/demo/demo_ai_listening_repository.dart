import '../../features/ai_listening/domain/entities/listening_analysis_result.dart';
import '../../features/ai_listening/domain/entities/listening_issue.dart';
import '../../features/ai_listening/domain/repositories/ai_listening_repository.dart';
import '../utils/result.dart';
import 'demo_progress_store.dart';

/// `AiListeningRepository` that returns a fake, single-use-looking
/// `attempt_token` and a realistic, hardcoded [ListeningAnalysisResult]
/// after a short simulated delay, instead of fetching a real token/calling
/// `analyze_listening` — purely for local UI/flow testing. Never claims to
/// be server-authoritative and is never wired into production/API code
/// paths; see `demo_mode.dart`.
class DemoAiListeningRepository implements AiListeningRepository {
  @override
  Future<Result<String>> fetchAttemptToken(int exerciseId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Success('demo-token-$exerciseId-${DateTime.now().millisecondsSinceEpoch}');
  }

  @override
  Future<Result<ListeningAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String referenceText,
    required int durationSeconds,
    required int pauseCount,
    required String attemptToken,
    required String language,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    const score25 = 20;
    DemoProgressStore.instance.recordAttempt(exerciseId, score: score25, maxScore: 25);

    return const Success(
      ListeningAnalysisResult(
        text: 'This is a demo of your typed summary, shown back for reference.',
        issues: [
          ListeningIssue(
            phrase: 'main point',
            type: 'Content',
            message: 'You captured the main idea but missed one supporting detail.',
            suggestion: 'Mention the specific example given in the story.',
          ),
        ],
        improvedPassage: 'This is a demo of a fuller summary, covering both the main idea and the supporting details.',
        feedback: 'Good grasp of the overall story — try to include more specific details from what you heard.',
        scores: {'accuracy': 80, 'completeness': 74, 'overall': 78},
        score25: score25,
        contentMatchPercent: 82,
      ),
    );
  }
}
