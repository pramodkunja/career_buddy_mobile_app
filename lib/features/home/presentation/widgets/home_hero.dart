import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

/// The updated web's unified hero (`landing.html:6536-6588`, confirmed by
/// direct source read in Phase 20) — one fixed headline plus 3 primary
/// CTAs, shown to every non-employer visitor regardless of auth state
/// (only 2 small role-pills vary by auth there, `landing.html:6556`; the 3
/// main CTA buttons — "Get Started Free", "Find Jobs", "Create Resume" —
/// are unconditional). This widget reproduces that same fixed, unified
/// structure — it does not itself vary by auth state; callers decide each
/// button's destination (see [PublicHomeBody]/[AuthenticatedHomeBody]).
///
/// The headline/subtitle copy is reproduced (shortened for mobile) from the
/// same section; the 3 CTAs are stacked full-width here rather than the
/// web's horizontal row — every width this app targets is narrower than
/// where that row would still fit without wrapping awkwardly.
class HomeHero extends StatelessWidget {
  const HomeHero({required this.onGetStarted, required this.onFindJobs, required this.onCreateResume, super.key});

  final VoidCallback onGetStarted;
  final VoidCallback onFindJobs;
  final VoidCallback onCreateResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0x40FFFFFF)),
            ),
            child: const Text(
              'AI-powered career platform',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Build skills. Craft capability. Claim your career.',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Professional learning, AI resume tools, interview practice, and skill certifications — '
            'all in one platform.',
            style: TextStyle(color: Color(0xD9FFFFFF)),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.rocket_launch_outlined, size: 18),
              label: const Text('Get Started'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onFindJobs,
              icon: const Icon(Icons.search, size: 18, color: Colors.white),
              label: const Text('Find Jobs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0x80FFFFFF)),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onCreateResume,
              icon: const Icon(Icons.description_outlined, size: 18, color: Colors.white),
              label: const Text('Create Resume', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0x80FFFFFF)),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
