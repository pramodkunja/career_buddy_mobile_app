import 'reading_issue.dart';

/// The server-authoritative response to `analyze_reading`
/// (`activities/views.py:1916-1969`). [score25] is duplicated at **both**
/// the top level and inside `data` (`result['score_25'] = score_25` *and*
/// `data['score_25'] = score_25`) — confirmed the same placement as
/// `analyzeSpeaking`, unlike `analyzeWriting` (top-level only) or
/// `analyzeListening` (nested only). Parsed from `data` here, the same
/// convention `SpeakingAnalysisResult` already uses.
///
/// [text] is the **reference passage** (with mistakes highlighted against
/// it), not the user's spoken transcript — confirmed directly from
/// `ReadingAgent.run()`'s own comment and return value
/// (`"text": reference_text or text`). The actual transcript is returned
/// separately as `user_transcript`, which the web's own JS never reads —
/// deliberately not parsed here either, the same "don't parse a dead
/// field" precedent as Speaking's unused `quick_tip`.
///
/// Unlike Speaking/Listening, [feedback] and [quickTip] **are** displayed
/// directly from the server here — confirmed by reading `analyzeReading()`
/// line by line (`result.feedback`/`result.quick_tip` used verbatim, no
/// client-side banding function like Listening's).
class ReadingAnalysisResult {
  const ReadingAnalysisResult({
    required this.text,
    required this.issues,
    required this.improvedPassage,
    required this.feedback,
    required this.quickTip,
    required this.scores,
    required this.score25,
  });

  final String text;
  final List<ReadingIssue> issues;
  final String improvedPassage;
  final String feedback;
  final String quickTip;
  final Map<String, num> scores;

  /// Out of 25 — the only score the web itself displays.
  final int score25;
}
