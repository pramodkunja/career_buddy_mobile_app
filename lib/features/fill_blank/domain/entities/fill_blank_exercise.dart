import '../../../../core/utils/exercise_hero_meta.dart';
import 'fill_blank_question.dart';

/// A Fill in the Blank exercise's full question set, extracted from the
/// same server-rendered `exercise_detail` HTML page a browser reads (the
/// `questions-data` script tag, `questions_json` —
/// `activities/views.py:1389-1403`) — there is no JSON API for this
/// `exercise_type` (same as Matching/W008 and Bingo/W009).
///
/// Deliberately carries no `instructions` field: `exercise.instructions`
/// is never rendered anywhere on the web's `exercise.html` page, for any
/// exercise type.
class FillBlankExercise {
  const FillBlankExercise({
    required this.id,
    required this.title,
    required this.order,
    required this.questions,
    this.heroMeta,
  });

  final int id;
  final String title;
  final int order;
  final List<FillBlankQuestion> questions;

  /// `ExerciseHero`'s activity/sub-activity breadcrumb titles and
  /// `Activity.color_class`, read from the same HTML page — `null` when
  /// that page's markup wasn't found.
  final ExerciseHeroMeta? heroMeta;
}
