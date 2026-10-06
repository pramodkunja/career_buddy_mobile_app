import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/coming_soon_screen.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../group_discussion/domain/services/gd_module_detection.dart';
import '../../../group_discussion/presentation/screens/gd_topic_screen.dart';
import '../../../jam/domain/services/jam_module_detection.dart';
import '../../../jam/presentation/screens/jam_topics_screen.dart';
import '../../../roleplay/domain/services/roleplay_module_detection.dart';
import '../../../roleplay/presentation/screens/roleplay_home_screen.dart';
import '../../domain/entities/activity_summary.dart';
import '../controllers/workshop_dashboard_controller.dart';

/// W013 — the dedicated Interactive Workshop page
/// (`templates/activities/workshop_dashboard.html`), distinct from the
/// regular Activities list filtered to the "workshop" category (that's the
/// dashboard Quick Start "Workshop" chip's destination — a different web
/// page entirely, `activity_list.html`). This screen reproduces
/// `workshop_dashboard.html`'s own specific layout: numbered cards, a
/// level badge, a static "Workshop" badge, a truncated objective, a static
/// "Real-time Interaction" line, and an "Enter Workshop" action — nothing
/// this specific page doesn't itself show (no lock/completion indicators
/// here, even though that data happens to be available via the reused API
/// — the real web page for this route doesn't render either).
class WorkshopDashboardScreen extends ConsumerWidget {
  const WorkshopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workshopDashboardControllerProvider);

    ref.listen<AsyncValue<List<ActivitySummary>>>(workshopDashboardControllerProvider, (previous, next) {
      final error = next.error;
      if (error is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    return Scaffold(
      drawer: const AppNavDrawer(),
      appBar: AppBar(title: const Text('Interactive Workshop'), leading: drawerAwareBackLeading(context)),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final modules) => _WorkshopList(modules: modules),
            AsyncError(:final error) when error is! UnauthorizedFailure => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.read(workshopDashboardControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading workshops...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _WorkshopList extends StatelessWidget {
  const _WorkshopList({required this.modules});

  final List<ActivitySummary> modules;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No workshop activities available right now.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Engage in real-time, AI-powered interactive learning sessions',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < modules.length; i++) ...[
          _WorkshopCard(number: i + 1, activity: modules[i]),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({required this.number, required this.activity});

  final int number;
  final ActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary,
                child: Text('$number', style: const TextStyle(color: AppColors.textOnDark, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              if (activity.level.isNotEmpty) _Badge(activity.level, type: _BadgeType.level),
              const _Badge('Workshop', icon: Icons.groups_outlined, type: _BadgeType.category),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(activity.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(_truncate(activity.description, 110), style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.bolt_outlined, size: 16, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Real-time Interaction',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Enter Workshop',
            icon: Icons.arrow_forward,
            onPressed: () => _enterWorkshop(context, activity.title),
          ),
        ],
      ),
    );
  }

  /// Matches Django's `|truncatechars:110` exactly: at most [max]
  /// characters, the last replaced with an ellipsis when the source is
  /// longer (`workshop_dashboard.html:45`, `activity.objective|truncatechars:110`).
  String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1)}…';
  }

  /// Mirrors `get_workshop_url()`'s own title-keyword routing
  /// (`activities/views.py:52-61`): Group Discussion → `/gd/`, JAM →
  /// `/jam/`, Role Play → `/roleplay/` — on the web each goes straight to
  /// its own dedicated app root, not through the generic `activity_detail`
  /// page. All three now have real in-app screens (reached the same way
  /// `ActivityDetailScreen` already reaches them, via the identical
  /// `isGdModuleActivity`/`isJamModuleActivity`/`isRoleplayModuleActivity`
  /// title checks — not duplicated routing logic, the same canonical
  /// rules), so this pushes the real screen directly instead of a
  /// `ComingSoonScreen`. The web's own fallback for a non-matching title is
  /// a dead `href="#"` link (confirmed by reading `workshop_dashboard()`);
  /// this app still surfaces that case honestly via `ComingSoonScreen`
  /// rather than silently doing nothing, consistent with this app's
  /// established "never a dead tap target" convention — but it's a
  /// defensive fallback only, not expected to trigger against the real
  /// seed data (exactly 3 workshop activities exist, and all 3 match).
  void _enterWorkshop(BuildContext context, String title) {
    if (isGdModuleActivity(title)) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GdTopicScreen()));
    } else if (isJamModuleActivity(title)) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const JamTopicsScreen()));
    } else if (isRoleplayModuleActivity(title)) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RoleplayHomeScreen()));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ComingSoonScreen(
            title: title,
            message: 'This workshop isn\'t available in the app yet. Please open it on the Career Buddy website for now.',
          ),
        ),
      );
    }
  }
}

enum _BadgeType { level, category }

/// `.badge-level`/`.badge-category` (`static/css/style.css:964-980`) —
/// this screen reuses the Activities List's own card/badge classes
/// (confirmed in `docs/W013_WORKSHOP_DASHBOARD.md`), so the level pill and
/// the static "Workshop" pill get the same purple/slate colors
/// `ActivityCard`'s badges use, not a generic gold accent.
class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.type, this.icon});

  final String label;
  final IconData? icon;
  final _BadgeType type;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (type) {
      _BadgeType.level => (const Color(0xFFEDE9FE), const Color(0xFF5B21B6)),
      _BadgeType.category => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: foreground)),
        ],
      ),
    );
  }
}
