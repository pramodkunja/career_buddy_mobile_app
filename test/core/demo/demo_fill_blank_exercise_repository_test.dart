import 'package:career_buddy_lms/core/demo/demo_fill_blank_exercise_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_progress_store.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/entities/fill_blank_exercise.dart';
import 'package:career_buddy_lms/features/fill_blank/domain/entities/fill_blank_submission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DemoProgressStore.instance.reset);

  late DemoFillBlankExerciseRepository repo;
  setUp(() => repo = DemoFillBlankExerciseRepository());

  group('getFillBlankExercise', () {
    test('returns the fixed 4-question demo exercise for the known demo id', () async {
      final result = await repo.getFillBlankExercise(9208, title: 'ignored', order: 1);
      final exercise = (result as Success<FillBlankExercise>).value;

      expect(exercise.questions, hasLength(4));
      for (final q in exercise.questions) {
        expect(q.questionText, isNotEmpty);
        expect(q.correctAnswer, isNotEmpty);
      }
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.getFillBlankExercise(1, title: 'T', order: 1);
      expect(result, isA<Failed<FillBlankExercise>>());
    });
  });

  group('submitFillBlankExercise', () {
    // Grading itself happens in the controller (client-authoritative, same
    // as the web) — this repository only persists whatever score/maxScore
    // it's given and returns the server-echo shape, same division of
    // responsibility as `DemoMatchingExerciseRepository`/
    // `DemoBingoExerciseRepository`.
    test('echoes back the caller-computed score/maxScore/percentage', () async {
      final result = await repo.submitFillBlankExercise(9208, score: 3, maxScore: 4, answers: const {});
      final submission = (result as Success<FillBlankSubmissionResult>).value;

      expect(submission.score, 3);
      expect(submission.maxScore, 4);
      expect(submission.percentage, 75);
    });

    test('records a demo attempt and marks the sub-activity complete', () async {
      await repo.submitFillBlankExercise(9208, score: 4, maxScore: 4, answers: const {});

      expect(DemoProgressStore.instance.lastAttemptFor(9208), isNotNull);
      expect(DemoProgressStore.instance.isSubActivityComplete(9111), isTrue);
    });

    test('attemptNumber increments across repeated submissions', () async {
      await repo.submitFillBlankExercise(9208, score: 1, maxScore: 4, answers: const {});
      final second = await repo.submitFillBlankExercise(9208, score: 4, maxScore: 4, answers: const {});
      final submission = (second as Success<FillBlankSubmissionResult>).value;

      expect(submission.attemptNumber, 2);
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.submitFillBlankExercise(1, score: 0, maxScore: 0, answers: const {});
      expect(result, isA<Failed<FillBlankSubmissionResult>>());
    });
  });
}
