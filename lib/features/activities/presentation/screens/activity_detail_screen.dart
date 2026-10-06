import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../ai_listening/domain/services/listening_module_detection.dart';
import '../../../ai_reading/domain/services/reading_module_detection.dart';
import '../../../ai_speaking/domain/services/speaking_module_detection.dart';
import '../../../ai_writing/domain/services/writing_module_detection.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../group_discussion/domain/services/gd_module_detection.dart';
import '../../../group_discussion/presentation/screens/gd_topic_screen.dart';
import '../../../jam/domain/services/jam_module_detection.dart';
import '../../../jam/presentation/screens/jam_topics_screen.dart';
import '../../../roleplay/domain/services/roleplay_module_detection.dart';
import '../../../roleplay/presentation/screens/roleplay_home_screen.dart';
import '../../domain/entities/activity_detail.dart';
import '../controllers/activity_detail_controller.dart';
import '../controllers/adjacent_activities_controller.dart';
import '../widgets/assessment_card.dart';
import '../widgets/activity_navigation_bar.dart';
import '../widgets/sub_activity_tile.dart';

/// Mirrors `templates/activities/detail.html`.
class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({required this.activityId, super.key});

  final int activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = activityDetailControllerProvider(activityId);
    final state = ref.watch(provider);

    ref.listen<AsyncValue<ActivityDetail>>(provider, (previous, next) {
      final error = next.error;
      if (error is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final data) => _ActivityDetailContent(data: data),
            AsyncError(:final error) when error is ForbiddenFailure => _LockedState(message: error.message),
            AsyncError(:final error) when error is! UnauthorizedFailure => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.read(provider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading activity...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _ActivityDetailContent extends ConsumerWidget {
  const _ActivityDetailContent({required this.data});

  final ActivityDetail data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjacent = ref.watch(adjacentActivitiesControllerProvider(data.id)).value;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _HeroBanner(data: data),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Batch 8/9 — Roleplay, JAM, and Group Discussion are all
              // workshop activities with a real in-app screen now (see
              // `isRoleplayModuleActivity`/`isJamModuleActivity`/
              // `isGdModuleActivity`, each ported verbatim from
              // `get_workshop_url()`'s own title-matching rule).
              if (data.isWorkshop && isRoleplayModuleActivity(data.title))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppButton(
                    label: 'Start Roleplay Practice',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const RoleplayHomeScreen()),
                    ),
                  ),
                )
              else if (data.isWorkshop && isJamModuleActivity(data.title))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppButton(
                    label: 'Start JAM Session',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const JamTopicsScreen()),
                    ),
                  ),
                )
              else if (data.isWorkshop && isGdModuleActivity(data.title))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppButton(
                    label: 'Start Group Discussion',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const GdTopicScreen()),
                    ),
                  ),
                )
              // W014/W015/W016/W017 — Speaking, Writing, Listening, and
              // Reading are all four AI modules with a real in-app screen
              // now; this banner must not tell the user they're
              // unavailable, or the (genuinely working) exercise below
              // becomes undiscoverable.
              else if (data.isWorkshop ||
                  (data.isModule &&
                      !isSpeakingModuleActivity(data.title) &&
                      !isWritingModuleActivity(data.title) &&
                      !isListeningModuleActivity(data.title) &&
                      !isReadingModuleActivity(data.title)))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    data.isWorkshop
                        ? 'This is an interactive workshop activity. It isn\'t available in the app yet.'
                        : 'This activity uses a guided AI module. It isn\'t available in the app yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              Text('Sub-Activities', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (data.subActivities.isEmpty)
                Text('No sub-activities yet.', style: Theme.of(context).textTheme.bodyMedium)
              else
                for (var i = 0; i < data.subActivities.length; i++) ...[
                  SubActivityTile(
                    subActivity: data.subActivities[i],
                    number: i + 1,
                    onTap: () => context.push(RoutePaths.subActivityDetail(data.id, data.subActivities[i].id)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              if (adjacent != null) ...[
                const SizedBox(height: AppSpacing.sm),
                ActivityNavigationBar(
                  adjacent: adjacent,
                  onSelect: (id) => context.pushReplacement(RoutePaths.activityDetail(id)),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const AssessmentCard(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mirrors `.activity-hero` (`static/css/style.css:1508-1543`): a
/// full-bleed colored banner with title/meta in white text and a
/// completion value/label pair in the corner. The web colors this per
/// activity via `activity.color_class` (`bg-primary`/`bg-success`/etc.) —
/// that field is NOT exposed by the existing `ActivityDetail` API/entity
/// (confirmed: no color/icon field exists on it), so inventing a per-
/// activity color would mean fabricating data the client doesn't have.
/// Uses the app's own consistent navy instead, preserving the web's
/// STRUCTURE (banner → title → meta → completion) honestly rather than
/// guessing a color — a documented, deliberate limitation, not an
/// oversight.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.data});

  final ActivityDetail data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _MetaItem(
                      icon: Icons.signal_cellular_alt,
                      text: data.level,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    _MetaItem(
                      icon: Icons.schedule,
                      text: data.duration,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    _MetaItem(
                      icon: Icons.layers_outlined,
                      text: '${data.subActivities.length} Sub-Activities',
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // `.ring-value`/`.ring-label` (`style.css:1543-1544`): gold
          // value, translucent-white label.
          Column(
            children: [
              Text(
                '${data.completionRate}%',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800),
              ),
              Text(
                'Complete',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text, this.color = AppColors.textMuted});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color))),
      ],
    );
  }
}

/// The web never actually renders `detail.html` for a locked activity — it
/// redirects back to the Activities list with the Upgrade-Required modal
/// (`activities/views.py:_locked_redirect`, `activity_list?locked=1`). This
/// screen can still be reached directly by a stale/deep link, so it shows
/// the same outcome in place instead: the API's own message plus a way
/// back to Activities (where W003's Upgrade-Required dialog lives) and a
/// way to the Pro/Membership placeholder.
class _LockedState extends StatelessWidget {
  const _LockedState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'View Plans',
              icon: Icons.workspace_premium_outlined,
              fullWidth: false,
              onPressed: () => context.push(RoutePaths.pro),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Back to Activities',
              variant: AppButtonVariant.text,
              fullWidth: false,
              onPressed: () => context.go(RoutePaths.activities),
            ),
          ],
        ),
      ),
    );
  }
}
