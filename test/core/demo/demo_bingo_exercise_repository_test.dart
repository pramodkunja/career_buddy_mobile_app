import 'package:career_buddy_lms/core/demo/demo_bingo_exercise_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_progress_store.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/bingo/domain/entities/bingo_exercise.dart';
import 'package:career_buddy_lms/features/bingo/domain/entities/bingo_submission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DemoProgressStore.instance.reset);

  late DemoBingoExerciseRepository repo;
  setUp(() => repo = DemoBingoExerciseRepository());

  group('getBingoExercise', () {
    test('returns the fixed 16-card demo exercise for the known demo id', () async {
      final result = await repo.getBingoExercise(9207, title: 'ignored', order: 1);
      final exercise = (result as Success<BingoExercise>).value;

      expect(exercise.cards, hasLength(16));
      expect(exercise.board, hasLength(16));
      for (final card in exercise.cards) {
        expect(card.word, isNotEmpty);
        expect(card.definition, isNotEmpty);
      }
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.getBingoExercise(1, title: 'T', order: 1);
      expect(result, isA<Failed<BingoExercise>>());
    });
  });

  group('submitBingoExercise', () {
    // Grading itself happens in the controller (client-authoritative, same
    // as the web) — this repository only persists whatever score/maxScore
    // it's given and returns the server-echo shape, same division of
    // responsibility as `DemoMatchingExerciseRepository`.
    test('echoes back the caller-computed score/maxScore/percentage', () async {
      final result = await repo.submitBingoExercise(9207, score: 12, maxScore: 16, answers: const {});
      final submission = (result as Success<BingoSubmissionResult>).value;

      expect(submission.score, 12);
      expect(submission.maxScore, 16);
      expect(submission.percentage, 75);
    });

    test('records a demo attempt and marks the sub-activity complete', () async {
      await repo.submitBingoExercise(9207, score: 16, maxScore: 16, answers: const {});

      expect(DemoProgressStore.instance.lastAttemptFor(9207), isNotNull);
      expect(DemoProgressStore.instance.isSubActivityComplete(9110), isTrue);
    });

    test('attemptNumber increments across repeated submissions', () async {
      await repo.submitBingoExercise(9207, score: 1, maxScore: 16, answers: const {});
      final second = await repo.submitBingoExercise(9207, score: 16, maxScore: 16, answers: const {});
      final submission = (second as Success<BingoSubmissionResult>).value;

      expect(submission.attemptNumber, 2);
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.submitBingoExercise(1, score: 0, maxScore: 0, answers: const {});
      expect(result, isA<Failed<BingoSubmissionResult>>());
    });
  });
}
