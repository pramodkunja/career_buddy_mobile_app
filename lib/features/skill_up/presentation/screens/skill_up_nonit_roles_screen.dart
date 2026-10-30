import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../resume/domain/entities/career_department.dart';
import '../../../resume/presentation/screens/career_departments_screen.dart'
    show careerIconFor;
import '../providers/skill_up_nonit_role_open_request_provider.dart';
import '../widgets/skill_up_nonit_role_sheet.dart';

/// Phase 47 — the role list inside one Non-IT department
/// (`initNonIt()`'s `deptView()`). Tapping a role opens
/// [SkillUpNonItRoleSheet] showing its skills and, when linked, a
/// "Start course" action into the real lesson page.
///
/// Phase 79 — a `role-nonit-*` deep link
/// (`SkillUpNonItDeepLinkScreen`/[skillUpNonItRoleOpenRequestProvider])
/// opens this same sheet automatically once this screen mounts, matching
/// the real site's own `roleView()` (`initNonIt()`): visiting that id
/// replaces the Non-IT section's content with that role's own dedicated
/// skills/course view, not just a scroll position in a list — the closest
/// Flutter equivalent to "this role's own view" is opening the identical
/// sheet a manual tap already opens, not merely scrolling its card into
/// view (contrast [TechCenterRolesScreen], where the real site's own
/// `role-tech-*` behavior is a plain scroll, so that screen only
/// scrolls-to-visible instead).
class SkillUpNonItRolesScreen extends ConsumerStatefulWidget {
  const SkillUpNonItRolesScreen({required this.department, super.key});

  final CareerDepartment department;

  @override
  ConsumerState<SkillUpNonItRolesScreen> createState() =>
      _SkillUpNonItRolesScreenState();
}

class _SkillUpNonItRolesScreenState
    extends ConsumerState<SkillUpNonItRolesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(skillUpNonItRoleOpenRequestProvider);
      if (pending != null) _openIfPending(pending);
    });
  }

  /// [roleName] matches `CareerRole.name` — already this screen's own role
  /// identity (its cards are keyed by `role.name`). A name that doesn't
  /// match any role in *this* department (e.g. the request was meant for a
  /// different one) is silently ignored — the same graceful "nothing to do"
  /// fallback used everywhere else in this phase.
  void _openIfPending(String roleName) {
    ref.read(skillUpNonItRoleOpenRequestProvider.notifier).clear();
    CareerRole? match;
    for (final role in widget.department.roles) {
      if (role.name == roleName) {
        match = role;
        break;
      }
    }
    if (match == null || !mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          SkillUpNonItRoleSheet(role: match!, department: widget.department),
    );
  }

  @override
  Widget build(BuildContext context) {
    final department = widget.department;
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
        builder: (_) =>
            SkillUpNonItRoleSheet(role: role, department: department),
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
                  Row(
                    children: [
                      Text(
                        skillCount > 0
                            ? '$skillCount skills'
                            : 'Skills coming soon',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                      if (role.coursePath != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentDark.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Text(
                            '1 course',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentDark,
                            ),
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
