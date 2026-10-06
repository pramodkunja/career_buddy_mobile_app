import 'skill_up_lesson.dart';

/// A `<div class="sub">` group inside one "Sections in depth"
/// `<article class="sec">` — the identical grouping also backs the
/// corresponding `<div class="grp">` under the Sitemap tab's tree for the
/// same section (same subsections, same lessons, just a card grid vs. a
/// plain link tree).
class SkillUpSubsection {
  const SkillUpSubsection({required this.title, required this.countLabel, required this.lessons});

  /// The `<h3>` group title, e.g. "CEFR levels (A1 → C2)".
  final String title;

  /// The `<span class="count">` text, e.g. "7 lessons", "1 assessment".
  final String countLabel;

  final List<SkillUpLesson> lessons;
}
