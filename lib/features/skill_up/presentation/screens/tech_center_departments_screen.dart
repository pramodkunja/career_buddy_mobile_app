import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../data/tech_center_catalog.g.dart';
import '../../domain/entities/tech_center_catalog.dart';

/// Phase 76 — the Tech Center's department browsing screen, closing the gap
/// Phase 75 confirmed (383 real nested lesson pages with no Flutter entry
/// point). Mirrors [SkillUpNonItDepartmentsScreen]'s own "list everything on
/// one screen" shape for the structurally identical Non-IT departments —
/// [kTechCenterDepartments] is `const` (generated once from the real page,
/// not fetched), so this needs no loading/error state the way the Non-IT
/// screen's JSON-asset fetch does.
class TechCenterDepartmentsScreen extends StatelessWidget {
  const TechCenterDepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roleCount = kTechCenterDepartments.fold(0, (n, d) => n + d.roles.length);
    return Scaffold(
      appBar: AppBar(title: const Text('Tech Center')),
      body: kTechCenterDepartments.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No departments are available right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'Every technology department and the roles inside it — ${kTechCenterDepartments.length} '
                  'departments, $roleCount roles, each with the courses that role calls for.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final department in kTechCenterDepartments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _DepartmentCard(department: department),
                  ),
              ],
            ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department});

  final TechCenterDepartment department;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('tech-center-department-card-${department.slug}'),
      borderRadius: AppRadius.lgRadius,
      onTap: () => context.push(RoutePaths.techCenterRoles, extra: department),
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
              child: const Icon(Icons.terminal, color: AppColors.action, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(department.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
