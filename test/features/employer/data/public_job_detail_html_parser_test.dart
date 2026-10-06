import 'package:career_buddy_lms/features/employer/data/public_job_detail_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the real markup of `templates/jobs/job_detail.html`
/// (`jobs_app.views.job_detail`), live-verified against a real production
/// job posting.
const _fixtureHtml = '''
<div class="d-flex align-items-center mb-3">
  <div>
    <h3 class="fw-bold mb-0">Senior Python Developer</h3>
    <span class="text-muted">Acme Corp</span>
  </div>
</div>
<div class="mb-3 d-flex flex-wrap gap-2">
  <span class="badge bg-primary">Full Time</span>
  <span class="badge bg-secondary">5-8 Years</span>
  <span class="badge bg-info text-dark"><i class="fas fa-map-marker-alt me-1"></i>Hyderabad</span>
  <span class="badge bg-success"><i class="fas fa-money-bill-wave me-1"></i>₹12 - 18 LPA</span>
  <span class="badge bg-warning text-dark">3 Opening(s)</span>
</div>
<h5 class="fw-bold mb-3">Job Description</h5>
<p>We are looking for a skilled engineer.</p>
<p>You will work on our core platform.</p>
<h5 class="fw-bold mt-4 mb-3">Requirements</h5>
<p>5+ years of Python experience.</p>
<h5 class="fw-bold mt-4 mb-3">Skills Required</h5>
<div><span class="badge-skill me-1 mb-1">Python</span><span class="badge-skill me-1 mb-1">Django</span></div>
<p class="mt-3 text-muted small"><i class="fas fa-calendar me-1"></i>Application Deadline: <strong>Dec. 31, 2026</strong></p>
''';

const _fixtureNoDeadline = '''
<h3 class="fw-bold mb-0">Backend Engineer</h3>
<span class="text-muted">Acme Corp</span>
<span class="badge bg-primary">Remote</span>
<span class="badge bg-secondary">Fresher</span>
<span class="badge bg-info text-dark"><i class="fas fa-map-marker-alt me-1"></i>Remote</span>
<span class="badge bg-success"><i class="fas fa-money-bill-wave me-1"></i>As per industry norms</span>
<span class="badge bg-warning text-dark">1 Opening(s)</span>
<h5 class="fw-bold mb-3">Job Description</h5>
<p>Join our team.</p>
<h5 class="fw-bold mt-4 mb-3">Requirements</h5>
<p>None listed.</p>
<h5 class="fw-bold mt-4 mb-3">Skills Required</h5>
<div></div>
''';

void main() {
  group('parsePublicJobDetailHtml', () {
    test('parses every field, including a multi-paragraph description', () {
      final d = parsePublicJobDetailHtml(_fixtureHtml);

      expect(d.title, 'Senior Python Developer');
      expect(d.companyName, 'Acme Corp');
      expect(d.jobType, 'Full Time');
      expect(d.experience, '5-8 Years');
      expect(d.location, 'Hyderabad');
      expect(d.salaryDisplay, '₹12 - 18 LPA');
      expect(d.openings, '3 Opening(s)');
      expect(d.description, contains('skilled engineer'));
      expect(d.description, contains('core platform'));
      expect(d.requirements, contains('5+ years'));
      expect(d.skills, ['Python', 'Django']);
      expect(d.deadline, 'Dec. 31, 2026');
    });

    test('handles a job with no deadline and no skills, not a crash', () {
      final d = parsePublicJobDetailHtml(_fixtureNoDeadline);

      expect(d.title, 'Backend Engineer');
      expect(d.deadline, isEmpty);
      expect(d.skills, isEmpty);
    });
  });
}
