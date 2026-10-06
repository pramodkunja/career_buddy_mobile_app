/// Per-question feedback, built client-side at submission time from
/// `McqQuestion.correctAnswer`/`explanation` (known from the initial page
/// load — see `McqQuestion`'s doc comment) plus the user's own selection.
/// Kept as its own result type (rather than reusing `McqQuestion` plus a
/// bool) so `McqResultView` doesn't need the exercise's full option map
/// just to render a review.
class McqQuestionResult {
  const McqQuestionResult({
    required this.questionId,
    required this.correct,
    required this.isCorrect,
    this.selected,
    this.explanation,
  });

  final int questionId;

  /// The letter the user submitted, or `null` if that question was left
  /// unanswered.
  final String? selected;
  final String correct;
  final bool isCorrect;
  final String? explanation;
}
