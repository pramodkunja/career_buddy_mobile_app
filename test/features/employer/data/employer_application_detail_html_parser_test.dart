import 'package:career_buddy_lms/features/employer/data/employer_application_detail_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixture reproduces the real, exact markup of
/// `templates/employer/application_detail.html` as read directly from the
/// Django source this session (`jobs_app/views.py:684-709`,
/// `jobs_app/models.py:242-298`, `jobs_app/forms.py:225-232`) — not a
/// guessed shape.
const _fixtureHtmlWithEverything = '''
<h2 class="fw-extrabold text-slate-900 mb-1" style="font-size: 2rem;">Priya Sharma</h2>
<span class="badge mb-2" style="background: #eff6ff;">
    <i class="fas fa-briefcase me-2"></i> Applicant for Senior Python Developer
</span>
<span><i class="fas fa-envelope me-1.5 text-slate-400"></i> priya@example.com</span>
<span><i class="fas fa-phone me-1.5 text-slate-400"></i> 9876543210</span>
<div class="info-label">Experience</div>
<div class="info-value">5 Year(s)</div>
<div class="info-label">Current Company</div>
<div class="info-value">Acme Corp</div>
<div class="info-label">Current Salary</div>
<div class="info-value">₹1200000.00 LPA</div>
<div class="info-label">Expected Salary</div>
<div class="info-value">₹1800000.00 LPA</div>
<a href="/media/resumes/priya_resume.pdf" target="_blank" class="btn btn-primary">
    <i class="fas fa-file-pdf me-2"></i> View Resume Document
</a>
<h6 class="fw-bold text-slate-900 mb-2">
    <i class="fas fa-video me-1 text-primary"></i> AI Mock Interview Recording
    <span class="badge bg-success ms-2">Score 82/100</span>
</h6>
<video controls preload="metadata">
    <source src="/media/interview_videos/priya_interview.mp4">
</video>
<div class="text-slate-500 small mt-1">Recorded 15 Sep 2026, 14:30</div>
<div class="p-3 bg-slate-50 border border-slate-200 rounded-3 text-slate-700 small" style="line-height: 1.7;">
    <p>I am excited to apply for this role given my 5 years of Python experience.</p>
</div>
<select name="status" id="id_status" class="form-select">
<option value="applied">Applied</option>
<option value="reviewing" selected>Under Review</option>
<option value="shortlisted">Shortlisted</option>
<option value="interview">Interview Scheduled</option>
<option value="offered">Offer Extended</option>
<option value="rejected">Rejected</option>
</select>
<textarea name="employer_notes" cols="40" rows="3" id="id_employer_notes" class="form-control">Strong candidate, schedule a call.</textarea>
<small class="text-slate-500">Applied on 10 Sep 2026, 09:15</small>
''';

const _fixtureHtmlMinimal = '''
<h2 class="fw-extrabold text-slate-900 mb-1" style="font-size: 2rem;">Alex Kumar</h2>
<span class="badge mb-2">
    <i class="fas fa-briefcase me-2"></i> Applicant for Backend Engineer
</span>
<span><i class="fas fa-envelope me-1.5 text-slate-400"></i> alex@example.com</span>
<span><i class="fas fa-phone me-1.5 text-slate-400"></i> 9123456780</span>
<div class="info-label">Experience</div>
<div class="info-value">0 Year(s)</div>
<div class="info-label">Current Company</div>
<div class="info-value">N/A</div>
<div class="info-label">Current Salary</div>
<div class="info-value">N/A</div>
<div class="info-label">Expected Salary</div>
<div class="info-value">N/A</div>
<select name="status" id="id_status" class="form-select">
<option value="applied" selected>Applied</option>
<option value="reviewing">Under Review</option>
<option value="shortlisted">Shortlisted</option>
<option value="interview">Interview Scheduled</option>
<option value="offered">Offer Extended</option>
<option value="rejected">Rejected</option>
</select>
<textarea name="employer_notes" cols="40" rows="3" id="id_employer_notes" class="form-control"></textarea>
<small class="text-slate-500">Applied on 1 Oct 2026, 08:00</small>
''';

void main() {
  group('parseEmployerApplicationDetailHtml', () {
    test('parses every field when resume/interview/cover-letter/notes are all present', () {
      final detail = parseEmployerApplicationDetailHtml(_fixtureHtmlWithEverything);

      expect(detail.applicantName, 'Priya Sharma');
      expect(detail.jobTitle, 'Senior Python Developer');
      expect(detail.applicantEmail, 'priya@example.com');
      expect(detail.applicantPhone, '9876543210');
      expect(detail.yearsExperience, 5);
      expect(detail.currentCompany, 'Acme Corp');
      expect(detail.currentSalary, '₹1200000.00 LPA');
      expect(detail.expectedSalary, '₹1800000.00 LPA');
      expect(detail.resumeUrl, '/media/resumes/priya_resume.pdf');
      expect(detail.interviewScore, 82);
      expect(detail.interviewVideoUrl, '/media/interview_videos/priya_interview.mp4');
      expect(detail.interviewRecordedAt, '15 Sep 2026, 14:30');
      expect(detail.coverLetter, contains('5 years of Python experience'));
      expect(detail.status, 'reviewing');
      expect(detail.employerNotes, 'Strong candidate, schedule a call.');
      expect(detail.appliedAt, '10 Sep 2026, 09:15');
    });

    test('handles a fresh application with no resume/interview/cover-letter/notes', () {
      final detail = parseEmployerApplicationDetailHtml(_fixtureHtmlMinimal);

      expect(detail.applicantName, 'Alex Kumar');
      expect(detail.jobTitle, 'Backend Engineer');
      expect(detail.yearsExperience, 0);
      expect(detail.currentCompany, 'N/A');
      expect(detail.resumeUrl, isNull);
      expect(detail.interviewScore, isNull);
      expect(detail.interviewVideoUrl, isNull);
      expect(detail.coverLetter, isNull);
      expect(detail.status, 'applied');
      expect(detail.employerNotes, isEmpty);
    });
  });
}
