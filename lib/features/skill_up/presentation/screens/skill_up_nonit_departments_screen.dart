import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../resume/domain/entities/career_department.dart';
import '../../../resume/presentation/screens/career_departments_screen.dart' show careerIconFor;
import '../providers/skill_up_providers.dart';

/// Phase 47 — the Non-IT Center's department browsing screen
/// (`index.html:3886-3892`'s `#depth-nonit` article + `initNonIt()`'s
/// `grid()`/`trackView()`). The real page hash-routes through a separate
/// "2 tracks" grid step before showing a track's departments; this screen
/// instead lists both tracks and their departments together on one
/// scrollable screen, the same simplification Phase 43's
/// `CareerDepartmentsScreen` already uses for the structurally identical
/// Non-IT career-path groups — every department is still reachable, just
/// with one less tap.
class SkillUpNonItDepartmentsScreen extends ConsumerWidget {
  const SkillUpNonItDepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(skillUpNonItDepartmentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Non-IT Center')),
      body: switch (groupsAsync) {
        AsyncData(:final value) => _GroupsList(groups: value),
        AsyncError(:final error) => AppErrorView(
          message: 'Departments could not be loaded: $error',
          onRetry: () => ref.invalidate(skillUpNonItDepartmentsProvider),
        ),
        _ => const AppLoader(message: 'Loading departments…'),
      },
    );
  }
}

class _GroupsList extends StatelessWidget {
  const _GroupsList({required this.groups});

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
    final deptCount = groups.fold(0, (n, g) => n + g.departments.length);
    final roleCount = groups.fold(0, (n, g) => n + g.departments.fold(0, (m, d) => m + d.roles.length));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // `index.html:3892`'s exact copy for the `#depth-nonit` article,
        // with the real counts substituted in (confirmed $deptCount/
        // $roleCount == 21/202 directly from the source data).
        Text(
          'Every Non-IT department and the roles inside it — $deptCount departments, '
          '$roleCount roles, each with the skills that role calls for.',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final group in groups)
          if (group.departments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
              child: Text(
                group.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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
      key: Key('skillup-nonit-department-card-${department.name}'),
      borderRadius: AppRadius.lgRadius,
      onTap: () => context.push(RoutePaths.skillUpNonItRoles, extra: department),
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
              decoration: BoxDecoration(color: AppColors.action.withValues(alpha: 0.1), borderRadius: AppRadius.mdRadius),
              child: Icon(careerIconFor(department.icon), color: AppColors.action, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(department.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                    '${department.roles.length} roles',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
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
