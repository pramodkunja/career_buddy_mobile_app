import 'mcq_question_result.dart';

/// The outcome of an MCQ submission. `score`/`maxScore`/`percentage` are
/// computed client-side (`McqExerciseController.submit`) from data already
/// known from the initial page load, then echoed back by the server —
/// `submit_exercise` doesn't grade MCQ itself (see `McqSubmitEcho`'s doc
/// comment). This is the same trust model every other HTML-scraped
/// exercise type (Matching/Bingo/Fill-Blank/Timer/Generic-Writing) already
/// uses; MCQ's earlier, dedicated JSON API would have graded server-side,
/// but that endpoint is confirmed not deployed to production.
class McqSubmissionResult {
  const McqSubmissionResult({
    required this.exerciseId,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.attemptNumber,
    required this.questions,
  });

  final int exerciseId;
  final int score;
  final int maxScore;

  /// Percentage, 0-100.
  final int percentage;
  final int attemptNumber;
  final List<McqQuestionResult> questions;
}
