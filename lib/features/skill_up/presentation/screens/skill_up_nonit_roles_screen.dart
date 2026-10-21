import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../resume/domain/entities/career_department.dart';
import '../../../resume/presentation/screens/career_departments_screen.dart' show careerIconFor;
import '../widgets/skill_up_nonit_role_sheet.dart';

/// Phase 47 — the role list inside one Non-IT department
/// (`initNonIt()`'s `deptView()`). Tapping a role opens
/// [SkillUpNonItRoleSheet] showing its skills and, when linked, a
/// "Start course" action into the real lesson page.
class SkillUpNonItRolesScreen extends StatelessWidget {
  const SkillUpNonItRolesScreen({required this.department, super.key});

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
                    'Pick a role to see the skills it calls for and start its course.',
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
      key: Key('skillup-nonit-role-card-${role.name}'),
      borderRadius: AppRadius.lgRadius,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SkillUpNonItRoleSheet(role: role, department: department),
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
              decoration: BoxDecoration(color: AppColors.action.withValues(alpha: 0.1), borderRadius: AppRadius.mdRadius),
              child: Icon(careerIconFor(department.icon), color: AppColors.action, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  Row(
                    children: [
                      Text(
                        skillCount > 0 ? '$skillCount skills' : 'Skills coming soon',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                      ),
                      if (role.coursePath != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accentDark.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Text(
                            '1 course',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentDark),
                          ),
                        ),
                      ],
                    ],
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
