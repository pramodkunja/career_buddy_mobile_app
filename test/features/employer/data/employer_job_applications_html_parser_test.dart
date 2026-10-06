import 'package:career_buddy_lms/features/employer/data/employer_job_applications_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the real markup of `templates/employer/applications.html`
/// (`jobs_app.views.job_applications`), live-verified against a real job
/// with 4 real applications.
const _fixtureWithApplications = '''
<h1 class="fw-extrabold text-slate-900 mb-1" style="font-size: 2.2rem;">Senior Python Developer</h1>
<p class="text-slate-600 mb-0">2 candidate submission(s) for this job opening.</p>
<div class="row g-3 justify-content-center">
    <div class="col-12">
        <div class="candidate-card p-4">
            <div class="row align-items-center">
                <div class="col-md-5 d-flex align-items-center gap-3">
                    <div class="candidate-avatar">RE</div>
                    <div>
                        <h5 class="fw-bold text-slate-900 mb-0">Renuka</h5>
                        <div class="text-slate-500 small"><i class="fas fa-envelope me-1 text-slate-400"></i>renuka@example.com</div>
                    </div>
                </div>
                <div class="col-md-2 text-center my-2 my-md-0">
                    <div class="small text-slate-400 font-semibold text-uppercase">Experience</div>
                    <div class="fw-bold text-slate-800">1 yr(s)</div>
                </div>
                <div class="col-md-2 text-center my-2 my-md-0">
                    <div class="small text-slate-400 font-semibold text-uppercase mb-1">Status</div>
                    <span class="app-status-badge status-offered">
                        Offer Extended
                    </span>
                </div>
                <div class="col-md-3 text-md-end">
                    <a href="/employer/employer/applications/16/" class="btn btn-primary px-4 py-2">
                        Review Submission <i class="fas fa-arrow-right ms-1"></i>
                    </a>
                </div>
            </div>
        </div>
    </div>
    <div class="col-12">
        <div class="candidate-card p-4">
            <div class="row align-items-center">
                <div class="col-md-5 d-flex align-items-center gap-3">
                    <div class="candidate-avatar">SA</div>
                    <div>
                        <h5 class="fw-bold text-slate-900 mb-0">Sai Venkat</h5>
                        <div class="text-slate-500 small"><i class="fas fa-envelope me-1 text-slate-400"></i>sai@example.com</div>
                    </div>
                </div>
                <div class="col-md-2 text-center my-2 my-md-0">
                    <div class="small text-slate-400 font-semibold text-uppercase">Experience</div>
                    <div class="fw-bold text-slate-800">0 yr(s)</div>
                </div>
                <div class="col-md-2 text-center my-2 my-md-0">
                    <div class="small text-slate-400 font-semibold text-uppercase mb-1">Status</div>
                    <span class="app-status-badge status-under_review">
                        Under Review
                    </span>
                </div>
                <div class="col-md-3 text-md-end">
                    <a href="/employer/employer/applications/12/" class="btn btn-primary px-4 py-2">
                        Review Submission <i class="fas fa-arrow-right ms-1"></i>
                    </a>
                </div>
            </div>
        </div>
    </div>
</div>
''';

const _fixtureEmpty = '''
<h1 class="fw-extrabold text-slate-900 mb-1">Backend Engineer</h1>
<div class="col-12 text-center py-5 bg-white border border-slate-200 rounded-3">
    <h5 class="fw-bold text-slate-700">No applications found for this status.</h5>
</div>
''';

void main() {
  group('parseEmployerJobApplicationsHtml', () {
    test('parses the job title and every candidate card', () {
      final page = parseEmployerJobApplicationsHtml(_fixtureWithApplications);

      expect(page.jobTitle, 'Senior Python Developer');
      expect(page.applications, hasLength(2));

      expect(page.applications[0].applicationId, 16);
      expect(page.applications[0].applicantName, 'Renuka');
      expect(page.applications[0].applicantEmail, 'renuka@example.com');
      expect(page.applications[0].yearsExperience, 1);
      expect(page.applications[0].status, 'offered');

      expect(page.applications[1].applicationId, 12);
      expect(page.applications[1].applicantName, 'Sai Venkat');
      expect(page.applications[1].yearsExperience, 0);
      expect(page.applications[1].status, 'reviewing');
    });

    test('an empty candidate list parses to an empty applications list, not a crash', () {
      final page = parseEmployerJobApplicationsHtml(_fixtureEmpty);

      expect(page.jobTitle, 'Backend Engineer');
      expect(page.applications, isEmpty);
    });
  });
}
