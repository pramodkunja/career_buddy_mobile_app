import 'package:career_buddy_lms/features/employer/data/employer_candidate_search_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the real markup of `templates/jobs/candidate_search.html`
/// (`jobs_app.views.search_candidates`), live-verified against a real
/// account (84 real candidates parsed correctly).
const _fixtureWithResults = '''
<div class="row g-4">
    <div class="col-md-6 col-lg-4">
        <div class="candidate-card p-4">
            <div class="d-flex align-items-start mb-3">
                <div class="rounded-circle bg-light p-3 me-3 text-primary"><i class="fas fa-user-tie fa-2x"></i></div>
                <div>
                    <h5 class="fw-bold mb-1">Priya Sharma
                        <span class="badge bg-success ms-1" title="Number of searched skills this candidate has">
                            <i class="fas fa-bolt me-1"></i>2 matches
                        </span>
                    </h5>
                    <p class="text-muted small mb-0"><i class="fas fa-map-marker-alt me-1"></i> Bengaluru</p>
                </div>
            </div>
            <div class="mb-3">
                <p class="small text-muted mb-2">Experience: <strong>5+ Years</strong></p>
                <p class="small text-muted mb-2">Industry: <strong>Information Technology</strong></p>
                <p class="small text-muted mb-2">Education: <strong>B.Tech</strong></p>
                <div class="skills-wrapper">
                    <span class="skill-badge skill-match">Python</span>
                    <span class="skill-badge">Django</span>
                </div>
            </div>
            <div class="border-top pt-3 d-flex justify-content-between align-items-center">
                <div class="contact-icons">
                    <a href="mailto:priya@example.com" class="text-muted me-3" title="priya@example.com"><i class="fas fa-envelope"></i></a>
                    <a href="tel:+919876543210" class="text-muted" title="+919876543210"><i class="fas fa-phone"></i></a>
                </div>
                <a href="/media/resumes/priya.pdf" class="btn btn-sm btn-outline-primary px-3" target="_blank">
                    <i class="fas fa-file-pdf me-1"></i> View Resume
                </a>
            </div>
        </div>
    </div>
    <div class="col-md-6 col-lg-4">
        <div class="candidate-card p-4">
            <div class="d-flex align-items-start mb-3">
                <div class="rounded-circle bg-light p-3 me-3 text-primary"><i class="fas fa-user-tie fa-2x"></i></div>
                <div>
                    <h5 class="fw-bold mb-1">Alex Kumar
                    </h5>
                    <p class="text-muted small mb-0"><i class="fas fa-map-marker-alt me-1"></i> Not Specified</p>
                </div>
            </div>
            <div class="mb-3">
                <p class="small text-muted mb-2">Experience: <strong>Information not extracted</strong></p>
                <p class="small text-muted mb-2">Industry: <strong>Not Specified</strong></p>
                <p class="small text-muted mb-2">Education: <strong>Not Specified</strong></p>
                <div class="skills-wrapper">
                    <span class="text-muted italic small">Skills not detected</span>
                </div>
            </div>
            <div class="border-top pt-3 d-flex justify-content-between align-items-center">
                <div class="contact-icons">
                    <a href="mailto:alex@example.com" class="text-muted me-3" title="alex@example.com"><i class="fas fa-envelope"></i></a>
                    <a href="tel:Not provided" class="text-muted" title="Not provided"><i class="fas fa-phone"></i></a>
                </div>
                <span class="badge bg-light text-muted border">No resume uploaded</span>
            </div>
        </div>
    </div>
</div>
''';

void main() {
  group('parseEmployerCandidateSearchHtml', () {
    test('parses every candidate card, including the skill-match badge and resume link', () {
      final results = parseEmployerCandidateSearchHtml(_fixtureWithResults);

      expect(results, hasLength(2));

      expect(results[0].name, 'Priya Sharma');
      expect(results[0].skillCount, 2);
      expect(results[0].location, 'Bengaluru');
      expect(results[0].experience, '5+ Years');
      expect(results[0].industry, 'Information Technology');
      expect(results[0].skills, ['Python', 'Django']);
      expect(results[0].email, 'priya@example.com');
      expect(results[0].resumeUrl, '/media/resumes/priya.pdf');

      expect(results[1].name, 'Alex Kumar');
      expect(results[1].skillCount, 0);
      expect(results[1].skills, isEmpty);
      expect(results[1].resumeUrl, isNull);
    });

    test('no candidate-card markup parses to an empty list, not a crash', () {
      expect(parseEmployerCandidateSearchHtml('<div class="empty-state">Ready to search?</div>'), isEmpty);
    });
  });
}
