import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_section_header.dart';

class _JourneyStep {
  const _JourneyStep(this.icon, this.color, this.title, this.description);
  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

/// `.journey-sec`/`#jrSteps` (`templates/landing.html:6674-6727`) — "Your
/// career journey, step by step", a 6-step horizontal scroller. The real
/// web uses looping GIF illustrations per step (`static/img/journey/*.gif`);
/// reproduced here with a colored icon dot instead, matching this app's
/// existing convention of using Material icons rather than downloading and
/// bundling the web's own illustration assets (the same choice already made
/// throughout `HomeFeatureGrid`/`PortalCard`).
///
/// Horizontal scrolling is used deliberately here, not stacked vertically —
/// this is the one section of the reference whose own layout is already a
/// horizontal track on every width (`.jr-scroller{overflow-x:auto}`,
/// confirmed directly), so scrolling sideways is the faithful mobile
/// adaptation, not a shortcut.
class HomeCareerJourney extends StatelessWidget {
  const HomeCareerJourney({super.key});

  static const _steps = [
    _JourneyStep(
      Icons.lightbulb_outline,
      Color(0xFF7C3AED),
      'Learn',
      'Build professional and communication skills.',
    ),
    _JourneyStep(
      Icons.edit_note,
      Color(0xFF6366F1),
      'Practice',
      'Work through activities, roleplay and AI-scored exercises.',
    ),
    _JourneyStep(
      Icons.badge_outlined,
      Color(0xFF7C3AED),
      'Build Profile',
      'Create your resume and complete your CareerBuddy profile.',
    ),
    _JourneyStep(
      Icons.record_voice_over_outlined,
      Color(0xFFC050F0),
      'Prepare',
      'Run AI mock interviews until you feel ready.',
    ),
    _JourneyStep(
      Icons.travel_explore_outlined,
      Color(0xFF7C3AED),
      'Find Opportunities',
      'Get job matches based on your real profile.',
    ),
    _JourneyStep(
      Icons.celebration_outlined,
      Color(0xFFF4725E),
      'Apply & Grow',
      'Apply, track progress and keep building skills.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          eyebrow: 'Your path on CareerBuddy',
          title: 'Your career journey, step by step',
          description: 'A connected path from first lesson to first offer.',
          centered: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _steps.length,
            separatorBuilder: (context, index) => Container(
              width: 28,
              height: 2,
              margin: const EdgeInsets.only(top: 34),
              color: AppColors.border,
            ),
            itemBuilder: (context, index) {
              final step = _steps[index];
              return SizedBox(
                width: 112,
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: step.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: step.color, width: 2),
                      ),
                      child: Icon(step.icon, color: step.color, size: 28),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.description,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
