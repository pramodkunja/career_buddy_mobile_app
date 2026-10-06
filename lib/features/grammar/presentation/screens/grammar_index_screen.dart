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

/// Batch 7 — Grammar index (`subject_views.subject_home`,
/// `templates/subject/home.html`). 9 topic cards, static content bundled
/// as a JSON asset (see `GrammarDataSource`'s doc comment) — no network
/// call needed for this screen at all.
class GrammarIndexScreen extends ConsumerWidget {
  const GrammarIndexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(grammarTopicCardsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          switch (cardsAsync) {
            AsyncData(value: final cards) => SingleChildScrollView(
              child: Column(
                children: [
                  _GrammarIndexContent(cards: cards),
                  const AppFooter(),
                ],
              ),
            ),
            AsyncError(:final error) => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.invalidate(grammarTopicCardsProvider),
            ),
            _ => const AppLoader(message: 'Loading Grammar...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _GrammarIndexContent extends StatelessWidget {
  const _GrammarIndexContent({required this.cards});

  final List<GrammarTopicSummary> cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `.page-header` (`home.html:291-299`) — eyebrow badge, gradient
          // H1, subtitle.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x1A185ADB),
              border: Border.all(color: const Color(0x33185ADB)),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.auto_stories, size: 15, color: Color(0xFF185ADB)),
                SizedBox(width: 6),
                Text(
                  'Grammar Library',
                  style: TextStyle(color: Color(0xFF185ADB), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF185ADB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'Choose a Topic to Begin',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Master English grammar step-by-step. Each topic has slides, a video lesson, an audio recap, rules, examples and practice.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          // `.topic-grid` (`home.html:159`) — 2-column on phone widths.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) => _TopicCard(topic: cards[index]),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FeaturesStrip(),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final GrammarTopicSummary topic;

  Color get _accent => Color(int.parse(topic.accentColorHex.substring(1), radix: 16) + 0xFF000000);

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push(RoutePaths.grammarTopic(topic.slug)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE8EDF2)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `.topic-card::before` — 5px top accent bar.
            Container(height: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        border: Border.all(color: accent.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(topic.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            topic.badge,
                            style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      topic.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        topic.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // `.card-footer-row` — "Explore lesson" CTA.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                color: Color(0xFFFAFBFC),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Explore lesson',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                  Icon(Icons.arrow_forward, size: 13, color: accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.features-strip` (`home.html:322-345`) — verbatim copy.
class _FeaturesStrip extends StatelessWidget {
  const _FeaturesStrip();

  static const _items = [
    (number: '1', color: Color(0xFF185ADB), title: 'Consistent Structure', body: 'Every topic follows the same pattern so you always know how to move through each lesson.'),
    (number: '2', color: Color(0xFF8B5CF6), title: 'Rules & Examples', body: 'Clear explanations, quick rules and sentence examples to build real understanding.'),
    (number: '3', color: Color(0xFF10B981), title: 'Smooth Navigation', body: 'Jump between grammar subjects without losing your place in the module.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0x0A185ADB),
        border: Border.all(color: const Color(0x1F185ADB)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final item in _items) ...[
            if (item != _items.first) const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    item.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(item.body, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
