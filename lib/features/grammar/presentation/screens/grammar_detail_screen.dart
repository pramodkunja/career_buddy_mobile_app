import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/grammar_topic.dart';
import '../providers/grammar_providers.dart';
import '../widgets/grammar_audio_player_sheet.dart';
import '../widgets/grammar_image_carousel_sheet.dart';
import '../widgets/grammar_video_player_sheet.dart';

/// The real page's `--accent` custom property (`detail.html:14-23`) — a
/// fixed value for every topic, not per-topic (confirmed by reading the
/// `<style>` block directly: no topic-specific override exists anywhere in
/// the template or `subject_views.py`). Matches [AppColors.action]'s value
/// exactly; kept as a literal here to mirror `GrammarIndexScreen`'s own
/// convention of literal per-screen hex constants.
const _kAccent = Color(0xFF185ADB);

/// Batch 7 — Grammar topic detail (`subject_views.subject_topic`,
/// `templates/subject/detail.html`). Reachable at `/grammar/:slug`
/// ([RoutePaths.grammarTopicPattern]), [slug] being the route's `:slug`
/// param.
class GrammarDetailScreen extends ConsumerWidget {
  const GrammarDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicAsync = ref.watch(grammarTopicDetailProvider(slug));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          switch (topicAsync) {
            AsyncData(value: final topic) => SingleChildScrollView(
              child: Column(
                children: [
                  _GrammarDetailContent(topic: topic),
                  const AppFooter(),
                ],
              ),
            ),
            AsyncError(:final error) => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.invalidate(grammarTopicDetailProvider(slug)),
            ),
            _ => const AppLoader(message: 'Loading topic...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _GrammarDetailContent extends StatelessWidget {
  const _GrammarDetailContent({required this.topic});

  final GrammarTopicDetail topic;

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `.back-link` (`detail.html:490-496`) — exact label + left arrow.
          InkWell(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RoutePaths.grammar);
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Text(
                    'Back to Subject Library',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // `.topic-header` (`detail.html:498-501`).
          Text(
            topic.title,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            topic.definition,
            style: const TextStyle(fontSize: 17, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.xl),
          // `.media-section` (`detail.html:504-542`) — single column at
          // mobile widths (`@media max-width:768px`, `detail.html:399-402`).
          _MediaCard(
            icon: Icons.image_outlined,
            iconColor: _kAccent,
            previewBg: const Color(0xFFF8FAFC),
            title: 'Visual Guide',
            subtitle: 'Tap to view the presentation slides',
            onTap: () => _openSheet(context, GrammarImageCarouselSheet(slug: topic.slug)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MediaCard(
            icon: Icons.play_circle_outline,
            iconColor: Colors.white,
            previewBg: const Color(0xFF0F172A),
            title: 'Video Lesson',
            subtitle: 'Watch a guided explanation',
            onTap: () => _openSheet(context, GrammarVideoPlayerSheet(slug: topic.slug)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MediaCard(
            icon: Icons.headphones,
            iconColor: _kAccent,
            previewBg: _kAccent.withValues(alpha: 0.1),
            title: 'Audio Recap',
            subtitle: 'Listen to a quick 60-second summary',
            onTap: () => _openSheet(context, GrammarAudioPlayerSheet(audioText: topic.audioText)),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Lesson slides text cards (`detail.html:561-579`) — the
          // authored slide title/lines only; the paired generated-SVG
          // illustration is intentionally not reproduced, see
          // `GrammarSlide`'s doc comment.
          if (topic.slides.isNotEmpty) ...[
            const _SectionHeading('Lesson slides'),
            for (var i = 0; i < topic.slides.length; i++) _SlideNoteCard(index: i + 1, slide: topic.slides[i]),
            const SizedBox(height: AppSpacing.md),
          ],
          // `.editorial-box` "why learning ___ is important"
          // (`detail.html:581-589`).
          _EditorialBox(
            title: 'Why learning ${topic.title.toLowerCase()} is important',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final item in topic.roleItems) _BulletLine(item)],
            ),
          ),
          // Summary table (`detail.html:591-610`) — hardcoded headers.
          if (topic.summaryRows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DataTable(
              headers: const ['Type', 'Definition', 'Example'],
              rows: [for (final r in topic.summaryRows) [r.type, r.definition, r.example]],
              italicLastColumn: true,
            ),
          ],
          // Dynamic sections (`detail.html:613-676`).
          for (final section in topic.sections) _GrammarSection(section: section),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Text(
          text,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: -0.3),
        ),
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.icon,
    required this.iconColor,
    required this.previewBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color previewBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 100,
              color: previewBg,
              alignment: Alignment.center,
              child: Icon(icon, size: 40, color: iconColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideNoteCard extends StatelessWidget {
  const _SlideNoteCard({required this.index, required this.slide});

  final int index;
  final GrammarSlide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. ${slide.title}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _kAccent),
          ),
          const SizedBox(height: 8),
          for (final line in slide.lines) _BulletLine(line),
        ],
      ),
    );
  }
}

class _EditorialBox extends StatelessWidget {
  const _EditorialBox({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.03),
        border: Border.all(color: _kAccent.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _kAccent)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: AppColors.textMuted)),
          Expanded(child: Text(text, style: style ?? const TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.4))),
        ],
      ),
    );
  }
}

/// A generic bordered table — used for both the hardcoded-header summary
/// table (`detail.html:591-610`) and each dynamic section's own
/// `table_headers`/`table_rows` (`detail.html:617-636`).
class _DataTable extends StatelessWidget {
  const _DataTable({required this.headers, required this.rows, this.italicLastColumn = false});

  final List<String> headers;
  final List<List<String>> rows;
  final bool italicLastColumn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder(
          horizontalInside: const BorderSide(color: AppColors.border),
        ),
        columnWidths: const {0: IntrinsicColumnWidth()},
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: [
              for (final h in headers)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(h, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                for (var i = 0; i < row.length; i++)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      row[i],
                      style: TextStyle(
                        color: i == 0 ? AppColors.textPrimary : AppColors.textMuted,
                        fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                        fontStyle: (italicLastColumn && i == row.length - 1) ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One `topic.sections` entry (`detail.html:613-676`) — a heading/lead plus
/// exactly one of the 5 content shapes [GrammarSection] can carry.
class _GrammarSection extends StatelessWidget {
  const _GrammarSection({required this.section});

  final GrammarSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(section.heading),
        if (section.lead != null) ...[
          Text(section.lead!, style: const TextStyle(fontSize: 16, color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (section.tableHeaders != null && section.tableRows != null)
          _DataTable(headers: section.tableHeaders!, rows: section.tableRows!),
        if (section.categoryItems != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in section.categoryItems!)
                  _CategoryItemLine(label: item.label, text: item.text),
              ],
            ),
          ),
        if (section.ruleBoxes != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rule in section.ruleBoxes!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4),
                        children: [
                          TextSpan(text: '${rule.title}: ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          TextSpan(text: rule.text),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (section.exampleItems != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: const Border(left: BorderSide(color: _kAccent, width: 4)),
              borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EXAMPLES IN CONTEXT',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                for (final example in section.exampleItems!)
                  _BulletLine(example, style: const TextStyle(color: AppColors.textPrimary, fontStyle: FontStyle.italic, height: 1.4)),
              ],
            ),
          ),
        if (section.exercises != null) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text('Practice Exercises', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          const Text('Test your understanding of this concept.', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          for (final exercise in section.exercises!) _ExerciseCard(exercise: exercise),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final GrammarExercise exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q: ${exercise.question}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          // Always shown directly under the question — no reveal toggle,
          // see `GrammarExercise`'s doc comment.
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
              children: [
                const TextSpan(text: 'Answer: ', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                TextSpan(text: exercise.answer, style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `<li><strong>{{ item.label }}:</strong> {{ item.text }}</li>`
/// (`detail.html:638-644`).
class _CategoryItemLine extends StatelessWidget {
  const _CategoryItemLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: AppColors.textMuted)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
