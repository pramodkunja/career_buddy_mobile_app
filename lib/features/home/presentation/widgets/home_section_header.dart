import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// `.sec-head` (`templates/landing.html`) — the eyebrow pill + heading +
/// description pattern repeated at the top of every landing-page section
/// this phase adds (Platform Overview, Career Journey, Choose Your Path,
/// Skill Up, Meet Buddy, About CareerBuddy, Resume maker, Tutorials).
/// Factored out once here rather than re-declared in each section widget,
/// per this phase's own "split into reusable widgets" instruction.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    required this.eyebrow,
    required this.title,
    this.description,
    this.centered = false,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final crossAxis = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: crossAxis,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.action.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            eyebrow,
            style: const TextStyle(
              color: AppColors.action,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: textAlign,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description!,
            textAlign: textAlign,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}
