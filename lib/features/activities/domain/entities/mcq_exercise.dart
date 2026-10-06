import '../../../../core/utils/exercise_hero_meta.dart';
import 'mcq_question.dart';

/// Deliberately carries no `instructions` field — `exercise.instructions`
/// is never rendered anywhere on the web's `exercise.html` page, for any
/// exercise type (confirmed by grep) — same reasoning as
/// `MatchingExercise`/`BingoExercise`/`FillBlankExercise`.
class McqExercise {
  const McqExercise({required this.id, required this.title, required this.questions, this.heroMeta});

  final int id;
  final String title;
  final List<McqQuestion> questions;

  /// `ExerciseHero`'s activity/sub-activity breadcrumb titles and
  /// `Activity.color_class`, read from the same HTML page — `null` when
  /// that page's markup wasn't found (see `ExerciseHeroMeta`'s doc
  /// comment). Same reasoning as `MatchingExercise.heroMeta`.
  final ExerciseHeroMeta? heroMeta;
}
