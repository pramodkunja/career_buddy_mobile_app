import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// `<footer id="contact">` (`templates/landing.html:7349-7402`) — the
/// landing page's **own** footer, not the shared `base.html` one
/// [AppFooter] models. Phase 37: confirmed by direct inspection that
/// `landing.html` has no `{% extends %}` at all — it is a fully standalone
/// template with its own `<body>`/`<main>`/`<footer>` — so on the real
/// site, the home page shows **only** this richer footer, never the
/// simpler navy one. [HomeScreen] replaces [AppFooter] with this widget
/// accordingly, rather than showing both (which this phase's own task list
/// warned against — "do not allow it to dominate the page").
///
/// Background is `footer`'s final, active rule
/// (`linear-gradient(180deg,#14213d,#0b1226)` — a later override of the
/// earlier plain `var(--navy)`), the same gradient pair already used
/// elsewhere in this app as [AppColors.primary]/[AppColors.primaryDark].
///
/// Of the real footer's 18 links, 16 map to an existing Flutter
/// destination and are reproduced below with that exact destination,
/// unchanged. The remaining 2 — "About Us" (`#why`) and "Ask Buddy"
/// (`#buddy`) — are anchors to in-page sections with no distinct Flutter
/// screen; "Ask Buddy" in particular already has a mobile equivalent in
/// spirit (the persistent [BuddyChatbotOverlay] floating on every screen,
/// not a separate destination to navigate to), so neither is reproduced as
/// a link here rather than inventing a destination or a placeholder
/// screen — see `docs/PHASE_37_LANDING_PAGE_UI_REBUILD_REPORT.md` for the
/// full link-by-link mapping.
class HomeLandingFooter extends StatelessWidget {
  const HomeLandingFooter({
    required this.onFindJobs,
    required this.onRegister,
    required this.onEmployerLogin,
    required this.onEmployerRegister,
    super.key,
  });

  final VoidCallback onFindJobs;
  final VoidCallback onRegister;
  final VoidCallback onEmployerLogin;
  final VoidCallback onEmployerRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/logo-mark-light.png',
                width: 28,
                height: 28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                  children: const [
                    TextSpan(text: 'Career'),
                    TextSpan(
                      text: 'Buddy',
                      style: TextStyle(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'CareerBuddy brings professional learning, AI resume tools, interview practice and skill '
            'certifications together — so you walk into every interview ready, and every hiring decision easier.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _FooterColumn(
            title: 'Platform',
            links: [
              _FooterLink('Skill Up', () => context.push(RoutePaths.skillUp)),
              _FooterLink(
                'Activities',
                () => context.push(RoutePaths.activities),
              ),
              _FooterLink(
                'Resume Parsing',
                () => context.push(RoutePaths.resumeBuilder),
              ),
              _FooterLink('Grammar', () => context.push(RoutePaths.grammar)),
              _FooterLink('Sitemap', () => context.push(RoutePaths.sitemap)),
            ],
          ),
          _FooterColumn(
            title: 'Job Seekers',
            links: [
              _FooterLink('Find Jobs', onFindJobs),
              _FooterLink(
                'Resume & AI',
                () => context.push(RoutePaths.resumeBuilder),
              ),
              _FooterLink(
                'Interviews',
                () => context.push(RoutePaths.resumeBuilder),
              ),
              _FooterLink(
                'Skills & Training',
                () => context.push(RoutePaths.skillUp),
              ),
              _FooterLink('Create Account', onRegister),
            ],
          ),
          _FooterColumn(
            title: 'Employers',
            links: [
              _FooterLink('Employer Dashboard', onEmployerLogin),
              _FooterLink('Manage Jobs', onEmployerLogin),
              _FooterLink('Candidates', onEmployerLogin),
              _FooterLink('Applications', onEmployerLogin),
              _FooterLink('Register Company', onEmployerRegister),
            ],
          ),
          _FooterColumn(
            title: 'Company',
            links: [
              _FooterLink(
                'CareerBuddy Pro',
                () => context.push(RoutePaths.pro),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: Color(0x1AFFFFFF), height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: AppSpacing.xs,
            children: const [
              Text(
                '© 2026 CareerBuddy. All rights reserved.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
              ),
              Text(
                'careerbuddy4u.com',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLink> links;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: InkWell(
                onTap: link.onTap,
                child: Text(
                  link.label,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
