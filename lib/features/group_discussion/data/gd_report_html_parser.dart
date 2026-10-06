import '../domain/entities/gd_report.dart';

/// Reads `GD_app:session_report`'s rendered `report.html` (read in full)
/// back into a [GdReport] — there is no JSON sibling for this view. Returns
/// `null` for the `{% else %}` "No analysis yet" branch (no `report-ring`
/// markup present at all), matching `GdRepository.getSessionReport`'s own
/// nullable return.
///
/// Every regex below targets markup that is either a literal, unchanging
/// class/style string from the template (not user data) or a numeric
/// `{{ report.<dimension>.score }}` immediately followed by a fixed
/// `<span>...</span>` suffix the template always prints — so a legitimate
/// score of `0` (the "no speech detected"/"short response" degenerate
/// reports) still matches. Feedback/strengths/improvements/summary text
/// **is** user-facing content Django auto-escapes (`<`, `>`, `&`, `'`, `"`),
/// so a literal `"` in there becomes `&quot;` and can never prematurely
/// close this parser's own `"..."` capture in [_summary].
GdReport? parseGdReportHtml(String html) {
  if (!html.contains('score-ring-wrap')) return null;

  final dims = _dimensions(html);
  return GdReport(
    overallScore: _overallScore(html),
    fluency: dims.isNotEmpty ? dims[0] : const GdReportDimension(score: 0, feedback: ''),
    grammar: dims.length > 1 ? dims[1] : const GdReportDimension(score: 0, feedback: ''),
    relevance: dims.length > 2 ? dims[2] : const GdReportDimension(score: 0, feedback: ''),
    confidence: dims.length > 3 ? dims[3] : const GdReportDimension(score: 0, feedback: ''),
    strengths: _listItems(html, insightBlockClass: 'insight-dark'),
    improvements: _listItems(html, insightBlockClass: 'insight-light'),
    summary: _summary(html),
  );
}

int _overallScore(String html) {
  final match = RegExp(
    r'font-size:3rem;font-weight:900;color:#1e293b;line-height:1;">(\d+)</div>',
  ).firstMatch(html);
  return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
}

/// The 4 `.dim-card` blocks always appear in this fixed order in the
/// template: Fluency, Grammar, Relevance, Confidence. Each has its own
/// distinguishing `dim-score` style/class (so the 4 scores can be told
/// apart), and the 4 `.dim-feedback` divs simply appear in that same order.
List<GdReportDimension> _dimensions(String html) {
  final scorePatterns = [
    RegExp(r'dim-score text-primary">(\d+)<span'), // Fluency
    RegExp(r'dim-score" style="color:#7c3aed;">(\d+)<span'), // Grammar
    RegExp(r'dim-score text-success">(\d+)<span'), // Relevance
    RegExp(r'dim-score" style="color:#d97706;">(\d+)<span'), // Confidence
  ];
  final feedbacks = RegExp(r'<div class="dim-feedback">([^<]*)</div>')
      .allMatches(html)
      .map((m) => m.group(1)!.trim())
      .toList();

  return List.generate(4, (i) {
    final scoreMatch = scorePatterns[i].firstMatch(html);
    final score = scoreMatch == null ? 0 : int.tryParse(scoreMatch.group(1)!) ?? 0;
    final feedback = i < feedbacks.length ? feedbacks[i] : '';
    return GdReportDimension(score: score, feedback: feedback);
  });
}

/// Each strength/improvement is rendered as `<p ...>{{ text }}</p>` inside
/// its own `.insight-item` wrapper div, all inside one `.insight-card
/// insight-dark`/`insight-light` block — the nesting depth isn't fixed
/// enough to bound with a closing-tag count, so this instead bounds the
/// capture with a lookahead for whichever real section always follows (the
/// other insight card, or the Coach's Verdict block).
List<String> _listItems(String html, {required String insightBlockClass}) {
  final blockMatch = RegExp(
    'insight-card $insightBlockClass">(.*?)(?=<div class="insight-card|<div class="verdict)',
    dotAll: true,
  ).firstMatch(html);
  if (blockMatch == null) return const [];
  final block = blockMatch.group(1)!;
  // The template's own `{% empty %}` fallback text ("No significant
  // strengths recorded."/"No improvement areas suggested.",
  // `templates/GD_app/report.html`) renders as the one `<p>` present when
  // the list is genuinely empty — it must not be mistaken for a real item.
  const emptyFallbacks = {'No significant strengths recorded.', 'No improvement areas suggested.'};
  return RegExp(r'<p[^>]*>([^<]*)</p>')
      .allMatches(block)
      .map((m) => m.group(1)!.trim())
      .where((text) => text.isNotEmpty && !emptyFallbacks.contains(text))
      .toList();
}

String _summary(String html) {
  final match = RegExp(r'<div class="verdict-quote">"(.*?)"</div>').firstMatch(html);
  return match == null ? '' : match.group(1)!.trim();
}
