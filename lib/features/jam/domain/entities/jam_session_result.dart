/// The scored result of a completed JAM session — every field here is
/// parsed directly out of `templates/jam/session_detail.html` (the page
/// `jam:complete_session` redirects to; see `parseJamSessionResultHtml`),
/// which is itself backed by real `JAMSession` model fields
/// (`jam_app/models.py`). No field here is invented: the five category
/// scores and `overallScore` come from `generate_ai_feedback_sarvam`/
/// `_rule_based_feedback` (`jam_app/views.py`), each 0-5, `overallScore`
/// their sum out of 25 (`JAMSession.overall_score_display`).
///
/// The 3-stage Assessment flow (`AssessmentGroup`, `jam:start_assessment`/
/// `jam:assessment_session`/`jam:assessment_result`) is a genuinely
/// different multi-session flow with its own result template
/// (`assessment_result.html`, not read/parsed by this client) — deferred,
/// see the JAM feature's top-level doc comment in `jam_providers.dart`.
/// This entity always represents a single ordinary practice session.
class JamSessionResult {
  const JamSessionResult({
    required this.sessionId,
    required this.topicTitle,
    required this.topicDifficulty,
    required this.durationDisplay,
    required this.confidenceScore,
    required this.fluencyScore,
    required this.languageScore,
    required this.pronunciationScore,
    required this.timeManagementScore,
    required this.overallScore,
    required this.transcript,
    required this.aiFeedback,
    required this.improvementTips,
    required this.audioUrl,
    required this.createdAtDisplay,
  });

  final int sessionId;
  final String topicTitle;
  final String topicDifficulty;

  /// `JAMSession.duration_display` (e.g. `"45s"` or `"1m 5s"`) — already a
  /// formatted string server-side, not raw seconds.
  final String durationDisplay;

  /// Each 0-5 (`session_detail.html`'s `|default:"0"` — an in-progress or
  /// scoreless session shows 0, not null; this client mirrors that, no
  /// nullable score fields).
  final int confidenceScore;
  final int fluencyScore;
  final int languageScore;
  final int pronunciationScore;
  final int timeManagementScore;

  /// Sum of the five scores above, out of 25.
  final int overallScore;

  /// May be empty — `"No transcript recorded for this session."`'s italic
  /// placeholder (`session_detail.html:146-150`) is normalized to `''` by
  /// the parser rather than kept as that literal sentence.
  final String transcript;

  /// `JAMSession.ai_feedback`, HTML-stripped to plain text (the stored
  /// value is itself a mix of literal HTML tags — `<h4>`/`<b>` — from
  /// `_format_ai_feedback`/`_rule_based_feedback`, further wrapped by
  /// Django's `linebreaks` filter server-side) — see
  /// `parseJamSessionResultHtml`'s doc comment for why plain text, not a
  /// second HTML-rendering layer, is what this client shows.
  final String aiFeedback;

  /// `JAMSession.improvement_tips`, same HTML-to-plain-text treatment as
  /// [aiFeedback]. Empty when the session has no roadmap yet
  /// (`session_detail.html:169-171`'s "Complete more sessions..." branch —
  /// normalized to `''`, not kept as that placeholder sentence).
  final String improvementTips;

  /// `JAMSession.audio_file.url`, only present when the session actually
  /// has a stored recording (`session_detail.html:179-183`'s
  /// `{% if session.audio_file %}`).
  final String? audioUrl;

  /// `session.created_at|date:"M d Y h:i A"` — already formatted
  /// server-side.
  final String createdAtDisplay;
}
