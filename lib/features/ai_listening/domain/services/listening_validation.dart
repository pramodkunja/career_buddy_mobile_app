/// Ports `lv.hasMeaningfulText()` verbatim
/// (`static/activities/js/linguavoice-common.js:60-64`) — the client-side
/// gate `analyzeText()` checks before submitting. The server independently
/// enforces its own, much lower bar (`has_meaningful_speech`, >=2
/// alphabetic words — `activities/agents/utils.py:217-220`), so this is a
/// real UX convenience backed by (a looser) server authority, not an
/// invented rule.
bool hasMeaningfulText(String text, {int minWords = 4, int minLetters = 12}) {
  final words = RegExp(r"[A-Za-z']+").allMatches(text).map((m) => m.group(0)!).toList();
  final letters = words.fold<int>(0, (sum, w) => sum + w.length);
  return words.length >= minWords && letters >= minLetters;
}
