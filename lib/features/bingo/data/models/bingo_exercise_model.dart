import 'dart:convert';

import '../../../../core/utils/exercise_hero_meta.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/entities/bingo_exercise.dart';

/// Extracts and JSON-decodes the contents of
/// `<script type="application/json" id="$elementId">...</script>` from a
/// raw HTML document. Same small extraction technique as
/// `matching_exercise_model.dart`'s `extractEmbeddedJsonList` and
/// `ai_listening`'s `extractEmbeddedJsonConfig` — kept as its own local
/// copy rather than a shared cross-feature import, consistent with how
/// this codebase already keeps each exercise-type feature self-contained.
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

/// Parses the `bingo-data` script tag's decoded JSON array
/// (`[{"word": ..., "definition": ...}, ...]`,
/// `activities/views.py:1404-1406`) into a [BingoExercise]'s cards, in
/// their original order — the same order `bingo_cards.all()` and the
/// on-page `#bingo-board` iterate.
extension BingoExerciseParsing on BingoExercise {
  static BingoExercise fromBingoJson({
    required int exerciseId,
    required String title,
    required int order,
    required List<dynamic> bingoJson,
    ExerciseHeroMeta? heroMeta,
  }) {
    final cards = <BingoCard>[];
    for (final entry in bingoJson) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final word = map['word'];
      final definition = map['definition'];
      if (word is! String || word.isEmpty) continue;
      cards.add(BingoCard(word: word, definition: definition is String ? definition : ''));
    }
    return BingoExercise(id: exerciseId, title: title, order: order, cards: cards, heroMeta: heroMeta);
  }
}
