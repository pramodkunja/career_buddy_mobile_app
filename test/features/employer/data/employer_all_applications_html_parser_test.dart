import 'package:career_buddy_lms/features/employer/data/employer_all_applications_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the real markup of `templates/employer/all_applications.html`
/// (`jobs_app.views.all_applications`), live-verified against a real
/// account with 4 real applications across 1 job.
const _fixtureWithApplications = '''
<div class="row g-3">
    <div class="col-12">
        <div class="application-card p-4 resume-parsed-card">
            <div class="row align-items-center">
                <div class="col-md-5">
                    <div class="d-flex align-items-center gap-2 mb-1">
                        <div class="fw-bold fs-5 text-slate-900">Renuka</div>
                        <span class="source-badge-parsed"><i class="fas fa-magic me-1"></i>Resume Parsed</span>
                    </div>
                    <div class="text-slate-500 small mb-2"><i class="fas fa-envelope me-1 text-slate-400"></i>renuka@example.com</div>
                    <span class="job-tag"><i class="fas fa-briefcase me-1"></i> Senior Python Developer</span>
                </div>
                <div class="col-md-4 my-2 my-md-0">
                    <div class="d-flex flex-column gap-1">
                        <div class="small text-slate-500"><strong>Applied:</strong> 25 Aug 2026, 17:57</div>
                    </div>
                </div>
                <div class="col-md-3 text-md-end">
                    <div class="d-flex flex-column align-items-md-end gap-2">
                        <span class="app-status-badge status-offered">Offer Extended</span>
                        <a href="/employer/employer/applications/16/" class="btn btn-sm btn-outline-primary">Review Submission</a>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="col-12">
        <div class="application-card p-4">
            <div class="row align-items-center">
                <div class="col-md-5">
                    <div class="d-flex align-items-center gap-2 mb-1">
                        <div class="fw-bold fs-5 text-slate-900">Sai Venkat</div>
                        <span class="source-badge-direct"><i class="fas fa-check-circle me-1"></i>Direct Apply</span>
                    </div>
                    <div class="text-slate-500 small mb-2"><i class="fas fa-envelope me-1 text-slate-400"></i>sai@example.com</div>
                    <span class="job-tag"><i class="fas fa-briefcase me-1"></i> Backend Engineer</span>
                </div>
                <div class="col-md-4 my-2 my-md-0">
                    <div class="d-flex flex-column gap-1">
                        <div class="small text-slate-500"><strong>Applied:</strong> 25 Aug 2026, 13:01</div>
                    </div>
                </div>
                <div class="col-md-3 text-md-end">
                    <div class="d-flex flex-column align-items-md-end gap-2">
                        <span class="app-status-badge status-under_review">Under Review</span>
                        <a href="/employer/employer/applications/12/" class="btn btn-sm btn-outline-primary">Review Submission</a>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
''';

const _fixtureEmpty = '''
<div class="row g-3">
    <div class="col-12">
        <div class="text-center py-5 bg-white border border-slate-200 rounded-3">
            <h5 class="fw-bold text-slate-700">No applications found</h5>
        </div>
    </div>
</div>
''';

void main() {
  group('parseEmployerAllApplicationsHtml', () {
    test('parses every card, including source and job title', () {
      final page = parseEmployerAllApplicationsHtml(_fixtureWithApplications);

      expect(page.applications, hasLength(2));

      expect(page.applications[0].applicationId, 16);
      expect(page.applications[0].applicantName, 'Renuka');
      expect(page.applications[0].jobTitle, 'Senior Python Developer');
      expect(page.applications[0].source, 'resume_parsed');
      expect(page.applications[0].status, 'offered');
      expect(page.applications[0].appliedAt, '25 Aug 2026, 17:57');

      expect(page.applications[1].applicationId, 12);
      expect(page.applications[1].applicantName, 'Sai Venkat');
      expect(page.applications[1].jobTitle, 'Backend Engineer');
      expect(page.applications[1].source, 'direct');
      expect(page.applications[1].status, 'reviewing');
    });

    test('an empty result parses to an empty list, not a crash', () {
      final page = parseEmployerAllApplicationsHtml(_fixtureEmpty);

      expect(page.applications, isEmpty);
    });
  });
}
