/// Ports `countWords()` verbatim (`static/js/exercises.js:658-661`):
/// `text.trim() ? text.trim().split(/\s+/).filter(Boolean).length : 0`.
///
/// A run of any whitespace (spaces, tabs, newlines) separates words; an
/// empty or whitespace-only string counts as 0. Punctuation is never
/// stripped — `"well-known,"` or `"hello!"` each count as one word, exactly
/// as the web's own `\s+` split does.
int countWritingWords(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
}
