/// One flagged mistake in the submitted text. Same 4-string shape as AI
/// Speaking's `SpeakingIssue` (both come from the same
/// `activities/agents/utils.py` issue-producing helpers), kept as its own
/// type rather than shared — each `features/` module owns its domain
/// entities independently in this codebase (see `SpeakingIssue`).
class WritingIssue {
  const WritingIssue({required this.phrase, required this.type, required this.message, required this.suggestion});

  final String phrase;

  /// e.g. "Grammar", "Vocabulary", "Spelling", "Punctuation", "Relevance",
  /// "Originality".
  final String type;
  final String message;
  final String suggestion;
}
