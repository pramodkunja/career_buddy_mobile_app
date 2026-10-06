import '../../../../core/utils/exercise_hero_meta.dart';
import '../../../matching/data/models/matching_exercise_model.dart' show extractEmbeddedJsonList;
import '../../domain/entities/mcq_exercise.dart';
import '../../domain/entities/mcq_question.dart';

/// Parses the `questions-data` script tag's decoded JSON array (the same
/// one `MatchingExerciseParsing.fromQuestionsJson` reads — see that
/// extension's doc comment for the shape: `{id, text, type, options,
/// correct, explanation}`, `activities/views.py:1389-1403`) into an
/// [McqExercise]. Unlike Matching, `id` here **is** used (`McqQuestion.id`
/// is the real DB `Question.id`, matching `McqExerciseController`'s
/// `selectedAnswers` map, which is keyed by it) — MCQ has no pairing
/// concept that would make position-based identity preferable.
extension McqExerciseParsing on McqExercise {
  static McqExercise fromQuestionsJson({
    required int exerciseId,
    required String title,
    required List<dynamic> questionsJson,
    ExerciseHeroMeta? heroMeta,
  }) {
    final questions = <McqQuestion>[];
    for (final entry in questionsJson) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final rawOptions = map['options'];
      final options = rawOptions is Map
          ? rawOptions.cast<String, dynamic>().map((key, value) => MapEntry(key, value?.toString() ?? ''))
          : <String, String>{};
      // A blank option letter means the backend didn't populate it for
      // this question (e.g. only 2 of 4 used) — dropped rather than shown
      // as an empty tappable option, same reasoning `McqQuestion.options`'
      // own doc comment already documents.
      options.removeWhere((_, value) => value.isEmpty);

      final idValue = map['id'];
      final id = idValue is int ? idValue : int.tryParse(idValue?.toString() ?? '');
      final correct = map['correct']?.toString() ?? '';
      if (id == null || correct.isEmpty || options.isEmpty) continue;

      questions.add(
        McqQuestion(
          id: id,
          questionText: map['text']?.toString() ?? '',
          options: options,
          correctAnswer: correct,
          explanation: (map['explanation']?.toString().trim().isNotEmpty ?? false) ? map['explanation'].toString() : null,
        ),
      );
    }
    return McqExercise(id: exerciseId, title: title, questions: questions, heroMeta: heroMeta);
  }
}

/// Re-exported so callers only need this one file's import, matching the
/// one-stop-shop convenience `matching_exercise_model.dart` already
/// provides for its own feature.
List<dynamic>? extractMcqQuestionsJson(String html) => extractEmbeddedJsonList(html, 'questions-data');
