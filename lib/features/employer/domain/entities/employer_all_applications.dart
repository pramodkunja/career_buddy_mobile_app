/// `jobs_app.views.all_applications` (`templates/employer/
/// all_applications.html`) — every application across all of the caller's
/// own job postings, optionally filtered server-side by `?q=`/`?status=`/
/// `?source=`.
class EmployerAllApplicationsPage {
  const EmployerAllApplicationsPage({required this.applications});

  final List<EmployerAllApplicationListItem> applications;
}

class EmployerAllApplicationListItem {
  const EmployerAllApplicationListItem({
    required this.applicationId,
    required this.applicantName,
    required this.applicantEmail,
    required this.jobTitle,
    required this.source,
    required this.appliedAt,
    required this.status,
  });

  final int applicationId;
  final String applicantName;
  final String applicantEmail;
  final String jobTitle;

  /// `JobApplication.SOURCE_CHOICES`' raw value — `'direct'` or
  /// `'resume_parsed'`.
  final String source;

  /// Already formatted exactly as the web renders it (`d M Y, H:i`).
  final String appliedAt;

  /// `JobApplication.STATUS_CHOICES`' raw value — see
  /// `kApplicationStatusOptions`.
  final String status;
}

/// `JobApplication.SOURCE_CHOICES` (`jobs_app/models.py`).
const List<(String value, String label)> kApplicationSourceOptions = [
  ('direct', 'Direct Apply'),
  ('resume_parsed', 'Resume Parsed'),
];
