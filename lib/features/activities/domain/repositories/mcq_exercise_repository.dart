import '../../../../core/utils/result.dart';
import '../entities/mcq_exercise.dart';

/// The server's echo of a submission — `submit_exercise`'s only response
/// fields for the MCQ/default exercise flow (`score`, `max_score`,
/// `percentage`, `attempt`; `activities/views.py:1518-1525`). The server
/// does not grade MCQ itself (it only ever echoes back whatever `score`/
/// `max_score` the client POSTed — confirmed by reading `submit_exercise`:
/// those two are only reassigned for `writing`/`timer` exercises), so this
/// is not an authoritative score in the way the earlier, undeployed
/// `submit_mcq_exercise_api` would have been — it's the same trust model
/// every other HTML-scraped exercise type already uses.
typedef McqSubmitEcho = ({int score, int maxScore, int percentage, int attemptNumber});

abstract class McqExerciseRepository {
  Future<Result<McqExercise>> getMcqExercise(int exerciseId);

  /// [answers] maps question id to the submitted option letter
  /// ('a'-'d'); [score]/[maxScore] are the caller's own, already-computed
  /// grading (see `McqExerciseController.submit`) — sent to the server
  /// for the attempt record, not computed here.
  Future<Result<McqSubmitEcho>> submitMcqExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  });
}
