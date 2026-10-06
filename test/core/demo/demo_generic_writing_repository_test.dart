import 'package:career_buddy_lms/core/demo/demo_generic_writing_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_progress_store.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/generic_writing_exercise.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/generic_writing_submission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DemoProgressStore.instance.reset);

  late DemoGenericWritingRepository repo;
  setUp(() => repo = DemoGenericWritingRepository());

  group('getGenericWritingExercise', () {
    test('returns the fixed 2-prompt demo exercise for the known demo id', () async {
      final result = await repo.getGenericWritingExercise(9209, title: 'ignored', order: 1);
      final exercise = (result as Success<GenericWritingExercise>).value;

      expect(exercise.prompts, hasLength(2));
      for (final prompt in exercise.prompts) {
        expect(prompt.questionText, isNotEmpty);
      }
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.getGenericWritingExercise(1, title: 'T', order: 1);
      expect(result, isA<Failed<GenericWritingExercise>>());
    });
  });

  group('submitGenericWritingExercise', () {
    // Grading itself happens in the controller (client-authoritative
    // heuristic, same as the web's own fallback path) — this repository
    // only persists whatever score/maxScore it's given and returns the
    // server-echo shape with no AI feedback, same division of
    // responsibility as `DemoFillBlankExerciseRepository`.
    test('echoes back the caller-computed score/maxScore/percentage with no task feedback', () async {
      final result = await repo.submitGenericWritingExercise(9209, score: 78, maxScore: 100, answers: const {});
      final submission = (result as Success<GenericWritingSubmissionResult>).value;

      expect(submission.score, 78);
      expect(submission.maxScore, 100);
      expect(submission.percentage, 78);
      expect(submission.taskFeedback, isEmpty);
    });

    test('records a demo attempt and marks the sub-activity complete', () async {
      await repo.submitGenericWritingExercise(9209, score: 100, maxScore: 100, answers: const {});

      expect(DemoProgressStore.instance.lastAttemptFor(9209), isNotNull);
      expect(DemoProgressStore.instance.isSubActivityComplete(9112), isTrue);
    });

    test('attemptNumber increments across repeated submissions', () async {
      await repo.submitGenericWritingExercise(9209, score: 40, maxScore: 100, answers: const {});
      final second = await repo.submitGenericWritingExercise(9209, score: 80, maxScore: 100, answers: const {});
      final submission = (second as Success<GenericWritingSubmissionResult>).value;

      expect(submission.attemptNumber, 2);
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.submitGenericWritingExercise(1, score: 0, maxScore: 0, answers: const {});
      expect(result, isA<Failed<GenericWritingSubmissionResult>>());
    });
  });
}
