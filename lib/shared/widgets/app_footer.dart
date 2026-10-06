import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// `.site-footer` (`templates/base.html:249-281`,
/// `static/css/style.css:322-357,2768-2782`) — navy background (`--dark`'s
/// final value, `#14213D`, same as [AppColors.primary]), a 3px gold top
/// border, brand/tagline, a student-only stats strip, and copyright.
///
/// [showActivityStats] mirrors the web's own conditional
/// (`base.html:267`, `{% if not request.session.portal == 'employer' and
/// not user.employer_profile and ... %}`) — hidden for employer sessions
/// and on the employer login/register pages (Batch 5B callers pass
/// `false`).
///
/// [showBrandIcon] mirrors the employer-page-specific CSS override
/// (`.site-footer .footer-brand svg{display:none!important}`, present on
/// every employer template — `templates/employer_login/login.html:6-10`,
/// `signup.html:7-11`, `jobs/employer_home.html:8-12`,
/// `employer_base.html:6-9`) — the brand *icon* is hidden, but the
/// "Career Buddy" text next to it stays.
class AppFooter extends StatelessWidget {
  const AppFooter({this.showActivityStats = true, this.showBrandIcon = true, super.key});

  final bool showActivityStats;
  final bool showBrandIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(top: BorderSide(color: AppColors.accent, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // `.footer-brand` logo (`base.html:254-259`) — the same navy
              // square + white book-icon mark used on the navbar/login.
              if (showBrandIcon) ...[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
                  child: const Icon(Icons.school_outlined, color: AppColors.primary, size: 14),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text.rich(
                TextSpan(
                  style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  children: const [
                    TextSpan(text: 'Career '),
                    TextSpan(text: 'Buddy', style: TextStyle(color: AppColors.accent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Master Business English for the global workplace',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
          if (showActivityStats) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _FooterStat(icon: Icons.menu_book_outlined, label: 'Activities'),
                _FooterStat(icon: Icons.checklist_outlined, label: 'Sub-Activities'),
                _FooterStat(icon: Icons.sports_esports_outlined, label: 'Interactive Exercises'),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '© 2026 Career Buddy. All rights reserved.',
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0x99FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xBFFFFFFF)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xBFFFFFFF))),
      ],
    );
  }
}
