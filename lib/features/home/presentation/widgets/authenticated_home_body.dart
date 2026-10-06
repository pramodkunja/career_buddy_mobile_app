import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import 'portal_hero_card.dart';

/// The authenticated branch of `{% block content %}`
/// (`templates/home.html:1276-1329`) — the two hero image cards plus the
/// action-button row below them.
///
/// Card 1 ("Learn Business English") always renders, for *every*
/// authenticated session including an employer one — confirmed directly
/// from the template: it isn't inside the `{% if user.employer_profile %}`
/// branch at all, only card 2 and the CTA row are. A genuine web quirk
/// (an employer sees a "Learn Business English" card too), reproduced
/// faithfully rather than "fixed".
///
/// [isEmployer] branches card 2 (`portal-hero-card-hiring`, "Manage Your
/// Hiring Pipeline" vs `portal-hero-card-applying`, "Apply for Your Dream
/// Job") and the CTA row (`Employer Dashboard`/`Find Candidates` vs `Parse
/// Your Resume`/`My Dashboard`/`Browse Activities`) exactly like
/// `home.html:1290-1328`'s own `{% if user.employer_profile %}`.
class AuthenticatedHomeBody extends StatelessWidget {
  const AuthenticatedHomeBody({
    required this.isEmployer,
    required this.onParseResume,
    required this.onDashboard,
    required this.onBrowseActivities,
    required this.onEmployerDashboard,
    required this.onFindCandidates,
    super.key,
  });

  final bool isEmployer;
  final VoidCallback onParseResume;
  final VoidCallback onDashboard;
  final VoidCallback onBrowseActivities;
  final VoidCallback onEmployerDashboard;
  final VoidCallback onFindCandidates;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const PortalHeroCard(
            assetImage: 'assets/images/student_learning.png',
            icon: Icons.menu_book_outlined,
            label: 'Learn Business English',
          ),
          const SizedBox(height: AppSpacing.md),
          if (isEmployer)
            const PortalHeroCard(
              assetImage: 'assets/images/employer_hiring.png',
              icon: Icons.people_outline,
              label: 'Manage Your Hiring Pipeline',
            )
          else
            const PortalHeroCard(
              assetImage: 'assets/images/student_job_applying.png',
              icon: Icons.work_outline,
              label: 'Apply for Your Dream Job',
            ),
          const SizedBox(height: AppSpacing.lg),
          // `.hero-actions .btn` row (`home.html:1310-1329`).
          Column(
            children: isEmployer
                ? [
                    _HeroActionButton(
                      label: 'Employer Dashboard',
                      icon: Icons.dashboard_outlined,
                      onTap: onEmployerDashboard,
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _HeroActionButton(
                      label: 'Find Candidates',
                      icon: Icons.search,
                      onTap: onFindCandidates,
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.primary,
                      outlined: true,
                    ),
                  ]
                : [
                    _HeroActionButton(
                      label: 'Parse Your Resume',
                      icon: Icons.description_outlined,
                      onTap: onParseResume,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _HeroActionButton(
                      label: 'My Dashboard',
                      icon: Icons.show_chart,
                      onTap: onDashboard,
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _HeroActionButton(
                      label: 'Browse Activities',
                      icon: Icons.grid_view_rounded,
                      onTap: onBrowseActivities,
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.primary,
                      outlined: true,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: outlined ? 0 : 2,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: outlined ? const BorderSide(color: AppColors.border) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
