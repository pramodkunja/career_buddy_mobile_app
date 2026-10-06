/// `jobs_app.models.JobApplication` + `templates/employer/
/// application_detail.html` — every field the real web page renders for
/// one application, scoped to the viewing employer's own job (the server
/// 404s, not 403s, if an employer tries another employer's application id
/// — `jobs_app/views.py:684-691`).
///
/// Deliberately excluded, matching a real, confirmed web-side bug rather
/// than inventing a fix for it: the "Extracted Skills" section
/// (`application_detail.html:157-166`) reads `app.parsed_skills`, a
/// template variable that does not exist anywhere in the Python source
/// (confirmed via a project-wide grep) — Django silently renders nothing
/// for an undefined attribute, so `{% if app.parsed_skills %}` is always
/// false and this section never actually appears on the real web page.
/// The real field (`applicant_skills`/`get_skills_list()`) is populated
/// data, but showing it in Flutter would mean showing the user something
/// the web itself never does — a parity mismatch, not an improvement.
class EmployerApplicationDetail {
  const EmployerApplicationDetail({
    required this.applicantName,
    required this.jobTitle,
    required this.applicantEmail,
    required this.applicantPhone,
    required this.yearsExperience,
    required this.currentCompany,
    required this.currentSalary,
    required this.expectedSalary,
    required this.resumeUrl,
    required this.coverLetter,
    required this.interviewScore,
    required this.interviewVideoUrl,
    required this.interviewRecordedAt,
    required this.status,
    required this.employerNotes,
    required this.appliedAt,
  });

  final String applicantName;
  final String jobTitle;
  final String applicantEmail;
  final String applicantPhone;
  final int yearsExperience;
  final String currentCompany;

  /// Already-formatted display strings ("₹45000.00 LPA" or "N/A") — the web
  /// does no further computation on these beyond the `{% if %}`/currency
  /// prefix shown in the template, so there is nothing to parse out into a
  /// number client-side.
  final String currentSalary;
  final String expectedSalary;

  final String? resumeUrl;
  final String? coverLetter;

  /// AI Mock Interview recording — all three are null together (the
  /// template's `{% if interview_session %}` gate) or all populated
  /// together.
  final int? interviewScore;
  final String? interviewVideoUrl;
  final String? interviewRecordedAt;

  /// One of `JobApplication.STATUS_CHOICES`' 6 values.
  final String status;
  final String employerNotes;
  final String appliedAt;
}

/// `JobApplication.STATUS_CHOICES` (`jobs_app/models.py:243-247`), verbatim.
class ApplicationStatusOption {
  const ApplicationStatusOption(this.value, this.label);
  final String value;
  final String label;
}

const List<ApplicationStatusOption> kApplicationStatusOptions = [
  ApplicationStatusOption('applied', 'Applied'),
  ApplicationStatusOption('reviewing', 'Under Review'),
  ApplicationStatusOption('shortlisted', 'Shortlisted'),
  ApplicationStatusOption('interview', 'Interview Scheduled'),
  ApplicationStatusOption('offered', 'Offer Extended'),
  ApplicationStatusOption('rejected', 'Rejected'),
];
