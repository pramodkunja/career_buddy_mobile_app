import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/tech_center_catalog.dart';
import '../widgets/tech_center_role_sheet.dart';

/// Phase 76 — the role list inside one Tech Center department. Tapping a
/// role opens [TechCenterRoleSheet] showing its courses — mirrors
/// [SkillUpNonItRolesScreen]'s own role-card-opens-a-sheet shape for the
/// structurally identical Non-IT department/role drill-down.
///
/// Phase 79 — [highlightRoleSlug], set only by a `role-tech-*` deep link
/// (`app_router.dart`'s own `skillUpSections` builder, which already has
/// the resolved [TechCenterRole] in hand synchronously), scrolls that one
/// role's card into view once this screen mounts. The real site's own
/// `role-tech-*` behavior (confirmed in Phase 79's audit) is a plain
/// `scrollIntoView` on an already-fully-rendered page — this is the closest
/// Flutter equivalent, not an auto-opened sheet (contrast
/// [SkillUpNonItRolesScreen], whose own Non-IT deep link *does* auto-open
/// one, because the real site's Non-IT behavior is genuinely different —
/// see that class's own doc comment).
class TechCenterRolesScreen extends StatefulWidget {
  const TechCenterRolesScreen({
    required this.department,
    this.highlightRoleSlug,
    super.key,
  });

  final TechCenterDepartment department;
  final String? highlightRoleSlug;

  @override
  State<TechCenterRolesScreen> createState() => _TechCenterRolesScreenState();
}

class _TechCenterRolesScreenState extends State<TechCenterRolesScreen> {
  final _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.highlightRoleSlug == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlightKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final department = widget.department;
    return Scaffold(
      appBar: AppBar(title: Text(department.title)),
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
          // A plain, eager `Column` rather than a `ListView` — up to 11
          // roles is a small, bounded list (same reasoning already used for
          // the nav drawer, `app_nav_drawer.dart`), and a lazily-virtualized
          // `ListView` can leave an off-screen role's card unbuilt, which
          // would make `Scrollable.ensureVisible` above a no-op for it.
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Pick a role to see its courses.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  for (final role in department.roles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _RoleCard(
                        key: role.slug == widget.highlightRoleSlug
                            ? _highlightKey
                            : null,
                        role: role,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, super.key});

  final TechCenterRole role;

  @override
  Widget build(BuildContext context) {
    final courseCount = role.courses.length;
    return InkWell(
      key: Key('tech-center-role-card-${role.slug}'),
      borderRadius: AppRadius.lgRadius,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => TechCenterRoleSheet(role: role),
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
              child: const Icon(
                Icons.badge_outlined,
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
                    role.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          role.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
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
                        child: Text(
                          courseCount == 1
                              ? '1 course'
                              : '$courseCount courses',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
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
