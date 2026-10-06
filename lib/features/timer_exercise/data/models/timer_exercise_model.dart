import 'dart:convert';

import '../../../../core/utils/exercise_hero_meta.dart';
import '../../domain/entities/timer_exercise.dart';
import '../../domain/entities/timer_task.dart';

/// Extracts and JSON-decodes the contents of
/// `<script type="application/json" id="$elementId">...</script>` from a
/// raw HTML document. Same small extraction technique as
/// `matching_exercise_model.dart`/`bingo_exercise_model.dart`/
/// `fill_blank_exercise_model.dart`/`generic_writing_exercise_model.dart`'s
/// own `extractEmbeddedJsonList` — kept as its own local copy rather than a
/// shared cross-feature import, consistent with how this codebase already
/// keeps each exercise-type feature self-contained.
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

/// Parses the `questions-data` script tag's decoded JSON array
/// (`[{id, text, type, options, correct, explanation, left, right}, ...]`,
/// `activities/views.py:1389-1403`) into a [TimerExercise]'s tasks, in their
/// original order — the array is **not sliced**, and a task's
/// [TimerTask.position] is its 1-based index in this array, matching the
/// web's own `TOTAL_QUESTIONS`/`Task {{ forloop.counter }}` numbering. Only
/// `text`/`explanation` are relevant for this exercise type —
/// `options`/`correct`/`left`/`right` are present in the JSON but unused.
extension TimerExerciseParsing on TimerExercise {
  static TimerExercise fromQuestionsJson({
    required int exerciseId,
    required String title,
    required int order,
    required List<dynamic> questionsJson,
    ExerciseHeroMeta? heroMeta,
  }) {
    final tasks = <TimerTask>[];
    for (var i = 0; i < questionsJson.length; i++) {
      final entry = questionsJson[i];
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final text = map['text'];
      if (text is! String || text.isEmpty) continue;
      final explanation = map['explanation'];
      tasks.add(
        TimerTask(
          position: i + 1,
          questionText: text,
          guide: explanation is String && explanation.isNotEmpty ? explanation : null,
        ),
      );
    }
    return TimerExercise(id: exerciseId, title: title, order: order, tasks: tasks, heroMeta: heroMeta);
  }
}
