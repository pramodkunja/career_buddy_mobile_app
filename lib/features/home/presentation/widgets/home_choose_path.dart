import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_section_header.dart';

/// `#choose-path`'s default (no `track`) state (`templates/landing.html:
/// 6729-6775`) — "Choose Your Path", 2 cards. Both the real `IT Job Seeker`
/// (`{% url 'career_path' 'it' %}`) and `Non-IT Job Seeker`
/// (`{% url 'career_path' 'non-it' %}`) links lead to department/role
/// browsing on the same landing page. Phase 43 implements that browsing
/// flow for real (`CareerDepartmentsScreen`/`CareerRolesScreen`) —
/// [onItJobSeeker]/[onNonItJobSeeker] now open it with the matching track
/// (`'it'`/`'non-it'`), the same parameter `career_path`'s own URL uses.
///
/// The real default-state section has no `.eyebrow` pill of its own
/// (confirmed directly); "Find your fit" is reused verbatim from the real
/// web's own "Which path suits you?" popup (`landing.html:7579`,
/// `<div class="eyebrow">Find your fit</div>`) covering the same choice,
/// rather than duplicating "Choose Your Path" as both the pill and the
/// heading. Phase 49 implements that popup for real
/// ([HomePathPickerPopup]) — [onItJobSeeker]/[onNonItJobSeeker] are shared
/// between this always-visible section and the popup's own cards (passed
/// through from [HomeScreen]/[PublicHomeBody]), not duplicated.
class HomeChoosePath extends StatelessWidget {
  const HomeChoosePath({
    required this.onItJobSeeker,
    required this.onNonItJobSeeker,
    super.key,
  });

  final VoidCallback onItJobSeeker;
  final VoidCallback onNonItJobSeeker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          eyebrow: 'Find your fit',
          title: 'Choose Your Path',
          description:
              'Select your career path and take the first step towards your future.',
        ),
        const SizedBox(height: AppSpacing.md),
        _PathCard(
          icon: Icons.computer_outlined,
          iconBackground: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF185ADB),
          title: 'IT Job Seeker',
          description:
              'Explore IT roles, build skills and get matched with top opportunities.',
          onTap: onItJobSeeker,
        ),
        const SizedBox(height: AppSpacing.sm),
        _PathCard(
          icon: Icons.groups_outlined,
          iconBackground: const Color(0xFFEDE9FE),
          iconColor: const Color(0xFF7C3AED),
          title: 'Non-IT Job Seeker',
          description:
              'Explore Technical and Non-Technical opportunities beyond IT.',
          onTap: onNonItJobSeeker,
        ),
      ],
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: AppRadius.mdRadius,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
