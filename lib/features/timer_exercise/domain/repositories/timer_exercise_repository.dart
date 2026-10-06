import '../../../../core/utils/result.dart';
import '../entities/timer_exercise.dart';
import '../entities/timer_submission_result.dart';

abstract class TimerExerciseRepository {
  /// [title]/[order] are supplied by the caller — there is no JSON API
  /// response to read them back from (same reasoning as
  /// `MatchingExerciseRepository`/`GenericWritingRepository`).
  Future<Result<TimerExercise>> getTimerExercise(int exerciseId, {required String title, required int order});

  /// [answers] maps each task's 1-based position to its captured
  /// transcript — mirrors `answers[Number(idx)+1] = text`
  /// (`static/js/exercises.js:1408-1409`); a task with no recorded speech
  /// has **no entry at all** (never an empty-string entry) — matching the
  /// web's own `if (!text) return;` guard skipping it entirely. [score]/
  /// [maxScore] are the client-computed values
  /// (`TimerExerciseController`, via `computeTimerClientScore`) — this is
  /// what the web itself sends; the server may override [score]/[maxScore]
  /// (see `TimerSubmissionResult`'s doc comment).
  Future<Result<TimerSubmissionResult>> submitTimerExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  });
}
