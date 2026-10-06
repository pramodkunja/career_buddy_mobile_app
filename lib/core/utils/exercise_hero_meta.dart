/// The 3 pieces of `ExerciseHero` data that live in the raw
/// `exercise_detail` HTML page (`templates/activities/exercise.html:14-25`)
/// alongside the `questions-data` script tag Matching/Bingo/Fill-Blank/
/// Generic-Writing already parse from that same fetch. `null` fields mean
/// the corresponding markup wasn't found (e.g. a locked-activity redirect
/// page has none of this) — never guessed.
///
/// A plain data class (no Flutter dependency) so domain entities across
/// those 4 features can hold one without a domain→presentation import.
class ExerciseHeroMeta {
  const ExerciseHeroMeta({this.activityTitle, this.subActivityTitle, this.colorSlug});

  final String? activityTitle;
  final String? subActivityTitle;

  /// `Activity.color_class` — resolved to an actual gradient by
  /// `resolveActivityHeroGradient` (`lib/app/theme/activity_hero_colors.dart`).
  final String? colorSlug;
}

final _colorSlugPattern = RegExp('class="exercise-hero bg-([\\w-]+)"');
final _breadcrumbItemPattern = RegExp('<li class="breadcrumb-item"><a[^>]*>(.*?)</a></li>', dotAll: true);

String _unescapeHtmlEntities(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"');
}

/// Extracts [ExerciseHeroMeta] from the raw `exercise_detail` HTML —
/// `exercise.html:14` for the `bg-{{ activity.color_class }}` class, and
/// `:80-83` for the two breadcrumb `<a>` links (`activity.title`/
/// `sub.title`, each already `|truncatechars:25` server-side).
ExerciseHeroMeta extractExerciseHeroMeta(String html) {
  final colorSlug = _colorSlugPattern.firstMatch(html)?.group(1);
  final breadcrumbTitles = _breadcrumbItemPattern
      .allMatches(html)
      .map((m) => _unescapeHtmlEntities(m.group(1)!.trim()))
      .toList();
  return ExerciseHeroMeta(
    activityTitle: breadcrumbTitles.isNotEmpty ? breadcrumbTitles[0] : null,
    subActivityTitle: breadcrumbTitles.length > 1 ? breadcrumbTitles[1] : null,
    colorSlug: colorSlug,
  );
}
