import '../entities/listening_issue.dart';

/// Ports `buildListeningFeedback()`/`buildListeningQuickTip()` verbatim
/// (English branch only — `static/activities/js/listening.js:338-395`).
///
/// A genuinely distinct pattern from both Speaking (server `quick_tip`
/// fetched but never shown) and Writing (server `quick_tip` shown
/// verbatim): Listening's **feedback and quick tip are both client-side
/// banding functions driven by the server's authoritative
/// `content_match_percent`**, not the server's raw `feedback`/`quick_tip`
/// strings — confirmed by reading `analyzeText()` line by line. The
/// server's `feedback` field is used only as the lowest-band fallback
/// (`match < 20`), via [fallbackFeedback]; the server's `quick_tip` is
/// never read at all (`buildListeningQuickTip` always returns non-empty).
String buildListeningFeedback({
  required int matchPercent,
  required List<ListeningIssue> issues,
  required String fallbackFeedback,
}) {
  final issueCount = issues.length;
  if (matchPercent >= 100) {
    return 'Excellent listening. Your response captures the story completely and stays accurate to the original audio.';
  }
  if (matchPercent >= 90) {
    final spot = issueCount == 1 ? '' : 's';
    final suffix = issueCount > 0 ? ' across $issueCount highlighted spot$spot' : '';
    return 'Very strong listening. Your answer stays very close to the story, with only small gaps or language mistakes$suffix.';
  }
  if (matchPercent >= 80) {
    return 'Good listening. You understood most of the story and captured the main events, but a few details still need tightening.';
  }
  if (matchPercent >= 60) {
    return 'Decent listening. Your answer relates to the story, but some important details are missing or mixed up.';
  }
  if (matchPercent >= 50) {
    return 'Partial understanding. You caught the general topic, but the summary needs more correct story details.';
  }
  if (matchPercent >= 20) {
    return 'Limited match with the story. Focus on the main characters, the central event, and the final outcome.';
  }
  return fallbackFeedback.isNotEmpty
      ? fallbackFeedback
      : 'Your response is not closely related to the story yet. Listen again and retell only the events from the audio.';
}

String buildListeningQuickTip({required int matchPercent, required List<ListeningIssue> issues}) {
  if (issues.isNotEmpty && issues.first.suggestion.isNotEmpty) {
    return 'Fix this first: ${issues.first.suggestion}';
  }
  if (matchPercent >= 90) {
    return 'Strong match. Next, tighten grammar and punctuation so your summary sounds polished.';
  }
  if (matchPercent >= 60) {
    return 'Keep the same story order: who, what happened, what changed, and how it ended.';
  }
  return 'Listen for the main person, the problem, and the ending before you start writing.';
}
