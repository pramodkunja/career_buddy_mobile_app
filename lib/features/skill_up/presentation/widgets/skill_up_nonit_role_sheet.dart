import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../resume/domain/entities/career_department.dart';
import '../../domain/skill_up_lesson_url.dart';
import '../skill_up_lesson_route_args.dart';

/// Phase 47 — the Non-IT Center's role detail (`initNonIt()`'s `roleView()`):
/// the role's full skill-chip list, plus a "Start course" action when the
/// role has a linked lesson (`role.coursePath`, the JSON's optional 3rd
/// array element) — opens the exact same [SkillUpLessonScreen] every other
/// Skill Up lesson already uses, including its existing locked-content/plan
/// gating (`SkillUpAccessMiddleware` locks every `NonITCenter/**` page to
/// Free-plan users server-side; nothing new is needed here to preserve
/// that).
class SkillUpNonItRoleSheet extends StatelessWidget {
  const SkillUpNonItRoleSheet({required this.role, required this.department, super.key});

  final CareerRole role;
  final CareerDepartment department;

  @override
  Widget build(BuildContext context) {
    final skills = role.allSkills;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(role.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              '${department.name} — the skills this role calls for.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            if (skills.isEmpty)
              const Text('Skills coming soon', style: TextStyle(color: AppColors.textMuted))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final skill in skills)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.action.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(skill, style: const TextStyle(fontSize: 12.5, color: AppColors.action)),
                    ),
                ],
              ),
            if (role.coursePath != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('skillup-nonit-start-course-button'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(
                      RoutePaths.skillUpLesson,
                      extra: SkillUpLessonRouteArgs(title: role.name, url: buildSkillUpLessonUrl(role.coursePath!)),
                    );
                  },
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Start course'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
