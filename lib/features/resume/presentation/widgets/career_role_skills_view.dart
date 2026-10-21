import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/career_department.dart';

/// The real "Skills this role requires." view (`itSkills()`,
/// `landing.html:8309-8319`, and the Non-IT `route()` function's own
/// `ri > -1` branch, `:8111-8123`) — one labeled skill-group card per
/// group, with chips, plus the real "Start Learning →" CTA.
///
/// The real CTA deep-links straight to this exact role's Skill Up section
/// (`skill_up?section=role-tech-<dept>--<role>` /
/// `role-nonit-<dept>--<role>`). This app's own Skill Up screen has no
/// per-section deep-link yet (confirmed: `RoutePaths.skillUpSections` only
/// opens the hub's general "Sections in depth" tab) — rather than
/// fabricate a destination that doesn't exist, this button opens that same
/// real, existing Skill Up entry point and is labeled accordingly; see
/// `docs/PHASE_43_IT_NONIT_CAREER_BROWSING_REPORT.md` for why.
class CareerRoleSkillsView extends StatelessWidget {
  const CareerRoleSkillsView({
    required this.role,
    required this.department,
    super.key,
  });

  final CareerRole role;
  final CareerDepartment department;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  department.name,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  role.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Skills this role requires.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      for (final group in role.skillGroups)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _SkillGroupCard(group: group),
                        ),
                      if (role.skillGroups.isEmpty || role.allSkills.isEmpty)
                        const Text(
                          'Skills coming soon.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(RoutePaths.skillUpSections);
                    },
                    icon: const Icon(Icons.arrow_forward, size: 17),
                    label: const Text('Explore Skill Up'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.action,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SkillGroupCard extends StatelessWidget {
  const _SkillGroupCard({required this.group});

  final CareerRoleSkillGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final skill in group.skills)
                Chip(
                  label: Text(skill, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.border),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (group.skills.isEmpty)
                const Text(
                  'Skills coming soon',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
