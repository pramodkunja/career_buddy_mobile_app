import 'package:flutter/widgets.dart' show IconData;

/// One `<a class="hl">` card from the real page's "Featured" section
/// (`#section-highlights`) — the 3 fastest-path shortcuts into the
/// catalog, shown on the Home tab.
class FeaturedHighlight {
  const FeaturedHighlight({
    required this.icon,
    required this.title,
    required this.description,
    required this.relativePath,
    required this.displayTitle,
  });

  final IconData icon;
  final String title;
  final String description;

  /// Relative to `static/001 Career Buddy/` — see
  /// `SkillUpLesson.relativePath`'s doc comment.
  final String relativePath;

  /// The real link's `title=` query param (decoded).
  final String displayTitle;
}
