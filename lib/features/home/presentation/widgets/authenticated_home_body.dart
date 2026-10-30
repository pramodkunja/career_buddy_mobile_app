import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_about_section.dart';
import 'home_choose_path.dart';
import 'home_hero.dart';
import 'home_tutorials_section.dart';
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
///
/// Phase 72 — the student branch also renders [HomeChoosePath],
/// [HomeAboutSection], and [HomeTutorialsSection] below the hero, closing a
/// gap Phase 71's audit flagged: the nav drawer's "Industries"/"About
/// Us"/"Resources → Tutorials" items navigate here and scroll to these
/// exact sections, but until this phase this branch never rendered them —
/// the scroll had nothing to land on. Confirmed directly from the updated
/// Django source (`activities/views.py`'s `home()`, read in full) that
/// this is a real content gap, not a deliberate site difference: `home()`
/// redirects only an **employer** session away (to `job_home`); every
/// other authenticated (student) session renders the exact same
/// `landing.html` a guest sees, the view's own comment stating plainly
/// that "the same markup serves signed-in and anonymous visitors." These 3
/// sections are reused as-is from [PublicHomeBody]'s own imports — no
/// content was duplicated or invented, and no other guest-only section
/// (Platform Overview, Career Journey, the portal story cards, Meet Buddy,
/// Resume Maker Teaser, Testimonials) was added here: those aren't targets
/// of any nav item this phase's audit named, and adding them would be
/// unrelated content-parity work for the whole Home screen, not the
/// narrow navigation fix this phase scopes. The employer branch is
/// untouched — out of this phase's scope (`home()`'s own redirect means an
/// employer never reaches any of this content on the real site either).
class AuthenticatedHomeBody extends StatelessWidget {
  const AuthenticatedHomeBody({
    required this.isEmployer,
    required this.onGetStarted,
    required this.onFindJobs,
    required this.onCreateResume,
    required this.onEmployerDashboard,
    required this.onFindCandidates,
    required this.onItJobSeeker,
    required this.onNonItJobSeeker,
    this.aboutSectionKey,
    this.choosePathSectionKey,
    this.tutorialsSectionKey,
    super.key,
  });

  final bool isEmployer;
  final VoidCallback onGetStarted;
  final VoidCallback onFindJobs;
  final VoidCallback onCreateResume;
  final VoidCallback onEmployerDashboard;
  final VoidCallback onFindCandidates;

  /// Same destinations [PublicHomeBody]'s own [HomeChoosePath] already
  /// uses (`RoutePaths.careerDepartments`, track `'it'`/`'non-it'`) —
  /// [RoutePaths.careerDepartments] is a member of
  /// [RoutePaths.universalRoutes], so this flow is already just as valid
  /// for an authenticated student as for a guest.
  final VoidCallback onItJobSeeker;
  final VoidCallback onNonItJobSeeker;

  /// See [HomeScrollRequestController]'s own doc comment — `null` unless
  /// [HomeScreen] is wiring up a pending scroll target. Only used in the
  /// non-employer branch below.
  final Key? aboutSectionKey;
  final Key? choosePathSectionKey;
  final Key? tutorialsSectionKey;

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
      child: Column(
        children: [
          HomeHero(
            onGetStarted: onGetStarted,
            onFindJobs: onFindJobs,
            onCreateResume: onCreateResume,
          ),
          const SizedBox(height: AppSpacing.xl),
          HomeChoosePath(
            key: choosePathSectionKey,
            onItJobSeeker: onItJobSeeker,
            onNonItJobSeeker: onNonItJobSeeker,
          ),
          const SizedBox(height: AppSpacing.xl),
          HomeAboutSection(key: aboutSectionKey),
          const SizedBox(height: AppSpacing.xl),
          HomeTutorialsSection(key: tutorialsSectionKey),
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
            side: outlined
                ? const BorderSide(color: AppColors.border)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
