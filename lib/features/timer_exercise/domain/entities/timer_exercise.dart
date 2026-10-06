import '../../../../core/utils/exercise_hero_meta.dart';
import 'timer_task.dart';

/// A Timer ("Timed Activity") exercise's full task set, extracted from the
/// same server-rendered `exercise_detail` HTML page a browser reads (the
/// `questions-data` script tag, `questions_json` —
/// `activities/views.py:1389-1403`) — there is no JSON API for this
/// `exercise_type` (same as Matching/W008, Bingo/W009, Fill in the
/// Blank/W010, and Generic Writing/W013). One task = one `<div
/// class="timer-task-card">` on the web
/// (`templates/activities/exercise.html:348-364`); `TOTAL_QUESTIONS` is
/// this list's length.
class TimerExercise {
  const TimerExercise({required this.id, required this.title, required this.order, required this.tasks, this.heroMeta});

  final int id;
  final String title;
  final int order;
  final List<TimerTask> tasks;

  /// `ExerciseHero`'s activity/sub-activity breadcrumb titles and
  /// `Activity.color_class`, read from the same HTML page — `null` when
  /// that page's markup wasn't found.
  final ExerciseHeroMeta? heroMeta;
}
