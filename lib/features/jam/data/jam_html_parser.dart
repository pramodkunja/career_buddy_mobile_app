// Regex extraction against `jam_app.views`' server-rendered HTML
// (`templates/jam/session.html`/`session_detail.html`/`topics.html`) — no
// JSON API exists for any of these three (confirmed directly: all three
// views call Django `render()`, never `JsonResponse`; only `save_audio`
// returns JSON — see `ApiEndpoints`'s doc comment). Same legitimate
// reuse-of-an-already-fetched-page technique already established by
// `resume_html_parser.dart`; every regex below is anchored to markup read
// directly from the real templates, not guessed.

import '../domain/entities/jam_assessment.dart';
import '../domain/entities/jam_history_profile.dart';
import '../domain/entities/jam_session_result.dart';
import '../domain/entities/jam_session_start.dart';
import '../domain/entities/jam_topic.dart';

/// True when [html] is a `jam/session.html` render — the page's own
/// `id="timerRing"` SVG element (the 60-second countdown ring) only exists
/// on that template.
bool isJamSessionStartHtml(String html) => html.contains('id="timerRing"');

/// True when [html] is a `jam/session_detail.html` render — the page's own
/// `id="resultCard"` wrapper only exists on that template.
bool isJamSessionResultHtml(String html) => html.contains('id="resultCard"');

/// Parses `jam:jam_session`/`jam:jam_session_topic`'s `session.html`
/// response: the freshly-created session id (embedded for the page's own
/// JS, `const SESSION_ID = Number("{{ session.id }}");`,
/// `session.html:193`) plus the chosen topic's title/description/
/// difficulty (`session.html:50-56`). Returns `null` if the page doesn't
/// look like a real session.html render (e.g. an unexpected redirect to
/// `jam:dashboard` when no topics exist, `jam_app/views.py:182-184`).
JamSessionStart? parseJamSessionStartHtml(String html) {
  final sessionIdMatch = RegExp(r'const SESSION_ID = Number\("(\d+)"\);').firstMatch(html);
  if (sessionIdMatch == null) return null;
  final sessionId = int.parse(sessionIdMatch.group(1)!);

  final titleMatch = RegExp(r'id="headerTopicTitle">([\s\S]*?)</h1>').firstMatch(html);
  final title = titleMatch == null ? '' : _unescape(titleMatch.group(1)!.trim());

  final descMatch = RegExp(r'id="headerTopicDesc">([^<]*)</p>').firstMatch(html);
  final description = descMatch == null ? '' : _unescape(descMatch.group(1)!.trim());

  final difficultyMatch = RegExp(r'badge-jam badge-jam-(\w+)">').firstMatch(html);
  final difficulty = difficultyMatch?.group(1) ?? '';

  return JamSessionStart(
    sessionId: sessionId,
    topicTitle: title,
    topicDescription: description,
    topicDifficulty: difficulty,
  );
}

/// Parses `jam:topics`' `topics.html` response into every active topic,
/// tagged with its difficulty by which of the 3 sections
/// (`id="easy"`/`id="medium"`/`id="hard"`, `topics.html:27,55,83`) it falls
/// in. Each card's title (`<h3 class="font-serif text-2xl font-bold
/// text-slate-900 mb-4 group-hover:text-{emerald,amber,rose}-600
/// transition-colors leading-tight">`, color varies per section) and
/// description (`<p class="text-slate-500 font-serif leading-relaxed
/// mb-10 flex-1">`, identical class across all 3 sections) are followed by
/// its "Practice Session" link, `{% url 'jam:jam_session_topic' topic.id
/// %}"` = `/jam/session/start/{id}/` (`topics.html:45,73,101`), which is
/// where the topic's id comes from — `Topic` itself is never otherwise
/// serialized with a bare numeric id anywhere in this page.
List<JamTopic> parseJamTopicsHtml(String html) {
  final easyStart = html.indexOf('id="easy"');
  final mediumStart = html.indexOf('id="medium"');
  final hardStart = html.indexOf('id="hard"');

  final cardPattern = RegExp(
    r'<h3 class="font-serif text-2xl font-bold text-slate-900 mb-4 group-hover:text-[a-z]+-600 transition-colors leading-tight">([^<]*)</h3>\s*'
    r'<p class="text-slate-500 font-serif leading-relaxed mb-10 flex-1">([^<]*)</p>\s*'
    r'<a href="/jam/session/start/(\d+)/"',
  );

  final topics = <JamTopic>[];
  for (final match in cardPattern.allMatches(html)) {
    final start = match.start;
    final difficulty = hardStart != -1 && start >= hardStart
        ? 'hard'
        : mediumStart != -1 && start >= mediumStart
        ? 'medium'
        : easyStart != -1 && start >= easyStart
        ? 'easy'
        : '';
    topics.add(
      JamTopic(
        id: int.parse(match.group(3)!),
        title: _unescape(match.group(1)!.trim()),
        description: _unescape(match.group(2)!.trim()),
        difficulty: difficulty,
      ),
    );
  }
  return topics;
}

/// Parses `jam:complete_session`'s redirect target,
/// `jam:session_detail`'s `session_detail.html` (`jam_app/views.py:704`,
/// `reverse('jam:session_detail', args=[session.id]) + '#ai-feedback'`),
/// into the full scored [JamSessionResult]. [sessionId] is passed in
/// rather than parsed out of the page — unlike `session.html`,
/// `session_detail.html` never embeds `session.id` in any script variable
/// (confirmed by reading the full template), but the caller already knows
/// it (it's the same id `completeSession` was called with).
///
/// [session.ai_feedback]/[session.improvement_tips] are rendered through
/// `{{ value|safe|linebreaks }}` (`session_detail.html:140,167`) — the
/// stored value already contains literal HTML (`<h4>`/`<b>`/`<span>` from
/// `_format_ai_feedback`/`_rule_based_feedback`, `jam_app/views.py`), and
/// Django's `linebreaks` filter then wraps that further in `<p>`/`<br>` on
/// top, purely by newline position, with no awareness of the embedded
/// tags. Re-rendering that exact mixed markup would mean shipping a full
/// HTML view for two text blocks; instead this parser strips every tag to
/// plain text (via `_htmlToPlainText`, converting block-level closes to
/// newlines first so paragraph structure survives) — the same real text
/// the web shows, without its styling.
JamSessionResult? parseJamSessionResultHtml(String html, int sessionId) {
  if (!isJamSessionResultHtml(html)) return null;

  final titleMatch = RegExp(
    r'text-4xl md:text-5xl font-bold text-slate-900 font-serif mb-4 leading-tight">([^<]*)</h1>',
  ).firstMatch(html);
  final topicTitle = titleMatch == null ? '' : _unescape(titleMatch.group(1)!.trim());

  final difficultyMatch = RegExp(r'capitalize">\s*([a-zA-Z]+)\s*Difficulty').firstMatch(html);
  final topicDifficulty = difficultyMatch?.group(1)?.toLowerCase() ?? '';

  final durationMatch = RegExp(
    r'font-serif border border-slate-100">\s*([^<]*?)\s*spoken',
  ).firstMatch(html);
  final durationDisplay = durationMatch == null ? '' : _unescape(durationMatch.group(1)!.trim());

  int scoreFor(String label) {
    final match = RegExp(
      '$label</span>\\s*<span class="text-sm font-bold font-serif text-slate-900">(\\d+)/5</span>',
    ).firstMatch(html);
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  final overallMatch = RegExp(r'text-5xl font-bold font-serif text-slate-900 block">(\d+)</span>').firstMatch(html);
  final overallScore = overallMatch == null ? 0 : int.parse(overallMatch.group(1)!);

  final feedbackMatch = RegExp(
    r'jam-feedback-content">([\s\S]*?)</div>\s*<div class="mt-10 pt-8 border-t border-slate-50">',
  ).firstMatch(html);
  final aiFeedback = feedbackMatch == null ? '' : _htmlToPlainText(feedbackMatch.group(1)!);

  final transcriptMatch = RegExp(
    r'Speech Transcript</h4>\s*<div class="bg-slate-50/50 rounded-3xl p-6 border border-slate-100 text-sm font-serif text-slate-600 leading-relaxed">([\s\S]*?)</div>',
  ).firstMatch(html);
  final rawTranscript = transcriptMatch?.group(1)?.trim() ?? '';
  final transcript = rawTranscript.startsWith('<span class="italic') ? '' : _unescape(rawTranscript);

  final tipsMatch = RegExp(
    r'jam-roadmap-content text-sm font-serif text-slate-300 leading-relaxed">([\s\S]*?)</div>',
  ).firstMatch(html);
  final improvementTips = tipsMatch == null ? '' : _htmlToPlainText(tipsMatch.group(1)!);

  final audioMatch = RegExp(
    r'<a href="([^"]*)" target="_blank" class="w-full bg-slate-800 text-slate-400 py-3 rounded-2xl font-serif font-bold text-center hover:text-white transition-all text-sm">',
  ).firstMatch(html);
  final audioUrl = audioMatch?.group(1);

  final createdAtMatch = RegExp(
    r'bg-white text-slate-400 rounded-full text-\[10px\] font-bold uppercase tracking-widest border border-slate-100">\s*([^<]*?)\s*</span>',
  ).firstMatch(html);
  final createdAtDisplay = createdAtMatch == null ? '' : _unescape(createdAtMatch.group(1)!.trim());

  return JamSessionResult(
    sessionId: sessionId,
    topicTitle: topicTitle,
    topicDifficulty: topicDifficulty,
    durationDisplay: durationDisplay,
    confidenceScore: scoreFor('Confidence'),
    fluencyScore: scoreFor('Fluency'),
    languageScore: scoreFor('Language'),
    pronunciationScore: scoreFor('Pronunciation'),
    timeManagementScore: scoreFor('Time Management'),
    overallScore: overallScore,
    transcript: transcript,
    aiFeedback: aiFeedback,
    improvementTips: improvementTips,
    audioUrl: audioUrl,
    createdAtDisplay: createdAtDisplay,
  );
}

/// True when [html] is a `jam/session.html` render **for an assessment
/// stage** specifically — the page's own stage indicator
/// (`id="labelStage">Stage N of 3`, `session.html:74`, only printed when
/// the view passes `is_assessment: True`, `jam_app/views.py:297-303`) only
/// exists on that variant of the page, distinguishing it from an ordinary
/// practice `session.html` render (which has `id="timerRing"` too, but no
/// stage indicator).
bool isJamAssessmentStageHtml(String html) => RegExp(r'id="labelStage">Stage \d+ of 3').hasMatch(html);

/// Parses `jam:start_assessment`'s redirect target (stage 1) or
/// `jam:complete_session`'s redirect target for stage 1→2/2→3 — both land
/// on the exact same `session.html` template [parseJamSessionStartHtml]
/// already parses, just with `is_assessment`/`stage` context added
/// (`assessment_session`, `jam_app/views.py:283-303`). Reuses that parser
/// for the session id/topic fields, then additionally requires and reads
/// the stage indicator; returns `null` if either the base page isn't a
/// real `session.html` render or it's a *non*-assessment one (no stage
/// indicator) — the same "didn't land where expected" signal
/// [parseJamSessionStartHtml] already gives callers for its own page.
JamSessionStart? parseJamAssessmentStageHtml(String html) {
  final base = parseJamSessionStartHtml(html);
  if (base == null) return null;
  final stageMatch = RegExp(r'id="labelStage">Stage (\d+) of 3').firstMatch(html);
  if (stageMatch == null) return null;
  return JamSessionStart(
    sessionId: base.sessionId,
    topicTitle: base.topicTitle,
    topicDescription: base.topicDescription,
    topicDifficulty: base.topicDifficulty,
    stage: int.parse(stageMatch.group(1)!),
  );
}

/// True when [html] is a `jam:history` render — `templates/jam/history.html`'s
/// own tab-switcher button (`id="tab-regular"`) only exists on that page.
bool isJamHistoryHtml(String html) => html.contains('id="tab-regular"');

/// Parses `jam:history`'s "Regular Sessions" tab
/// (`templates/jam/history.html:26-64`) into one [JamPracticeSessionSummary]
/// per completed practice session, reading each card's difficulty badge
/// (`badge-jam badge-jam-{{ session.topic.difficulty }}`,
/// `history.html:40` — the identical badge class `parseJamTopicsHtml`
/// already reads on the Topics page). The "Assessments" tab
/// (`history.html:67-101`, wrapped in a *separate* `id="content-assessments"`
/// container) is intentionally not parsed here — `history()`'s own
/// `regular_sessions` queryset already excludes every assessment-stage
/// session (`assessment_easy/medium/hard__isnull=True`,
/// `jam_app/views.py:732-738`), so nothing there could contaminate this
/// eligibility count even without a container boundary, but this parser
/// still only walks `content-regular` between the two tab markers to stay
/// anchored to exactly what the intent (`get_jam_level_progress`) needs.
List<JamPracticeSessionSummary> parseJamHistoryHtml(String html) {
  final regularStart = html.indexOf('id="content-regular"');
  final assessmentsStart = html.indexOf('id="content-assessments"');
  final regularSection = regularStart == -1
      ? html
      : html.substring(regularStart, assessmentsStart == -1 ? html.length : assessmentsStart);

  final badgeMatch = RegExp(r'badge-jam badge-jam-(\w+)"');
  return [
    for (final match in badgeMatch.allMatches(regularSection)) JamPracticeSessionSummary(difficulty: match.group(1)!),
  ];
}

/// Parses the full `jam:history` page for the History screen (not just the
/// eligibility-only difficulty list [parseJamHistoryHtml] already reads) —
/// both the "Regular Sessions" and "Assessments" tabs, scoped to their own
/// `id="content-regular"`/`id="content-assessments"` containers the same
/// way [parseJamHistoryHtml] already does, then split per-card on each
/// card's own distinctive opening class string (cards nest to an
/// unpredictable depth, so there's no fixed closing-tag count to rely on —
/// same technique proven on the employer-side list parsers).
JamHistoryPage parseJamHistoryPageHtml(String html) {
  final regularStart = html.indexOf('id="content-regular"');
  final assessmentsStart = html.indexOf('id="content-assessments"');
  final regularSection = regularStart == -1
      ? html
      : html.substring(regularStart, assessmentsStart == -1 ? html.length : assessmentsStart);
  final assessmentsSection = assessmentsStart == -1 ? '' : html.substring(assessmentsStart);

  final sessionStarts = [
    for (final m in RegExp(r'group flex items-center justify-between p-5 rounded-2xl border border-slate-50').allMatches(regularSection))
      m.start,
  ];
  final sessions = <JamHistorySession>[];
  for (var i = 0; i < sessionStarts.length; i++) {
    final end = i + 1 < sessionStarts.length ? sessionStarts[i + 1] : regularSection.length;
    final card = regularSection.substring(sessionStarts[i], end);

    final idMatch = RegExp(r'/jam/session/(\d+)/"').firstMatch(card);
    final titleMatch = RegExp(r'<h4[^>]*>([^<]*)</h4>').firstMatch(card);
    if (idMatch == null || titleMatch == null) continue;

    final difficultyMatch = RegExp(r'badge-jam badge-jam-(\w+)"').firstMatch(card);
    final createdAtMatch = RegExp(r'text-xs text-slate-400 font-serif">([^<]*)</span>').firstMatch(card);
    final durationMatch = RegExp(r'text-sm font-bold font-serif text-slate-900">([^<]*)</div>').firstMatch(card);
    final scoreMatch = RegExp(r'text-amber-500">★\s*(\d+)</div>').firstMatch(card);

    sessions.add(
      JamHistorySession(
        sessionId: int.parse(idMatch.group(1)!),
        topicTitle: _unescape(titleMatch.group(1)!.trim()),
        difficulty: difficultyMatch?.group(1) ?? '',
        createdAt: _unescape(createdAtMatch?.group(1)?.trim() ?? ''),
        durationDisplay: _unescape(durationMatch?.group(1)?.trim() ?? ''),
        overallScore: int.tryParse(scoreMatch?.group(1) ?? ''),
      ),
    );
  }

  final assessmentStarts = [
    for (final m in RegExp(r'p-6 rounded-\[32px\] border border-slate-100 bg-slate-50/50').allMatches(assessmentsSection))
      m.start,
  ];
  final assessments = <JamHistoryAssessment>[];
  for (var i = 0; i < assessmentStarts.length; i++) {
    final end = i + 1 < assessmentStarts.length ? assessmentStarts[i + 1] : assessmentsSection.length;
    final card = assessmentsSection.substring(assessmentStarts[i], end);

    final idMatch = RegExp(r'/jam/assessment/result/(\d+)/"').firstMatch(card);
    final createdAtMatch = RegExp(r'Assessment on ([^<]*)</h3>').firstMatch(card);
    if (idMatch == null) continue;

    final topicMatches = RegExp(r'text-\[10px\] font-bold text-slate-500">([^<]*)</span>').allMatches(card).toList();

    assessments.add(
      JamHistoryAssessment(
        assessmentId: int.parse(idMatch.group(1)!),
        createdAt: _unescape(createdAtMatch?.group(1)?.trim() ?? ''),
        easyTopicTitle: topicMatches.isNotEmpty ? _unescape(topicMatches[0].group(1)!.trim()) : '',
        mediumTopicTitle: topicMatches.length > 1 ? _unescape(topicMatches[1].group(1)!.trim()) : '',
        hardTopicTitle: topicMatches.length > 2 ? _unescape(topicMatches[2].group(1)!.trim()) : '',
      ),
    );
  }

  return JamHistoryPage(sessions: sessions, assessments: assessments);
}

/// Parses `jam:profile`'s `profile.html` — both the read-only sidebar
/// stats and the edit form's pre-filled values (the template renders
/// `user.first_name`/`user.last_name`/`user.email`/`profile.bio` directly
/// as plain `value="..."` attributes, not bound `{{ form.field }}` widgets
/// — see `ApiEndpoints.jamProfile`'s doc comment).
JamProfile parseJamProfileHtml(String html) {
  final fullNameMatch = RegExp(r'font-serif text-xl font-bold text-slate-900">([^<]*)</h3>').firstMatch(html);
  final sessionsMatch = RegExp(r'Total Sessions</span>\s*<span[^>]*>([^<]*)</span>').firstMatch(html);
  final minutesMatch = RegExp(r'Minutes Spoken</span>\s*<span[^>]*>(\d+)m</span>').firstMatch(html);
  final firstNameMatch = RegExp(r'name="first_name" value="([^"]*)"').firstMatch(html);
  final lastNameMatch = RegExp(r'name="last_name" value="([^"]*)"').firstMatch(html);
  final emailFieldMatch = RegExp(r'name="email" value="([^"]*)"').firstMatch(html);
  final bioMatch = RegExp(r'name="bio"[^>]*>([\s\S]*?)</textarea>').firstMatch(html);

  return JamProfile(
    fullName: _unescape(fullNameMatch?.group(1)?.trim() ?? ''),
    email: _unescape(emailFieldMatch?.group(1)?.trim() ?? ''),
    firstName: _unescape(firstNameMatch?.group(1)?.trim() ?? ''),
    lastName: _unescape(lastNameMatch?.group(1)?.trim() ?? ''),
    bio: _unescape(bioMatch?.group(1)?.trim() ?? ''),
    totalSessions: int.tryParse(sessionsMatch?.group(1)?.trim() ?? '') ?? 0,
    totalMinutes: int.tryParse(minutesMatch?.group(1) ?? '') ?? 0,
  );
}

/// True when [html] is a `jam:assessment_result` render — the page's own
/// heading (`templates/jam/assessment_result.html:31`,
/// `<h1 ...>Diagnostic Performance Report</h1>`) only exists on that
/// template.
bool isJamAssessmentResultHtml(String html) => html.contains('Diagnostic Performance Report');

/// Parses `jam:assessment_result`'s `assessment_result.html` — the page
/// `jam:complete_session` redirects to after stage 3
/// (`jam_app/views.py:696-701`) — into the full [JamAssessmentResult].
/// Returns `null` if [html] doesn't look like a real render of that page.
///
/// `level`/`averageDurationSeconds`/`averageFluency` are all read straight
/// out of `AssessmentGroup.final_report`'s own literal HTML
/// (`generate_final_assessment`, `jam_app/views.py:611-618` — inserted
/// `|safe`, so its markup appears verbatim in the response) rather than
/// re-derived from the page's separate Tailwind progress-bar markup, since
/// the report text is where the server actually states them in plain
/// language; [totalScore] and each stage's topic/score instead come from
/// the page's own "Stage Summary Strip" (`assessment_result.html:124-140`)
/// and total-score circle (`:105,112`), which are populated independently
/// of the report text.
JamAssessmentResult? parseJamAssessmentResultHtml(String html) {
  if (!isJamAssessmentResultHtml(html)) return null;

  final feedbackMatch = RegExp(
    r'jam-feedback-content">([\s\S]*?)</div>\s*<!-- Per-Stage Transcripts accordion -->',
  ).firstMatch(html);
  final reportHtml = feedbackMatch?.group(1) ?? '';
  final reportText = _htmlToPlainText(reportHtml);

  final levelMatch = RegExp(r'Result Level:\s*([A-Za-z]+)').firstMatch(reportHtml);
  final level = levelMatch?.group(1) ?? '';

  final durationMatch = RegExp(r'Average Duration</b>:\s*(\d+)s').firstMatch(reportHtml);
  final averageDurationSeconds = durationMatch == null ? 0 : int.parse(durationMatch.group(1)!);

  final fluencyMatch = RegExp(r'Average Fluency Consistency</b>:\s*([\d.]+)/5').firstMatch(reportHtml);
  final averageFluency = fluencyMatch == null ? 0.0 : double.parse(fluencyMatch.group(1)!);

  final totalMatch = RegExp(r'text-5xl font-bold font-serif text-slate-900 block">(\d+)</span>').firstMatch(html);
  final totalScore = totalMatch == null ? 0 : int.parse(totalMatch.group(1)!);

  JamAssessmentStageSummary stageSummary(String difficulty, String label) {
    final match = RegExp(
      '$label Stage</div>\\s*'
      r'<div class="text-sm font-bold font-serif text-slate-900">([^<]*)</div>\s*'
      r'<div class="text-xs text-[a-z]+-500 font-bold mt-1">★\s*([^<]*?)/25</div>',
    ).firstMatch(html);
    final title = match == null ? '' : _unescape(match.group(1)!.trim());
    final scoreRaw = match?.group(2)?.trim();
    final score = scoreRaw == null || scoreRaw == '—' ? null : int.tryParse(scoreRaw);
    return JamAssessmentStageSummary(difficulty: difficulty, topicTitle: title, overallScore: score);
  }

  return JamAssessmentResult(
    level: level,
    averageDurationSeconds: averageDurationSeconds,
    averageFluency: averageFluency,
    totalScore: totalScore,
    stages: [stageSummary('easy', 'Easy'), stageSummary('medium', 'Medium'), stageSummary('hard', 'Hard')],
    reportText: reportText,
  );
}

String _htmlToPlainText(String raw) {
  var text = raw;
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
  text = text.replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<[^>]*>'), '');
  text = _unescape(text);
  final lines = text.split('\n').map((line) => line.trim()).toList();
  text = lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return text;
}

String _unescape(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"');
