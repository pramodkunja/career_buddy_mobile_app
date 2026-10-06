import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/entities/fill_blank_exercise.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/entities/fill_blank_question.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/entities/fill_blank_submission_result.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/repositories/fill_blank_exercise_repository.dart';
import 'package:career_buddy_lms/features/fill_blank/presentation/controllers/fill_blank_exercise_controller.dart';
import 'package:career_buddy_lms/features/fill_blank/presentation/providers/fill_blank_exercise_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FillBlankExercise _exercise({int questionCount = 3}) => FillBlankExercise(
  id: 7,
  title: 'Vocabulary Fill in the Blank',
  order: 1,
  questions: List.generate(
    questionCount,
    (i) => FillBlankQuestion(position: i + 1, questionText: 'Q$i', correctAnswer: 'Answer$i'),
  ),
);

class _FakeFillBlankExerciseRepository implements FillBlankExerciseRepository {
  _FakeFillBlankExerciseRepository({this.getResult, this.submitResult});

  Result<FillBlankExercise>? getResult;
  Result<FillBlankSubmissionResult>? submitResult;
  int submitCallCount = 0;
  int? lastScore;
  int? lastMaxScore;
  Map<int, ({String given, String correct, bool isCorrect})>? lastAnswers;

  @override
  Future<Result<FillBlankExercise>> getFillBlankExercise(int exerciseId, {required String title, required int order}) async =>
      getResult!;

  @override
  Future<Result<FillBlankSubmissionResult>> submitFillBlankExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String given, String correct, bool isCorrect})> answers,
  }) async {
    submitCallCount++;
    lastScore = score;
    lastMaxScore = maxScore;
    lastAnswers = answers;
    return submitResult!;
  }
}

Future<ProviderContainer> _readyContainer(FillBlankExerciseRepository repo, {String title = 'Vocabulary Fill in the Blank', int order = 1}) async {
  final container = ProviderContainer(overrides: [fillBlankExerciseRepositoryProvider.overrideWithValue(repo)]);
  container.read(fillBlankExerciseControllerProvider((7, title, order)));
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  final providerArg = (7, 'Vocabulary Fill in the Blank', 1);

  group('FillBlankExerciseController — load', () {
    test('resolves to InProgress with no checked questions on a successful load', () async {
      final container = await _readyContainer(_FakeFillBlankExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);

      final state = container.read(fillBlankExerciseControllerProvider(providerArg));
      expect(state, isA<FillBlankExerciseInProgress>());
      final inProgress = state as FillBlankExerciseInProgress;
      expect(inProgress.checkedResults, isEmpty);
      expect(inProgress.checkedCount, 0);
      expect(inProgress.currentScore, 0);
      expect(inProgress.allChecked, isFalse);
    });

    test('resolves to LoadFailed on a failed load', () async {
      final container = await _readyContainer(_FakeFillBlankExerciseRepository(getResult: const Failed(NotFoundFailure())));
      addTearDown(container.dispose);

      expect(container.read(fillBlankExerciseControllerProvider(providerArg)), isA<FillBlankExerciseLoadFailed>());
    });
  });

  group('FillBlankExerciseController — checking answers', () {
    test('an empty answer shows an inline error without locking the question or counting it as checked', () async {
      final container = await _readyContainer(_FakeFillBlankExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, '   '); // blank after trim
      final state = container.read(fillBlankExerciseControllerProvider(providerArg)) as FillBlankExerciseInProgress;

      expect(state.emptyErrorPositions, contains(1));
      expect(state.checkedResults, isEmpty);
      expect(state.checkedCount, 0);
    });

    test('a correct answer (exact, trimmed, case-insensitive) locks the question and increments the score', () async {
      final container = await _readyContainer(_FakeFillBlankExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, '  Answer0  ');
      final state = container.read(fillBlankExerciseControllerProvider(providerArg)) as FillBlankExerciseInProgress;

      expect(state.checkedResults[1]!.isCorrect, isTrue);
      expect(state.checkedResults[1]!.given, '  Answer0  '); // raw value stored, not trimmed
      expect(state.currentScore, 1);
      expect(state.checkedCount, 1);
    });

    test('a case-mismatched but otherwise exact answer is still graded correct', () async {
      final container = await _readyContainer(_FakeFillBlankExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, 'ANSWER0');
      final state = container.read(fillBlankExerciseControllerProvider(providerArg)) as FillBlankExerciseInProgress;

      expect(state.checkedResults[1]!.isCorrect, isTrue);
    });

    test('a wrong answer locks the question and does not increment the score', () async {
      final container = await _readyContainer(_FakeFillBlankExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, 'nope');
      final state = container.read(fillBlankExerciseControllerProvider(providerArg)) as FillBlankExerciseInProgress;

      expect(state.checkedResults[1]!.isCorrect, isFalse);
      expect(state.currentScore, 0);
      expect(state.checkedCount, 1); // checked regardless of correctness
    });

    test('checkedCount increments regardless of correctness', () async {
      final container = await _readyContainer(_FakeFillBlankExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, 'Answer0'); // correct
      notifier.checkAnswer(2, 'wrong'); // wrong
      final state = container.read(fillBlankExerciseControllerProvider(providerArg)) as FillBlankExerciseInProgress;

      expect(state.checkedCount, 2);
      expect(state.currentScore, 1);
    });

    test('a checked question cannot be checked again — re-checking is a no-op', () async {
      final container = await _readyContainer(_FakeFillBlankExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, 'wrong');
      notifier.checkAnswer(1, 'Answer0'); // attempt to "fix" the locked answer
      final state = container.read(fillBlankExerciseControllerProvider(providerArg)) as FillBlankExerciseInProgress;

      expect(state.checkedResults[1]!.isCorrect, isFalse); // still the original wrong grading
      expect(state.checkedResults[1]!.given, 'wrong');
    });

    test('re-attempting an empty check on the same position clears its empty-error flag once answered', () async {
      final container = await _readyContainer(_FakeFillBlankExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, '');
      var state = container.read(fillBlankExerciseControllerProvider(providerArg)) as FillBlankExerciseInProgress;
      expect(state.emptyErrorPositions, contains(1));

      notifier.checkAnswer(1, 'Answer0');
      state = container.read(fillBlankExerciseControllerProvider(providerArg)) as FillBlankExerciseInProgress;
      expect(state.emptyErrorPositions, isNot(contains(1)));
      expect(state.checkedResults[1]!.isCorrect, isTrue);
    });
  });

  group('FillBlankExerciseController — submit gating', () {
    test('submit() is a no-op until every question is checked', () async {
      final repo = _FakeFillBlankExerciseRepository(getResult: Success(_exercise()));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, 'Answer0'); // only 1 of 3 checked
      await notifier.submit();

      expect(repo.submitCallCount, 0);
      expect(container.read(fillBlankExerciseControllerProvider(providerArg)), isA<FillBlankExerciseInProgress>());
    });

    test('a fully wrong but fully checked exercise is submittable — submit does NOT require all correct', () async {
      final repo = _FakeFillBlankExerciseRepository(
        getResult: Success(_exercise()),
        submitResult: const Success(
          FillBlankSubmissionResult(exerciseId: 7, score: 0, maxScore: 3, percentage: 0, attemptNumber: 1),
        ),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, 'wrong');
      notifier.checkAnswer(2, 'wrong');
      notifier.checkAnswer(3, 'wrong');
      await notifier.submit();

      expect(repo.submitCallCount, 1);
      expect(repo.lastScore, 0);
      expect(container.read(fillBlankExerciseControllerProvider(providerArg)), isA<FillBlankExerciseSubmitted>());
    });
  });

  group('FillBlankExerciseController — submission', () {
    test('submit() sends the exact locally-computed score/maxScore and answers, and transitions to Submitted', () async {
      final repo = _FakeFillBlankExerciseRepository(
        getResult: Success(_exercise()),
        submitResult: const Success(
          FillBlankSubmissionResult(exerciseId: 7, score: 2, maxScore: 3, percentage: 67, attemptNumber: 4),
        ),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, 'Answer0');
      notifier.checkAnswer(2, 'Answer1');
      notifier.checkAnswer(3, 'wrong');
      await notifier.submit();

      expect(repo.lastScore, 2);
      expect(repo.lastMaxScore, 3);
      expect(repo.lastAnswers![3]!.isCorrect, isFalse);
      expect(repo.lastAnswers![3]!.correct, 'Answer2');

      final state = container.read(fillBlankExerciseControllerProvider(providerArg));
      expect(state, isA<FillBlankExerciseSubmitted>());
      expect((state as FillBlankExerciseSubmitted).result.attemptNumber, 4);
    });

    test('a failed submit keeps the checked answers and surfaces submitError, without resetting to loading', () async {
      final repo = _FakeFillBlankExerciseRepository(
        getResult: Success(_exercise()),
        submitResult: const Failed(ServerFailure()),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, 'Answer0');
      notifier.checkAnswer(2, 'Answer1');
      notifier.checkAnswer(3, 'Answer2');
      await notifier.submit();

      final state = container.read(fillBlankExerciseControllerProvider(providerArg));
      expect(state, isA<FillBlankExerciseInProgress>());
      final inProgress = state as FillBlankExerciseInProgress;
      expect(inProgress.submitError, isA<ServerFailure>());
      expect(inProgress.isSubmitting, isFalse);
      expect(inProgress.checkedResults, hasLength(3));
    });

    test('submit() while already submitting does not fire a second request', () async {
      final repo = _FakeFillBlankExerciseRepository(
        getResult: Success(_exercise()),
        submitResult: const Success(
          FillBlankSubmissionResult(exerciseId: 7, score: 3, maxScore: 3, percentage: 100, attemptNumber: 1),
        ),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);
      notifier.checkAnswer(1, 'Answer0');
      notifier.checkAnswer(2, 'Answer1');
      notifier.checkAnswer(3, 'Answer2');

      final first = notifier.submit();
      final second = notifier.submit(); // should be a no-op — already submitting
      await Future.wait([first, second]);

      expect(repo.submitCallCount, 1);
    });
  });

  group('FillBlankExerciseController — retry', () {
    test('tryAgain() re-fetches and fully resets checked state, score, and errors', () async {
      final repo = _FakeFillBlankExerciseRepository(getResult: Success(_exercise()));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(fillBlankExerciseControllerProvider(providerArg).notifier);

      notifier.checkAnswer(1, 'Answer0');
      notifier.checkAnswer(2, '');
      await notifier.tryAgain();

      final state = container.read(fillBlankExerciseControllerProvider(providerArg)) as FillBlankExerciseInProgress;
      expect(state.checkedResults, isEmpty);
      expect(state.emptyErrorPositions, isEmpty);
      expect(state.currentScore, 0);
      expect(state.submitError, isNull);
    });
  });
}
