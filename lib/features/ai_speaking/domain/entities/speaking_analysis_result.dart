import 'speaking_issue.dart';

/// The server-authoritative response to `analyze_speaking`
/// (`activities/views.py:1629-1685`). [score25] is
/// `result_data.score_25` — computed server-side
/// (`_normalised_module_score`, `round(raw * 25 / 100)` clamped 0-25, with
/// a relevance-based cap) and persisted before being echoed back; nothing
/// here is recomputed client-side.
///
/// [scores] is intentionally a raw `Map<String, num>`, not a fixed set of
/// named fields — the actual key set genuinely varies (AI-provided keys
/// like `fluency`/`pronunciation`/`grammar`/`vocabulary`/`clarity`/
/// `relevance`/`overall` vs. the offline-fallback's smaller
/// `fluency`/`pronunciation`/`confidence`), and the web's own JS treats it
/// the same defensive way (`scores.fluency`, `scores.pronunciation`, …,
/// each individually optional). Forcing named fields here would mean
/// guessing which keys are guaranteed, which they are not.
class SpeakingAnalysisResult {
  const SpeakingAnalysisResult({
    required this.transcript,
    required this.issues,
    required this.improvedPassage,
    required this.feedback,
    required this.scores,
    required this.score25,
    required this.durationSeconds,
    required this.pauseCount,
  });

  final String transcript;
  final List<SpeakingIssue> issues;
  final String improvedPassage;
  final String? feedback;
  final Map<String, num> scores;

  /// Out of 25 — the only score the web itself actually displays
  /// (`lessonScore.textContent = \`${scoreValue}/25\``).
  final int score25;
  final double durationSeconds;
  final int pauseCount;
}
