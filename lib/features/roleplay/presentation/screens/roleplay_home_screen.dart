import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../data/roleplay_topics_data.dart';
import '../widgets/roleplay_topic_card.dart';
import 'roleplay_practice_screen.dart';

/// Entry point for the Roleplay Workshop feature (Storytelling / Situations
/// / Roleplay). Mirrors `roleplay_home.html` (`roleplay_home`,
/// `activities/views.py:1976-1988`): a hero header plus one card per
/// `TOPIC_PRACTICE_CONFIG` entry.
///
/// This screen itself makes no network call and shows no locked state —
/// `TOPIC_PRACTICE_CONFIG` is static, bundled data (`RoleplayTopicsData`),
/// and there is no standalone JSON endpoint mirroring `roleplay_home`'s own
/// `_can_access_workshop` check to pre-flight against (the real
/// `roleplay_home` view is plain server-rendered HTML — a plan-denied hit
/// there redirects away before ever rendering, which has no meaningful
/// analogue for a client that fetches nothing to render this list). The
/// plan gate is real and still enforced — it surfaces the moment the user
/// actually tries to start a session (`RoleplayPracticeScreen`'s
/// `RoleplayLocked` state, driven by `roleplay_practice`'s own 403), which
/// is the same point the two real, gated JSON endpoints this app talks to
/// enforce it.
///
/// Self-contained: takes no required constructor parameters and navigates
/// to [RoleplayPracticeScreen] via a plain `Navigator.push` (not
/// `context.push`/a named route), so it works standalone before a human
/// wires `RoutePaths.roleplayHome` into `app_router.dart`.
class RoleplayHomeScreen extends StatelessWidget {
  const RoleplayHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      drawer: const AppNavDrawer(),
      // No AppBar title text: the hero below already renders the real
      // "Topic Practice Workshop" copy prominently — duplicating it in the
      // AppBar would just repeat the same string twice on screen.
      appBar: AppBar(leading: drawerAwareBackLeading(context)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // `.rp-hero` (`roleplay_home.html:11-23,116-121`).
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Topic Practice Workshop',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Select a practice mode to improve your storytelling, situational responses, and professional '
                      'roleplay skills with AI.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final topic in RoleplayTopicsData.all) ...[
                RoleplayTopicCard(
                  topic: topic,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RoleplayPracticeScreen(topicSlug: topic.slug),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
      backgroundColor: AppColors.background,
    );
  }
}
