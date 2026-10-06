/// One AI-flagged issue within a task's feedback — mirrors one `<li>` in
/// `submit_exercise`'s generated `customSummaryHtml`
/// (`activities/views.py:1468-1473`): the flagged phrase, the problem
/// message, and a suggested replacement.
class WritingIssue {
  const WritingIssue({required this.phrase, required this.message, required this.suggestion});

  final String phrase;
  final String message;
  final String suggestion;
}

/// One task's parsed AI feedback block — see [parseWritingSummaryHtml].
class WritingTaskFeedback {
  const WritingTaskFeedback({
    required this.taskNumber,
    this.tooShortToEvaluate = false,
    this.issues = const [],
    this.improvedPassage,
  });

  final int taskNumber;

  /// `"Answer too short to evaluate."` (`activities/views.py:1488`) — the
  /// AI branch never ran for this task (`word_count <= min_words`,
  /// `activities/views.py:1440-1441`).
  final bool tooShortToEvaluate;

  /// Empty when the AI found "No major issues found."
  /// (`activities/views.py:1475`).
  final List<WritingIssue> issues;

  /// `null` when the AI response carried no improved rewrite.
  final String? improvedPassage;
}
