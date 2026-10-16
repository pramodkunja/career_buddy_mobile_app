import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_hero.dart';
import 'portal_hero_card.dart';

/// The authenticated branch of `{% block content %}`.
///
/// **Employer session ([isEmployer]): unchanged from the pre-Phase-21
/// behavior**, still mirroring the now-superseded `home.html:1276-1329`
/// (two hero image cards + `Employer Dashboard`/`Find Candidates` CTAs).
/// This is deliberate, not an oversight: the updated web's `home()` view
/// redirects an authenticated employer to `job_home` *before* `landing.html`
/// ever renders (`activities/views.py:79-80`, confirmed directly) — an
/// employer never actually sees the new unified hero on the real site, so
/// nothing about the employer branch needed to change to match it. Card 1
/// ("Learn Business English") always renders for *every* authenticated
/// session including this one — a genuine, confirmed web quirk from the
/// original template, reproduced faithfully rather than "fixed".
///
/// **Student session (`!isEmployer`): replaced in Phase 21.** The old
/// hero-image-cards + "Parse Your Resume"/"My Dashboard"/"Browse
/// Activities" button row (`home.html:1290-1328`'s non-employer branch) is
/// now [HomeHero] — the same unified hero [PublicHomeBody] shows an
/// anonymous visitor, matching the updated web's own hero being identical
/// for anonymous and logged-in-student visitors alike
/// (`landing.html:6536-6588`; only 2 small role-pills vary by auth there,
/// and neither survives into any authenticated view regardless). See
/// `docs/PHASE_21_HOME_HERO_IMPLEMENTATION_REPORT.md` for exactly which
/// existing destination each of the 3 CTAs uses for an already-authenticated
/// student (deliberately not `/users/register/`, since re-registering a
/// logged-in user would make no sense — the task that commissioned this
/// change is explicit on this point).
class AuthenticatedHomeBody extends StatelessWidget {
  const AuthenticatedHomeBody({
    required this.isEmployer,
    required this.onGetStarted,
    required this.onFindJobs,
    required this.onCreateResume,
    required this.onEmployerDashboard,
    required this.onFindCandidates,
    super.key,
  });

  final bool isEmployer;
  final VoidCallback onGetStarted;
  final VoidCallback onFindJobs;
  final VoidCallback onCreateResume;
  final VoidCallback onEmployerDashboard;
  final VoidCallback onFindCandidates;

  @override
  Widget build(BuildContext context) {
    if (isEmployer) {
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
            const PortalHeroCard(
              assetImage: 'assets/images/employer_hiring.png',
              icon: Icons.people_outline,
              label: 'Manage Your Hiring Pipeline',
            ),
            const SizedBox(height: AppSpacing.lg),
            // `.hero-actions .btn` row (`home.html:1310-1328`'s employer branch).
            Column(
              children: [
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
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: HomeHero(
        onGetStarted: onGetStarted,
        onFindJobs: onFindJobs,
        onCreateResume: onCreateResume,
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
            side: outlined
                ? const BorderSide(color: AppColors.border)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
