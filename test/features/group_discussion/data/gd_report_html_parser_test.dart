import 'package:career_buddy_lms/features/group_discussion/data/gd_report_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixtureHtml = '''
<div class="score-ring-wrap">
  <div style="font-size:3rem;font-weight:900;color:#1e293b;line-height:1;">78</div>
</div>
<div class="dim-score text-primary">80<span></span></div>
<div class="dim-feedback">You didn&#x27;t pause much — great fluency.</div>
<div class="dim-score" style="color:#7c3aed;">70<span></span></div>
<div class="dim-feedback">Watch your subject-verb agreement.</div>
<div class="dim-score text-success">75<span></span></div>
<div class="dim-feedback">Relevant, but you didn&#x27;t fully address the prompt.</div>
<div class="dim-score" style="color:#d97706;">60<span></span></div>
<div class="dim-feedback">Speak with more confidence next time.</div>
<div class="insight-card insight-dark">
  <div class="insight-item"><p>You&#x27;re good at structuring arguments.</p></div>
  <div class="insight-item"><p>Clear articulation throughout.</p></div>
</div>
<div class="insight-card insight-light">
  <div class="insight-item"><p>Don&#x27;t rush your closing statement.</p></div>
</div>
<div class="verdict">
  <div class="verdict-quote">"Overall a strong performance — keep practicing and you&#x27;ll excel."</div>
</div>
''';

void main() {
  group('parseGdReportHtml', () {
    test('returns null when there is no report yet', () {
      expect(parseGdReportHtml('<div>No analysis yet</div>'), isNull);
    });

    test('decodes the hex apostrophe entity (&#x27;) in dimension feedback, strengths, improvements, and summary', () {
      final report = parseGdReportHtml(_fixtureHtml)!;

      expect(report.overallScore, 78);
      expect(report.fluency.feedback, "You didn't pause much — great fluency.");
      expect(report.relevance.feedback, "Relevant, but you didn't fully address the prompt.");
      expect(report.strengths, contains("You're good at structuring arguments."));
      expect(report.improvements, contains("Don't rush your closing statement."));
      expect(report.summary, "Overall a strong performance — keep practicing and you'll excel.");
      // No raw entity should ever leak through to the parsed result.
      expect(report.fluency.feedback, isNot(contains('&#x27;')));
      expect(report.summary, isNot(contains('&#x27;')));
    });
  });
}
