import 'package:career_buddy_lms/core/demo/demo_matching_exercise_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_progress_store.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/matching/domain/entities/matching_exercise.dart';
import 'package:career_buddy_lms/features/matching/domain/entities/matching_submission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DemoProgressStore.instance.reset);

  late DemoMatchingExerciseRepository repo;
  setUp(() => repo = DemoMatchingExerciseRepository());

  group('getMatchingExercise', () {
    test('returns the fixed 5-pair demo exercise for the known demo id', () async {
      final result = await repo.getMatchingExercise(9206, title: 'ignored', order: 1);
      final exercise = (result as Success<MatchingExercise>).value;

      expect(exercise.pairs, hasLength(5));
      for (final pair in exercise.pairs) {
        expect(pair.leftText, isNotEmpty);
        expect(pair.rightText, isNotEmpty);
      }
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.getMatchingExercise(1, title: 'T', order: 1);
      expect(result, isA<Failed<MatchingExercise>>());
    });
  });

  group('submitMatchingExercise', () {
    // Grading itself happens in the controller (client-authoritative, same
    // as the web) — this repository only persists whatever score/maxScore
    // it's given and returns the server-echo shape, same division of
    // responsibility the real `MatchingExerciseRepositoryImpl` has.
    test('echoes back the caller-computed score/maxScore/percentage', () async {
      final result = await repo.submitMatchingExercise(9206, score: 4, maxScore: 5, matches: const {});
      final submission = (result as Success<MatchingSubmissionResult>).value;

      expect(submission.score, 4);
      expect(submission.maxScore, 5);
      expect(submission.percentage, 80);
    });

    test('records a demo attempt and marks the sub-activity complete', () async {
      await repo.submitMatchingExercise(9206, score: 5, maxScore: 5, matches: const {});

      expect(DemoProgressStore.instance.lastAttemptFor(9206), isNotNull);
      expect(DemoProgressStore.instance.isSubActivityComplete(9109), isTrue);
    });

    test('attemptNumber increments across repeated submissions', () async {
      await repo.submitMatchingExercise(9206, score: 1, maxScore: 5, matches: const {});
      final second = await repo.submitMatchingExercise(9206, score: 5, maxScore: 5, matches: const {});
      final submission = (second as Success<MatchingSubmissionResult>).value;

      expect(submission.attemptNumber, 2);
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.submitMatchingExercise(1, score: 0, maxScore: 0, matches: const {});
      expect(result, isA<Failed<MatchingSubmissionResult>>());
    });
  });
}
