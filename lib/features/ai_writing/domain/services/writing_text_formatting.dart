/// Ports `formatImprovedText()` verbatim
/// (`static/activities/js/linguavoice-common.js:466-471`): collapses
/// whitespace, ensures the text ends with terminal punctuation, and
/// capitalizes the first letter. Applied to `improved_passage` both for
/// display and for what's remembered as `previousImprovedPassage` on the
/// next submission — the web does the same (`window.lastImprovedPassage`
/// stores the *formatted* text, not the raw server value).
String formatImprovedPassage(
  String? text, {
  String fallbackText = '',
  String emptyText = 'An improved version will appear after analysis.',
}) {
  final cleanText = (text?.isNotEmpty == true ? text! : fallbackText).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleanText.isEmpty) return emptyText;
  final withPunctuation = RegExp(r'[.!?]$').hasMatch(cleanText) ? cleanText : '$cleanText.';
  return withPunctuation[0].toUpperCase() + withPunctuation.substring(1);
}
