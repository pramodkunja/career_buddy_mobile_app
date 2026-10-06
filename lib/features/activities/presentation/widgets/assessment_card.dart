import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';

class _AssessmentItem {
  const _AssessmentItem(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;
}

/// Mirrors the web activity-detail page's "Assessment" sidebar card
/// (`templates/activities/detail.html:181-200`) exactly. This content is
/// static — hardcoded in the template, identical for every activity, not
/// backed by any model field or API data — so it's reproduced here as-is,
/// with nothing invented and nothing derived.
class AssessmentCard extends StatelessWidget {
  const AssessmentCard({super.key});

  static const _items = [
    _AssessmentItem(Icons.groups_outlined, AppColors.action, 'Peer evaluation rubrics'),
    _AssessmentItem(Icons.record_voice_over_outlined, AppColors.success, 'Instructor observation'),
    _AssessmentItem(Icons.videogame_asset_outlined, AppColors.warning, 'Interactive exercises'),
    _AssessmentItem(Icons.fact_check_outlined, AppColors.action, 'Self-reflection'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 18, color: AppColors.action),
              const SizedBox(width: AppSpacing.xs),
              Text('Assessment', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(item.icon, size: 16, color: item.color),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(item.label, style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
