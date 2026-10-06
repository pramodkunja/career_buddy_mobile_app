import 'dart:convert';

import '../../../../core/utils/exercise_hero_meta.dart';
import '../../domain/entities/matching_exercise.dart';
import '../../domain/entities/matching_pair.dart';

/// Extracts and JSON-decodes the contents of
/// `<script type="application/json" id="$elementId">...</script>` from a
/// raw HTML document. Same technique as `ai_listening`'s
/// `extractEmbeddedJsonConfig`, kept as a separate small function here
/// (rather than a shared import across features) because the shape read
/// out is a JSON **array** (`questions_json`,
/// `activities/views.py:1389-1403`), not the object
/// `extractEmbeddedJsonConfig` assumes.
List<dynamic>? extractEmbeddedJsonList(String html, String elementId) {
  final pattern = RegExp('<script[^>]*id=["\']${RegExp.escape(elementId)}["\'][^>]*>(.*?)</script>', dotAll: true);
  final match = pattern.firstMatch(html);
  if (match == null) return null;
  final raw = match.group(1)?.trim();
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// Parses the `questions-data` script tag's decoded JSON array into a
/// [MatchingExercise]'s pairs.
///
/// Each array entry has the shape `{id, text, type, options, correct,
/// explanation, left, right}` (`activities/views.py:1389-1403`) — `id` is
/// the database `Question.id` and is **not used for pairing**; a pair's
/// [MatchingPair.position] is its 1-based index within this array, matching
/// the web's own `data-id="{{ forloop.counter }}"` (see
/// `MatchingPair`'s doc comment). `left`/`right` fall back to
/// `text`/`correct` respectively when blank, mirroring the template's own
/// `question.left_item|default:question.question_text` /
/// `question.right_item|default:question.correct_answer`
/// (`templates/activities/exercise.html:222,234`).
extension MatchingExerciseParsing on MatchingExercise {
  static MatchingExercise fromQuestionsJson({
    required int exerciseId,
    required String title,
    required int order,
    required List<dynamic> questionsJson,
    ExerciseHeroMeta? heroMeta,
  }) {
    final pairs = <MatchingPair>[];
    for (var i = 0; i < questionsJson.length; i++) {
      final entry = questionsJson[i];
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final leftText = _stringOrDefault(map['left'], _stringOrDefault(map['text'], ''));
      final rightText = _stringOrDefault(map['right'], _stringOrDefault(map['correct'], ''));
      pairs.add(MatchingPair(position: i + 1, leftText: leftText, rightText: rightText));
    }
    return MatchingExercise(id: exerciseId, title: title, order: order, pairs: pairs, heroMeta: heroMeta);
  }

  // Matches Django's `|default` filter, which falls back on any falsy
  // value — an empty string, not a trimmed/whitespace-only one — so this
  // intentionally does not `.trim()` before checking.
  static String _stringOrDefault(Object? value, String fallback) {
    if (value is String && value.isNotEmpty) return value;
    return fallback;
  }
}
