import 'roleplay_issue.dart';

/// The server-authoritative `data` payload of `analyze_roleplay`
/// (`activities/views.py:2083-2124`) on a successful (`"success": true`)
/// response. Confirmed by reading the view directly: it builds `agent =
/// SpeakingAgent()` (`activities/agents/speaking.py`) — the **same** agent
/// class `analyze_speaking` (W014) uses — and returns
/// `JsonResponse(agent.safe_run(payload))` completely unmodified, unlike
/// `analyze_speaking`'s view which additionally injects a top-level and
/// nested `score_25` before responding. `analyze_roleplay` computes a
/// `score_25` too, but only to persist a `ScoreRecord` server-side
/// (`module='roleplay'`) — it is **never written back into the response
/// body** (confirmed: no `result['score_25'] = ...` or `data['score_25'] =
/// ...` anywhere in `analyze_roleplay`, unlike `analyze_speaking`). So,
/// deliberately, this entity has **no `score25` field** — reproducing one
/// here would be inventing data the API does not actually send back.
///
/// [scores] is a raw `Map<String, num>` for the same reason
/// `SpeakingAnalysisResult.scores` is: the real key set varies (AI-provided
/// `fluency`/`grammar`/`clarity`/`relevance`/`overall`/... vs. the
/// offline-fallback's smaller `fluency`/`pronunciation`/`confidence`), and
/// the web's own `renderResults()` JS (`roleplay.html:707-727`) reads it
/// the same defensively optional way: `scores.overall || 0`,
/// `scores.fluency || 0`, `scores.grammar || 0`,
/// `scores.clarity || scores.pronunciation || 0`.
class RoleplayAnalysisResult {
  const RoleplayAnalysisResult({
    required this.transcript,
    required this.issues,
    required this.improvedPassage,
    required this.feedback,
    required this.quickTip,
    required this.scores,
    required this.durationSeconds,
    required this.pauseCount,
  });

  final String transcript;
  final List<RoleplayIssue> issues;
  final String improvedPassage;

  /// `data.feedback` — the web's own fallback when absent/empty is the
  /// literal string `"Good job practicing!"` (`roleplay.html:732`,
  /// `data.feedback || "Good job practicing!"`); reproduced verbatim by the
  /// presentation layer, not baked into this entity, so a `null` here
  /// always means "the server sent no feedback string".
  final String? feedback;

  /// `data.quick_tip` — real API data (same field `SpeakingAgent.run`
  /// always populates for `analyze_speaking` too), but unlike
  /// `SpeakingAnalysisResult` this is genuinely parsed and shown: the real
  /// `roleplay.html` never computes a client-side substitute quick tip the
  /// way `speaking.js` does, it simply never displays this field at all.
  /// Showing it here surfaces real, non-fabricated server data the web
  /// itself just happens to omit from its own UI.
  final String? quickTip;

  final Map<String, num> scores;
  final double durationSeconds;
  final int pauseCount;
}
