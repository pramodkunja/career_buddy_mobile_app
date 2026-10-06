import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../certifications/presentation/widgets/certifications_section.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../data/skill_up_data.dart';
import '../../domain/entities/featured_highlight.dart';
import '../../domain/entities/skill_up_lesson.dart';
import '../../domain/entities/skill_up_section.dart';
import '../../domain/entities/skill_up_stat.dart';
import '../../domain/entities/skill_up_subsection.dart';
import '../../domain/skill_up_lesson_url.dart';
import '../skill_up_lesson_route_args.dart';

/// Called with a lesson/highlight's real `relativePath` + `displayTitle`
/// (see `SkillUpLesson`) to open it via `RoutePaths.skillUpLesson`.
typedef _OpenLesson = void Function(String relativePath, String displayTitle);

/// Batch 7 — Skill Up hub (`riya_bot.skillup_views.skillup_hub`,
/// `static/001 Career Buddy/index.html`). The real web page is a single
/// static-HTML document with 4 in-page anchor sections (Home/Featured,
/// Sections in depth, Sitemap, Certifications) navigated via same-page JS,
/// not 4 separate URLs — reproduced here as one screen with 4 tabs so the
/// structure stays faithful while fitting mobile navigation conventions.
///
/// Tab index mapping for router wiring (see `RoutePaths.skillUp`/
/// `RoutePaths.sitemap`'s own doc comments):
///  - `0` — Home (hero + Featured highlights). Default; `RoutePaths.skillUp`.
///  - `1` — Sections in depth (the 3 major sections' full lesson catalog).
///  - `2` — Sitemap (`#section-sitemap` on the web). `RoutePaths.sitemap`
///    should open this screen with `initialTabIndex: 2`.
///  - `3` — Certifications (`#section-certifications` on the web); see
///    `CertificationsSection`.
class SkillUpScreen extends ConsumerStatefulWidget {
  const SkillUpScreen({this.initialTabIndex = 0, super.key});

  /// Which tab is pre-selected. See the class doc comment for the index
  /// mapping.
  final int initialTabIndex;

  @override
  ConsumerState<SkillUpScreen> createState() => _SkillUpScreenState();
}

class _SkillUpScreenState extends ConsumerState<SkillUpScreen> with SingleTickerProviderStateMixin {
  static const _tabCount = 4;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabCount - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToTab(int index) => _tabController.animateTo(index);

  /// Opens a lesson via `context.push` (not `context.go`) so the back
  /// button returns here with this screen's tab state intact — see
  /// `RoutePaths.skillUpLesson`'s doc comment.
  void _openLesson(String relativePath, String displayTitle) {
    context.push(
      RoutePaths.skillUpLesson,
      extra: SkillUpLessonRouteArgs(title: displayTitle, url: buildSkillUpLessonUrl(relativePath)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          Column(
            children: [
              ColoredBox(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.accent,
                  tabs: const [
                    Tab(text: 'Home'),
                    Tab(text: 'Sections in depth'),
                    Tab(text: 'Sitemap'),
                    Tab(text: 'Certifications'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _HomeTab(onOpenLesson: _openLesson, onViewSitemap: () => _goToTab(2)),
                    _SectionsInDepthTab(onOpenLesson: _openLesson, onJumpToSitemap: () => _goToTab(2)),
                    const _SitemapTab(),
                    const _CertificationsTab(),
                  ],
                ),
              ),
            ],
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

// ============================================================
// HOME TAB — hero + Featured highlights (`#section-highlights`)
// ============================================================

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.onOpenLesson, required this.onViewSitemap});

  final _OpenLesson onOpenLesson;
  final VoidCallback onViewSitemap;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  // The real web's "Featured tracks" hero button is a working anchor link
  // to `#section-highlights` (`static/001 Career Buddy/index.html:2057-2059`)
  // — this section, already rendered just below the hero on this same tab,
  // is that same destination; scrolling it into view reproduces the web's
  // in-page jump exactly, no new content or backend call involved.
  final _highlightsKey = GlobalKey();

  void _scrollToFeaturedHighlights() {
    final context = _highlightsKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroCard(onExploreSitemap: widget.onViewSitemap, onViewFeatured: _scrollToFeaturedHighlights),
          const SizedBox(height: AppSpacing.xl),
          _SectionEyebrow(SkillUpData.featuredEyebrow, key: _highlightsKey),
          const SizedBox(height: 4),
          Text(
            SkillUpData.featuredHeadline,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            SkillUpData.featuredSubtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: widget.onViewSitemap, child: const Text(SkillUpData.featuredViewSitemapLabel)),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final highlight in SkillUpData.featuredHighlights) ...[
            _FeaturedHighlightCard(highlight: highlight, onTap: () => widget.onOpenLesson(highlight.relativePath, highlight.displayTitle)),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
          const AppFooter(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onExploreSitemap, required this.onViewFeatured});

  final VoidCallback onExploreSitemap;
  final VoidCallback onViewFeatured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(50),
            ),
            // `Wrap` rather than a fixed `Row` — the pill's fixed
            // horizontal padding plus icon plus label can exceed the
            // available width on very narrow phones or with the test
            // harness's wider fallback font metrics; wrapping to a second
            // line degrades gracefully instead of overflowing.
            child: const Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                Text(SkillUpData.heroPill, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
              children: [
                const TextSpan(text: SkillUpData.heroHeadline),
                TextSpan(text: SkillUpData.heroHeadlineHighlight, style: TextStyle(color: AppColors.accent)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            SkillUpData.heroLede,
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ElevatedButton.icon(
                onPressed: onExploreSitemap,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text(SkillUpData.heroPrimaryActionLabel),
              ),
              OutlinedButton(
                onPressed: onViewFeatured,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                child: const Text(SkillUpData.heroSecondaryActionLabel),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            children: [for (final stat in SkillUpData.heroStats) _StatTile(stat: stat)],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final SkillUpStat stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(stat.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(stat.label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
      ],
    );
  }
}

class _FeaturedHighlightCard extends StatelessWidget {
  const _FeaturedHighlightCard({required this.highlight, required this.onTap});

  final FeaturedHighlight highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _LessonLikeCard(
      icon: highlight.icon,
      title: highlight.title,
      description: highlight.description,
      onTap: onTap,
    );
  }
}

class _LessonLikeCard extends StatelessWidget {
  const _LessonLikeCard({required this.icon, required this.title, required this.description, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentDark, letterSpacing: 0.6),
    );
  }
}

// ==================================================================
// SECTIONS IN DEPTH TAB (`#section-depth`) — the 3 major sections
// ==================================================================

class _SectionsInDepthTab extends StatelessWidget {
  const _SectionsInDepthTab({required this.onOpenLesson, required this.onJumpToSitemap});

  final _OpenLesson onOpenLesson;
  final VoidCallback onJumpToSitemap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionEyebrow(SkillUpData.depthEyebrow),
          const SizedBox(height: 4),
          const Text(
            SkillUpData.depthHeadline,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            SkillUpData.depthSubtitle,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: onJumpToSitemap, child: const Text(SkillUpData.depthJumpToSitemapLabel)),
          ),
          for (final section in SkillUpData.sections) ...[
            const SizedBox(height: AppSpacing.lg),
            _SectionInDepthArticle(section: section, onOpenLesson: onOpenLesson),
          ],
          const SizedBox(height: AppSpacing.lg),
          const AppFooter(),
        ],
      ),
    );
  }
}

class _SectionInDepthArticle extends StatelessWidget {
  const _SectionInDepthArticle({required this.section, required this.onOpenLesson});

  final SkillUpSection section;
  final _OpenLesson onOpenLesson;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeadRow(section: section),
        const SizedBox(height: 4),
        Text(section.depthDescription, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4)),
        for (final sub in section.subsections) ...[
          const SizedBox(height: AppSpacing.md),
          _SubsectionHead(sub: sub),
          const SizedBox(height: AppSpacing.sm),
          for (final lesson in sub.lessons) ...[
            _LessonCard(lesson: lesson, onTap: () => onOpenLesson(lesson.relativePath, lesson.displayTitle)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _SectionHeadRow extends StatelessWidget {
  const _SectionHeadRow({required this.section});

  final SkillUpSection section;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
          child: Icon(section.icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(section.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.accentDark.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(50)),
          child: Text(section.tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentDark)),
        ),
      ],
    );
  }
}

class _SubsectionHead extends StatelessWidget {
  const _SubsectionHead({required this.sub});

  final SkillUpSubsection sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(sub.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        Text(sub.countLabel, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.onTap});

  final SkillUpLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (lesson.chipIsAlt ? AppColors.textMuted : AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                lesson.chip,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: lesson.chipIsAlt ? AppColors.textMuted : AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(lesson.description, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35)),
            const SizedBox(height: 6),
            const Row(
              children: [
                Text('Open lesson', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.action)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 12, color: AppColors.action),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// SITEMAP TAB (`#section-sitemap`) — "platform at a glance" + tree
// ==================================================================

class _SitemapTab extends StatefulWidget {
  const _SitemapTab();

  @override
  State<_SitemapTab> createState() => _SitemapTabState();
}

class _SitemapTabState extends State<_SitemapTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openLesson(String relativePath, String displayTitle) {
    context.push(
      RoutePaths.skillUpLesson,
      extra: SkillUpLessonRouteArgs(title: displayTitle, url: buildSkillUpLessonUrl(relativePath)),
    );
  }

  bool _lessonMatches(SkillUpLesson lesson) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return lesson.title.toLowerCase().contains(q) ||
        lesson.description.toLowerCase().contains(q) ||
        lesson.chip.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionEyebrow(SkillUpData.sitemapEyebrow),
          const SizedBox(height: 4),
          const Text(
            SkillUpData.sitemapHeadline,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            SkillUpData.sitemapSubtitle,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: SkillUpData.sitemapSearchPlaceholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _GlanceCard(stats: SkillUpData.platformStats),
          const SizedBox(height: AppSpacing.lg),
          for (final section in SkillUpData.sections) ...[
            _SitemapCategory(section: section, matches: _lessonMatches, onOpenLesson: _openLesson),
            const SizedBox(height: AppSpacing.lg),
          ],
          const AppFooter(),
        ],
      ),
    );
  }
}

class _GlanceCard extends StatelessWidget {
  const _GlanceCard({required this.stats});

  final List<SkillUpStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(SkillUpData.glanceTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          for (final stat in stats)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(stat.label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  Text(stat.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SitemapCategory extends StatelessWidget {
  const _SitemapCategory({required this.section, required this.matches, required this.onOpenLesson});

  final SkillUpSection section;
  final bool Function(SkillUpLesson lesson) matches;
  final _OpenLesson onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final visibleSubs = section.subsections.where((sub) => sub.lessons.any(matches)).toList();
    if (visibleSubs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeadRow(section: section),
        const SizedBox(height: 4),
        Text(section.sitemapDescription, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4)),
        for (final sub in visibleSubs) ...[
          const SizedBox(height: AppSpacing.sm),
          _SubsectionHead(sub: sub),
          for (final lesson in sub.lessons.where(matches))
            InkWell(
              onTap: () => onOpenLesson(lesson.relativePath, lesson.displayTitle),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 5, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(lesson.title, style: const TextStyle(fontSize: 13, color: AppColors.action))),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ============================================================
// CERTIFICATIONS TAB — placeholder, owned by another agent
// ============================================================

/// The Certifications tab (`#section-certifications` on the web) — a real,
/// live, API-backed feature (`skillup_assessment`), built as the standalone
/// `CertificationsSection` widget and wrapped here the same way every other
/// tab wraps its own content for scrolling within the `TabBarView`.
class _CertificationsTab extends StatelessWidget {
  const _CertificationsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: CertificationsSection(),
    );
  }
}
