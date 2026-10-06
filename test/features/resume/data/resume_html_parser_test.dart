import 'package:career_buddy_lms/features/resume/data/resume_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _resultFixture = '''
<div class="score-ring-wrap">
    <svg width="160" height="160" viewBox="0 0 160 160">
        <circle cx="80" cy="80" r="65" stroke="#e2e8f0" stroke-width="10" fill="transparent"/>
        <circle cx="80" cy="80" r="65" stroke="#0ea5e9" stroke-width="10" fill="transparent"
            stroke-dasharray="408" stroke-dashoffset="408" id="score-ring"/>
    </svg>
    <div class="score-center">
        <span class="score-number" id="pct-text">0%</span>
        <span class="score-label">ATS Score</span>
    </div>
</div>
<h2 class="fw-bold mb-2">Resume Analysis Complete</h2>
<p class="text-muted mb-3">Your resume is solid overall with room to grow in a few key areas.</p>
<div class="alert alert-danger" role="alert">
    <i class="fas fa-exclamation-triangle me-2"></i>Invalid resume. We could only find 2 out of 10 standard resume sections.
</div>
<span class="badge bg-light text-dark border">
    <i class="fas fa-briefcase text-secondary"></i>
    Detected Experience:
    2.5 years
</span>
<a href="/pro/" class="btn btn-warning">Upgrade for AI Interview</a>
<!-- Skills Grid -->
<div class="row g-4 mb-4">
    <!-- Matching Skills -->
    <div class="col-md-6">
        <div>Matching Skills</div>
        <div>
            <span class="skill-chip chip-found">python</span>
            <span class="skill-chip chip-found">django</span>
        </div>
    </div>
    <!-- Missing Skills -->
    <div class="col-md-6">
        <div>Missing Skills</div>
        <div>
            <span class="skill-chip chip-gap">docker</span>
        </div>
    </div>
</div>
<!-- Complete Interview to Unlock Jobs Banner -->
<div class="result-card mb-4"></div>
<div class="result-card">
    <p class="text-muted small fw-semibold mb-2">Skills missing or not matched with your resume:</p>
    <div>
        <span class="skill-chip chip-gap">docker</span>
    </div>
    <div class="advice-item">
        <div class="advice-dot"><i class="fas fa-star"></i></div>
        <span>Add a dedicated Skills section.</span>
    </div>
    <div class="advice-item">
        <div class="advice-dot"><i class="fas fa-star"></i></div>
        <span>Quantify your achievements with numbers.</span>
    </div>
</div>
<script>
document.addEventListener('DOMContentLoaded', () => {
    const pct = parseInt("73", 10) || 0;
});
</script>
''';

const _errorFixture = '''
<div class="error-box">
    <i class="fas fa-exclamation-circle fa-lg"></i>
    <div>We couldn&#39;t read any text from this resume.</div>
</div>
''';

const _historyFixture = '''
<div class="mb-3 text-muted small">2 resumes uploaded so far</div>
<div class="resume-history-card current">
    <div class="resume-history-icon"><i class="fas fa-file-alt"></i></div>
    <div class="flex-grow-1">
        <div class="fw-bold text-dark">
            priya_resume_final.pdf
            <span class="badge bg-primary bg-opacity-10 text-primary ms-1">Current</span>
        </div>
        <div class="text-muted small">Uploaded 29 Sep 2026, 3:45 PM</div>
    </div>
    <div class="d-flex gap-2">
        <a href="/media/resumes/priya_resume_final.pdf" target="_blank" class="btn btn-sm btn-outline-secondary rounded-3">
            <i class="fas fa-eye me-1"></i> View File
        </a>
        <form method="post" action="/resume-builder/reanalyze/42/">
            <button type="submit" class="btn btn-sm btn-primary rounded-3">View ATS Analysis</button>
        </form>
    </div>
</div>
<div class="resume-history-card">
    <div class="resume-history-icon"><i class="fas fa-file-alt"></i></div>
    <div class="flex-grow-1">
        <div class="fw-bold text-dark">
            old_resume.docx
        </div>
        <div class="text-muted small">Uploaded 01 Jan 2026, 9:00 AM</div>
    </div>
    <div class="d-flex gap-2">
        <a href="/media/resumes/old_resume.docx" target="_blank" class="btn btn-sm btn-outline-secondary rounded-3">
            <i class="fas fa-eye me-1"></i> View File
        </a>
        <form method="post" action="/resume-builder/reanalyze/17/">
            <button type="submit" class="btn btn-sm btn-primary rounded-3">View ATS Analysis</button>
        </form>
    </div>
</div>
''';

void main() {
  group('isResumeMatchResultHtml', () {
    test('true for a result page, false for an upload-page-with-error', () {
      expect(isResumeMatchResultHtml(_resultFixture), isTrue);
      expect(isResumeMatchResultHtml(_errorFixture), isFalse);
    });
  });

  group('parseResumeBuilderError', () {
    test('extracts and unescapes the error message', () {
      expect(parseResumeBuilderError(_errorFixture), "We couldn't read any text from this resume.");
    });

    test('returns null when no error box is present', () {
      expect(parseResumeBuilderError(_resultFixture), isNull);
    });
  });

  group('parseResumeMatchResultHtml', () {
    final result = parseResumeMatchResultHtml(_resultFixture);

    test('extracts the ATS score from the ring-animation JS, not the static 0% markup', () {
      expect(result.analysis.matchPercentage, 73);
    });

    test('scopes matching/missing skills to their own list, excluding the AI Suggestions duplicate', () {
      expect(result.analysis.matchingSkills, ['python', 'django']);
      expect(result.analysis.missingSkills, ['docker']); // not ['docker', 'docker']
    });

    test('extracts the summary paragraph', () {
      expect(result.analysis.summary, 'Your resume is solid overall with room to grow in a few key areas.');
    });

    test('extracts every career-advice item, not the missing-skills chips inside the same card', () {
      expect(result.analysis.careerAdvice, [
        'Add a dedicated Skills section.',
        'Quantify your achievements with numbers.',
      ]);
    });

    test('extracts the validation warning and flips resumeValid to false', () {
      expect(result.resumeValid, isFalse);
      expect(
        result.validationMessage,
        'Invalid resume. We could only find 2 out of 10 standard resume sections.',
      );
    });

    test('extracts years of experience from the "Detected Experience" badge', () {
      expect(result.yearsExperience, 2.5);
    });

    test('canInterview is false when the upgrade CTA renders instead of Try Interview', () {
      expect(result.canInterview, isFalse);
    });

    test('isAtsOnly is true when the score label says "ATS Score"', () {
      expect(result.isAtsOnly, isTrue);
    });
  });

  group('parseResumeMatchResultHtml — resumeValid defaults true with no validation alert', () {
    test('when the alert-danger block is absent, resumeValid is true and validationMessage is null', () {
      final withoutWarning = _resultFixture.replaceFirst(
        RegExp(r'<div class="alert alert-danger"[\s\S]*?</div>\n'),
        '',
      );
      final result = parseResumeMatchResultHtml(withoutWarning);
      expect(result.resumeValid, isTrue);
      expect(result.validationMessage, isNull);
    });
  });

  group('parseFlashedErrorMessage', () {
    test('extracts a Django flash message from the shared messages-container markup', () {
      const html = '''
        <div class="messages-container">
          <div class="alert alert-danger alert-dismissible fade show toast-message" role="alert">
            <i class="fas fa-exclamation-circle me-2"></i>
            This resume has no readable text saved — please upload it again.
            <button type="button" class="btn-close"></button>
          </div>
        </div>
      ''';
      expect(
        parseFlashedErrorMessage(html),
        'This resume has no readable text saved — please upload it again.',
      );
    });

    test('returns null when no danger/error alert is present', () {
      expect(parseFlashedErrorMessage('<div class="alert alert-success">Welcome!</div>'), isNull);
    });
  });

  group('parseResumeHistoryHtml', () {
    final items = parseResumeHistoryHtml(_historyFixture);

    test('extracts every resume row in document order', () {
      expect(items, hasLength(2));
      expect(items[0].id, 42);
      expect(items[1].id, 17);
    });

    test('extracts the filename, stripping surrounding whitespace', () {
      expect(items[0].fileName, 'priya_resume_final.pdf');
      expect(items[1].fileName, 'old_resume.docx');
    });

    test('extracts the formatted upload date', () {
      expect(items[0].uploadedAtDisplay, '29 Sep 2026, 3:45 PM');
    });

    test('marks the current resume via the "current" class, not the badge text', () {
      expect(items[0].isCurrent, isTrue);
      expect(items[1].isCurrent, isFalse);
    });

    test('extracts the protected file URL', () {
      expect(items[0].fileUrl, '/media/resumes/priya_resume_final.pdf');
    });

    test('an empty history page yields an empty list', () {
      expect(parseResumeHistoryHtml('<div class="text-center py-5">No resumes uploaded yet</div>'), isEmpty);
    });
  });
}
