import 'listening_issue.dart';

/// The server-authoritative response to `analyze_listening`
/// (`activities/views.py:1770-1908`). [score25] and [contentMatchPercent]
/// are parsed from **inside** the response body's `data` object — verified
/// directly against the view (`data['score_25'] = score_25`,
/// `data['content_match_percent'] = content_match_percent`, mutating the
/// same dict `result['data']` already references) — the same nested
/// placement as `analyzeSpeaking`, **not** `analyzeWriting`'s top-level
/// placement. Confirmed independently rather than assumed from either.
class ListeningAnalysisResult {
  const ListeningAnalysisResult({
    required this.text,
    required this.issues,
    required this.improvedPassage,
    required this.feedback,
    required this.scores,
    required this.score25,
    required this.contentMatchPercent,
  });

  final String text;
  final List<ListeningIssue> issues;
  final String improvedPassage;

  /// `WritingAgent`'s offline fallback (shared with Speaking/Listening via
  /// `fallback_text_module_analysis`) always populates this — confirmed
  /// the same guarantee as `WritingAnalysisResult.feedback`.
  final String feedback;
  final Map<String, num> scores;

  /// Out of 25 — derived server-side directly from content-similarity
  /// against the story (`compute_listening_score_25`), not from the AI's
  /// generic language-quality scores.
  final int score25;

  /// 0-100 — the same content-similarity ratio `score25` was derived
  /// from, shown as "Content Match %" and used to pick which
  /// feedback/quick-tip banding message displays (see
  /// `buildListeningFeedback`/`buildListeningQuickTip`).
  final int contentMatchPercent;
}
