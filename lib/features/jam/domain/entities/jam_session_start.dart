/// The result of starting a JAM session (`jam:jam_session`/
/// `jam:jam_session_topic`, parsed from `templates/jam/session.html`'s
/// embedded `SESSION_ID` and topic title/description/difficulty markup —
/// see `parseJamSessionStartHtml`). `topicId` is intentionally absent: the
/// web's own `session.html` never embeds it anywhere (only the session id
/// and the topic's title/description/difficulty are printed into the page),
/// and nothing downstream in this flow (`save_audio`/`complete_session`)
/// needs it — only `sessionId` does.
class JamSessionStart {
  const JamSessionStart({
    required this.sessionId,
    required this.topicTitle,
    required this.topicDescription,
    required this.topicDifficulty,
    this.stage,
  });

  final int sessionId;
  final String topicTitle;
  final String topicDescription;
  final String topicDifficulty;

  /// `null` for an ordinary practice session. `1`/`2`/`3` when this session
  /// is one stage of the 3-stage Assessment flow (`AssessmentGroup`,
  /// `jam:assessment_session`'s `stage` context var,
  /// `templates/jam/session.html`'s `id="labelStage">Stage {{ stage }} of
  /// 3` — see `parseJamAssessmentStageHtml`). `assessment_id` itself is
  /// deliberately not carried here: the real `session.html` never embeds it
  /// anywhere (confirmed by reading the full template) — only the server
  /// needs it, to look up the `AssessmentGroup` a given session belongs to
  /// on `complete_session`'s next redirect (`jam_app/views.py:685-701`);
  /// this client never has to know it.
  final int? stage;
}
