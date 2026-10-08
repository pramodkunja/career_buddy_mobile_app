import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

/// The web navbar's collapsed-panel content
/// (`templates/base.html:105-218`), reproduced as a `Drawer` — see
/// [AppTopBar]'s doc comment for why a drawer is the faithful mobile
/// equivalent, not an invented pattern.
///
/// The employer branch (`user.isEmployer`) consolidates two *separate* web
/// surfaces into this one drawer, since there's no room on mobile for a
/// second, persistent nav panel: the top navbar's own employer-specific
/// item (`Home`/`Employer Dashboard`, `base.html:131-136` — note "Home"
/// itself is the *same* job-seeker `home()` page for every session, not a
/// distinct employer one; it isn't linked from the top navbar at all,
/// reachable only via post-login/-registration redirect, see
/// `RoutePaths.employerHome`'s doc comment) and the employer sidebar's 6
/// links (`templates/employer_base.html:214-238`, only otherwise shown on
/// pages that extend that separate layout). 5 of these 6 sidebar links are
/// real, built screens (Employer Dashboard, All Applications, Company
/// Profile, Job Openings, Candidate Search); only "Post New Job" still
/// routes to a `ComingSoonScreen` placeholder, deliberately deferred — see
/// `ApiEndpoints.employerJobCreate`'s doc comment for why.
///
/// The Pro badge never shows the web's "ACTIVE" sub-badge
/// (`base.html:168-170`, `user.profile.plan_type`) — that field doesn't
/// exist on this app's [AuthUser] (no profile endpoint yet, see
/// `AuthUser`'s own doc comment) — documented limitation, not fabricated.
/// It's also never shown at all for an employer session, matching the
/// web's own `{% if request.path|slice:":9" != '/employer' %}` check
/// (`base.html:163`) — every one of this drawer's employer destinations is
/// an `/employer...` page.
class AppNavDrawer extends ConsumerWidget {
  const AppNavDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _NavTile(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: () {
                Navigator.of(context).pop();
                context.go(RoutePaths.home);
              },
            ),
            if (user != null && user.isEmployer) ...[
              _NavTile(
                icon: Icons.dashboard_outlined,
                label: 'Employer Dashboard',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(RoutePaths.employerDashboard);
                },
              ),
              _NavTile(icon: Icons.post_add_outlined, label: 'Post New Job', onTap: () => _goComingSoon(context, RoutePaths.employerJobCreate)),
              _NavTile(icon: Icons.description_outlined, label: 'All Applications', onTap: () => _goComingSoon(context, RoutePaths.employerAllApplications)),
              _NavTile(icon: Icons.business_outlined, label: 'Company Profile', onTap: () => _goComingSoon(context, RoutePaths.employerCompanyProfile)),
              _NavTile(icon: Icons.work_outline, label: 'Job Openings', onTap: () => _goComingSoon(context, RoutePaths.employerJobOpenings)),
              _NavTile(icon: Icons.search, label: 'Candidate Search', onTap: () => _goComingSoon(context, RoutePaths.employerSearchCandidates)),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.business, color: Colors.white, size: 16),
                ),
                title: Text(user.username),
                onTap: () => _goComingSoon(context, RoutePaths.employerCompanyProfile),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('Logout', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authControllerProvider.notifier).logout();
                },
              ),
            ] else if (user != null) ...[
              ExpansionTile(
                leading: const Icon(Icons.layers_outlined, color: AppColors.textMuted),
                title: const Text('Skill Up'),
                childrenPadding: const EdgeInsets.only(left: AppSpacing.md),
                children: [
                  _NavTile(icon: Icons.language_outlined, label: 'English & Vocabulary', onTap: () => _goComingSoon(context, RoutePaths.skillUpSections)),
                  _NavTile(icon: Icons.psychology_outlined, label: 'Aptitude', onTap: () => _goComingSoon(context, RoutePaths.skillUpSections)),
                  _NavTile(icon: Icons.code_outlined, label: 'Tech', onTap: () => _goComingSoon(context, RoutePaths.skillUpSections)),
                  _NavTile(icon: Icons.grid_view_outlined, label: 'Browse All', onTap: () => _goComingSoon(context, RoutePaths.skillUpSections)),
                ],
              ),
              _NavTile(icon: Icons.account_tree_outlined, label: 'Sitemap', onTap: () => _goComingSoon(context, RoutePaths.sitemap)),
              _NavTile(icon: Icons.description_outlined, label: 'Resume Parsing', onTap: () => _goComingSoon(context, RoutePaths.resumeBuilder)),
              _NavTile(icon: Icons.spellcheck_outlined, label: 'Grammar', onTap: () => _goComingSoon(context, RoutePaths.grammar)),
              // `jobs_app.views.job_openings` — plain `@login_required` on
              // the real backend (confirmed live), not employer-gated, even
              // though it's reached via the same screen/route the employer
              // sidebar also links — see `RoutePaths.employerJobOpenings`'s
              // doc comment.
              _NavTile(icon: Icons.work_outline, label: 'Job Openings', onTap: () => _goComingSoon(context, RoutePaths.employerJobOpenings)),
              _NavTile(
                icon: Icons.grid_view_rounded,
                label: 'Activities',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(RoutePaths.activities);
                },
              ),
              _NavTile(
                icon: Icons.bar_chart_outlined,
                label: 'Dashboard',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(RoutePaths.dashboard);
                },
              ),
              const Divider(height: 1),
              // `.pro-nav-btn` (`base.html:19-31`) — forced gold, regardless
              // of the app-wide navy default.
              ListTile(
                leading: const Icon(Icons.workspace_premium, color: AppColors.accent),
                title: const Text('Pro', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => _goComingSoon(context, RoutePaths.pro),
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user.username.length >= 2 ? user.username.substring(0, 2).toUpperCase() : user.username.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(user.username),
                onTap: () => _goComingSoon(context, RoutePaths.profile),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('Logout', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authControllerProvider.notifier).logout();
                },
              ),
            ] else ...[
              _NavTile(
                icon: Icons.person_outline,
                label: 'Job Seeker Login',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(RoutePaths.login);
                },
              ),
              _NavTile(
                icon: Icons.apartment_outlined,
                label: 'Employer Login',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(RoutePaths.employerLogin);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _goComingSoon(BuildContext context, String path) {
    Navigator.of(context).pop();
    context.push(path);
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon, color: AppColors.textMuted), title: Text(label), onTap: onTap);
  }
}
