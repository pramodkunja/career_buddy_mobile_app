/// One row of the "My Job Postings" table (`templates/employer/
/// dashboard.html:229-256`).
class EmployerJobListItem {
  const EmployerJobListItem({
    required this.jobId,
    required this.title,
    required this.jobType,
    required this.status,
    required this.applicationsCount,
    required this.postedDate,
  });

  /// Scraped from the row's own Edit link (`.../jobs/<pk>/edit/`) — the
  /// table never prints the id as visible text.
  final int jobId;
  final String title;
  final String jobType;

  /// One of `'active'`/`'closed'`/`'draft'` — normalized from the
  /// rendered badge text ("Active"/"Closed"/"Draft").
  final String status;
  final int applicationsCount;

  /// Already formatted exactly as the web renders it (`d M Y`, e.g.
  /// "05 Jan 2026") — not re-parsed into a `DateTime`, since the server
  /// never sends the raw ISO value to begin with.
  final String postedDate;
}

/// Parsed from `jobs_app.views.employer_dashboard`'s server-rendered HTML
/// (`templates/employer/dashboard.html`) — no JSON API exists (see
/// `ApiEndpoints.employerDashboard`'s doc comment). `own_jobs`/
/// `recent_apps` are computed by the view but never rendered in this
/// template (confirmed by reading it directly) — not represented here,
/// since there's nothing on the real page to port.
class EmployerDashboardSummary {
  const EmployerDashboardSummary({
    required this.greetingName,
    required this.totalJobsCount,
    required this.activeJobs,
    required this.totalApps,
    required this.jobs,
  });

  final String greetingName;
  final int totalJobsCount;
  final int activeJobs;
  final int totalApps;
  final List<EmployerJobListItem> jobs;
}
