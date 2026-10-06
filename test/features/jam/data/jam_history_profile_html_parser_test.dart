import 'package:career_buddy_lms/features/jam/data/jam_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the real markup of `templates/jam/history.html` and
/// `templates/jam/profile.html` (`jam_app.views.history`/`profile_view`),
/// read directly from the Django source this session.
const _historyFixture = '''
<div id="content-regular" class="space-y-4">
    <div class="group flex items-center justify-between p-5 rounded-2xl border border-slate-50 hover:border-coral/20 hover:bg-coral/[0.02] transition-all relative">
        <a href="/jam/session/42/" class="absolute inset-0 z-0"></a>
        <div class="flex items-center gap-5 relative z-10">
            <div class="w-12 h-12 rounded-xl bg-slate-50"><span class="material-symbols-outlined">description</span></div>
            <div>
                <h4 class="font-serif font-bold text-slate-900 group-hover:text-coral transition-all">Business Negotiation</h4>
                <div class="flex items-center gap-3 mt-1">
                    <span class="badge-jam badge-jam-medium">medium</span>
                    <span class="text-xs text-slate-400 font-serif">Sep 15 2026 02:30 PM</span>
                </div>
            </div>
        </div>
        <div class="flex items-center gap-8 relative z-10">
            <div class="text-right">
                <div class="text-sm font-bold font-serif text-slate-900">1m 5s</div>
                <div class="text-[10px] text-slate-400 font-serif uppercase tracking-wider">Duration</div>
            </div>
            <div class="text-right">
                <div class="text-sm font-bold font-serif text-amber-500">★ 18</div>
                <div class="text-[10px] text-slate-400 font-serif uppercase tracking-wider">Score</div>
            </div>
            <form action="/jam/session/delete/42/" method="POST" onsubmit="return confirm('Delete this session?')">
                <button type="submit"><span class="material-symbols-outlined text-[20px]">delete</span></button>
            </form>
        </div>
    </div>
    <div class="group flex items-center justify-between p-5 rounded-2xl border border-slate-50 hover:border-coral/20 hover:bg-coral/[0.02] transition-all relative">
        <a href="/jam/session/41/" class="absolute inset-0 z-0"></a>
        <div class="flex items-center gap-5 relative z-10">
            <div><h4 class="font-serif font-bold text-slate-900 group-hover:text-coral transition-all">Self Introduction</h4>
            <div class="flex items-center gap-3 mt-1">
                <span class="badge-jam badge-jam-easy">easy</span>
                <span class="text-xs text-slate-400 font-serif">Sep 10 2026 09:00 AM</span>
            </div></div>
        </div>
        <div class="flex items-center gap-8 relative z-10">
            <div class="text-right">
                <div class="text-sm font-bold font-serif text-slate-900">45s</div>
                <div class="text-[10px] text-slate-400 font-serif uppercase tracking-wider">Duration</div>
            </div>
        </div>
    </div>
</div>
<div id="content-assessments" class="hidden space-y-6">
    <div class="p-6 rounded-[32px] border border-slate-100 bg-slate-50/50 hover:bg-white hover:shadow-md transition-all relative">
        <a href="/jam/assessment/result/7/" class="absolute inset-0 z-0"></a>
        <div class="flex items-center justify-between relative z-10">
            <div>
                <div class="text-[10px] font-bold text-coral uppercase tracking-widest mb-2">3-Stage Diagnostic</div>
                <h3 class="font-serif text-xl font-bold text-slate-900 mb-1">Assessment on Sep 20 2026 11:00 AM</h3>
                <div class="flex gap-2 mt-3">
                    <span class="px-3 py-1 rounded-full bg-white border border-slate-100 text-[10px] font-bold text-slate-500">Self Introduction</span>
                    <span class="px-3 py-1 rounded-full bg-white border border-slate-100 text-[10px] font-bold text-slate-500">Business Negotiation</span>
                    <span class="px-3 py-1 rounded-full bg-white border border-slate-100 text-[10px] font-bold text-slate-500">Conflict Resolution</span>
                </div>
            </div>
        </div>
    </div>
</div>
''';

const _profileFixture = '''
<div class="w-20 h-20 rounded-full bg-coral/10 text-coral flex items-center justify-center mx-auto mb-4 font-serif text-3xl font-bold">A</div>
<h3 class="font-serif text-xl font-bold text-slate-900">Alex Kumar</h3>
<p class="text-sm text-slate-400 font-serif">alex@example.com</p>
<div class="bg-slate-900 rounded-[32px] p-6 text-white space-y-6">
    <div class="flex items-center justify-between">
        <span class="text-xs font-bold text-slate-500 uppercase tracking-widest">Total Sessions</span>
        <span class="font-serif font-bold text-coral text-xl">12</span>
    </div>
    <div class="flex items-center justify-between">
        <span class="text-xs font-bold text-slate-500 uppercase tracking-widest">Minutes Spoken</span>
        <span class="font-serif font-bold text-coral text-xl">34m</span>
    </div>
</div>
<form method="POST" class="space-y-6">
    <input type="text" name="first_name" value="Alex" class="w-full bg-slate-50 border-none rounded-2xl p-4 font-serif" placeholder="Enter first name">
    <input type="text" name="last_name" value="Kumar" class="w-full bg-slate-50 border-none rounded-2xl p-4 font-serif" placeholder="Enter last name">
    <input type="email" name="email" value="alex@example.com" class="w-full bg-slate-50 border-none rounded-2xl p-4 font-serif" placeholder="your@email.com">
    <textarea name="bio" rows="4" class="w-full bg-slate-50 border-none rounded-2xl p-4 font-serif" placeholder="Tell us why you're learning English...">Learning for my new job.</textarea>
</form>
''';

void main() {
  group('parseJamHistoryPageHtml', () {
    test('parses every regular session and every assessment', () {
      final page = parseJamHistoryPageHtml(_historyFixture);

      expect(page.sessions, hasLength(2));
      expect(page.sessions[0].sessionId, 42);
      expect(page.sessions[0].topicTitle, 'Business Negotiation');
      expect(page.sessions[0].difficulty, 'medium');
      expect(page.sessions[0].createdAt, 'Sep 15 2026 02:30 PM');
      expect(page.sessions[0].durationDisplay, '1m 5s');
      expect(page.sessions[0].overallScore, 18);

      expect(page.sessions[1].sessionId, 41);
      expect(page.sessions[1].overallScore, isNull);

      expect(page.assessments, hasLength(1));
      expect(page.assessments[0].assessmentId, 7);
      expect(page.assessments[0].createdAt, 'Sep 20 2026 11:00 AM');
      expect(page.assessments[0].easyTopicTitle, 'Self Introduction');
      expect(page.assessments[0].mediumTopicTitle, 'Business Negotiation');
      expect(page.assessments[0].hardTopicTitle, 'Conflict Resolution');
    });

    test('an empty history parses to empty lists, not a crash', () {
      final page = parseJamHistoryPageHtml('<div id="content-regular"></div><div id="content-assessments"></div>');

      expect(page.sessions, isEmpty);
      expect(page.assessments, isEmpty);
    });
  });

  group('parseJamProfileHtml', () {
    test('parses every field', () {
      final profile = parseJamProfileHtml(_profileFixture);

      expect(profile.fullName, 'Alex Kumar');
      expect(profile.email, 'alex@example.com');
      expect(profile.firstName, 'Alex');
      expect(profile.lastName, 'Kumar');
      expect(profile.bio, 'Learning for my new job.');
      expect(profile.totalSessions, 12);
      expect(profile.totalMinutes, 34);
    });
  });
}
