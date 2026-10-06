import 'package:career_buddy_lms/features/employer/data/job_openings_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the real markup of `templates/employer/job_openings.html`
/// (`jobs_app.views.job_openings`), live-verified against a real account
/// (80 real active jobs parsed correctly).
const _fixtureWithJobs = '''
<div class="row g-4" id="jobs-grid">
    <div class="col-sm-6 col-md-4 col-xl-3 job-card-col" data-seeded="false">
        <div class="job-opening-card">
            <div class="d-flex justify-content-between align-items-start mb-3">
                <div class="d-flex align-items-center gap-2 overflow-hidden" style="flex:1;min-width:0;">
                    <div class="company-logo-placeholder"><i class="fas fa-briefcase"></i></div>
                    <div class="overflow-hidden">
                        <h6 class="fw-bold mb-0 text-truncate text-slate-900" title="Senior Python Developer">Senior Python Developer</h6>
                        <p class="text-slate-500 small mb-0 text-truncate">Acme Corp</p>
                    </div>
                </div>
                <span class="badge rounded-pill ms-1 flex-shrink-0" style="font-size:0.65rem; background:#eff6ff; color:#185adb; border:1px solid #bfdbfe;">Mine</span>
            </div>
            <div class="mb-3">
                <div class="mb-2"><span class="job-badge badge-full_time">Full Time</span></div>
                <div class="text-slate-500 small mb-2"><i class="fas fa-map-marker-alt me-1 text-slate-400"></i> Hyderabad</div>
                <div class="text-slate-500 small mb-2"><i class="fas fa-briefcase me-1 text-slate-400"></i> 5-8 Years</div>
                <div class="d-flex flex-wrap gap-1">
                    <span class="skill-tag">Python</span>
                    <span class="skill-tag">Django</span>
                </div>
            </div>
            <div class="mt-auto">
                <div class="salary-box"><div class="fw-bold small text-primary">₹12 LPA – ₹18 LPA</div></div>
                <a href="/employer/jobs/68/" class="apply-btn d-block text-center text-decoration-none">View Job Description</a>
            </div>
        </div>
    </div>
    <div class="col-sm-6 col-md-4 col-xl-3 job-card-col" data-seeded="true">
        <div class="job-opening-card">
            <div class="d-flex justify-content-between align-items-start mb-3">
                <div class="d-flex align-items-center gap-2 overflow-hidden" style="flex:1;min-width:0;">
                    <div class="company-logo-placeholder"><i class="fas fa-briefcase"></i></div>
                    <div class="overflow-hidden">
                        <h6 class="fw-bold mb-0 text-truncate text-slate-900" title="QA Tester">QA Tester</h6>
                        <p class="text-slate-500 small mb-0 text-truncate">Career Buddy Partner</p>
                    </div>
                </div>
                <span class="badge rounded-pill ms-1 flex-shrink-0" style="font-size:0.65rem; background:#fffbeb; color:#b45309; border:1px solid #fde68a;">CB</span>
            </div>
            <div class="mb-3">
                <div class="mb-2"><span class="job-badge badge-remote">Remote</span></div>
                <div class="text-slate-500 small mb-2"><i class="fas fa-map-marker-alt me-1 text-slate-400"></i> Remote</div>
                <div class="text-slate-500 small mb-2"><i class="fas fa-briefcase me-1 text-slate-400"></i> Fresher</div>
                <div class="d-flex flex-wrap gap-1"></div>
            </div>
            <div class="mt-auto">
                <div class="salary-box"><div class="fw-bold small text-primary">As per industry norms</div></div>
                <a href="/employer/jobs/70/" class="apply-btn d-block text-center text-decoration-none">View Job Description</a>
            </div>
        </div>
    </div>
</div>
''';

void main() {
  group('parseJobOpeningsHtml', () {
    test('parses every job card, including the seeded vs Mine badge and skills', () {
      final page = parseJobOpeningsHtml(_fixtureWithJobs);

      expect(page.jobs, hasLength(2));

      expect(page.jobs[0].jobId, 68);
      expect(page.jobs[0].title, 'Senior Python Developer');
      expect(page.jobs[0].companyName, 'Acme Corp');
      expect(page.jobs[0].jobType, 'Full Time');
      expect(page.jobs[0].isSeeded, isFalse);
      expect(page.jobs[0].location, 'Hyderabad');
      expect(page.jobs[0].skills, ['Python', 'Django']);
      expect(page.jobs[0].salaryDisplay, '₹12 LPA – ₹18 LPA');

      expect(page.jobs[1].jobId, 70);
      expect(page.jobs[1].isSeeded, isTrue);
      expect(page.jobs[1].skills, isEmpty);
    });

    test('an empty grid parses to an empty list, not a crash', () {
      expect(parseJobOpeningsHtml('<div class="row g-4" id="jobs-grid"></div>').jobs, isEmpty);
    });
  });
}
