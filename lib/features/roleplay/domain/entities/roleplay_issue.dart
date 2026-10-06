/// One flagged mistake in the analyzed transcript, returned inside
/// `analyze_roleplay`'s `data.issues` (`activities/agents/speaking.py`'s
/// `SpeakingAgent.run`, the exact same agent class `analyze_speaking` uses
/// — see `RoleplayAnalysisResult`'s doc comment). Same 4-field shape as
/// `ai_speaking`'s `SpeakingIssue` (both are produced by the same
/// `derive_revision_issues`/`derive_languagetool_issues`/Sarvam-prompt
/// helpers in `activities/agents/utils.py`), duplicated here rather than
/// imported cross-feature so `roleplay` has no dependency on `ai_speaking`.
class RoleplayIssue {
  const RoleplayIssue({required this.phrase, required this.type, required this.message, required this.suggestion});

  /// The exact substring of the transcript this issue refers to.
  final String phrase;

  /// e.g. "Grammar", "Vocabulary", "Spelling", "Punctuation".
  final String type;
  final String message;
  final String suggestion;
}
