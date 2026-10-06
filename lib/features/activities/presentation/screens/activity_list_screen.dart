import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/demo/demo_mode_toggle.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/responsive/breakpoints.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/activity_list_data.dart';
import '../../domain/entities/activity_summary.dart';
import '../controllers/activity_list_controller.dart';
import '../widgets/activity_card.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/free_plan_banner.dart';
import '../widgets/upgrade_required_dialog.dart';

/// Mirrors `templates/activities/list.html` — category tabs, activity
/// cards, and the web's exact empty-state copy.
class ActivityListScreen extends ConsumerStatefulWidget {
  const ActivityListScreen({this.initialCategory, super.key});

  /// Set when reached via a category-specific link (the dashboard's Quick
  /// Start section, `dashboard.html:283-303`) so the list opens already
  /// filtered, instead of opening on "All" and requiring a second tap.
  /// `null` when reached normally (e.g. "Browse Activities"/"View All").
  final String? initialCategory;

  @override
  ConsumerState<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends ConsumerState<ActivityListScreen> {
  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory;
    if (category != null && category.isNotEmpty) {
      Future.microtask(() => ref.read(activityListControllerProvider.notifier).filterByCategory(category));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityListControllerProvider);

    ref.listen<AsyncValue<ActivityListData>>(activityListControllerProvider, (previous, next) {
      final error = next.error;
      if (error is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    return Scaffold(
      // See `DashboardScreen`'s doc comment on the same fix — a top-level,
      // drawer-linked landing screen must never leave the user stranded if
      // its own data fails to load.
      drawer: const AppNavDrawer(),
      appBar: AppBar(
        title: const Text('Activities'),
        leading: drawerAwareBackLeading(context),
        actions: const [DemoModeToggleAction()],
      ),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final data) => _ActivityListContent(data: data),
            AsyncError(:final error) when error is! UnauthorizedFailure => AppErrorView(
              message: error is Failure ? error.message : 'Something went wrong. Please try again.',
              onRetry: () => ref.read(activityListControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(message: 'Loading activities...'),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _ActivityListContent extends ConsumerWidget {
  const _ActivityListContent({required this.data});

  final ActivityListData data;

  /// The Free-Plan activity the user has already claimed, if any — derived
  /// from `is_locked` exactly as the web computes it server-side, not read
  /// from a dedicated field. See `FreePlanBanner`'s doc comment.
  ActivitySummary? get _claimedFreeActivity {
    if (!data.isFreePreview) return null;
    final unlocked = data.activities.where((a) => !a.isLocked).toList();
    return unlocked.length == 1 ? unlocked.single : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablet = isTablet(context);

    return RefreshIndicator(
      onRefresh: () => ref.read(activityListControllerProvider.notifier).retry(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: _PageHeader(isFreePreview: data.isFreePreview, totalActivities: data.totalActivities),
            ),
          ),
          if (!data.isFreePreview)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: CategoryFilterBar(
                  categories: data.categories,
                  selectedCategory: data.selectedCategory,
                  onSelected: (category) => ref.read(activityListControllerProvider.notifier).filterByCategory(category),
                ),
              ),
            ),
          if (data.isFreePreview)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: FreePlanBanner(claimedActivity: _claimedFreeActivity, totalActivities: data.totalActivities),
              ),
            ),
          if (data.activities.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                onShowAll: () => ref.read(activityListControllerProvider.notifier).filterByCategory(null),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: tablet ? _tabletGrid(context, data.activities) : _phoneList(context, data.activities),
            ),
        ],
      ),
    );
  }

  Widget _phoneList(BuildContext context, List<ActivitySummary> activities) {
    return SliverList.separated(
      itemCount: activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _card(context, activities[index], index + 1),
    );
  }

  Widget _tabletGrid(BuildContext context, List<ActivitySummary> activities) {
    final rows = <Widget>[];
    for (var i = 0; i < activities.length; i += 2) {
      final second = i + 1 < activities.length ? activities[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _card(context, activities[i], i + 1)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: second == null ? const SizedBox.shrink() : _card(context, second, i + 2)),
            ],
          ),
        ),
      );
    }
    return SliverList.list(children: rows);
  }

  Widget _card(BuildContext context, ActivitySummary activity, int activityNumber) {
    return ActivityCard(
      activity: activity,
      activityNumber: activityNumber,
      // Matches the web exactly (`list.html:135-151`): a locked card opens
      // the Upgrade-Required dialog, it never navigates to Activity Detail.
      onTap: activity.isLocked
          ? () => showUpgradeRequiredDialog(context)
          : () => context.push(RoutePaths.activityDetail(activity.id)),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.isFreePreview, required this.totalActivities});

  final bool isFreePreview;
  final int totalActivities;

  @override
  Widget build(BuildContext context) {
    // Matches `list.html:12-19` exactly.
    final subtitle = isFreePreview
        ? 'Free Plan — choose any one of the 4 activities below. Once started, the rest will be locked.'
        : '$totalActivities comprehensive activities to master professional communication';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('English Activities', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            // Exact copy from templates/activities/list.html's `{% empty %}`
            // block — the web uses this same text unconditionally, not a
            // different message for an unfiltered empty list.
            Text(
              'No activities found for this category.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Show All', fullWidth: false, onPressed: onShowAll),
          ],
        ),
      ),
    );
  }
}
