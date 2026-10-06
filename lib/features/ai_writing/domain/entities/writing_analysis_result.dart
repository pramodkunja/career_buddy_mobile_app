import 'writing_issue.dart';

/// The server-authoritative response to `analyze_writing`
/// (`activities/views.py:1690-1767`). [score25] is parsed from the
/// response body's **top-level** `score_25` field — confirmed by reading
/// the view directly that, unlike `analyze_speaking`, it is never
/// duplicated inside `data` for this endpoint.
///
/// Unlike `SpeakingAnalysisResult`, [feedback] and [quickTip] are
/// non-nullable: `WritingAgent.run()`'s offline fallback always populates
/// both before any AI call even runs, so a successful response body always
/// has non-empty strings for each (verified directly in
/// `activities/agents/utils.py:fallback_text_module_analysis` and
/// `activities/agents/writing.py`).
///
/// [quickTip] **is** the field the web actually displays for Writing —
/// the opposite of Speaking, where the server's `quick_tip` is fetched but
/// never shown. Verified independently by reading `writing.js` line by
/// line rather than assumed from Speaking's behavior.
class WritingAnalysisResult {
  const WritingAnalysisResult({
    required this.text,
    required this.issues,
    required this.improvedPassage,
    required this.feedback,
    required this.quickTip,
    required this.scores,
    required this.score25,
  });

  final String text;
  final List<WritingIssue> issues;
  final String improvedPassage;
  final String feedback;
  final String quickTip;
  final Map<String, num> scores;

  /// Out of 25 — the only score the web itself displays.
  final int score25;
}
