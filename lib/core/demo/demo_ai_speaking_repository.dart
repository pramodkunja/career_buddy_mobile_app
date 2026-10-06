import '../../features/ai_speaking/domain/entities/speaking_analysis_result.dart';
import '../../features/ai_speaking/domain/entities/speaking_issue.dart';
import '../../features/ai_speaking/domain/repositories/ai_speaking_repository.dart';
import '../utils/result.dart';
import 'demo_progress_store.dart';

/// `AiSpeakingRepository` that returns a realistic, hardcoded
/// [SpeakingAnalysisResult] after a short simulated delay instead of
/// calling the real `analyze_speaking` endpoint — purely for local UI/flow
/// testing. Never claims to be server-authoritative and is never wired into
/// production/API code paths; see `demo_mode.dart`.
class DemoAiSpeakingRepository implements AiSpeakingRepository {
  @override
  Future<Result<SpeakingAnalysisResult>> analyze({
    required int exerciseId,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    const score25 = 19;
    DemoProgressStore.instance.recordAttempt(exerciseId, score: score25, maxScore: 25);

    return Success(
      SpeakingAnalysisResult(
        transcript: 'This is a demo transcript of what you might have said about the given topic.',
        issues: const [
          SpeakingIssue(
            phrase: 'a lot of experience',
            type: 'Vocabulary',
            message: 'Consider a more specific phrase to sound more precise.',
            suggestion: 'considerable experience',
          ),
          SpeakingIssue(
            phrase: 'I think that',
            type: 'Fluency',
            message: 'This filler phrase can often be removed for a more confident tone.',
            suggestion: '(remove)',
          ),
        ],
        improvedPassage:
            'This is a demo of an improved version of your response, with clearer structure and more precise vocabulary.',
        feedback: 'Good pace and clear pronunciation overall — work on reducing filler phrases for extra polish.',
        scores: const {
          'fluency': 78,
          'pronunciation': 82,
          'grammar': 75,
          'vocabulary': 70,
          'clarity': 80,
          'relevance': 88,
          'overall': 76,
        },
        score25: score25,
        durationSeconds: durationSeconds,
        pauseCount: pauseCount,
      ),
    );
  }
}
