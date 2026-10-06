import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_exercise.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_question.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/mcq_exercise_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/controllers/mcq_exercise_controller.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

McqExercise _exercise({int questionCount = 2}) => McqExercise(
  id: 56,
  title: 'Vocabulary Quiz',
  questions: List.generate(
    questionCount,
    (i) => McqQuestion(
      id: 100 + i,
      questionText: 'Q$i',
      options: const {'a': 'A', 'b': 'B'},
      correctAnswer: 'a',
      explanation: 'Because A is right.',
    ),
  ),
);

class _FakeMcqExerciseRepository implements McqExerciseRepository {
  _FakeMcqExerciseRepository({this.getResult, this.submitResult});

  Result<McqExercise>? getResult;
  Result<McqSubmitEcho>? submitResult;
  int submitCallCount = 0;
  Map<int, String>? lastSubmittedAnswers;
  int? lastSubmittedScore;
  int? lastSubmittedMaxScore;

  @override
  Future<Result<McqExercise>> getMcqExercise(int exerciseId) async => getResult!;

  @override
  Future<Result<McqSubmitEcho>> submitMcqExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    submitCallCount++;
    lastSubmittedAnswers = answers;
    lastSubmittedScore = score;
    lastSubmittedMaxScore = maxScore;
    return submitResult!;
  }
}

const _echo = (score: 1, maxScore: 2, percentage: 50, attemptNumber: 1);

Future<ProviderContainer> _readyContainer(McqExerciseRepository repo) async {
  final container = ProviderContainer(overrides: [mcqExerciseRepositoryProvider.overrideWithValue(repo)]);
  container.read(mcqExerciseControllerProvider(56));
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  group('McqExerciseController', () {
    test('resolves to InProgress with no answers selected on a successful load', () async {
      final container = await _readyContainer(_FakeMcqExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);

      final state = container.read(mcqExerciseControllerProvider(56));
      expect(state, isA<McqExerciseInProgress>());
      expect((state as McqExerciseInProgress).selectedAnswers, isEmpty);
    });

    test('resolves to LoadFailed on a failed load', () async {
      final container = await _readyContainer(_FakeMcqExerciseRepository(getResult: const Failed(NotFoundFailure())));
      addTearDown(container.dispose);

      final state = container.read(mcqExerciseControllerProvider(56));
      expect(state, isA<McqExerciseLoadFailed>());
      expect((state as McqExerciseLoadFailed).failure, isA<NotFoundFailure>());
    });

    test('selectAnswer records the answer and allQuestionsAnswered flips once all are answered', () async {
      final container = await _readyContainer(_FakeMcqExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(mcqExerciseControllerProvider(56).notifier);

      notifier.selectAnswer(100, 'a');
      var state = container.read(mcqExerciseControllerProvider(56)) as McqExerciseInProgress;
      expect(state.selectedAnswers, {100: 'a'});
      expect(state.allQuestionsAnswered, isFalse);

      notifier.selectAnswer(101, 'b');
      state = container.read(mcqExerciseControllerProvider(56)) as McqExerciseInProgress;
      expect(state.allQuestionsAnswered, isTrue);
    });

    test('submit() is a no-op until every question is answered', () async {
      final repo = _FakeMcqExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(_echo));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mcqExerciseControllerProvider(56).notifier);

      notifier.selectAnswer(100, 'a'); // only 1 of 2 answered
      await notifier.submit();

      expect(repo.submitCallCount, 0);
      expect(container.read(mcqExerciseControllerProvider(56)), isA<McqExerciseInProgress>());
    });

    test(
      'submit() grades client-side from correctAnswer (one right, one wrong) and sends that score to the repository',
      () async {
        final repo = _FakeMcqExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(_echo));
        final container = await _readyContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(mcqExerciseControllerProvider(56).notifier);

        notifier.selectAnswer(100, 'a'); // correct
        notifier.selectAnswer(101, 'b'); // wrong — correctAnswer is 'a'
        await notifier.submit();

        expect(repo.lastSubmittedScore, 1);
        expect(repo.lastSubmittedMaxScore, 2);
        expect(repo.lastSubmittedAnswers, {100: 'a', 101: 'b'});
      },
    );

    test('submit() transitions to Submitted, using the echoed score/percentage/attempt for the result', () async {
      final repo = _FakeMcqExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(_echo));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mcqExerciseControllerProvider(56).notifier);

      notifier.selectAnswer(100, 'a');
      notifier.selectAnswer(101, 'b');
      await notifier.submit();

      final state = container.read(mcqExerciseControllerProvider(56));
      expect(state, isA<McqExerciseSubmitted>());
      final result = (state as McqExerciseSubmitted).result;
      expect(result.score, _echo.score);
      expect(result.maxScore, _echo.maxScore);
      expect(result.percentage, _echo.percentage);
      expect(result.attemptNumber, _echo.attemptNumber);
    });

    test('the Submitted result\'s per-question breakdown is built from the exercise\'s own correctAnswer/explanation', () async {
      final repo = _FakeMcqExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(_echo));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mcqExerciseControllerProvider(56).notifier);

      notifier.selectAnswer(100, 'a');
      notifier.selectAnswer(101, 'b');
      await notifier.submit();

      final result = (container.read(mcqExerciseControllerProvider(56)) as McqExerciseSubmitted).result;
      final q100 = result.questions.firstWhere((q) => q.questionId == 100);
      final q101 = result.questions.firstWhere((q) => q.questionId == 101);

      expect(q100.selected, 'a');
      expect(q100.correct, 'a');
      expect(q100.isCorrect, isTrue);
      expect(q100.explanation, 'Because A is right.');

      expect(q101.selected, 'b');
      expect(q101.correct, 'a');
      expect(q101.isCorrect, isFalse);
    });

    test('a failed submit keeps the answers and surfaces submitError, without resetting to loading', () async {
      final repo = _FakeMcqExerciseRepository(
        getResult: Success(_exercise()),
        submitResult: const Failed(ServerFailure()),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mcqExerciseControllerProvider(56).notifier);

      notifier.selectAnswer(100, 'a');
      notifier.selectAnswer(101, 'b');
      await notifier.submit();

      final state = container.read(mcqExerciseControllerProvider(56));
      expect(state, isA<McqExerciseInProgress>());
      final inProgress = state as McqExerciseInProgress;
      expect(inProgress.submitError, isA<ServerFailure>());
      expect(inProgress.isSubmitting, isFalse);
      expect(inProgress.selectedAnswers, {100: 'a', 101: 'b'});
    });

    test('submit() while already submitting does not fire a second request', () async {
      final repo = _FakeMcqExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(_echo));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mcqExerciseControllerProvider(56).notifier);
      notifier.selectAnswer(100, 'a');
      notifier.selectAnswer(101, 'b');

      final first = notifier.submit();
      final second = notifier.submit(); // should be a no-op — already submitting
      await Future.wait([first, second]);

      expect(repo.submitCallCount, 1);
    });
  });
}
