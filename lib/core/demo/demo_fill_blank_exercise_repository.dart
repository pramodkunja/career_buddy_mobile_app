import '../../features/fill_blank/domain/entities/fill_blank_exercise.dart';
import '../../features/fill_blank/domain/entities/fill_blank_question.dart';
import '../../features/fill_blank/domain/entities/fill_blank_submission_result.dart';
import '../../features/fill_blank/domain/repositories/fill_blank_exercise_repository.dart';
import 'demo_progress_store.dart';
import '../errors/failures.dart';
import '../utils/result.dart';

/// The demo exercise/sub-activity ids this repository serves — match
/// `kDemoActivities`'s "Vocabulary Fill in the Blank" fixture.
const _kDemoFillBlankExerciseId = 9208;
const _kDemoFillBlankSubActivityId = 9111;

const _kDemoQuestions = [
  FillBlankQuestion(
    position: 1,
    questionText: 'Please find the report ___ to this email.',
    correctAnswer: 'attached',
    explanation: '"Attached" is the correct past-participle form used as an adjective here.',
  ),
  FillBlankQuestion(
    position: 2,
    questionText: 'Could you please ___ base with the client before Friday?',
    correctAnswer: 'touch',
    explanation: '"Touch base" is a common idiom meaning to make brief contact with someone.',
  ),
  FillBlankQuestion(
    position: 3,
    questionText: 'The meeting has been rescheduled ___ to a scheduling conflict.',
    correctAnswer: 'due',
    explanation: '"Due to" introduces the reason for something.',
  ),
  FillBlankQuestion(
    position: 4,
    questionText: 'We need to ___ the deadline by end of week.',
    correctAnswer: 'meet',
    explanation: '"Meet a deadline" means to complete something by the required time.',
  ),
];

/// `FillBlankExerciseRepository` backed by a fixed, four-question
/// in-memory exercise. Grading itself happens in the controller
/// (client-authoritative, same as the web) — this repository only
/// persists whatever score/maxScore it's given and returns the
/// server-echo shape, same division of responsibility as
/// `DemoMatchingExerciseRepository`/`DemoBingoExerciseRepository`. Never
/// wired into production/API code paths — see `demo_mode.dart` for how
/// this gets swapped in.
class DemoFillBlankExerciseRepository implements FillBlankExerciseRepository {
  static const _networkDelay = Duration(milliseconds: 200);

  @override
  Future<Result<FillBlankExercise>> getFillBlankExercise(int exerciseId, {required String title, required int order}) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoFillBlankExerciseId) return const Failed(NotFoundFailure());
    return const Success(
      FillBlankExercise(id: _kDemoFillBlankExerciseId, title: 'Workplace Vocabulary Fill in the Blank', order: 1, questions: _kDemoQuestions),
    );
  }

  @override
  Future<Result<FillBlankSubmissionResult>> submitFillBlankExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String given, String correct, bool isCorrect})> answers,
  }) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoFillBlankExerciseId) return const Failed(NotFoundFailure());

    DemoProgressStore.instance.recordAttempt(exerciseId, score: score, maxScore: maxScore);
    DemoProgressStore.instance.markSubActivityComplete(_kDemoFillBlankSubActivityId);
    final attemptNumber = DemoProgressStore.instance.lastAttemptFor(exerciseId)!.attemptNumber;
    final percentage = maxScore == 0 ? 0 : ((score / maxScore) * 100).round();

    return Success(
      FillBlankSubmissionResult(
        exerciseId: exerciseId,
        score: score,
        maxScore: maxScore,
        percentage: percentage,
        attemptNumber: attemptNumber,
      ),
    );
  }
}
