import '../../../../core/utils/exercise_hero_meta.dart';
import 'matching_pair.dart';

/// A Matching exercise's question content, extracted from the same
/// server-rendered `exercise_detail` HTML page a browser reads (see
/// `MatchingExerciseRemoteDataSource`) — there is no JSON API for this
/// `exercise_type` (see `docs/EXERCISE_FEASIBILITY_AUDIT.md` §W008).
///
/// Deliberately carries no `instructions` field: `exercise.instructions`
/// is never rendered anywhere on the web's `exercise.html` page, for any
/// exercise type (confirmed by grep) — this is not an omission.
class MatchingExercise {
  const MatchingExercise({
    required this.id,
    required this.title,
    required this.order,
    required this.pairs,
    this.heroMeta,
  });

  final int id;
  final String title;
  final int order;
  final List<MatchingPair> pairs;

  /// `ExerciseHero`'s activity/sub-activity breadcrumb titles and
  /// `Activity.color_class`, read from the same HTML page — `null` when
  /// that page's markup wasn't found (see `ExerciseHeroMeta`'s doc
  /// comment).
  final ExerciseHeroMeta? heroMeta;
}
