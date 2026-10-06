/// One flagged mistake in the transcript. Shape confirmed directly from the
/// server's issue-producing helpers (`activities/agents/utils.py`:
/// `derive_revision_issues`, `derive_languagetool_issues`, and the AI
/// prompt's own instructed shape in `analyze_text_with_sarvam_chat`) — every
/// issue, whichever helper produced it, always has exactly these 4 string
/// fields.
class SpeakingIssue {
  const SpeakingIssue({required this.phrase, required this.type, required this.message, required this.suggestion});

  /// The exact substring of the transcript this issue refers to.
  final String phrase;

  /// e.g. "Grammar", "Vocabulary", "Spelling", "Punctuation", "Clarity".
  final String type;
  final String message;
  final String suggestion;
}
