import '../../features/ai_writing/domain/entities/writing_analysis_result.dart';
import '../../features/ai_writing/domain/entities/writing_issue.dart';
import '../../features/ai_writing/domain/repositories/ai_writing_repository.dart';
import '../utils/result.dart';
import 'demo_progress_store.dart';

/// `AiWritingRepository` that returns a realistic, hardcoded
/// [WritingAnalysisResult] after a short simulated delay instead of calling
/// the real `analyze_writing` endpoint — purely for local UI/flow testing.
/// Never claims to be server-authoritative and is never wired into
/// production/API code paths; see `demo_mode.dart`.
class DemoAiWritingRepository implements AiWritingRepository {
  @override
  Future<Result<WritingAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String language,
    required String referenceText,
    String? previousImprovedPassage,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    const score25 = 21;
    DemoProgressStore.instance.recordAttempt(exerciseId, score: score25, maxScore: 25);

    return const Success(
      WritingAnalysisResult(
        text: 'This is a demo of the passage you wrote, shown back with mistakes highlighted.',
        issues: [
          WritingIssue(
            phrase: 'there going',
            type: 'Grammar',
            message: '"there" should be "they\'re" (they are) in this context.',
            suggestion: "they're going",
          ),
          WritingIssue(
            phrase: 'very good',
            type: 'Vocabulary',
            message: 'Consider a more precise word to strengthen this sentence.',
            suggestion: 'excellent',
          ),
        ],
        improvedPassage: 'This is a demo of an improved version of your writing, with corrected grammar and stronger vocabulary.',
        feedback: 'Clear structure and a good attempt at professional tone — watch for a few grammar slips.',
        quickTip: 'Read your writing aloud before submitting — it helps catch small grammar mistakes.',
        scores: {'grammar': 74, 'vocabulary': 72, 'clarity': 80, 'structure': 78, 'overall': 76},
        score25: score25,
      ),
    );
  }
}
