import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/tech_center_catalog.dart';
import '../../domain/skill_up_lesson_url.dart';
import '../skill_up_lesson_route_args.dart';

/// Phase 76 — a Tech Center role's course list, mirroring
/// [SkillUpNonItRoleSheet]'s own "sheet with a Start-course action" shape.
/// Unlike a Non-IT role (at most one linked course), a Tech Center role can
/// have 1-5 real courses, so this lists one "Start course" row per course
/// rather than a single button — every row opens the exact same
/// [SkillUpLessonScreen] every other Skill Up lesson already uses,
/// including its existing locked-content/plan gating
/// (`SkillUpAccessMiddleware` gates `TechCenter/**` server-side; nothing
/// new is needed here to preserve that).
///
/// Phase 77 — confirmed, reproducible overflow fix: a 5-course role (a real
/// case — e.g. "VP Sales & Marketing / Chief Commercial Officer") combined
/// with a long title overflowed this sheet on a short/landscape viewport,
/// since the content was a plain, non-scrolling `Column`. Wrapped in a
/// `SingleChildScrollView` so it scrolls instead of overflowing whenever the
/// sheet is given less height than the content needs — the common,
/// shorter-role case is unaffected (nothing to scroll).
class TechCenterRoleSheet extends StatelessWidget {
  const TechCenterRoleSheet({required this.role, super.key});

  final TechCenterRole role;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(role.category, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            for (final course in role.courses)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CourseRow(role: role, course: course),
              ),
          ],
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.role, required this.course});

  final TechCenterRole role;
  final TechCenterCourse course;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('tech-center-course-row-${role.slug}-${course.relativePath}'),
      borderRadius: AppRadius.mdRadius,
      onTap: () {
        Navigator.of(context).pop();
        context.push(
          RoutePaths.skillUpLesson,
          extra: SkillUpLessonRouteArgs(title: course.title, url: buildSkillUpLessonUrl(course.relativePath)),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.action.withValues(alpha: 0.06),
          borderRadius: AppRadius.mdRadius,
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, color: AppColors.action, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(course.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
