/// The exact shape `analyze_resume_with_sarvam`/`_local_resume_analysis`
/// return (`career_app/resume_utils.py:465-576`) — an AI (Sarvam) call with
/// a deterministic, rule-based fallback (`compute_ats_score` +
/// `_local_resume_analysis`) if the AI call fails; either path returns
/// these same 5 keys, so this entity doesn't need to distinguish which one
/// produced it.
class ResumeAnalysis {
  const ResumeAnalysis({
    required this.matchPercentage,
    required this.matchingSkills,
    required this.missingSkills,
    required this.summary,
    required this.careerAdvice,
  });

  /// `match_percentage` — the ATS score, 0-100. Always the deterministic
  /// `compute_ats_score()` value regardless of AI path (the view
  /// overwrites the AI's own number with it, `resume_utils.py:571`).
  final int matchPercentage;
  final List<String> matchingSkills;
  final List<String> missingSkills;

  /// `analysis` — a short (max ~3 sentence) summary string. Named
  /// `summary` here, not `analysis`, to avoid a field called the same as
  /// its own container type.
  final String summary;
  final List<String> careerAdvice;
}

/// Phase 46 — `career_app/views.py:185` `ATS_INTERVIEW_THRESHOLD`,
/// confirmed directly against the current (`royalStaffing_CB01`) source:
/// **90**, not the 70 this result screen previously, incorrectly
/// displayed. The AI-interview passing score (`career_app/views.py:1134`
/// `PASSING_SCORE`) is a separate server constant that is *also* 90 today
/// (confirmed no drift) — kept as its own, separately-named constant
/// (`kInterviewPassingScore`, in `interview_analytics.dart`) rather than
/// reused here, since the two gate genuinely different things server-side
/// and could diverge again.
const int kAtsInterviewThreshold = 90;

/// Phase 46 — the real page's own 4-way branch
/// (`templates/resume_match_result.html:222-247,309-379`, confirmed
/// directly), replacing a previous 2-way split that conflated "Free plan"
/// with "paid plan but below the ATS threshold" and "paid plan but the
/// picked role doesn't fit" — both of the latter two silently looked like
/// a Free-plan "Upgrade" prompt before this phase, which was itself wrong
/// (a paying user doesn't need to upgrade, they need a better score or a
/// different role).
enum ResumeInterviewGate {
  /// `can_interview and role_fit and not role_fit.ok` — the resume doesn't
  /// show the skills the picked target role needs (its ATS score for that
  /// role is forced to 0 server-side).
  roleMismatch,

  /// `can_interview and not ats_ok` — the plan allows the interview, but
  /// the ATS score hasn't reached [kAtsInterviewThreshold] yet.
  belowThreshold,

  /// `can_interview` with role fit ok (or no role picked) and the ATS
  /// score at or above [kAtsInterviewThreshold] — ready for the interview.
  eligible,

  /// `not can_interview` — Free plan; the interview isn't included at all.
  planLocked,
}

/// One full render of `templates/resume_match_result.html` —
/// `career_app.views.resume_job_match`/`resume_reanalyze`'s success
/// response. Confirmed by reading the template directly: it never
/// references the `resume`/`jd` context objects it's given (no `{{
/// resume.* }}`/`{{ jd.* }}` anywhere in the file) — there is no resume id
/// to recover from this page even in principle, so no `resumeId` field is
/// carried here at all (not an oversight). `resumeValid`/`validationMessage`
/// are `null` only on the GET-from-session path (`resume_job_match`'s
/// no-POST branch, `career_app/views.py:802-818`), which never passes
/// `resume_valid`/`validation_msg` into the template context either — a
/// genuine absence in the real page, not a parsing gap.
class ResumeAnalysisResult {
  const ResumeAnalysisResult({
    required this.analysis,
    required this.isAtsOnly,
    required this.yearsExperience,
    required this.canInterview,
    this.gate,
    this.targetRoleName,
    this.showSkillUpAction = false,
    this.resumeValid,
    this.validationMessage,
  });

  final ResumeAnalysis analysis;

  /// `is_ats_only` — true when no job-description text was submitted
  /// alongside the resume (`career_app/views.py:795`, `not jd_text`). The
  /// real upload page (`resume_builder.html`) has no UI field for a job
  /// description at all (confirmed by reading the template — the view
  /// accepts one, but nothing ever renders an input for it), so every
  /// upload this app makes is `is_ats_only: true` in practice, same as
  /// every `resume_reanalyze` result (hardcoded `true` server-side there
  /// regardless).
  final bool isAtsOnly;
  final double yearsExperience;

  /// `can_interview` — `_can_access_interview(user)`, Normal (₹499)/Pro
  /// plans only. The AI Mock Interview flow this gates is out of this
  /// batch's scope; this field only drives the CTA button's
  /// enabled/locked state on the result screen.
  final bool canInterview;

  /// Phase 46 — the real 4-way branch this result actually rendered
  /// (`null` only for pre-Phase-46 test fixtures that predate this field
  /// and never set it — see [effectiveGate]). Every real, freshly-parsed
  /// result from [parseResumeMatchResultHtml] always sets this.
  final ResumeInterviewGate? gate;

  /// `target_role.role`, when a target role was picked
  /// (`resume_match_result.html:218,225,316-317,537`) — `null` when none
  /// was. Used for the role-mismatch banner's own message text.
  final String? targetRoleName;

  /// `can_interview and target_role.section and not ats_ok`
  /// (`resume_match_result.html:560`) — whether the "Skill up yourself"
  /// button inside the AI Suggestions card should render.
  final bool showSkillUpAction;

  final bool? resumeValid;
  final String? validationMessage;

  /// [gate], falling back to a 2-way split of [canInterview] for any
  /// caller that predates Phase 46 and never set [gate] explicitly. Every
  /// real, freshly-parsed result always sets [gate], making this fallback
  /// unreachable in production — it exists purely so pre-Phase-46 test
  /// fixtures that only ever set [canInterview] keep behaving exactly as
  /// they did before (planLocked for `canInterview: false`, eligible for
  /// `canInterview: true`), without needing to touch every one of them.
  ResumeInterviewGate get effectiveGate =>
      gate ?? (canInterview ? ResumeInterviewGate.eligible : ResumeInterviewGate.planLocked);
}
