import '../../features/activities/domain/entities/mcq_exercise.dart';
import '../../features/activities/domain/entities/mcq_question.dart';
import '../../features/activities/domain/repositories/mcq_exercise_repository.dart';
import '../errors/failures.dart';
import '../utils/result.dart';
import 'demo_progress_store.dart';

/// The demo exercise id this repository serves — matches
/// `kDemoActivities`'s "Vocabulary Quiz Exercise" (id 9205).
const _kDemoMcqExerciseId = 9205;
const _kDemoSubActivityId = 9108;

const _kDemoQuestions = [
  McqQuestion(
    id: 1,
    questionText: 'Which word best completes: "Please find the report ___ to this email."',
    options: {'a': 'attach', 'b': 'attached', 'c': 'attaching', 'd': 'attachment'},
    correctAnswer: 'b',
    explanation: '"Attached" is the correct past-participle form used as an adjective here.',
  ),
  McqQuestion(
    id: 2,
    questionText: 'Choose the most professional way to start a formal email to someone you don\'t know.',
    options: {'a': 'Hey there,', 'b': 'Dear Sir/Madam,', 'c': 'Yo,', 'd': 'What\'s up,'},
    correctAnswer: 'b',
    explanation: 'When the recipient\'s name is unknown, "Dear Sir/Madam," is the standard professional greeting.',
  ),
  McqQuestion(
    id: 3,
    questionText: 'What does "touch base" mean in a workplace context?',
    options: {'a': 'To make brief contact', 'b': 'To finish a task', 'c': 'To take a break', 'd': 'To resign'},
    correctAnswer: 'a',
    explanation: '"Touch base" is a common idiom meaning to make brief contact with someone.',
  ),
  McqQuestion(
    id: 4,
    questionText: 'Select the correctly punctuated sentence.',
    options: {
      'a': 'The meeting is at 3pm, please be on time.',
      'b': 'The meeting is at 3pm; please be on time.',
      'c': 'The meeting is at 3pm please be on time.',
      'd': 'The meeting is, at 3pm please be on time.',
    },
    correctAnswer: 'b',
    explanation: 'A semicolon correctly joins two related independent clauses without a conjunction.',
  ),
];

/// `McqExerciseRepository` backed by a fixed, four-question in-memory quiz
/// — never wired into production/API code paths, only manual UI testing
/// (see `demo_mode.dart` for how this gets swapped in). Grading itself now
/// happens in `McqExerciseController.submit` (the same place it happens
/// for the real repository, since `McqQuestion.correctAnswer` is known
/// from the initial load either way) — this repository only has to echo
/// back whatever score it's given, exactly like the real
/// `submit_exercise` endpoint does for MCQ.
class DemoMcqExerciseRepository implements McqExerciseRepository {
  static const _networkDelay = Duration(milliseconds: 200);

  @override
  Future<Result<McqExercise>> getMcqExercise(int exerciseId) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoMcqExerciseId) return const Failed(NotFoundFailure());
    return const Success(
      McqExercise(id: _kDemoMcqExerciseId, title: 'Vocabulary Quiz Exercise', questions: _kDemoQuestions),
    );
  }

  @override
  Future<Result<McqSubmitEcho>> submitMcqExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoMcqExerciseId) return const Failed(NotFoundFailure());

    DemoProgressStore.instance.recordAttempt(exerciseId, score: score, maxScore: maxScore);
    DemoProgressStore.instance.markSubActivityComplete(_kDemoSubActivityId);
    final attemptNumber = DemoProgressStore.instance.lastAttemptFor(exerciseId)!.attemptNumber;
    final percentage = maxScore > 0 ? ((score / maxScore) * 100).round() : 0;

    return Success((score: score, maxScore: maxScore, percentage: percentage, attemptNumber: attemptNumber));
  }
}
