import 'package:flutter/material.dart';

import '../../app/theme/activity_hero_colors.dart';

export '../../core/utils/exercise_hero_meta.dart' show ExerciseHeroMeta, extractExerciseHeroMeta;

/// Per-`exercise_type` icon + translucent tint for [ExerciseHero]'s badge —
/// `templates/activities/exercise.html:88-95`'s icon choice (`fa-list-ul`/
/// `fa-pen-to-square`/`fa-link`/`fa-th`/`fa-file-alt`) paired with
/// `.exercise-icon-{type}`'s own `rgba(<color>, .3)` tint
/// (`style.css:1985-2005`) — a different color per type, independent of
/// the hero's own background gradient. Only the 5 types this app actually
/// implements a working screen for are covered.
(IconData, Color) exerciseHeroIconFor(String exerciseType) {
  return switch (exerciseType) {
    'mcq' => (Icons.format_list_bulleted, const Color(0x4D2563EB)), // rgba(37,99,235,.3)
    'fill_blank' => (Icons.edit_note, const Color(0x4D10B981)), // rgba(16,185,129,.3)
    'matching' => (Icons.link, const Color(0x4D8B5CF6)), // rgba(139,92,246,.3)
    'bingo' => (Icons.grid_on, const Color(0x4DEC4899)), // rgba(236,72,153,.3)
    'writing' => (Icons.description_outlined, const Color(0x4D06B6D4)), // rgba(6,182,212,.3)
    _ => (Icons.extension_outlined, const Color(0x4D64748B)),
  };
}

/// `.exercise-hero` (`static/css/style.css:1968-2007`,
/// `templates/activities/exercise.html:14-103`) — the generic-exercise
/// header shared by MCQ/Matching/Bingo/Fill-in-the-Blank/Generic-Writing.
/// Structurally distinct from [ModuleHero] (the AI modules' own header):
/// breadcrumb sits *above* the icon+title here, and there is no badge pill
/// or subtitle paragraph — reproduced as its own component rather than a
/// shared one, per the two components' real markup differences.
///
/// [heroColorSlug] is `Activity.color_class` (`bg-{{ activity.color_class
/// }}`, exercise.html:14) — the exact value the web renders. Only
/// available when the exercise was fetched via raw HTML extraction
/// (Matching/Bingo/Fill-Blank/Generic-Writing all read the same
/// `exercise_detail` page already, so the class name is free to read from
/// it); MCQ's own dedicated JSON API doesn't serialize this field at all
/// (see `docs/UI_PARITY_MASTER_AUDIT.md` §3.3's Batch 2 finding), so its
/// caller always passes `null` here — never fabricated.
class ExerciseHero extends StatelessWidget {
  const ExerciseHero({
    required this.activityTitle,
    required this.subActivityTitle,
    required this.exerciseTitle,
    required this.exerciseTypeDisplay,
    required this.icon,
    required this.iconTint,
    this.heroColorSlug,
    super.key,
  });

  /// Breadcrumb segment 1 — `activity.title|truncatechars:25`.
  final String activityTitle;

  /// Breadcrumb segment 2 — `sub.title|truncatechars:25`.
  final String subActivityTitle;

  /// `exercise.title` — the large white heading.
  final String exerciseTitle;

  /// `exercise.get_exercise_type_display()` — the small label above the
  /// title (e.g. "Multiple Choice", "Matching").
  final String exerciseTypeDisplay;

  /// The exercise-type icon (`.exercise-hero-icon`'s `<i>`, e.g.
  /// `fa-list-ul` for mcq) — chosen per exercise type by the caller.
  final IconData icon;

  /// `.exercise-icon-{type}`'s translucent tint
  /// (`rgba(<color>, .3)`, `style.css:1985-2005`) — the icon badge's own
  /// background, independent of [heroColorSlug].
  final Color iconTint;

  final String? heroColorSlug;

  static const _breadcrumbActive = Color(0x80FFFFFF); // rgba(255,255,255,.5)
  static const _breadcrumbLink = Color(0xB3FFFFFF); // rgba(255,255,255,.7)
  static const _breadcrumbSeparator = Color(0x66FFFFFF); // rgba(255,255,255,.4)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (start, end) = resolveActivityHeroGradient(heroColorSlug) ?? kDefaultActivityHeroGradient;

    return Container(
      width: double.infinity,
      // `.exercise-hero{padding-top:80px}` (`style.css:1968-1970`) is
      // meant for a fixed desktop navbar this app's own `AppBar` already
      // occupies — reproduced here as the hero's own top/bottom padding
      // instead, since there's no second nav bar to clear.
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [start, end], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `.breadcrumb-light` (`style.css:1571-1581`).
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(activityTitle, style: theme.textTheme.bodySmall?.copyWith(color: _breadcrumbLink)),
              const Text(' / ', style: TextStyle(color: _breadcrumbSeparator, fontSize: 12)),
              Text(subActivityTitle, style: theme.textTheme.bodySmall?.copyWith(color: _breadcrumbLink)),
              const Text(' / ', style: TextStyle(color: _breadcrumbSeparator, fontSize: 12)),
              Text('Exercise', style: theme.textTheme.bodySmall?.copyWith(color: _breadcrumbActive)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // `.exercise-hero-icon` — 56×56, `--radius-sm` (8px),
              // `style.css:1972-1982`.
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconTint, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseTypeDisplay,
                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0x80FFFFFF)), // text-white-50
                    ),
                    Text(
                      exerciseTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
