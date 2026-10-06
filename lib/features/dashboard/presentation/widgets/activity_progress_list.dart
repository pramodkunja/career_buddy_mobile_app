import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/activity_progress.dart';

/// Mirrors the web dashboard's activity-progress list —
/// `dashboard.html:153-200`, including its `{% empty %}` copy and "Start
/// Learning" CTA (`dashboard.html:192-197`).
class ActivityProgressList extends StatelessWidget {
  const ActivityProgressList({required this.activities, this.onTapActivity, this.onStartLearning, super.key});

  final List<ActivityProgress> activities;

  /// Called with the tapped activity's id, if the caller wants tiles to
  /// navigate (e.g. to the Activities feature's detail screen). Omitted in
  /// contexts where tapping shouldn't navigate.
  final void Function(int activityId)? onTapActivity;

  /// The empty state's "Start Learning" button (`{% url 'activity_list' %}`
  /// on the web). Omitted in contexts where the button shouldn't navigate.
  final VoidCallback? onStartLearning;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No activities started yet.'),
            if (onStartLearning != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Start Learning', fullWidth: false, onPressed: onStartLearning),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final activity in activities) ...[
          _ActivityTile(activity: activity, onTap: onTapActivity),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, this.onTap});

  final ActivityProgress activity;
  final void Function(int activityId)? onTap;

  static const _gold = Color(0xFFFCA311);

  /// `text-success`/`bg-success` at 100%, `text-warning`/`bg-warning`
  /// (post-rebrand gold) above 0%, `text-muted`/`bg-secondary` at 0% —
  /// the exact tiers in `templates/dashboard.html:172-178`.
  Color _tierColor(num completionRate) {
    if (completionRate == 100) return AppColors.success;
    if (completionRate > 0) return _gold;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final percent = (activity.completionRate.clamp(0, 100)) / 100;
    final tierColor = _tierColor(activity.completionRate);
    final onTap = this.onTap;

    final card = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(activity.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: tierColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    children: [
                      TextSpan(
                        text: '${activity.completedSubActivities}/${activity.totalSubActivities} completed • ',
                      ),
                      TextSpan(
                        text: '${activity.completionRate.round()}%',
                        style: TextStyle(color: tierColor, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (activity.startedAt != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.action),
                const SizedBox(width: 4),
                Text(
                  'Started ${formatMonthDayYear(activity.startedAt!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.action),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: () => onTap(activity.activityId),
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}
