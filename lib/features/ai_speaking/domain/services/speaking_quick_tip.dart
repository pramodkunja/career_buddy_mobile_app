import '../entities/speaking_issue.dart';

/// Ports `getDynamicQuickTip()` (`static/activities/js/speaking.js:660-732`)
/// verbatim (English branch only — see `AiSpeakingScreen`'s doc comment for
/// why the 4-language cosmetic overlay isn't reproduced). The web computes
/// this **client-side** and displays it instead of the server's own
/// `data.quick_tip` field, which the web's JS never reads at all — this is
/// the actual displayed behavior, confirmed directly, not an oversight to
/// "fix" by using the simpler server field.
int _clampScore(num? value, int fallback) {
  if (value == null) return fallback;
  return value.round().clamp(0, 100);
}

String computeSpeakingQuickTip({
  required String transcript,
  required List<SpeakingIssue> issues,
  required Map<String, num> scores,
  required int elapsedSeconds,
  required int pauseCount,
}) {
  final words = RegExp(r"[A-Za-z']+").allMatches(transcript).length;
  final minutes = (elapsedSeconds / 60).clamp(0.1, double.infinity);
  final wordsPerMinute = words / minutes;

  if (issues.isNotEmpty) {
    final topIssue = issues.first;
    if (topIssue.type.isNotEmpty && topIssue.suggestion.isNotEmpty) {
      return '${topIssue.type}: ${topIssue.suggestion}';
    }
  }

  final fluency = _clampScore(scores['fluency'], 70);
  final pronunciation = _clampScore(scores['pronunciation'], 70);
  final confidence = _clampScore(scores['confidence'], 70);

  if (wordsPerMinute > 175) {
    return 'You are speaking too fast. Slow down slightly and finish each sentence clearly.';
  }
  if (wordsPerMinute > 0 && wordsPerMinute < 90) {
    return 'Your pace is a bit slow. Keep a steady rhythm and connect ideas in short sentences.';
  }
  if (pauseCount >= 3 || fluency < 70) {
    return 'Reduce long pauses. Take one short breath and continue your thought confidently.';
  }
  if (pronunciation < 75) {
    return 'Focus on pronunciation: stress key words and open your mouth more on vowel sounds.';
  }
  if (confidence < 75) {
    return 'Improve confidence by using a stronger voice and ending sentences without trailing off.';
  }
  return 'Good delivery. Next step: add clearer sentence structure and stronger keyword emphasis.';
}
