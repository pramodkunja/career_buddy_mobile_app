import 'writing_limits.dart';
import 'writing_word_count.dart';

/// One prompt's answer, as needed by [computeGenericWritingClientScore].
class WritingScoreInput {
  const WritingScoreInput({required this.text, required this.questionText, this.guide});

  /// The raw textarea value (trimmed internally, same as `ta.value.trim()`
  /// in `static/js/exercises.js:847`).
  final String text;
  final String questionText;
  final String? guide;
}

final _reqRecommendationsPattern = RegExp(r'(\d+)\s+(?:actionable\s+)?recommendations', caseSensitive: false);
final _reqExamplesPattern = RegExp(r'(\d+)\s+examples', caseSensitive: false);
final _listItemPattern = RegExp(r'^\s*[\d\-*•][.)]\s+', multiLine: true);
final _keywordStartPattern = RegExp(
  r'(?:^|\.)\s*(?:we\s+recommend|firstly|secondly|thirdly|finally|for\s+example|example\s+\d)',
  caseSensitive: false,
);
final _dataPointPattern = RegExp(r'\d+(?:\.\d+)?%?|\$\d+(?:\.\d+)?[MK]?');
final _sentenceSplitPattern = RegExp(r'[.!?]+');
final _structureKeywordPattern = RegExp('recommend|should|suggest', caseSensitive: false);

/// Ports `initWriting()`'s client-side scoring heuristic verbatim
/// (`static/js/exercises.js:813-1107`) — the score this app must submit as
/// `score` (with `max_score: 100`) so the backend behaves identically to
/// the web's own submission: when `SARVAM_API_KEY` is unset,
/// `submit_exercise` trusts this score outright, the AI branch at
/// `activities/views.py:1422` never running; when it *is* set but a single
/// prompt's AI call throws, that prompt's server-side contribution falls
/// back to `score / len(questions)` — an even split of *this* total
/// (`activities/views.py:1484`). This is not a new AI scoring algorithm —
/// it is an exact port of the deterministic heuristic that already ships
/// on the web, per the task's own instruction not to invent one.
///
/// Returns the rounded 0-100 overall score (`Math.round(finalScore)`,
/// `static/js/exercises.js:1106`); `max_score` is always 100, submitted
/// separately by the caller.
int computeGenericWritingClientScore({required String exerciseTitle, required List<WritingScoreInput> answers}) {
  if (answers.isEmpty) return 0;

  var totalScorePercent = 0.0;
  for (final answer in answers) {
    final text = answer.text.trim();
    final words = countWritingWords(text);
    final limits = getWritingLimits(exerciseTitle: exerciseTitle, questionText: answer.questionText, guide: answer.guide);
    final minTarget = limits.min;

    var qScore = 0.0;
    if (words >= minTarget && (limits.max == null || words <= limits.max!)) {
      qScore = 100;
    } else if (words >= minTarget * 0.7) {
      qScore = 80;
    } else if (words >= minTarget * 0.4) {
      qScore = 50;
    } else if (words > 0) {
      qScore = 20;
    }

    final qTextRaw = answer.questionText;
    final qText = qTextRaw.toLowerCase();
    // Penalize copying the question/prompt text back as the answer.
    if (qText.length > 20 && text.toLowerCase().contains(qText)) {
      qScore *= 0.3;
    }

    // A required count of recommendations/examples, if the prompt asks for
    // one — penalize proportionally when fewer than asked for are found.
    final reqMatch = _reqRecommendationsPattern.firstMatch(qTextRaw) ?? _reqExamplesPattern.firstMatch(qTextRaw);
    if (reqMatch != null) {
      final countRequired = int.parse(reqMatch.group(1)!);
      final listItems = _listItemPattern.allMatches(text).length;
      final keywordStarts = _keywordStartPattern.allMatches(text).length;
      final countFound = [listItems, keywordStarts, 1].reduce((a, b) => a > b ? a : b);
      if (countFound < countRequired && words > 0) {
        qScore *= countFound / countRequired;
      }
    }

    // Contextual relevance: numbers/percentages/currency figures mentioned
    // in the prompt that the answer should reference back.
    final dataPoints = _dataPointPattern.allMatches(qTextRaw).map((m) => m.group(0)!).toList();
    if (dataPoints.length >= 2) {
      final foundPoints = dataPoints.where(text.contains).length;
      final relevanceRatio = foundPoints / dataPoints.length;
      if (relevanceRatio < 0.3) {
        qScore *= 0.4;
      } else if (relevanceRatio < 0.6) {
        qScore *= 0.8;
      }
    }

    // Sentence-repetition penalty: duplicate sentences (>25 chars, trimmed
    // + lowercased) cost 20 points each, floored at 0.
    final sentences = text.split(_sentenceSplitPattern).map((s) => s.trim().toLowerCase()).where((s) => s.length > 25).toList();
    final uniqueSentences = sentences.toSet();
    if (sentences.length > uniqueSentences.length) {
      final diff = sentences.length - uniqueSentences.length;
      qScore = (qScore - diff * 20).clamp(0, double.infinity);
    }

    // Structure check — only when the Guide text itself mentions
    // "structure"; checks for purpose/findings/recommendation sub-sections.
    final guideText = answer.guide ?? '';
    if (guideText.toLowerCase().contains('structure')) {
      var structMet = 0;
      var structTotal = 0;
      if (RegExp('purpose', caseSensitive: false).hasMatch(guideText)) {
        structTotal++;
        if (sentences.isNotEmpty) structMet++;
      }
      if (RegExp('findings', caseSensitive: false).hasMatch(guideText)) {
        structTotal++;
        if (sentences.length >= 2) structMet++;
      }
      if (RegExp('recommendation', caseSensitive: false).hasMatch(guideText)) {
        structTotal++;
        if (_structureKeywordPattern.hasMatch(text.toLowerCase())) structMet++;
      }
      if (structTotal > 0 && structMet != structTotal) {
        qScore *= structMet / structTotal;
      }
    }

    totalScorePercent += qScore;
  }

  var finalScore = totalScorePercent / answers.length;

  // Cross-prompt duplication: if two or more substantial (>50 char)
  // responses are identical once trimmed/lowercased, the whole submission
  // is penalized.
  final allResponses = answers.map((a) => a.text.trim().toLowerCase()).where((s) => s.length > 50).toList();
  if (allResponses.length > allResponses.toSet().length) {
    finalScore *= 0.4;
  }

  return finalScore.round();
}
