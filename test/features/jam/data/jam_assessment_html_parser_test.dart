import 'package:career_buddy_lms/features/jam/data/jam_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures below are trimmed excerpts of the real templates
// (`templates/jam/session.html`/`history.html`/`assessment_result.html`),
// keeping every literal class string/marker the parser regexes anchor to —
// same convention `jam_html_parser_test.dart` already established.

String _assessmentStageFixture({int stage = 1, String difficulty = 'easy', int sessionId = 501}) => '''
<h1 class="text-3xl font-bold text-slate-900 font-serif" id="headerTopicTitle">My Family
                    </h1>
<span class="badge-jam badge-jam-$difficulty">$difficulty</span>
<p class="text-slate-500 font-serif mt-2 max-w-2xl" id="headerTopicDesc">Talk about your family members.</p>
<div class="text-right">
    <div class="text-[10px] font-bold text-coral uppercase tracking-widest mb-2" id="labelAssessmentJourney">Assessment Journey</div>
    <div class="flex gap-1 justify-end">
        <span class="w-2 h-2 rounded-full bg-[#0ea5e9]"></span>
    </div>
    <div class="text-xs font-serif font-bold text-slate-400 mt-1" id="labelStage">Stage $stage of 3
    </div>
</div>
<svg class="timer-ring w-full h-full -rotate-90" viewBox="0 0 120 120">
  <circle class="ring-progress fill-none stroke-amber-400" id="timerRing" cx="60" cy="60" r="54" />
</svg>
<script>
    const SESSION_ID = Number("$sessionId");
</script>
''';

const _historyFixture = '''
<div id="content-regular" class="space-y-4">
    <div class="group flex items-center justify-between p-5">
        <h4 class="font-serif font-bold text-slate-900">My Family</h4>
        <span class="badge-jam badge-jam-easy">easy</span>
    </div>
    <div class="group flex items-center justify-between p-5">
        <h4 class="font-serif font-bold text-slate-900">Climate Change</h4>
        <span class="badge-jam badge-jam-medium">medium</span>
    </div>
</div>
<div id="content-assessments" class="hidden space-y-6">
    <div class="p-6 rounded-[32px] border border-slate-100">
        <span class="px-3 py-1 rounded-full bg-white border border-slate-100 text-[10px] font-bold text-slate-500">Hard Topic</span>
        <span class="badge-jam badge-jam-hard">hard</span>
    </div>
</div>
''';

const _historyEmptyFixture = '''
<div id="content-regular" class="space-y-4">
    <div class="text-center py-12 text-slate-400 font-serif">No regular sessions found.</div>
</div>
<div id="content-assessments" class="hidden space-y-6">
</div>
''';

const _reportHtml = '''
<h4 class='feedback-highlight'><b>🏆 Result Level: Advanced</b></h4>
<p>Congratulations on completing the 3-stage JAM assessment!</p>
<h3>📈 Overall Statistics</h3>
<ul>
<li><b>Average Duration</b>: 52s per topic</li>
<li><b>Average Fluency Consistency</b>: 4.7/5 → <b>Advanced</b></li>
<li><b>Easy (My Family)</b>: 22/25</li>
<li><b>Medium (Climate Change)</b>: 20/25</li>
<li><b>Hard (AI &amp; Ethics)</b>: 18/25</li>
</ul>
<h3>🔍 Diagnostic Profile</h3>
<p>You maintained strong, consistent pacing across all three difficulty levels — a sign of a skilled communicator.</p>
<h3>🚀 Next Steps for You</h3>
<ul>
<li><b>Vocabulary</b>: Practice synonyms for common words to avoid repetition in Hard topics.</li>
<li><b>Pacing</b>: Use the full 60 seconds even on Easy topics to build stamina.</li>
<li><b>Tone</b>: Work on varying your pitch to sound more engaging.</li>
</ul>
''';

String _assessmentResultFixture({String easyScore = '22', String mediumScore = '20', String hardScore = '18'}) => '''
<h1 class="text-4xl md:text-5xl font-bold text-slate-900 font-serif mb-4 leading-tight">Diagnostic Performance Report</h1>
<div class="relative w-48 h-48 flex items-center justify-center">
    <span class="text-5xl font-bold font-serif text-slate-900 block">60</span>
    <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Total / 75</span>
</div>
<div class="mt-12 pt-10 border-t border-slate-100 grid grid-cols-3 gap-6">
    <div class="text-center">
        <div class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Easy Stage</div>
        <div class="text-sm font-bold font-serif text-slate-900">My Family</div>
        <div class="text-xs text-emerald-500 font-bold mt-1">★ $easyScore/25</div>
    </div>
    <div class="text-center">
        <div class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Medium Stage</div>
        <div class="text-sm font-bold font-serif text-slate-900">Climate Change</div>
        <div class="text-xs text-amber-500 font-bold mt-1">★ $mediumScore/25</div>
    </div>
    <div class="text-center">
        <div class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Hard Stage</div>
        <div class="text-sm font-bold font-serif text-slate-900">AI &amp; Ethics</div>
        <div class="text-xs text-rose-500 font-bold mt-1">★ $hardScore/25</div>
    </div>
</div>
<div class="prose prose-slate max-w-none font-serif text-slate-700 leading-relaxed jam-feedback-content">
$_reportHtml
</div>

<!-- Per-Stage Transcripts accordion -->
<div class="mt-10 pt-8 border-t border-slate-50 space-y-4"></div>
''';

void main() {
  group('isJamAssessmentStageHtml', () {
    test('true for a session.html render with the stage indicator', () {
      expect(isJamAssessmentStageHtml(_assessmentStageFixture()), isTrue);
    });

    test('false for an ordinary (non-assessment) session.html render', () {
      const ordinary = '''
<h1 id="headerTopicTitle">My Family</h1>
<span class="badge-jam badge-jam-easy">easy</span>
<svg><circle id="timerRing" /></svg>
<script>const SESSION_ID = Number("9");</script>
''';
      expect(isJamAssessmentStageHtml(ordinary), isFalse);
    });
  });

  group('parseJamAssessmentStageHtml', () {
    test('parses session id/topic fields plus the stage number', () {
      final parsed = parseJamAssessmentStageHtml(_assessmentStageFixture(stage: 2, difficulty: 'medium', sessionId: 777));

      expect(parsed, isNotNull);
      expect(parsed!.sessionId, 777);
      expect(parsed.topicTitle, 'My Family');
      expect(parsed.topicDifficulty, 'medium');
      expect(parsed.stage, 2);
    });

    test('returns null for an ordinary session.html render with no stage indicator', () {
      const ordinary = '''
<h1 id="headerTopicTitle">My Family</h1>
<span class="badge-jam badge-jam-easy">easy</span>
<svg><circle id="timerRing" /></svg>
<script>const SESSION_ID = Number("9");</script>
''';
      expect(parseJamAssessmentStageHtml(ordinary), isNull);
    });

    test('returns null for a page that is not a real session.html render at all', () {
      expect(parseJamAssessmentStageHtml('<html><body>redirected to dashboard</body></html>'), isNull);
    });
  });

  group('parseJamHistoryHtml', () {
    test('parses only the Regular Sessions tab difficulties, ignoring the Assessments tab', () {
      final sessions = parseJamHistoryHtml(_historyFixture);

      expect(sessions.map((s) => s.difficulty), ['easy', 'medium']);
    });

    test('an empty history yields an empty list', () {
      expect(parseJamHistoryHtml(_historyEmptyFixture), isEmpty);
    });
  });

  group('isJamAssessmentResultHtml / parseJamAssessmentResultHtml', () {
    test('detects a real assessment_result.html render', () {
      expect(isJamAssessmentResultHtml(_assessmentResultFixture()), isTrue);
    });

    test('parses level/stats/total/stage summaries/report text', () {
      final result = parseJamAssessmentResultHtml(_assessmentResultFixture());

      expect(result, isNotNull);
      expect(result!.level, 'Advanced');
      expect(result.averageDurationSeconds, 52);
      expect(result.averageFluency, 4.7);
      expect(result.totalScore, 60);

      expect(result.stages, hasLength(3));
      expect(result.stages[0].difficulty, 'easy');
      expect(result.stages[0].topicTitle, 'My Family');
      expect(result.stages[0].overallScore, 22);
      expect(result.stages[1].difficulty, 'medium');
      expect(result.stages[1].topicTitle, 'Climate Change');
      expect(result.stages[1].overallScore, 20);
      expect(result.stages[2].difficulty, 'hard');
      expect(result.stages[2].topicTitle, 'AI & Ethics');
      expect(result.stages[2].overallScore, 18);

      expect(result.reportText, contains('Result Level: Advanced'));
      expect(result.reportText, contains('skilled communicator'));
      expect(result.reportText, isNot(contains('<b>')));
      expect(result.reportText, isNot(contains('<li>')));
    });

    test('a "—" (unscored) stage score parses as a null overallScore', () {
      final result = parseJamAssessmentResultHtml(_assessmentResultFixture(hardScore: '—'));

      expect(result!.stages[2].overallScore, isNull);
    });

    test('returns null for a page that is not a real assessment_result.html render', () {
      expect(parseJamAssessmentResultHtml('<html><body>Not found</body></html>'), isNull);
    });
  });
}
