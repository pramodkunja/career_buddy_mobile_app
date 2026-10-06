/// `jobs_app.views.job_detail` (`templates/jobs/job_detail.html`) — the
/// public, job-seeker-facing job listing page. Reachable by anyone
/// (anonymous, student, or employer), with the apply form only rendered
/// server-side when the session isn't an employer portal session
/// (`request.session.portal != 'employer'`) — reproduced client-side from
/// the already-known auth state rather than re-derived from the HTML.
class PublicJobDetail {
  const PublicJobDetail({
    required this.title,
    required this.companyName,
    required this.jobType,
    required this.experience,
    required this.location,
    required this.salaryDisplay,
    required this.openings,
    required this.description,
    required this.requirements,
    required this.skills,
    required this.deadline,
  });

  final String title;
  final String companyName;
  final String jobType;
  final String experience;
  final String location;
  final String salaryDisplay;
  final String openings;
  final String description;
  final String requirements;
  final List<String> skills;

  /// Already formatted exactly as Django's default `{{ job.deadline }}`
  /// renders a `DateField` (e.g. `"Aug. 25, 2026"`), or empty if unset.
  final String deadline;
}

/// `jobs_app.forms.JobApplicationForm` — the public apply form. Only
/// [name]/[email]/[phoneE164] are required (`applicant_phone` is required
/// via `phone_input.html`, not the model's own `blank=True`).
class PublicJobApplicationSubmission {
  const PublicJobApplicationSubmission({
    required this.name,
    required this.email,
    required this.phoneE164,
    this.resumePath,
    this.coverLetter = '',
    this.skills = '',
    this.yearsExperience,
    this.currentCompany = '',
    this.currentSalary,
    this.expectedSalary,
  });

  final String name;
  final String email;
  final String phoneE164;
  final String? resumePath;
  final String coverLetter;
  final String skills;
  final int? yearsExperience;
  final String currentCompany;
  final double? currentSalary;
  final double? expectedSalary;
}
