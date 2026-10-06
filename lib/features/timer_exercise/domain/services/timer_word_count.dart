/// Ports `countWords()` verbatim (`static/js/exercises.js:1176-1178`, the
/// `initTimer()`-local copy — same body as the top-level `countWords()`
/// Generic Writing's `countWritingWords` already ports):
/// `text.trim() ? text.trim().split(/\s+/).filter(Boolean).length : 0`.
///
/// A run of any whitespace (spaces, tabs, newlines) separates words; an
/// empty or whitespace-only string counts as 0.
int countTimerWords(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
}
