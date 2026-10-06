import '../../../../core/utils/result.dart';
import '../entities/generic_writing_exercise.dart';
import '../entities/generic_writing_submission_result.dart';

abstract class GenericWritingRepository {
  /// [title]/[order] are supplied by the caller — there is no JSON API
  /// response to read them back from (same reasoning as
  /// `MatchingExerciseRepository`/`BingoExerciseRepository`/
  /// `FillBlankExerciseRepository`).
  Future<Result<GenericWritingExercise>> getGenericWritingExercise(int exerciseId, {required String title, required int order});

  /// [answers] maps each prompt's 1-based position to its trimmed text —
  /// mirrors `answers[q] = text` (`static/js/exercises.js:850`). [score] is
  /// computed by the caller (`GenericWritingController`, via
  /// `computeGenericWritingClientScore`) and [maxScore] is always 100 —
  /// this is the client-computed score the web itself sends; the server
  /// may override it (see [GenericWritingSubmissionResult]'s doc comment).
  Future<Result<GenericWritingSubmissionResult>> submitGenericWritingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  });
}
