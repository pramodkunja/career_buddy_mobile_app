/// One lesson/course card.
///
/// Mirrors a real `<a class="card">` inside a "Sections in depth"
/// `<div class="sub">` group, and the equivalent `<li><a>` inside the
/// Sitemap tab's `<ul class="lvl3">` tree — both point at the exact same
/// `#load=<relativePath>&title=<displayTitle>` target in the real
/// `static/001 Career Buddy/index.html`, just rendered as a card in one
/// tab and a plain link in the other.
class SkillUpLesson {
  const SkillUpLesson({
    required this.chip,
    required this.title,
    required this.description,
    required this.relativePath,
    required this.displayTitle,
    this.chipIsAlt = false,
  });

  /// The small badge text (`<span class="chip">`), e.g. "A1", "Coach",
  /// "50 questions".
  final String chip;

  /// True for the `chip alt` visual variant the real page uses on
  /// reference/hub/index-style cards (e.g. "Reference", "Hub", "Guide").
  final bool chipIsAlt;

  /// The card's `<h4>` title.
  final String title;

  /// The card's `<p>` description.
  final String description;

  /// Relative to `static/001 Career Buddy/` on the Django backend, exactly
  /// as it appears (with real spaces/parentheses, not pre-encoded) in the
  /// real page's `#load=` href — see `buildSkillUpLessonUrl`.
  final String relativePath;

  /// The lesson's real title, read from the same link's `title=` query
  /// param (decoded) / the Sitemap tree's own link text for this lesson.
  final String displayTitle;
}
