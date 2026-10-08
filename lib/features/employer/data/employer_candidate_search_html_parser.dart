import '../../../core/utils/html_unescape.dart';
import '../domain/entities/employer_candidate_search.dart';

/// Parses `templates/jobs/candidate_search.html` (`jobs_app.views.
/// search_candidates`). Same card-start-marker splitting technique as the
/// other employer list parsers — cards nest to an unpredictable depth.
List<EmployerCandidateSearchResult> parseEmployerCandidateSearchHtml(String html) {
  final starts = [for (final m in RegExp(r'candidate-card p-4">').allMatches(html)) m.end];
  final results = <EmployerCandidateSearchResult>[];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : html.length;
    final card = html.substring(starts[i], end);

    final nameMatch = RegExp(r'fw-bold mb-1">\s*([^<\n]+?)\s*(?:<span|\n\s*</h5>|</h5>)').firstMatch(card);
    if (nameMatch == null) continue;

    final skillCountMatch = RegExp(r'fa-bolt me-1"></i>(\d+)\s*match').firstMatch(card);
    final locationMatch = RegExp(r'fa-map-marker-alt me-1"></i>\s*([^<]*?)\s*</p>').firstMatch(card);
    final experienceMatch = RegExp(r'Experience:\s*<strong>([^<]*)</strong>').firstMatch(card);
    final industryMatch = RegExp(r'Industry:\s*<strong>([^<]*)</strong>').firstMatch(card);
    final educationMatch = RegExp(r'Education:\s*<strong>([^<]*)</strong>').firstMatch(card);
    final emailMatch = RegExp(r'mailto:([^"]*)"').firstMatch(card);
    final phoneMatch = RegExp(r'tel:([^"]*)"').firstMatch(card);
    final resumeMatch = RegExp(r'<a href="([^"]*)" class="btn btn-sm btn-outline-primary px-3"').firstMatch(card);

    final skills = [
      for (final m in RegExp(r'skill-badge[^"]*">\s*([^<]+?)\s*</span>').allMatches(card)) _unescape(m.group(1)!.trim()),
    ];

    results.add(
      EmployerCandidateSearchResult(
        name: _unescape(nameMatch.group(1)!.trim()),
        email: _unescape(emailMatch?.group(1)?.trim() ?? ''),
        phone: _unescape(phoneMatch?.group(1)?.trim() ?? ''),
        location: _unescape(locationMatch?.group(1)?.trim() ?? ''),
        experience: _unescape(experienceMatch?.group(1)?.trim() ?? ''),
        skillCount: int.tryParse(skillCountMatch?.group(1) ?? '') ?? 0,
        industry: _unescape(industryMatch?.group(1)?.trim() ?? ''),
        education: _unescape(educationMatch?.group(1)?.trim() ?? ''),
        skills: skills,
        resumeUrl: resumeMatch?.group(1),
      ),
    );
  }
  return results;
}

String _unescape(String value) => unescapeHtmlEntities(value);
