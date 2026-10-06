import 'package:career_buddy_lms/core/demo/demo_mcq_exercise_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_progress_store.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_exercise.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/mcq_exercise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DemoProgressStore.instance.reset);

  late DemoMcqExerciseRepository repo;
  setUp(() => repo = DemoMcqExerciseRepository());

  group('getMcqExercise', () {
    test('returns the fixed 4-question demo quiz for the known demo id', () async {
      final result = await repo.getMcqExercise(9205);
      final exercise = (result as Success<McqExercise>).value;

      expect(exercise.title, 'Vocabulary Quiz Exercise');
      expect(exercise.questions, hasLength(4));
      for (final q in exercise.questions) {
        expect(q.options, isNotEmpty);
        expect(q.correctAnswer, isNotEmpty);
      }
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.getMcqExercise(1);
      expect(result, isA<Failed<McqExercise>>());
    });
  });

  group('submitMcqExercise', () {
    // Grading itself happens in `McqExerciseController.submit` now (see
    // its own tests) — this repository's only job is to echo the score
    // it's given back, exactly like the real `submit_exercise` endpoint
    // does for MCQ.
    test('echoes back the given score/maxScore and computes the percentage', () async {
      final result = await repo.submitMcqExercise(9205, score: 3, maxScore: 4, answers: {1: 'b', 2: 'b', 3: 'a', 4: 'c'});
      final echo = (result as Success<McqSubmitEcho>).value;

      expect(echo.score, 3);
      expect(echo.maxScore, 4);
      expect(echo.percentage, 75);
    });

    test('records a demo attempt and marks the sub-activity complete', () async {
      await repo.submitMcqExercise(9205, score: 4, maxScore: 4, answers: {1: 'b', 2: 'b', 3: 'a', 4: 'b'});

      expect(DemoProgressStore.instance.lastAttemptFor(9205), isNotNull);
      expect(DemoProgressStore.instance.isSubActivityComplete(9108), isTrue);
    });

    test('attemptNumber increments across repeated submissions', () async {
      await repo.submitMcqExercise(9205, score: 1, maxScore: 4, answers: {1: 'b'});
      final second = await repo.submitMcqExercise(9205, score: 1, maxScore: 4, answers: {1: 'b'});
      final echo = (second as Success<McqSubmitEcho>).value;

      expect(echo.attemptNumber, 2);
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.submitMcqExercise(1, score: 0, maxScore: 0, answers: {});
      expect(result, isA<Failed<McqSubmitEcho>>());
    });
  });
}
