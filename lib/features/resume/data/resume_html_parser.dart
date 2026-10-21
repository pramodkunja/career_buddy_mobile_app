// Regex extraction against `career_app.views`' server-rendered HTML
// (`templates/resume_builder.html`/`resume_match_result.html`/
// `resume_history.html`) — no JSON API exists for any of Resume Parsing
// (confirmed directly: every one of these views calls Django `render()`,
// never `JsonResponse`). Same legitimate reuse-of-an-already-fetched-page
// technique already used elsewhere in this app (e.g.
// `extractExerciseHeroMeta`, `parseEmployerDashboardHtml`); every regex
// below is anchored to markup read directly from the templates, not
// guessed.

import '../../../core/utils/html_unescape.dart';
import '../domain/entities/resume_analysis.dart';
import '../domain/entities/resume_history_item.dart';
import '../domain/repositories/resume_repository.dart' show ResumeParseQuota;

/// True when [html] is a `resume_match_result.html` render — the page's
/// own `id="score-ring"` SVG element only exists on that template.
bool isResumeMatchResultHtml(String html) => html.contains('id="score-ring"');

/// `resume_job_match`'s failure path re-renders `resume_builder.html`
/// with `{"error": msg}` — the message sits inside `.error-box`
/// (`resume_builder.html:185-190`). Returns `null` if no error block is
/// present (e.g. a genuinely unexpected response).
String? parseResumeBuilderError(String html) {
  final match = RegExp(
    r'<div class="error-box">\s*<i class="fas fa-exclamation-circle fa-lg"></i>\s*<div>([\s\S]*?)</div>',
  ).firstMatch(html);
  return match == null ? null : _unescape(match.group(1)!.trim());
}

/// Parses a `resume_match_result.html` response (from either
/// `resume_job_match` or `resume_reanalyze` — byte-identical template for
/// both) into a [ResumeAnalysisResult].
ResumeAnalysisResult parseResumeMatchResultHtml(String html) {
  // `parseInt("{{ analysis.match_percentage|default:0 }}", 10)`
  // (`resume_match_result.html:491`) — the only place the raw score
  // number appears in the response; the SVG ring itself starts at 0 and
  // is only animated to the real value by client-side JS that never runs
  // in an HTTP client.
  final scoreMatch = RegExp(r'parseInt\("(\d+)",\s*10\)').firstMatch(html);
  final matchPercentage = int.tryParse(scoreMatch?.group(1) ?? '') ?? 0;

  // Matching/Missing Skills each have their own `<!-- ... -->` HTML
  // comment immediately before them (`resume_match_result.html:241,259`,
  // preserved verbatim by Django's renderer) — used to scope each list to
  // its OWN chip-list only. Missing Skills chips are also re-rendered a
  // second time later, inside the "AI Suggestions" card
  // (`resume_match_result.html:466-475`) — scoping to
  // `<!-- Missing Skills -->` … `<!-- Complete Interview` excludes that
  // duplicate.
  final matchingBlock = _between(html, '<!-- Matching Skills -->', '<!-- Missing Skills -->');
  final missingBlock = _between(html, '<!-- Missing Skills -->', '<!-- Complete Interview');
  final matchingSkills = _extractAll(matchingBlock, RegExp(r'chip-found">([^<]*)</span>'));
  final missingSkills = _extractAll(missingBlock, RegExp(r'chip-gap">([^<]*)</span>'));

  final summaryMatch = RegExp(r'<p class="text-muted mb-3">([^<]*)</p>').firstMatch(html);
  final summary = summaryMatch == null ? '' : _unescape(summaryMatch.group(1)!.trim());

  // `.advice-item`'s compound icon+span markup is unique to career-advice
  // rows (unlike the plain `skill-chip` spans above), so this can safely
  // scan the whole document without scoping.
  final careerAdvice = _extractAll(
    html,
    RegExp(r'<div class="advice-dot"><i class="fas fa-star"></i></div>\s*<span>([^<]*)</span>'),
  );

  final validationMatch = RegExp(
    r'fa-exclamation-triangle me-2"></i>([^<]*)</div>',
  ).firstMatch(html);
  final resumeValid = validationMatch == null;
  final validationMessage = validationMatch == null ? null : _unescape(validationMatch.group(1)!.trim());

  // "Detected Experience: 2.5 years" or "Detected Experience: Fresher"
  // (`resume_match_result.html:211-215`).
  final yearsMatch = RegExp(r'Detected Experience:\s*([\s\S]*?)\s*</span>').firstMatch(html);
  final yearsText = yearsMatch?.group(1)?.trim() ?? '';
  final yearsNumberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(yearsText);
  final yearsExperience = yearsNumberMatch == null ? 0.0 : double.tryParse(yearsNumberMatch.group(1)!) ?? 0.0;

  // Phase 46 — the real "Complete Interview to Unlock Jobs Banner" 4-way
  // `{% if %}/{% elif %}/{% else %}` chain (`resume_match_result.html:
  // 309-379`), detected via each branch's own unique heading text rather
  // than re-deriving `can_interview`/`ats_ok`/`role_fit.ok` independently —
  // this is the exact signal the server itself already decided, so it
  // can't drift from what actually rendered. Checked in the template's own
  // branch order; an unrecognized/abbreviated page (e.g. a test fixture
  // with no lower banner at all) safely falls through to `planLocked`,
  // the most conservative state.
  final ResumeInterviewGate gate;
  if (html.contains('doesn&rsquo;t match the') && html.contains(' role</h6>')) {
    gate = ResumeInterviewGate.roleMismatch;
  } else if (html.contains('ATS Score to Unlock the AI Interview')) {
    gate = ResumeInterviewGate.belowThreshold;
  } else if (html.contains('Complete the Interview to Unlock Job Recommendations')) {
    gate = ResumeInterviewGate.eligible;
  } else {
    gate = ResumeInterviewGate.planLocked;
  }
  final canInterview = gate != ResumeInterviewGate.planLocked;

  // `{{ target_role.role }}` — tried against the role-mismatch heading
  // first (`"This resume doesn&rsquo;t match the {role} role"`,
  // `resume_match_result.html:316`), then the AI Suggestions card's own
  // role-specific header (`"Skills {role} needs that your resume
  // doesn&rsquo;t show:"`, line 537), which also covers the belowThreshold
  // case when a role was picked. `null` when neither is present (no role
  // picked, or role_fit unknown).
  final targetRoleName =
      RegExp(r'This resume doesn&rsquo;t match the ([^<]+?) role</h6>').firstMatch(html)?.group(1) ??
      RegExp(r'Skills ([^<]+?) needs that your resume doesn&rsquo;t show:').firstMatch(html)?.group(1);

  // `can_interview and target_role.section and not ats_ok`
  // (`resume_match_result.html:560-563`) — detected the same
  // signal-not-re-derived way as [gate] above.
  final showSkillUpAction = html.contains('Skill up yourself');

  // `is_ats_only` only ever changes 2 words of copy, never structure
  // (`resume_match_result.html:196,202`) — "ATS Score" (the score-ring
  // label) only renders on the `is_ats_only: true` branch.
  final isAtsOnly = html.contains('ATS Score');

  return ResumeAnalysisResult(
    analysis: ResumeAnalysis(
      matchPercentage: matchPercentage,
      matchingSkills: matchingSkills,
      missingSkills: missingSkills,
      summary: summary,
      careerAdvice: careerAdvice,
    ),
    isAtsOnly: isAtsOnly,
    yearsExperience: yearsExperience,
    canInterview: canInterview,
    gate: gate,
    targetRoleName: targetRoleName == null ? null : _unescape(targetRoleName.trim()),
    showSkillUpAction: showSkillUpAction,
    resumeValid: resumeValid,
    validationMessage: validationMessage,
  );
}

/// `resume_reanalyze`'s failure path (`career_app/views.py:858-866`) never
/// re-renders a template at all — it sets a Django `messages.error(...)`
/// and issues a 302 redirect to `resume_history`, which this client's Dio
/// call follows by default. The message ends up in `base.html`'s shared
/// `.messages-container` block (`{% for message in messages %}<div
/// class="alert alert-{{ message.tags }} ...">{{ message }}...`). Returns
/// `null` if no such alert is present (an unexpected response shape).
String? parseFlashedErrorMessage(String html) {
  final match = RegExp(
    r'class="alert alert-(?:error|danger)[^"]*"[^>]*>\s*(?:<i[^>]*></i>)?\s*([^<]*)',
  ).firstMatch(html);
  return match == null ? null : _unescape(match.group(1)!.trim());
}

/// `resume_builder_home`'s "Target role" badge (`resume_builder.html:
/// 186-189`): `Target role: {{ target_role.role }} &middot; {{
/// target_role.dept }}` — rendered only when `target_role` (i.e.
/// `request.session['rb_role']`) is truthy, regardless of plan. This is
/// the mechanism Phase 23's `selectTargetRole` uses to **confirm** a role
/// selection actually took effect server-side, rather than assuming any
/// 200 response means success: a `role`/`dept`/`track` query string sent
/// to an anonymous/expired session is redirected to the login page by
/// `resume_builder_home`'s own `@login_required` before this badge could
/// ever render, so its absence (or a mismatch against what was just sent)
/// reliably signals the selection was never saved.
({String role, String dept})? parseTargetRoleBadge(String html) {
  final match = RegExp(r'Target role:\s*([^<]*?)\s*&middot;\s*([^<]*?)\s*</span>').firstMatch(html);
  if (match == null) return null;
  final role = _unescape(match.group(1)!.trim());
  final dept = _unescape(match.group(2)!.trim());
  if (role.isEmpty || dept.isEmpty) return null;
  return (role: role, dept: dept);
}

/// `resume_builder_home`'s Free-plan usage badge (`resume_builder.html:
/// 191-195`): `<i class="fas fa-file-lines"></i> Free plan: {{ parses_left
/// }} of {{ parse_limit }} resume analyses left`. That whole `<span>` is
/// omitted server-side entirely for a paid plan (`{% if parses_left is not
/// None %}`), so a `null` return here correctly covers both "paid plan"
/// and "unexpected/malformed page" — this never guesses which. Also
/// returns `null` for a value outside what the server could actually ever
/// send (`left` negative, `limit` non-positive, or `left` exceeding
/// `limit`) rather than display something nonsensical.
ResumeParseQuota? parseResumeParsesLeft(String html) {
  final match = RegExp(r'Free plan:\s*(\d+)\s*of\s*(\d+)\s*resume analyses left').firstMatch(html);
  if (match == null) return null;
  final left = int.tryParse(match.group(1)!);
  final limit = int.tryParse(match.group(2)!);
  if (left == null || limit == null || left < 0 || limit <= 0 || left > limit) return null;
  return (left: left, limit: limit);
}

/// Parses `resume_history.html`'s `resumes` list. Each card is delimited
/// by its own `class="resume-history-card` opening
/// (`resume_history.html:69`) — splitting on that literal substring turns
/// the whole list into one chunk per resume, in document (i.e.
/// `-uploaded_at`, newest-first) order.
List<ResumeHistoryItem> parseResumeHistoryHtml(String html) {
  final chunks = html.split('class="resume-history-card');
  final items = <ResumeHistoryItem>[];
  // chunks[0] is everything before the first card (page chrome) — skipped.
  for (final chunk in chunks.skip(1)) {
    final idMatch = RegExp(r'/resume-builder/reanalyze/(\d+)/').firstMatch(chunk);
    if (idMatch == null) continue; // A card with no reanalyze form has no usable id.
    final id = int.parse(idMatch.group(1)!);

    final isCurrent = chunk.trimLeft().startsWith('current"');

    // `<div class="fw-bold text-dark">FILENAME [<span class="badge...
    // ">Current</span>]</div>` (`resume_history.html:71-76`) — stop at
    // whichever comes first, the optional "Current" badge or the closing
    // `</div>`.
    final fileNameMatch = RegExp(
      r'class="fw-bold text-dark">\s*([^<]*?)\s*(?:<span|</div>)',
    ).firstMatch(chunk);
    final fileName = fileNameMatch == null ? '' : _unescape(fileNameMatch.group(1)!.trim());

    final dateMatch = RegExp(r'Uploaded\s+([^<]*)</div>').firstMatch(chunk);
    final uploadedAtDisplay = dateMatch == null ? '' : _unescape(dateMatch.group(1)!.trim());

    final fileUrlMatch = RegExp(r'<a href="([^"]*)"[^>]*target="_blank"').firstMatch(chunk);
    final fileUrl = fileUrlMatch?.group(1);

    items.add(
      ResumeHistoryItem(
        id: id,
        fileName: fileName,
        uploadedAtDisplay: uploadedAtDisplay,
        isCurrent: isCurrent,
        fileUrl: fileUrl,
      ),
    );
  }
  return items;
}

String _between(String html, String start, String end) {
  final startIndex = html.indexOf(start);
  if (startIndex == -1) return '';
  final from = startIndex + start.length;
  final endIndex = html.indexOf(end, from);
  return endIndex == -1 ? html.substring(from) : html.substring(from, endIndex);
}

List<String> _extractAll(String text, RegExp pattern) {
  return [for (final match in pattern.allMatches(text)) _unescape(match.group(1)!.trim())];
}

String _unescape(String value) => unescapeHtmlEntities(value);
