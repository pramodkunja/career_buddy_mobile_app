import '../../../../core/utils/result.dart';
import '../entities/fill_blank_exercise.dart';
import '../entities/fill_blank_submission_result.dart';

abstract class FillBlankExerciseRepository {
  /// [title]/[order] are supplied by the caller — there is no JSON API
  /// response to read them back from (same reasoning as
  /// `MatchingExerciseRepository`/`BingoExerciseRepository`).
  Future<Result<FillBlankExercise>> getFillBlankExercise(int exerciseId, {required String title, required int order});

  /// [answers] maps each question's 1-based position to what the player
  /// typed and whether it was graded correct — mirrors
  /// `answers[q] = {given, correct, result}` (`static/js/exercises.js:226`).
  /// [score]/[maxScore] are computed by the caller
  /// (`FillBlankExerciseController`, from exact trimmed/lowercased
  /// string comparison) — this exercise type is client-authoritative on
  /// the web itself, same as Matching/Bingo.
  Future<Result<FillBlankSubmissionResult>> submitFillBlankExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String given, String correct, bool isCorrect})> answers,
  });
}
