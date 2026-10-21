import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/career_department.dart';
import '../widgets/career_role_action_sheet.dart';
import 'career_departments_screen.dart' show careerIconFor;

/// The role list shown after picking a department — `deptRolesView`/the
/// Non-IT `route()` function's role-grid rendering (`landing.html:8212-
/// 8222`, `:8125-8136`). Tapping a role opens the same 3-action sheet the
/// real `roleAct` dialog shows (`CareerRoleActionSheet`).
class CareerRolesScreen extends StatelessWidget {
  const CareerRolesScreen({required this.department, super.key});

  final CareerDepartment department;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(department.name)),
      body: department.roles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No roles are listed for this department yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Pick a role to see its skills, build a resume or start resume parsing & an AI interview.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
                for (final role in department.roles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _RoleCard(role: role, department: department),
                  ),
              ],
            ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.department});

  final CareerRole role;
  final CareerDepartment department;

  @override
  Widget build(BuildContext context) {
    final skillCount = role.allSkills.length;
    return InkWell(
      key: Key('role-card-${role.name}'),
      borderRadius: AppRadius.lgRadius,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CareerRoleActionSheet(role: role, department: department),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.action.withValues(alpha: 0.1),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Icon(
                careerIconFor(department.icon),
                color: AppColors.action,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  Text(
                    skillCount > 0 ? '$skillCount skills' : 'Skills coming soon',
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
