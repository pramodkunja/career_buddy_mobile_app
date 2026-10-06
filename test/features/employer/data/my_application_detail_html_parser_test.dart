import 'package:career_buddy_lms/features/employer/data/my_application_detail_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the real markup of `templates/jobs/my_application.html`
/// (`jobs_app.views.my_application_detail`), built from the exact Django
/// source read directly (`jobs_app/views.py:147-153`).
const _fixtureWithCoverLetter = '''
<span class="badge mb-3">Application #12</span>
<h1 class="fw-bold mb-1">Senior Python Developer</h1>
<p class="mb-4">
    Acme Corp
     &middot; Hyderabad
</p>
<div class="d-flex flex-wrap align-items-center gap-3 mb-4">
    <span>Current status</span>
    <span class="badge px-3 py-2 rounded-pill bg-primary-subtle text-primary border border-primary-subtle">
        Under Review
    </span>
</div>
<div class="row g-3">
    <div class="col-sm-6">
        <div>Applied on</div>
        <div>10 Sep 2026, 09:15</div>
    </div>
    <div class="col-sm-6">
        <div>Last updated</div>
        <div>12 Sep 2026, 14:00</div>
    </div>
    <div class="col-sm-6">
        <div>Applied as</div>
        <div>Alex Kumar &middot; alex@example.com</div>
    </div>
    <div class="col-sm-6">
        <div>Job type</div>
        <div>Full Time &middot; 5-8 Years</div>
    </div>
</div>
<div>Your cover letter</div>
<p>I am excited to apply.</p>
<div class="mt-4">
    <a href="/employer/jobs/68/">View job posting</a>
</div>
''';

const _fixtureMinimal = '''
<span class="badge mb-3">Application #9</span>
<h1 class="fw-bold mb-1">Backend Engineer</h1>
<p class="mb-4">
    Career Buddy Partner
</p>
<span class="badge px-3 py-2 rounded-pill bg-danger-subtle text-danger border border-danger-subtle">
    Rejected
</span>
<div>Applied on</div>
<div>1 Oct 2026, 08:00</div>
<div>Last updated</div>
<div>1 Oct 2026, 08:00</div>
<div>Applied as</div>
<div>Jordan Lee &middot; jordan@example.com</div>
<div>Job type</div>
<div>Internship &middot; Fresher</div>
''';

void main() {
  group('parseMyApplicationDetailHtml', () {
    test('parses every field, including the cover letter and job-posting link', () {
      final d = parseMyApplicationDetailHtml(_fixtureWithCoverLetter);

      expect(d.applicationId, 12);
      expect(d.jobTitle, 'Senior Python Developer');
      expect(d.companyName, 'Acme Corp');
      expect(d.jobLocation, 'Hyderabad');
      expect(d.status, 'reviewing');
      expect(d.appliedAt, '10 Sep 2026, 09:15');
      expect(d.updatedAt, '12 Sep 2026, 14:00');
      expect(d.applicantName, 'Alex Kumar');
      expect(d.applicantEmail, 'alex@example.com');
      expect(d.jobType, 'Full Time');
      expect(d.jobExperience, '5-8 Years');
      expect(d.coverLetter, 'I am excited to apply.');
      expect(d.jobId, 68);
      expect(d.jobIsActive, isTrue);
    });

    test('handles a closed job (no posting link) and no cover letter', () {
      final d = parseMyApplicationDetailHtml(_fixtureMinimal);

      expect(d.applicationId, 9);
      expect(d.companyName, 'Career Buddy Partner');
      expect(d.jobLocation, isEmpty);
      expect(d.status, 'rejected');
      expect(d.coverLetter, isNull);
      expect(d.jobIsActive, isFalse);
      expect(d.jobId, isNull);
    });
  });
}
