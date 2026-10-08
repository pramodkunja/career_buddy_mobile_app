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

  // `can_interview` decides between two literal CTA labels
  // (`resume_match_result.html:218-227`) — "Try Interview" only ever
  // renders on the `can_interview: true` branch.
  final canInterview = html.contains('Try Interview');

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
