import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/sub_activity_status.dart';
import '../../domain/entities/sub_activity_summary.dart';
import 'status_badge.dart';

/// Mirrors the web activity-detail page's sub-activity card —
/// `templates/activities/detail.html:102-150`: a number badge (a checkmark
/// once completed), title, status badge, exercise count, description,
/// Started/Completed timestamps, and a status-driven CTA
/// (Start/Continue/Review).
class SubActivityTile extends StatelessWidget {
  const SubActivityTile({required this.subActivity, required this.number, required this.onTap, super.key});

  final SubActivitySummary subActivity;

  /// The card's position in the activity's sub-activity list (1-based),
  /// matching the web's `{{ forloop.counter }}` — not `subActivity.order`,
  /// which the web itself doesn't use for this badge either.
  final int number;

  final VoidCallback onTap;

  String get _ctaLabel => switch (subActivity.status) {
    SubActivityStatus.completed => 'Review',
    SubActivityStatus.inProgress => 'Continue',
    SubActivityStatus.notStarted => 'Start',
  };

  IconData get _ctaIcon => switch (subActivity.status) {
    SubActivityStatus.completed => Icons.replay,
    SubActivityStatus.inProgress => Icons.play_arrow,
    SubActivityStatus.notStarted => Icons.arrow_forward,
  };

  Color get _accentColor => switch (subActivity.status) {
    SubActivityStatus.completed => AppColors.success,
    SubActivityStatus.inProgress => AppColors.action,
    SubActivityStatus.notStarted => AppColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NumberBadge(
                  number: number,
                  isCompleted: subActivity.status == SubActivityStatus.completed,
                  color: _accentColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subActivity.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(status: subActivity.status),
                          Text(
                            '${subActivity.exerciseCount} '
                            'Exercise${subActivity.exerciseCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_ctaIcon, size: 18, color: _accentColor),
                    Text(_ctaLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _accentColor)),
                  ],
                ),
              ],
            ),
            if (subActivity.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subActivity.description, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (subActivity.startedAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _TimestampLine(
                icon: Icons.play_circle_outline,
                color: AppColors.action,
                text: 'Started ${formatMonthDayYearTime(subActivity.startedAt!)}',
              ),
            ],
            if (subActivity.completedAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _TimestampLine(
                icon: Icons.event_available_outlined,
                color: AppColors.success,
                text: 'Completed ${formatMonthDayYearTime(subActivity.completedAt!)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.isCompleted, required this.color});

  final int number;
  final bool isCompleted;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: isCompleted
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : Text(
              '$number',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
            ),
    );
  }
}

class _TimestampLine extends StatelessWidget {
  const _TimestampLine({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
