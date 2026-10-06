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

  final bool? resumeValid;
  final String? validationMessage;
}
