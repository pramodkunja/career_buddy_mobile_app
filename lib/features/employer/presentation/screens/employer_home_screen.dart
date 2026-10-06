import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../home/presentation/widgets/portal_hero_card.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';

/// `templates/jobs/employer_home.html` (`jobs_app.views.home`, the
/// "Recruiter Portal Landing Page" — its own view docstring) — the real
/// redirect target after employer login/registration
/// (`redirect('job_home')`). `total_jobs`/`total_companies` are computed by
/// the view (`jobs_app/views.py:342-351`) but never referenced anywhere in
/// this template (grep-confirmed) — dead context, not ported.
///
/// Reuses [PortalHeroCard] (`.portal-hero-card`/`.portal-hero-overlay`/
/// `.portal-hero-label`, `employer_home.html:40-56`) — the exact same
/// component/CSS classes as the student Home screen's authenticated hero
/// cards (Batch 5A), just different image/icon/label, confirmed by reading
/// both templates.
class EmployerHomeScreen extends ConsumerWidget {
  const EmployerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isAuthenticated = authState is AuthAuthenticated;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      const PortalHeroCard(
                        assetImage: 'assets/images/employer_hiring.png',
                        icon: Icons.manage_search,
                        label: 'Screen Top Candidates with AI',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const PortalHeroCard(
                        assetImage: 'assets/images/employer_interview.png',
                        icon: Icons.handshake_outlined,
                        label: 'Build Your Dream Team',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (isAuthenticated) ...[
                        _HomeActionButton(
                          label: 'Manage Dashboard',
                          icon: Icons.dashboard_outlined,
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          onTap: () => context.go(RoutePaths.employerDashboard),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _HomeActionButton(
                          label: 'Find Candidates',
                          icon: Icons.search,
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.primary,
                          outlined: true,
                          onTap: () => context.push(RoutePaths.employerSearchCandidates),
                        ),
                      ] else ...[
                        _HomeActionButton(
                          label: 'Join as Recruiter',
                          icon: Icons.person_add_outlined,
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          onTap: () => context.push(RoutePaths.employerRegister),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _HomeActionButton(
                          label: 'Employer Login',
                          icon: Icons.login,
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.primary,
                          outlined: true,
                          onTap: () => context.push(RoutePaths.employerLogin),
                        ),
                      ],
                    ],
                  ),
                ),
                const _HowItWorksSection(),
                const AppFooter(showActivityStats: false, showBrandIcon: false),
              ],
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
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

/// `.how-section` / "How It Works" (`employer_home.html:84-119`) — 3 steps,
/// verbatim copy.
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  static const _steps = [
    (
      icon: Icons.description_outlined,
      title: 'Post Your Job',
      body: "Describe your requirements and the skills you're looking for in your ideal candidate.",
    ),
    (
      icon: Icons.psychology_outlined,
      title: 'AI-Powered Screening',
      body: 'Our system automatically parses resumes and scores candidates based on your specific criteria.',
    ),
    (
      icon: Icons.how_to_reg_outlined,
      title: 'Direct Hire',
      body: 'Review shortlisted profiles, contact top candidates, and build your dream team effortlessly.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x146366F1),
              border: Border.all(color: const Color(0x336366F1)),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Text(
              'SIMPLE WORKFLOW',
              style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'How It Works',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          const SizedBox(height: 6),
          Text(
            'A streamlined process to find and hire the best talent',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _HowCard(step: i + 1, icon: _steps[i].icon, title: _steps[i].title, body: _steps[i].body),
          ],
        ],
      ),
    );
  }
}

class _HowCard extends StatelessWidget {
  const _HowCard({required this.step, required this.icon, required this.title, required this.body});

  final int step;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$step',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Icon(icon, size: 32, color: const Color(0xFF6366F1)),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
