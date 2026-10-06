import '../../../../core/utils/result.dart';
import '../entities/bingo_exercise.dart';
import '../entities/bingo_submission_result.dart';

abstract class BingoExerciseRepository {
  /// [title]/[order] are supplied by the caller — there is no JSON API
  /// response to read them back from (same reasoning as
  /// `MatchingExerciseRepository`).
  Future<Result<BingoExercise>> getBingoExercise(int exerciseId, {required String title, required int order});

  /// [answers] maps each round's 1-based index (matching the web's
  /// `answers['w' + (i+1)]`) to the round's target word and the word the
  /// player actually picked — mirrors `sel = {target, chosen}`
  /// (`static/js/exercises.js:584`). [score]/[maxScore] are computed by
  /// the caller (`BingoExerciseController`, from grading each round
  /// against [BingoExercise.cards]) — this exercise type is
  /// client-authoritative on the web itself (see
  /// `BingoSubmissionResult`'s doc comment).
  Future<Result<BingoSubmissionResult>> submitBingoExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String target, String chosen})> answers,
  });
}
