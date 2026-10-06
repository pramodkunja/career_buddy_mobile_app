import 'jam_session_start.dart';

/// One completed, non-assessment practice session's difficulty — parsed
/// from `jam:history`'s "Regular Sessions" tab (`templates/jam/history.html`,
/// see `parseJamHistoryHtml`). That view already filters to
/// `completed=True` `JAMSession`s that are **not** part of an
/// `AssessmentGroup` (`jam_app/views.py:730-743`), so every entry here is
/// exactly one real completed practice session — the same population
/// `get_jam_level_progress` (`jam_app/views.py:59-81`) counts server-side.
class JamPracticeSessionSummary {
  const JamPracticeSessionSummary({required this.difficulty});

  /// Raw backend string (`'easy'`/`'medium'`/`'hard'`), same convention as
  /// `JamTopic.difficulty`.
  final String difficulty;
}

/// The 3-stage Assessment's server-side display label per difficulty
/// (`JAM_ASSESSMENT_LEVEL_LABELS`, `jam_app/views.py:52-56`) — used to
/// reproduce the exact wording of `start_assessment`'s flash message
/// (`jam_app/views.py:245-249`) when this client's own client-side
/// eligibility check finds the same gate not yet satisfied.
const Map<String, String> jamAssessmentLevelLabels = {'easy': 'Simple', 'medium': 'Intermediate', 'hard': 'Hard'};

/// Client-side reproduction of `get_jam_level_progress(user)`
/// (`jam_app/views.py:59-81`) — the exact eligibility gate
/// `jam:start_assessment` checks server-side before creating an
/// `AssessmentGroup`. No dedicated JSON endpoint exists for this (confirmed
/// against `jam_app/urls.py`); it's derived instead from
/// [JamPracticeSessionSummary]s already fetched via `jam:history` — see
/// `computeJamAssessmentEligibility`.
class JamAssessmentEligibility {
  const JamAssessmentEligibility({required this.easyDone, required this.mediumDone, required this.hardDone});

  final bool easyDone;
  final bool mediumDone;
  final bool hardDone;

  /// `all(level_progress.values())` (`jam_app/views.py:156,240`).
  bool get isEligible => easyDone && mediumDone && hardDone;

  /// Display labels (`'Simple'`/`'Intermediate'`/`'Hard'`) for every
  /// difficulty not yet done, in the same easy→medium→hard order
  /// `start_assessment`'s own `missing` list is built in
  /// (`jam_app/views.py:241-244`).
  List<String> get missingLevelLabels => [
    if (!easyDone) jamAssessmentLevelLabels['easy']!,
    if (!mediumDone) jamAssessmentLevelLabels['medium']!,
    if (!hardDone) jamAssessmentLevelLabels['hard']!,
  ];

  /// Matches `start_assessment`'s own flash message text verbatim
  /// (`jam_app/views.py:245-249`, re-wrapped onto one string) — empty when
  /// already eligible, since the real view never shows this message then.
  String get ineligibleReason {
    if (isEligible) return '';
    return 'Complete one topic from each of the three levels (Simple, Intermediate, Hard) '
        'before starting the assessment. Still pending: ${missingLevelLabels.join(', ')}.';
  }
}

/// Pure reproduction of `get_jam_level_progress`'s grouping logic
/// (`JAMSession.objects.filter(user=user, completed=True,
/// topic__difficulty__in=(...)).values_list('topic__difficulty',
/// flat=True).distinct()`, `jam_app/views.py:68-77`) — a difficulty is
/// "done" iff at least one completed practice session exists at it,
/// regardless of how many.
JamAssessmentEligibility computeJamAssessmentEligibility(Iterable<JamPracticeSessionSummary> sessions) {
  final difficulties = sessions.map((s) => s.difficulty).toSet();
  return JamAssessmentEligibility(
    easyDone: difficulties.contains('easy'),
    mediumDone: difficulties.contains('medium'),
    hardDone: difficulties.contains('hard'),
  );
}

/// One stage's summary row in the final diagnostic report — the "Stage
/// Summary Strip" (`templates/jam/assessment_result.html:124-140`):
/// difficulty label, the topic that was drawn for that stage, and its
/// `overall_score_display` (out of 25, `null`/`—` if somehow unscored).
class JamAssessmentStageSummary {
  const JamAssessmentStageSummary({required this.difficulty, required this.topicTitle, required this.overallScore});

  final String difficulty;
  final String topicTitle;
  final int? overallScore;
}

/// The final diagnostic report (`AssessmentGroup.final_report` +
/// surrounding page stats, `jam:assessment_result` /
/// `templates/jam/assessment_result.html`, see
/// `generate_final_assessment`, `jam_app/views.py:572-629`). Every field is
/// parsed directly out of the real page (see `parseJamAssessmentResultHtml`)
/// — nothing here is invented.
class JamAssessmentResult {
  const JamAssessmentResult({
    required this.level,
    required this.averageDurationSeconds,
    required this.averageFluency,
    required this.totalScore,
    required this.stages,
    required this.reportText,
  });

  /// `"Beginner"` / `"Intermediate"` / `"Advanced"` — `generate_final_
  /// assessment`'s `level` (`jam_app/views.py:578-583`), derived
  /// server-side from average fluency across all 3 stages.
  final String level;

  /// `generate_final_assessment`'s `avg_duration` (`jam_app/views.py:575`),
  /// already an average across the 3 stages, in seconds.
  final int averageDurationSeconds;

  /// `generate_final_assessment`'s `score_display` (`jam_app/views.py:593`)
  /// — average fluency across the 3 stages, out of 5, one decimal place.
  final double averageFluency;

  /// Sum of all 3 stages' `overall_score_display`, out of 75
  /// (`assessment_result.html:105`, `{% widthratio total 75 553 %}`).
  final int totalScore;

  /// Always exactly 3 entries, easy → medium → hard order (the "Stage
  /// Summary Strip", `assessment_result.html:124-140`).
  final List<JamAssessmentStageSummary> stages;

  /// `AssessmentGroup.final_report`, HTML-stripped to plain text — the same
  /// treatment `parseJamSessionResultHtml` already applies to
  /// `JAMSession.ai_feedback`/`improvement_tips` (see that parser's doc
  /// comment for why plain text, not a second HTML-rendering layer).
  /// Contains the "Result Level" heading, overall stats, the diagnostic
  /// paragraph, the per-stage score list, and the 3 fixed "Next Steps"
  /// tips (`generate_final_assessment`, `jam_app/views.py:611-629`) — every
  /// numeric field above is also independently parsed from elsewhere in
  /// this same page rather than re-derived from this text.
  final String reportText;
}

/// The 3-way outcome `jam:complete_session`'s redirect can land on for a
/// session that belongs to an `AssessmentGroup` (`jam_app/views.py:
/// 684-701`) — either the next stage's session (stage 1→2 or 2→3) or, after
/// stage 3, the final report. Never a normal `session_detail.html`: that
/// branch only fires for a session server-side confirmed to be **outside**
/// any `AssessmentGroup` (`jam_app/views.py:685-704`).
sealed class JamAssessmentStageOutcome {
  const JamAssessmentStageOutcome();
}

/// Stage 1→2 or 2→3: `session` is the next stage's freshly-rendered
/// `session.html`, already started server-side (no separate "start" call
/// needed — the next `JAMSession` was created up front by
/// `jam:start_assessment` itself, `jam_app/views.py:268-270`).
final class JamAssessmentNextStage extends JamAssessmentStageOutcome {
  const JamAssessmentNextStage(this.session);
  final JamSessionStart session;
}

/// Stage 3 complete: the `AssessmentGroup` is now `completed`, its
/// `final_report` generated, and this is that final diagnostic report.
final class JamAssessmentFinished extends JamAssessmentStageOutcome {
  const JamAssessmentFinished(this.result);
  final JamAssessmentResult result;
}
