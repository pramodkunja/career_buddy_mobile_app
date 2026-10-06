import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import 'portal_card.dart';

/// The guest branch of `{% block content %}` (`templates/home.html:1185-1274`)
/// — the "for job seekers" / "for clients" portal cards. Copy (titles,
/// descriptions, stat numbers) is reproduced verbatim from the template;
/// see [PortalCard]'s own doc comment for the shared visual spec.
///
/// Out of scope for this batch (§17): the Seven Core Skill Areas,
/// Featured Activities, How It Works, Testimonials, and closing CTA
/// sections further down `home.html` — none of those are in the Batch 5A
/// checklist, and `featured_activities` in particular isn't data this
/// app has a way to fetch yet.
class PublicHomeBody extends StatelessWidget {
  const PublicHomeBody({required this.onLogin, required this.onRegister, required this.onEmployerLogin, required this.onEmployerRegister, super.key});

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
