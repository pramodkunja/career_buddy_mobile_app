import 'package:flutter/widgets.dart' show IconData;

import 'skill_up_subsection.dart';

/// One of the 3 major "Sections in depth" `<article class="sec">` blocks
/// (English & Vocabulary / Aptitude & Reasoning / Tech Center) — the same
/// 3 sections the Sitemap tab's `<article class="cat">` tree mirrors.
class SkillUpSection {
  const SkillUpSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.tag,
    required this.depthDescription,
    required this.sitemapDescription,
    required this.subsections,
  });

  /// `depth-english` / `depth-aptitude` / `depth-tech` anchor id on the
  /// real page.
  final String id;

  final IconData icon;
  final String title;

  /// `<span class="tag">`, e.g. "Language", "Assessment", "Engineering".
  final String tag;

  /// The `<p>` under this section's `<h2>` in "Sections in depth"
  /// (`.sec-head`).
  final String depthDescription;

  /// The `<p class="cat-desc">` under this same section's Sitemap tree
  /// entry — near-identical wording to [depthDescription] but not
  /// byte-identical on the real page (e.g. "10-step" vs "ten-step",
  /// "vocabulary lexicons" vs "workplace vocabulary lexicons`); both are
  /// reproduced verbatim rather than merged into one string.
  final String sitemapDescription;

  final List<SkillUpSubsection> subsections;
}
