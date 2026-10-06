import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/recommended_job.dart';

/// Mirrors the web dashboard's "Recommended Job Opportunities" card —
/// `dashboard.html:97-151`. The web only renders this card at all when
/// `recommended_jobs` is non-empty (`{% if recommended_jobs %}`); this
/// widget does the same by returning nothing rather than an empty-state
/// message, since an empty list here means "not eligible yet", not "no
/// jobs available".
class RecommendedJobsSection extends StatelessWidget {
  const RecommendedJobsSection({required this.jobs, this.interviewScore, super.key});

  final List<RecommendedJob> jobs;

  /// Shown in the header's "Unlocked with your interview score of X/100"
  /// line (`dashboard.html:108`). Nullable, matching `DashboardData` — the
  /// web only ever shows it when the recommendations exist in the first
  /// place, which is the same condition that makes this section render.
  final num? interviewScore;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();

    // `<div class="card border-0 rounded-4 shadow-sm p-4 mb-4 bg-white">`
    // (`dashboard.html:97`) — the whole section (header + every job card)
    // sits inside ONE outer white, radius-16, border-0, light-shadow card,
    // not loose in the page.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // `dashboard.html:101-104`: a 36×36 green circle with a
              // briefcase icon — decorative, not data-driven.
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.work_outline, color: Color(0xFF15803D), size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recommended Job Opportunities', style: Theme.of(context).textTheme.titleMedium),
                    if (interviewScore != null)
                      Text(
                        'Unlocked with your interview score of $interviewScore/100 — '
                        'matched to your experience & skills.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _MatchedJobsBadge(count: jobs.length),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final job in jobs) ...[
            _JobCard(job: job),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _MatchedJobsBadge extends StatelessWidget {
  const _MatchedJobsBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count Matched Job${count == 1 ? '' : 's'}',
        // `rgba(252,163,17,.16)` bg / `#a86a08` text (`dashboard.html:111`)
        // — the exact inline literal, not `AppColors.accentDark`
        // (`#E0900C`), which is close but not identical.
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFFA86A08)),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final RecommendedJob job;

  @override
  Widget build(BuildContext context) {
    // Matches the web card, which only ever shows the first 3 skills
    // (`dashboard.html:128`, `{{ job.get_skills_list|slice:":3" }}`).
    final visibleSkills = job.skills.take(3);

    // `.border.rounded-3.p-3.h-100.overflow-hidden` (`dashboard.html:119`)
    // — a plain 1px-bordered, radius-8 card with NO shadow (unlike the
    // app's usual `AppCard`, which always adds one) and no custom
    // background (it inherits the outer card's white).
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `job-logo` (`dashboard.html:121`): a bare navy icon, no
          // surrounding box/circle — confirmed no `.job-logo` CSS rule
          // exists anywhere in style.css.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.apartment_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: Theme.of(context).textTheme.titleMedium),
                    Text(job.companyName, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: visibleSkills.map((s) => _SkillBadge(label: s)).toList(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaItem(icon: Icons.location_on_outlined, text: job.location),
              _JobTypeBadge(label: job.jobType),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _MetaItem(icon: Icons.timeline_outlined, text: job.experienceLevel),
          const SizedBox(height: AppSpacing.xs),
          // `.p-2.rounded.bg-light.border` (`dashboard.html:139-141`): a
          // bordered, light-gray box wrapping the bold green salary text —
          // not plain unboxed text.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border.all(color: const Color(0xFFE5E5E5)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              job.salaryDisplay,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'View & Apply',
            icon: Icons.send_outlined,
            onPressed: () => context.push(RoutePaths.jobDetail),
          ),
        ],
      ),
    );
  }
}

/// `badge bg-light text-dark border` (`dashboard.html:129`) — a bordered,
/// light-gray Bootstrap badge, not a Material `Chip`.
class _SkillBadge extends StatelessWidget {
  const _SkillBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// `badge bg-primary bg-opacity-10 text-primary` (`dashboard.html:134`) —
/// a 10%-opacity navy-tinted badge, not plain icon+muted-text.
class _JobTypeBadge extends StatelessWidget {
  const _JobTypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
