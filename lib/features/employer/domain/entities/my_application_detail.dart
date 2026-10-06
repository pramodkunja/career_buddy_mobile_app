/// `jobs_app.views.my_application_detail` (`templates/jobs/
/// my_application.html`) — a student's read-only view of their own job
/// application.
class MyApplicationDetail {
  const MyApplicationDetail({
    required this.applicationId,
    required this.jobId,
    required this.jobTitle,
    required this.companyName,
    required this.jobLocation,
    required this.status,
    required this.appliedAt,
    required this.updatedAt,
    required this.applicantName,
    required this.applicantEmail,
    required this.jobType,
    required this.jobExperience,
    required this.coverLetter,
    required this.jobIsActive,
  });

  final int applicationId;

  /// Null when the job posting link couldn't be resolved from the page
  /// (should not normally happen — every application has a job).
  final int? jobId;
  final String jobTitle;
  final String companyName;
  final String jobLocation;

  /// `JobApplication.STATUS_CHOICES`' raw value.
  final String status;

  /// Already formatted exactly as the web renders it (`d M Y, H:i`).
  final String appliedAt;
  final String updatedAt;
  final String applicantName;
  final String applicantEmail;
  final String jobType;
  final String jobExperience;
  final String? coverLetter;

  /// `{% if app.job.status == 'active' %}` gates the "View job posting"
  /// link — a closed/draft job's posting page isn't linked.
  final bool jobIsActive;
}
