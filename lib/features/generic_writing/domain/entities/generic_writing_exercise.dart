import '../../../../core/utils/exercise_hero_meta.dart';
import '../services/writing_limits.dart';
import 'writing_prompt.dart';

/// A Generic Writing exercise's full prompt set, extracted from the same
/// server-rendered `exercise_detail` HTML page a browser reads (the
/// `questions-data` script tag, `questions_json` —
/// `activities/views.py:1389-1403`) — there is no JSON API for this
/// `exercise_type` (same as Matching/W008, Bingo/W009, and Fill in the
/// Blank/W010).
///
/// **Not** the AI Writing module (`ai_writing` feature) — that is a
/// separate, server-AI-driven single-prompt screen reached only for
/// Activities whose *title* matches `isWritingModuleActivity`
/// (`"writing" in title and "professional" in title`,
/// `activities/views.py:34-35`). This entity is for `Exercise.exercise_type
/// == 'writing'` rows under ordinary (non-module) Activities — e.g. the
/// real seed exercise "Negotiation Outcome Reflection"
/// (`populate_activities.py:135-142`) — which render through the generic
/// `exercise.html` "Writing Submission" branch
/// (`templates/activities/exercise.html:295-320`), not a module template.
class GenericWritingExercise {
  const GenericWritingExercise({
    required this.id,
    required this.title,
    required this.order,
    required this.prompts,
    this.heroMeta,
  });

  final int id;
  final String title;
  final int order;
  final List<WritingPrompt> prompts;

  /// `ExerciseHero`'s activity/sub-activity breadcrumb titles and
  /// `Activity.color_class`, read from the same HTML page — `null` when
  /// that page's markup wasn't found.
  final ExerciseHeroMeta? heroMeta;

  /// The word-count range this prompt must satisfy — depends on this
  /// exercise's own [title] and the prompt's [WritingPrompt.guide] text,
  /// exactly mirroring `getWritingLimits()`'s two inputs
  /// (`static/js/exercises.js:670-729`).
  WritingLimits limitsFor(WritingPrompt prompt) =>
      getWritingLimits(exerciseTitle: title, questionText: prompt.questionText, guide: prompt.guide);
}
