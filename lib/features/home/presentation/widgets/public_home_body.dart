import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import 'home_hero.dart';
import 'portal_card.dart';

/// The guest branch of `{% block content %}`. Previously mirrored the
/// now-superseded `home.html:1185-1274` (the "for job seekers" / "for
/// clients" portal cards only); Phase 21 adds [HomeHero] above those same
/// cards, matching the updated `landing.html`'s own hero now sitting above
/// its equivalent job-seeker/employer marketing sections
/// (`landing.html:6536-6588` vs `6839-6945`). The portal cards themselves
/// (titles, descriptions, stat numbers) are intentionally left unchanged
/// this phase — see [PortalCard]'s own doc comment for the shared visual
/// spec, and `docs/PHASE_20_HOME_LANDING_PARITY_AUDIT.md` §6 Gap 14 for the
/// stat-number accuracy question this phase does not resolve.
///
/// Out of scope for this batch (§17, and unchanged by Phase 21): the Seven
/// Core Skill Areas, Featured Activities, How It Works, Testimonials, and
/// closing CTA sections further down `home.html`; the updated web's own
/// Trust Strip/Features Grid/Career Journey/Choose-Your-Path/Skill-Up/
/// Why-CareerBuddy/Videos/Stories/Final-CTA sections (confirmed absent from
/// `landing.html` only above/below the hero this phase reproduces).
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          HomeHero(onGetStarted: onGetStarted, onFindJobs: onFindJobs, onCreateResume: onCreateResume),
          const SizedBox(height: AppSpacing.lg),
          PortalCard(
            assetImage: 'assets/images/job_seekers.png',
            badgeIcon: Icons.school_outlined,
            badgeLabel: 'Job Seeker Portal',
            title: 'for job seekers',
            description: 'Learn English, build resumes, & get matched with top employers.',
            actions: [
              PortalCardAction(label: 'Login', icon: Icons.login, onTap: onLogin),
              PortalCardAction(label: 'Register Free', onTap: onRegister, isPrimary: true),
            ],
            stats: const [
              PortalCardStat(number: '20+', label: 'Activities'),
              PortalCardStat(number: '100+', label: 'Exercises'),
              PortalCardStat(number: 'Free', label: 'Access'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PortalCard(
            assetImage: 'assets/images/clients.png',
            badgeIcon: Icons.apartment_outlined,
            badgeLabel: 'Employer Portal',
            title: 'for clients',
            description: 'Post jobs, search verified candidates, & hire in 30 mins.',
            actions: [
              PortalCardAction(label: 'Login', icon: Icons.login, onTap: onEmployerLogin),
              PortalCardAction(label: 'Register Company', onTap: onEmployerRegister, isPrimary: true),
            ],
            stats: const [
              PortalCardStat(number: '1.5L+', label: 'Monthly Reg'),
              PortalCardStat(number: '50L+', label: 'Active Seekers'),
              PortalCardStat(number: '30m', label: 'Hire Time'),
            ],
          ),
        ],
      ),
    );
  }
}
