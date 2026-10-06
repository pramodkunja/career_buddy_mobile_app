/// `jobs_app.views.job_applications` (`templates/employer/applications.html`)
/// — one job's candidate list, optionally filtered server-side by
/// `?status=`.
class EmployerJobApplicationsPage {
  const EmployerJobApplicationsPage({
    required this.jobTitle,
    required this.applications,
  });

  final String jobTitle;
  final List<EmployerJobApplicationListItem> applications;
}

class EmployerJobApplicationListItem {
  const EmployerJobApplicationListItem({
    required this.applicationId,
    required this.applicantName,
    required this.applicantEmail,
    required this.yearsExperience,
    required this.status,
  });

  final int applicationId;
  final String applicantName;
  final String applicantEmail;
  final int yearsExperience;

  /// One of `JobApplication.STATUS_CHOICES`' values (`applied`/`reviewing`/
  /// `shortlisted`/`interview`/`offered`/`rejected`) — the raw value, not
  /// the display label (`app.status` in the template, the same convention
  /// already used by `EmployerApplicationDetail.status` and
  /// `kApplicationStatusOptions`).
  final String status;
}
