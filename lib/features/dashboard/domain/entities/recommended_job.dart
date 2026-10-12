class RecommendedJob {
  const RecommendedJob({
    required this.title,
    required this.companyName,
    required this.skills,
    required this.location,
    required this.jobType,
    required this.experienceLevel,
    required this.salaryDisplay,
    this.id,
  });

  /// `job.pk`, scraped from the card's own "View & Apply" link
  /// (`dashboard.html:142`, `{% url 'employer_portal:job_detail' job.pk %}`)
  /// — present in the real HTML's `href` attribute even though it's never
  /// shown as visible text. `null` only when that link's markup doesn't
  /// match (e.g. a future template change) — never fabricated — so the
  /// card can still render every other real field while safely refusing
  /// to navigate anywhere (see `RecommendedJobsSection`'s `_JobCard`).
  final int? id;

  final String title;
  final String companyName;
  final List<String> skills;
  final String location;
  final String jobType;
  final String experienceLevel;
  final String salaryDisplay;
}
