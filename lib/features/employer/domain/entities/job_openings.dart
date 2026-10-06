/// `jobs_app.views.job_openings` (`templates/employer/job_openings.html`)
/// — every active job posting (employer-posted + seeded), job-seeker
/// facing despite its URL living under `jobs_app.employer_urls`
/// (`@login_required`, no employer-portal/profile check — confirmed live).
class JobOpeningsPage {
  const JobOpeningsPage({required this.jobs});

  final List<JobOpeningListItem> jobs;
}

class JobOpeningListItem {
  const JobOpeningListItem({
    required this.jobId,
    required this.title,
    required this.companyName,
    required this.jobType,
    required this.isSeeded,
    required this.location,
    required this.experience,
    required this.skills,
    required this.salaryDisplay,
  });

  final int jobId;
  final String title;
  final String companyName;
  final String jobType;

  /// `"CB"` ("Career Buddy Listed") vs `"Mine"` badge in the template —
  /// drives the client-side-only "My Postings"/"Career Buddy Listed"
  /// filter tabs (no server-side filter param exists for this view).
  final bool isSeeded;
  final String location;
  final String experience;

  /// Only the first 2 skills (`job.get_skills_list|slice:":2"` in the real
  /// template) — not the job's full skill list.
  final List<String> skills;
  final String salaryDisplay;
}
