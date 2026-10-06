import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/responsive/breakpoints.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/dashboard_data.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/activity_progress_list.dart';
import '../widgets/dashboard_stats_row.dart';
import '../widgets/mock_tests_entry_card.dart';
import '../widgets/payment_history_section.dart';
import '../widgets/quick_start_section.dart';
import '../widgets/recent_results_list.dart';
import '../widgets/recommended_jobs_section.dart';
import '../widgets/workshop_entry_card.dart';

/// Mirrors `templates/dashboard.html` (`activities.views.dashboard`) —
/// section order and content match the web dashboard; see
/// `docs/BACKEND_CONTRACT_dashboard.md` for the (not-yet-implemented)
/// backend contract this consumes.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardControllerProvider);

    ref.listen<AsyncValue<DashboardData>>(dashboardControllerProvider, (previous, next) {
      final error = next.error;
      if (error is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    final authState = ref.watch(authControllerProvider);
    final username = authState is AuthAuthenticated ? authState.user.username : '';

    return Scaffold(
      // The real web's navigation (`base.html`'s persistent top navbar) is
      // reachable from every page regardless of that page's own content —
      // including a dashboard whose data failed to load. This screen was
      // the one confirmed, real dead-end: without this, a student whose
      // dashboard fails (e.g. the current `/dashboard/api/` deployment gap)
      // had no way to reach any other screen except logging out.
      drawer: const AppNavDrawer(),
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: drawerAwareBackLeading(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Stack(
        children: [
          switch (dashboardState) {
            AsyncData(value: final data) => RefreshIndicator(
              onRefresh: () => ref.read(dashboardControllerProvider.notifier).retry(),
              child: _DashboardContent(username: username, data: data),
            ),
            AsyncError(:final error) when error is! UnauthorizedFailure => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.read(dashboardControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading your dashboard...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.username, required this.data});

  final String username;
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final tablet = isTablet(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _WelcomeBanner(username: username, onBrowseActivities: () => context.push(RoutePaths.activities)),
        const SizedBox(height: AppSpacing.lg),
        DashboardStatsRow(stats: data.stats),
        const SizedBox(height: AppSpacing.lg),
        if (tablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RecommendedJobsSection(jobs: data.recommendedJobs, interviewScore: data.interviewScore),
                    if (data.recommendedJobs.isNotEmpty) const SizedBox(height: AppSpacing.lg),
                    const _ActivitiesSectionHeader(),
                    const SizedBox(height: AppSpacing.sm),
                    ActivityProgressList(
                      activities: data.activities,
                      onTapActivity: (id) => context.push(RoutePaths.activityDetail(id)),
                      onStartLearning: () => context.push(RoutePaths.activities),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PaymentHistorySection(payments: data.paymentHistory),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Results', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    RecentResultsList(results: data.recentResults),
                    const SizedBox(height: AppSpacing.lg),
                    MockTestsEntryCard(onTap: () => context.push(RoutePaths.mockTestsHub)),
                    const SizedBox(height: AppSpacing.lg),
                    WorkshopEntryCard(onTap: () => context.push(RoutePaths.workshopDashboard)),
                    const SizedBox(height: AppSpacing.lg),
                    const QuickStartSection(),
                  ],
                ),
              ),
            ],
          )
        else ...[
          RecommendedJobsSection(jobs: data.recommendedJobs, interviewScore: data.interviewScore),
          if (data.recommendedJobs.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          const _ActivitiesSectionHeader(),
          const SizedBox(height: AppSpacing.sm),
          ActivityProgressList(
            activities: data.activities,
            onTapActivity: (id) => context.push(RoutePaths.activityDetail(id)),
            onStartLearning: () => context.push(RoutePaths.activities),
          ),
          const SizedBox(height: AppSpacing.lg),
          PaymentHistorySection(payments: data.paymentHistory),
          if (data.paymentHistory.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          Text('Recent Results', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          RecentResultsList(results: data.recentResults),
          const SizedBox(height: AppSpacing.lg),
          MockTestsEntryCard(onTap: () => context.push(RoutePaths.mockTestsHub)),
          const SizedBox(height: AppSpacing.lg),
          WorkshopEntryCard(onTap: () => context.push(RoutePaths.workshopDashboard)),
          const SizedBox(height: AppSpacing.lg),
          const QuickStartSection(),
        ],
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.username, required this.onBrowseActivities});

  final String username;
  final VoidCallback onBrowseActivities;

  @override
  Widget build(BuildContext context) {
    // `.dashboard-welcome` (`static/css/style.css:1280-1288`) is its own
    // white, rounded-12px, shadowed card — not bare text on the page
    // background.
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.headlineSmall,
                    children: [
                      const TextSpan(text: 'Welcome back, '),
                      // `<span class="text-accent">{{ username }}</span>`
                      // (`dashboard.html:54`) — `.text-accent`'s final,
                      // AA-contrast-adjusted cascade winner is a dark gold,
                      // not the raw `--accent` gold (`style.css:2813-2815`).
                      TextSpan(text: username, style: const TextStyle(color: Color(0xFFA86A08))),
                    ],
                  ),
                ),
                Text('Continue your Business English journey', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: AppButton(
              label: 'Browse Activities',
              icon: Icons.grid_view_outlined,
              fullWidth: false,
              onPressed: onBrowseActivities,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitiesSectionHeader extends StatelessWidget {
  const _ActivitiesSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Activity Progress',
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () => context.push(RoutePaths.activities),
          child: const Text('View All'),
        ),
      ],
    );
  }
}
