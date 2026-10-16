/// `preview_api`'s `completeness` field (`career_app/resume_document.py`'s
/// `completeness()`, verified directly: 6 fixed categories — personal,
/// career, education, skills, experience, extras). Parsed but, per Phase
/// 26's own precedent of deliberately not building the web's completeness
/// meter UI, only shown as a brief summary here rather than a full
/// per-category meter.
class ManualResumeCompletenessCategory {
  const ManualResumeCompletenessCategory({
    required this.key,
    required this.label,
    required this.value,
    required this.optional,
    required this.step,
  });

  final String key;
  final String label;

  /// 0–100.
  final int value;
  final bool optional;
  final int step;
}

class ManualResumeCompletenessSummary {
  const ManualResumeCompletenessSummary({required this.overall, required this.categories});

  /// 0–100.
  final int overall;
  final List<ManualResumeCompletenessCategory> categories;
}
