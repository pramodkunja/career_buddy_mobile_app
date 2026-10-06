/// `jobs_app.views.search_candidates` / `search_registered_candidates`
/// (`templates/jobs/candidate_search.html`) — a registered-student search
/// result. [skillCount] and [skills] are only meaningful relative to the
/// query that produced this result (server-computed, not reproducible
/// client-side).
class EmployerCandidateSearchResult {
  const EmployerCandidateSearchResult({
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    required this.experience,
    required this.skillCount,
    required this.industry,
    required this.education,
    required this.skills,
    required this.resumeUrl,
  });

  final String name;
  final String email;
  final String phone;
  final String location;

  /// Already formatted exactly as the web renders it (e.g. `"3+ Years"` or
  /// `"Fresher"`).
  final String experience;
  final int skillCount;
  final String industry;
  final String education;
  final List<String> skills;
  final String? resumeUrl;
}

/// `EXPERIENCE_CHOICES` as rendered by `candidate_search.html`'s own
/// `<select name="experience">` — a genuinely different set from
/// `JobPosting.EXPERIENCE_CHOICES` (see `ApiEndpoints.
/// employerSearchCandidates`'s doc comment), reproduced as-is.
const List<(String value, String label)> kCandidateSearchExperienceOptions = [
  ('fresher', 'Fresher'),
  ('1-3', '1-3 Years'),
  ('3-5', '3-5 Years'),
  ('5+', '5+ Years'),
];
