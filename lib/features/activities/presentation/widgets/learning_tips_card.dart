import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';

/// Mirrors the web sub-activity page's "Learning Tips" card
/// (`templates/activities/sub_activity.html:226-237`) exactly — static
/// content, identical for every sub-activity, not backed by any model
/// field or API data, so it's reproduced here verbatim.
class LearningTipsCard extends StatelessWidget {
  const LearningTipsCard({super.key});

  static const _tips = [
    'Read the instructions carefully before starting.',
    'Complete exercises to reinforce what you learn.',
    'Retry exercises to improve your score.',
    'Mark complete when you feel confident.',
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.accentDark),
              const SizedBox(width: AppSpacing.xs),
              Text('Learning Tips', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final tip in _tips)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: Theme.of(context).textTheme.bodySmall),
                  Expanded(child: Text(tip, style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
