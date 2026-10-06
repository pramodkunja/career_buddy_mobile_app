/// A prompt's required word range. [max] is `null` when the web has no
/// upper bound (`DEFAULT_MAX_WORDS = null`,
/// `static/js/exercises.js:656`).
class WritingLimits {
  const WritingLimits({required this.min, this.max});

  final int min;
  final int? max;
}

const _kDefaultMinWords = 50;

final _kRangePattern = RegExp(r'(\d+)\s*(?:[-–—]|to)\s*(\d+)\s*words', caseSensitive: false);
final _kSinglePattern = RegExp(r'(\d+)\s*words', caseSensitive: false);

/// Ports `getWritingLimits()` verbatim (`static/js/exercises.js:670-729`).
///
/// Checked in order:
/// 1. The exercise's own title is exactly "proposal section writing", or
///    the prompt's question text contains "proposal section" (both
///    case-insensitive) — a hardcoded 150-200 word range
///    (`static/js/exercises.js:684-692`).
/// 2. [guide] contains an explicit range ("80-120 words" / "80–120 words"
///    / "80 to 120 words") — that exact range.
/// 3. [guide] contains a single count ("150 words") — that count as the
///    minimum, no maximum.
/// 4. Otherwise the default: minimum 50 words, no maximum
///    (`DEFAULT_MIN_WORDS`/`DEFAULT_MAX_WORDS`,
///    `static/js/exercises.js:655-656`).
WritingLimits getWritingLimits({required String exerciseTitle, required String questionText, String? guide}) {
  final titleLower = exerciseTitle.trim().toLowerCase();
  final questionLower = questionText.trim().toLowerCase();
  if (titleLower == 'proposal section writing' || questionLower.contains('proposal section')) {
    return const WritingLimits(min: 150, max: 200);
  }

  final guideText = guide ?? '';
  final range = _kRangePattern.firstMatch(guideText);
  if (range != null) {
    return WritingLimits(min: int.parse(range.group(1)!), max: int.parse(range.group(2)!));
  }

  final single = _kSinglePattern.firstMatch(guideText);
  if (single != null) {
    return WritingLimits(min: int.parse(single.group(1)!));
  }

  return const WritingLimits(min: _kDefaultMinWords);
}
