import 'package:career_buddy_lms/features/employer/data/employer_dashboard_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixtureWithJobs = '''
<div class="employer-hero-band">
  <h1 class="mb-2 fw-extrabold text-slate-900" style="font-size: 2.2rem; letter-spacing: -1px;">
    Welcome back, Priya!
  </h1>
</div>
<div class="row g-4 mb-4">
  <div class="col-md-4"><div class="emp-stat-card"><div class="emp-stat-icon emp-stat-icon-blue"><i class="fas fa-briefcase"></i></div><div><div class="emp-stat-number">7</div><div class="emp-stat-label">Total Jobs</div></div></div></div>
  <div class="col-md-4"><div class="emp-stat-card"><div class="emp-stat-icon emp-stat-icon-green"><i class="fas fa-check-circle"></i></div><div><div class="emp-stat-number" style="color: #10b981;">5</div><div class="emp-stat-label">Active Listings</div></div></div></div>
  <div class="col-md-4"><div class="emp-stat-card"><div class="emp-stat-icon emp-stat-icon-amber"><i class="fas fa-users"></i></div><div><div class="emp-stat-number" style="color: #f59e0b;">42</div><div class="emp-stat-label">Applications</div></div></div></div>
</div>
<table class="table table-hover align-middle mb-0">
  <thead></thead>
  <tbody>
    <tr>
      <td class="ps-4 fw-bold text-slate-900">Senior Backend Engineer</td>
      <td><span class="badge" style="background: #eff6ff; color: #185adb; font-weight: 600; padding: 0.35rem 0.75rem; border-radius: 50px;">Full Time</span></td>
      <td><span class="badge bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 px-2.5 py-1 rounded-full text-xs font-semibold">Active</span></td>
      <td><a href="/employer/employer/jobs/1/applications/" class="btn btn-sm btn-light py-1 px-3"><i class="fas fa-users me-1 text-primary"></i> 12</a></td>
      <td class="text-slate-500 small">05 Jan 2026</td>
      <td class="text-end pe-4"><a href="/employer/employer/jobs/1/edit/" title="Edit"></a></td>
    </tr>
    <tr>
      <td class="ps-4 fw-bold text-slate-900">Product Designer</td>
      <td><span class="badge" style="background: #eff6ff; color: #185adb; font-weight: 600; padding: 0.35rem 0.75rem; border-radius: 50px;">Contract</span></td>
      <td><span class="badge bg-slate-100 text-slate-600 border border-slate-200 px-2.5 py-1 rounded-full text-xs font-semibold">Draft</span></td>
      <td><a href="/employer/employer/jobs/2/applications/" class="btn btn-sm btn-light py-1 px-3"><i class="fas fa-users me-1 text-primary"></i> 0</a></td>
      <td class="text-slate-500 small">01 Jan 2026</td>
      <td class="text-end pe-4"><a href="/employer/employer/jobs/2/edit/" title="Edit"></a></td>
    </tr>
  </tbody>
</table>
''';

const _fixtureEmpty = '''
<h1 class="mb-2 fw-extrabold text-slate-900">Welcome back, jane_hr!</h1>
<div class="emp-stat-number">0</div>
<div class="emp-stat-number" style="color: #10b981;">0</div>
<div class="emp-stat-number" style="color: #f59e0b;">0</div>
<table><tbody>
<tr>
  <td colspan="6" class="text-center py-5 text-slate-400">
    <i class="fas fa-briefcase fa-2x mb-2 d-block text-slate-300"></i>
    No jobs posted yet. <a href="/employer/employer/jobs/new/" class="text-primary fw-bold">Post your first job!</a>
  </td>
</tr>
</tbody></table>
''';

void main() {
  group('parseEmployerDashboardHtml', () {
    test('extracts the greeting name, the 3 stat numbers in order, and every job row', () {
      final summary = parseEmployerDashboardHtml(_fixtureWithJobs);

      expect(summary.greetingName, 'Priya');
      expect(summary.totalJobsCount, 7);
      expect(summary.activeJobs, 5);
      expect(summary.totalApps, 42);
      expect(summary.jobs, hasLength(2));

      expect(summary.jobs[0].jobId, 1);
      expect(summary.jobs[0].title, 'Senior Backend Engineer');
      expect(summary.jobs[0].jobType, 'Full Time');
      expect(summary.jobs[0].status, 'active');
      expect(summary.jobs[0].applicationsCount, 12);
      expect(summary.jobs[0].postedDate, '05 Jan 2026');

      expect(summary.jobs[1].title, 'Product Designer');
      expect(summary.jobs[1].status, 'draft');
      expect(summary.jobs[1].applicationsCount, 0);
    });

    test('falls back to the username when first_name is empty, matching the template default', () {
      final summary = parseEmployerDashboardHtml(_fixtureEmpty);

      expect(summary.greetingName, 'jane_hr');
    });

    test('the {% empty %} row (no title cell) is not parsed as a job', () {
      final summary = parseEmployerDashboardHtml(_fixtureEmpty);

      expect(summary.jobs, isEmpty);
      expect(summary.totalJobsCount, 0);
      expect(summary.activeJobs, 0);
      expect(summary.totalApps, 0);
    });

    test('a "Closed" status row is normalized to lowercase', () {
      const fixture = '''
        <h1>Welcome back, x!</h1>
        <div class="emp-stat-number">1</div><div class="emp-stat-number">0</div><div class="emp-stat-number">0</div>
        <tbody>
        <tr>
          <td class="ps-4 fw-bold text-slate-900">Old Listing</td>
          <td><span class="badge" style="background: #eff6ff; color: #185adb;">Internship</span></td>
          <td><span class="badge bg-rose-500/10 text-rose-600 border border-rose-500/20">Closed</span></td>
          <td><a href="#"><i class="fas fa-users me-1 text-primary"></i> 3</a></td>
          <td class="text-slate-500 small">10 Dec 2025</td>
          <td><a href="/employer/employer/jobs/9/edit/"></a></td>
        </tr>
        </tbody>
      ''';

      final summary = parseEmployerDashboardHtml(fixture);

      expect(summary.jobs.single.status, 'closed');
    });
  });
}
