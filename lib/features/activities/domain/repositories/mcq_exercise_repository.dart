import '../../../../core/utils/result.dart';
import '../entities/mcq_exercise.dart';

/// The server's echo of a submission — `submit_exercise`'s only response
/// fields for the MCQ/default exercise flow (`score`, `max_score`,
/// `percentage`, `attempt`; `activities/views.py:1518-1525`).
///
/// **Phase 16 correction**: this used to be the authoritative word on
/// whether the server trusted the client's score for MCQ — it no longer
/// is. The updated backend's `submit_exercise` now calls
/// `grade_submission` (`activities/grading.py`) for every exercise type
/// except `writing`/`timer`, which **re-derives** the MCQ score from the
/// submitted `answers` against each `Question.correct_answer` and
/// overwrites whatever `score`/`max_score` the client sent. This echo is
/// now the real, server-computed score — the client's own locally-computed
/// `score`/`maxScore` (still sent, since the server still records an
/// attempt either way) is only ever a provisional value shown before this
/// echo arrives, not the number actually persisted.
typedef McqSubmitEcho = ({int score, int maxScore, int percentage, int attemptNumber});

abstract class McqExerciseRepository {
  Future<Result<McqExercise>> getMcqExercise(int exerciseId);

  /// [answers] maps question id to the submitted option letter
  /// ('a'-'d'); [questionOrder] is the same questions' ids in the exact
  /// order the exercise originally listed them (`McqExercise.questions`'s
  /// own list order) — required so the real server grading contract (keyed
  /// by 1-based position, not database id — see [McqSubmitEcho]'s doc
  /// comment and `McqExerciseRemoteDataSource.submitMcqExercise`'s) can be
  /// satisfied without the caller needing to know that wire-format detail
  /// itself. [score]/[maxScore] are the caller's own, already-computed
  /// grading (see `McqExerciseController.submit`) — sent to the server for
  /// the attempt record; no longer authoritative for this exercise type
  /// (see [McqSubmitEcho]).
  Future<Result<McqSubmitEcho>> submitMcqExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required List<int> questionOrder,
    required Map<int, String> answers,
  });
}
