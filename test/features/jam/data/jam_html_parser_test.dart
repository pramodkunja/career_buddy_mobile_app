import 'package:career_buddy_lms/features/jam/data/jam_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures below are trimmed excerpts of the real templates
// (`templates/jam/session.html`/`session_detail.html`/`topics.html`),
// keeping every literal class string/marker the parser regexes anchor to.

const _sessionStartFixture = '''
<h1 class="text-3xl font-bold text-slate-900 font-serif" id="headerTopicTitle">Describe your favorite hobby
                    </h1>
<span class="badge-jam badge-jam-easy">easy</span>
<p class="text-slate-500 font-serif mt-2 max-w-2xl" id="headerTopicDesc">Talk about something you enjoy doing.</p>
<svg class="timer-ring w-full h-full -rotate-90" viewBox="0 0 120 120">
  <circle class="ring-progress fill-none stroke-amber-400" id="timerRing" cx="60" cy="60" r="54" />
</svg>
<script>
    const SESSION_ID = Number("482");
    const CSRF_TOKEN = "abc123";
</script>
''';

const _sessionStartNoDescriptionFixture = '''
<h1 class="text-3xl font-bold text-slate-900 font-serif" id="headerTopicTitle">A topic with no description
                    </h1>
<span class="badge-jam badge-jam-hard">hard</span>
<svg><circle id="timerRing" /></svg>
<script>const SESSION_ID = Number("7");</script>
''';

const _topicsFixture = '''
<section id="easy" class="scroll-mt-32">
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
    <div class="group bg-white rounded-[40px] p-10 border border-slate-200/60 shadow-sm hover:border-emerald-400/40">
      <h3 class="font-serif text-2xl font-bold text-slate-900 mb-4 group-hover:text-emerald-600 transition-colors leading-tight">My Family</h3>
      <p class="text-slate-500 font-serif leading-relaxed mb-10 flex-1">Talk about your family members.</p>
      <a href="/jam/session/start/1/" class="w-full bg-slate-900 text-white py-4 rounded-2xl">Practice Session</a>
    </div>
  </div>
</section>
<section id="medium" class="scroll-mt-32">
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
    <div class="group bg-white rounded-[40px] p-10 border border-slate-200/60 shadow-sm hover:border-amber-400/40">
      <h3 class="font-serif text-2xl font-bold text-slate-900 mb-4 group-hover:text-amber-600 transition-colors leading-tight">Climate Change</h3>
      <p class="text-slate-500 font-serif leading-relaxed mb-10 flex-1">Discuss its impact.</p>
      <a href="/jam/session/start/2/" class="w-full bg-slate-900 text-white py-4 rounded-2xl">Practice Session</a>
    </div>
  </div>
</section>
<section id="hard" class="scroll-mt-32">
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
    <div class="group bg-white rounded-[40px] p-10 border border-slate-200/60 shadow-sm hover:border-rose-400/40">
      <h3 class="font-serif text-2xl font-bold text-slate-900 mb-4 group-hover:text-rose-600 transition-colors leading-tight">AI &amp; Ethics</h3>
      <p class="text-slate-500 font-serif leading-relaxed mb-10 flex-1">Is AI a threat?</p>
      <a href="/jam/session/start/3/" class="w-full bg-slate-900 text-white py-4 rounded-2xl">Practice Session</a>
    </div>
  </div>
</section>
''';

String _sessionDetailFixture({
  bool hasTranscript = true,
  bool hasTips = true,
  bool hasAudio = true,
}) => '''
<div id="resultCard" class="bg-white rounded-[48px] p-8">
  <span class="px-4 py-1.5 bg-white text-slate-400 rounded-full text-[10px] font-bold uppercase tracking-widest border border-slate-100">
            Feb 10 2026 03:45 PM
        </span>
  <h1 class="text-4xl md:text-5xl font-bold text-slate-900 font-serif mb-4 leading-tight">Describe your favorite hobby</h1>
  <span class="px-4 py-1 bg-slate-50 text-slate-500 rounded-full text-xs font-bold font-serif border border-slate-100 capitalize">
                    easy Difficulty
                </span>
  <span class="px-4 py-1 bg-slate-50 text-slate-500 rounded-full text-xs font-bold font-serif border border-slate-100">
                    45s spoken
                </span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Confidence</span>
  <span class="text-sm font-bold font-serif text-slate-900">4/5</span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Fluency</span>
  <span class="text-sm font-bold font-serif text-slate-900">3/5</span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Language</span>
  <span class="text-sm font-bold font-serif text-slate-900">5/5</span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Pronunciation</span>
  <span class="text-sm font-bold font-serif text-slate-900">4/5</span>
  <span class="text-xs font-bold text-slate-400 uppercase tracking-widest">Time Management</span>
  <span class="text-sm font-bold font-serif text-slate-900">5/5</span>
  <span class="text-5xl font-bold font-serif text-slate-900 block">21</span>
  <div class="prose prose-slate max-w-none font-serif text-slate-700 leading-relaxed jam-feedback-content">
                    <h4 class='feedback-highlight'><b>Performance Analysis — 'Describe your favorite hobby'</b></h4>
<p>📝 <b>Feedback</b>: Great job overall.</p>
                </div>

                <div class="mt-10 pt-8 border-t border-slate-50">
                    <h4 class="text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em] mb-4">Speech Transcript</h4>
                    <div class="bg-slate-50/50 rounded-3xl p-6 border border-slate-100 text-sm font-serif text-slate-600 leading-relaxed">
                        ${hasTranscript ? 'I really enjoy hiking on weekends.' : '<span class="italic text-slate-400">No transcript recorded for this session.</span>'}
                    </div>
                </div>
  ${hasTips ? '''
  <div class="jam-roadmap-content text-sm font-serif text-slate-300 leading-relaxed">
                            <span class='feedback-highlight'><b>1. Pacing</b></span>: Great job hitting the time target!
                        </div>
  ''' : '<p class="text-sm font-serif text-slate-400 italic">Complete more sessions to build a personalized roadmap.</p>'}
  ${hasAudio ? '<a href="/media/audio/session_482.webm" target="_blank" class="w-full bg-slate-800 text-slate-400 py-3 rounded-2xl font-serif font-bold text-center hover:text-white transition-all text-sm">Listen to Recording</a>' : ''}
</div>
''';

void main() {
  group('isJamSessionStartHtml / isJamSessionResultHtml', () {
    test('detects session.html by its timer ring', () {
      expect(isJamSessionStartHtml(_sessionStartFixture), isTrue);
      expect(isJamSessionResultHtml(_sessionStartFixture), isFalse);
    });

    test('detects session_detail.html by its result card', () {
      expect(isJamSessionResultHtml(_sessionDetailFixture()), isTrue);
      expect(isJamSessionStartHtml(_sessionDetailFixture()), isFalse);
    });
  });

  group('parseJamSessionStartHtml', () {
    test('parses session id, topic title, description, and difficulty', () {
      final parsed = parseJamSessionStartHtml(_sessionStartFixture);

      expect(parsed, isNotNull);
      expect(parsed!.sessionId, 482);
      expect(parsed.topicTitle, 'Describe your favorite hobby');
      expect(parsed.topicDescription, 'Talk about something you enjoy doing.');
      expect(parsed.topicDifficulty, 'easy');
    });

    test('an absent description (topic.description falsy) parses as empty', () {
      final parsed = parseJamSessionStartHtml(_sessionStartNoDescriptionFixture);

      expect(parsed, isNotNull);
      expect(parsed!.sessionId, 7);
      expect(parsed.topicDescription, '');
      expect(parsed.topicDifficulty, 'hard');
    });

    test('returns null when the page is not a real session.html render', () {
      expect(parseJamSessionStartHtml('<html><body>No topics available.</body></html>'), isNull);
    });
  });

  group('parseJamTopicsHtml', () {
    test('parses every topic, tagged with the difficulty of its section', () {
      final topics = parseJamTopicsHtml(_topicsFixture);

      expect(topics, hasLength(3));
      expect(topics[0].id, 1);
      expect(topics[0].title, 'My Family');
      expect(topics[0].description, 'Talk about your family members.');
      expect(topics[0].difficulty, 'easy');

      expect(topics[1].id, 2);
      expect(topics[1].title, 'Climate Change');
      expect(topics[1].difficulty, 'medium');

      expect(topics[2].id, 3);
      expect(topics[2].title, 'AI & Ethics');
      expect(topics[2].description, 'Is AI a threat?');
      expect(topics[2].difficulty, 'hard');
    });

    test('an empty page yields an empty list', () {
      expect(parseJamTopicsHtml('<html></html>'), isEmpty);
    });
  });

  group('parseJamSessionResultHtml', () {
    test('parses the full scored result, including feedback/transcript/tips/audio', () {
      final result = parseJamSessionResultHtml(_sessionDetailFixture(), 482);

      expect(result, isNotNull);
      expect(result!.sessionId, 482);
      expect(result.topicTitle, 'Describe your favorite hobby');
      expect(result.topicDifficulty, 'easy');
      expect(result.durationDisplay, '45s');
      expect(result.confidenceScore, 4);
      expect(result.fluencyScore, 3);
      expect(result.languageScore, 5);
      expect(result.pronunciationScore, 4);
      expect(result.timeManagementScore, 5);
      expect(result.overallScore, 21);
      expect(result.transcript, 'I really enjoy hiking on weekends.');
      expect(result.aiFeedback, contains('Great job overall.'));
      expect(result.aiFeedback, contains("Performance Analysis"));
      expect(result.aiFeedback, isNot(contains('<b>')));
      expect(result.improvementTips, contains('Great job hitting the time target!'));
      expect(result.improvementTips, isNot(contains('<span')));
      expect(result.audioUrl, '/media/audio/session_482.webm');
      expect(result.createdAtDisplay, 'Feb 10 2026 03:45 PM');
    });

    test('the "No transcript recorded" placeholder normalizes to an empty string', () {
      final result = parseJamSessionResultHtml(_sessionDetailFixture(hasTranscript: false), 1);

      expect(result!.transcript, '');
    });

    test('the "Complete more sessions..." placeholder normalizes improvementTips to empty', () {
      final result = parseJamSessionResultHtml(_sessionDetailFixture(hasTips: false), 1);

      expect(result!.improvementTips, '');
    });

    test('no audio_file means a null audioUrl', () {
      final result = parseJamSessionResultHtml(_sessionDetailFixture(hasAudio: false), 1);

      expect(result!.audioUrl, isNull);
    });

    test('returns null for a page that is not a real session_detail.html render', () {
      expect(parseJamSessionResultHtml('<html><body>Not found</body></html>', 1), isNull);
    });
  });
}
