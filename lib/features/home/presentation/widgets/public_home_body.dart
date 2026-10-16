import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import 'home_hero.dart';
import 'home_trust_strip.dart';
import 'portal_card.dart';

/// The guest branch of `{% block content %}` (`templates/landing.html`).
///
/// Phase 37: [HomeHero] and the two [PortalCard] "story" sections (`#job
/// -seeker`/`#employer`, `landing.html:6839-6945`) rebuilt from the actual
/// current web source — see each widget's own doc comment for what changed
/// and why. The CTA labels below changed from "Register Free"/"Register
/// Company" to the real web's "Explore Job Seeker Portal"/"Explore Employer
/// Portal" (`landing.html:6859,6912`), but both still call the exact same
/// [onRegister]/[onEmployerRegister] callbacks as before — only the visible
/// label changed, not the destination. A secondary "Login" text action was
/// added under each primary CTA so [onLogin]/[onEmployerLogin] remain
/// reachable from this screen exactly as before (the real web does not
/// repeat a login link here — it's only in the nav bar — but removing an
/// existing, working action from this screen was out of this phase's
/// scope; `AppNavDrawer` also still has both, unchanged).
///
/// Still out of scope (unchanged by this phase, see
/// `docs/PHASE_37_LANDING_PAGE_UI_REBUILD_REPORT.md` for the full list):
/// the Trust Strip, the career-journey timeline, the Choose-Your-Path
/// cards, the Feature Grid, testimonials, the Final CTA section, and the
/// richer landing-specific footer — each is a separate, undone section of
/// `landing.html`, not something this phase's task list asked for beyond
/// the hero/cards/logo/colors/trust-strip-and-footer-scoping it did cover.
class PublicHomeBody extends StatelessWidget {
  const PublicHomeBody({
    required this.onGetStarted,
    required this.onFindJobs,
    required this.onCreateResume,
    required this.onLogin,
    required this.onRegister,
    required this.onEmployerLogin,
    required this.onEmployerRegister,
    super.key,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onFindJobs;
  final VoidCallback onCreateResume;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onEmployerLogin;
  final VoidCallback onEmployerRegister;

  /// `--grad` — the same vibrant-layer gradient [HomeHero] uses for its
  /// primary CTA; `#job-seeker`'s own `.btn-primary` resolves to the exact
  /// same rule.
  static const _primaryCtaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF185ADB), Color(0xFF7C3AED), Color(0xFFDB2777)],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          HomeHero(
            onGetStarted: onGetStarted,
            onFindJobs: onFindJobs,
            onCreateResume: onCreateResume,
          ),
          const SizedBox(height: AppSpacing.md),
          const HomeTrustStrip(),
          const SizedBox(height: AppSpacing.xl),
          PortalCard(
            eyebrow: 'For job seekers',
            title: 'Built for your career journey',
            description:
                'From your first lesson to your next offer, your Job Seeker Portal keeps everything connected — '
                'learning, resume, interviews and opportunities, all in one dashboard.',
            checklist: const [
              'AI-powered Resume & Interview Preparation',
              'Skills & Training with earned certifications',
              'Job matches based on your real profile',
              'One dashboard to track it all',
            ],
            ctaLabel: 'Explore Job Seeker Portal',
            onCta: onRegister,
            ctaGradient: _primaryCtaGradient,
            ctaFallbackColor: AppColors.action,
            secondaryLabel: 'Login',
            onSecondary: onLogin,
            caption: 'Learn, practice, get hired',
            avatarColors: const [
              Color(0xFF93C5FD),
              Color(0xFFF9A8D4),
              Color(0xFFFCD34D),
            ],
            isDarkVisual: true,
            highlights: const [
              PortalHighlight(
                icon: Icons.description_outlined,
                title: 'Resume & AI',
                description: 'AI feedback on every upload, ATS-ready.',
              ),
              PortalHighlight(
                icon: Icons.school_outlined,
                title: 'Skills & Training',
                description: '20+ activities, 100+ exercises, free to start.',
              ),
              PortalHighlight(
                icon: Icons.videocam_outlined,
                title: 'Interviews',
                description: 'Practice with AI, arrive prepared.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          PortalCard(
            eyebrow: 'For employers',
            title: 'Build your hiring pipeline with CareerBuddy',
            description:
                'Post roles, search verified candidate profiles and manage every application from one dashboard — '
                'built for teams that need to hire quickly without losing quality.',
            checklist: const [
              'Post and manage job openings in minutes',
              'Search candidates by skills, not just keywords',
              'Review every application in one place',
              'Keep your company profile current',
            ],
            ctaLabel: 'Explore Employer Portal',
            onCta: onEmployerRegister,
            ctaFallbackColor: AppColors.primary,
            secondaryLabel: 'Login',
            onSecondary: onEmployerLogin,
            caption: 'Post, screen, hire faster',
            avatarColors: const [
              Color(0xFFF9A8D4),
              Color(0xFFFCD34D),
              Color(0xFF6EE7B7),
            ],
            isDarkVisual: false,
            highlights: const [
              PortalHighlight(
                icon: Icons.work_outline,
                title: 'Manage Jobs',
                description: 'Create and manage postings in one place.',
              ),
              PortalHighlight(
                icon: Icons.search,
                title: 'Find Candidates',
                description: 'Search verified, skills-matched profiles.',
              ),
              PortalHighlight(
                icon: Icons.inbox_outlined,
                title: 'Applications',
                description: 'Review every candidate who applies.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
