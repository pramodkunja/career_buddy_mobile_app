import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../domain/entities/career_department.dart';
import '../providers/resume_providers.dart';

/// `career_path(request, 'it'|'non-it')` (`activities/views.py:120-125`) —
/// the real "Choose Your Path" department browsing page. [track] is `'it'`
/// or `'non-it'`, matching the real view's own parameter; a `'non-it'`
/// track shows both of its real groups ("Non-IT · Technical"/"Non-IT ·
/// Non-Technical") on one screen, exactly like the real page shows both
/// `panelTech`/`panelNt` together for this track (confirmed directly:
/// `{% if track == 'non-it' or track == 'technical' %}` and the equivalent
/// `non-technical` check both evaluate true for `track == 'non-it'`).
class CareerDepartmentsScreen extends ConsumerWidget {
  const CareerDepartmentsScreen({required this.track, super.key});

  final String track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(careerDepartmentsProvider(track));
    return Scaffold(
      appBar: AppBar(
        title: Text(track == 'it' ? 'IT Career Paths' : 'Non-IT Career Paths'),
      ),
      body: switch (groupsAsync) {
        AsyncData(:final value) => _GroupsList(track: track, groups: value),
        AsyncError(:final error) => AppErrorView(
          message: 'Departments could not be loaded: $error',
          onRetry: () => ref.invalidate(careerDepartmentsProvider(track)),
        ),
        _ => const AppLoader(message: 'Loading departments…'),
      },
    );
  }
}

class _GroupsList extends StatelessWidget {
  const _GroupsList({required this.track, required this.groups});

  final String track;
  final List<CareerDepartmentGroup> groups;

  @override
  Widget build(BuildContext context) {
    if (groups.every((g) => g.departments.isEmpty)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No departments are available right now.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final group in groups)
          if (group.departments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                group.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            for (final department in group.departments)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _DepartmentCard(department: department),
              ),
          ],
      ],
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department});

  final CareerDepartment department;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('department-card-${department.name}'),
      borderRadius: AppRadius.lgRadius,
      onTap: () => context.push(
        RoutePaths.careerRoles,
        extra: department,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.action.withValues(alpha: 0.1),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Icon(
                careerIconFor(department.icon),
                color: AppColors.action,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    department.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${department.roles.length} roles',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Maps the source's own short icon keys (`it_departments.json`'s/the
/// inline `DEPTS` array's `i` field — e.g. `'code'`, `'search'`, `'hat'`)
/// to a Material icon. Reproduced with Material icons rather than the real
/// site's inline SVG sprite, the same convention already used throughout
/// this app's other landing-page work.
IconData careerIconFor(String key) => switch (key) {
  'code' => Icons.code,
  'flag' => Icons.flag_outlined,
  'globe' => Icons.public_outlined,
  'bug' => Icons.bug_report_outlined,
  'layers' => Icons.layers_outlined,
  'clip' => Icons.assignment_outlined,
  'mega' => Icons.campaign_outlined,
  'people' => Icons.groups_outlined,
  'chart' => Icons.bar_chart_outlined,
  'search' => Icons.search,
  'hat' => Icons.school_outlined,
  'shield' => Icons.shield_outlined,
  'gear' => Icons.settings_outlined,
  'box' => Icons.inventory_2_outlined,
  'brain' => Icons.psychology_outlined,
  'wallet' => Icons.account_balance_wallet_outlined,
  'bolt' => Icons.bolt_outlined,
  'cart' => Icons.local_shipping_outlined,
  'crown' => Icons.workspace_premium_outlined,
  'trend' => Icons.trending_up,
  'net' => Icons.hub_outlined,
  'brief' => Icons.work_outline,
  _ => Icons.work_outline,
};
