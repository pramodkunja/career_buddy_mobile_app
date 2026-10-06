import '../../features/generic_writing/domain/entities/generic_writing_exercise.dart';
import '../../features/generic_writing/domain/entities/generic_writing_submission_result.dart';
import '../../features/generic_writing/domain/entities/writing_prompt.dart';
import '../../features/generic_writing/domain/repositories/generic_writing_repository.dart';
import 'demo_progress_store.dart';
import '../errors/failures.dart';
import '../utils/result.dart';

/// The demo exercise/sub-activity ids this repository serves — match
/// `kDemoActivities`'s "Negotiation Outcome Reflection" fixture, itself a
/// direct copy of the real seed exercise
/// (`populate_activities.py:135-142`, under "Business Negotiation
/// Simulation" → "Live Negotiation and Debrief").
const _kDemoGenericWritingExerciseId = 9209;
const _kDemoGenericWritingSubActivityId = 9112;

const _kDemoPrompts = [
  WritingPrompt(
    position: 1,
    questionText:
        'Describe the outcome of your negotiation. Did you reach an agreement? '
        'What were the key terms? What concessions did you make?',
    guide: 'Aim for 80–120 words. Use past tense and business vocabulary.',
  ),
  WritingPrompt(
    position: 2,
    questionText: 'What negotiation phrases from the phrase bank did you use effectively? Give 2 specific examples with context.',
    guide: "Reference actual phrases: 'We'd be willing to… if you could…' etc.",
  ),
];

/// `GenericWritingRepository` backed by a fixed, two-prompt in-memory
/// exercise. Grading itself happens in the controller
/// (`computeGenericWritingClientScore`, the same client heuristic the web
/// itself runs) — this repository only persists whatever score/maxScore
/// it's given and returns the server-echo shape with no AI feedback (no
/// `SARVAM_API_KEY` exists in demo mode), same division of responsibility
/// as `DemoFillBlankExerciseRepository`/`DemoMatchingExerciseRepository`/
/// `DemoBingoExerciseRepository`. Never wired into production/API code
/// paths — see `demo_mode.dart` for how this gets swapped in.
class DemoGenericWritingRepository implements GenericWritingRepository {
  static const _networkDelay = Duration(milliseconds: 200);

  @override
  Future<Result<GenericWritingExercise>> getGenericWritingExercise(int exerciseId, {required String title, required int order}) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoGenericWritingExerciseId) return const Failed(NotFoundFailure());
    return const Success(
      GenericWritingExercise(
        id: _kDemoGenericWritingExerciseId,
        title: 'Negotiation Outcome Reflection',
        order: 1,
        prompts: _kDemoPrompts,
      ),
    );
  }

  @override
  Future<Result<GenericWritingSubmissionResult>> submitGenericWritingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoGenericWritingExerciseId) return const Failed(NotFoundFailure());

    DemoProgressStore.instance.recordAttempt(exerciseId, score: score, maxScore: maxScore);
    DemoProgressStore.instance.markSubActivityComplete(_kDemoGenericWritingSubActivityId);
    final attemptNumber = DemoProgressStore.instance.lastAttemptFor(exerciseId)!.attemptNumber;
    final percentage = maxScore == 0 ? 0 : ((score / maxScore) * 100).round();

    return Success(
      GenericWritingSubmissionResult(
        exerciseId: exerciseId,
        score: score,
        maxScore: maxScore,
        percentage: percentage,
        attemptNumber: attemptNumber,
      ),
    );
  }
}
