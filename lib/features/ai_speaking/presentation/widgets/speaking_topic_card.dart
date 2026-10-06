import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';

/// Mirrors the "Your Topic" card (`speaking.html:333-345`).
class SpeakingTopicCard extends StatelessWidget {
  const SpeakingTopicCard({required this.topic, required this.onNewTopic, super.key});

  final String topic;
  final VoidCallback onNewTopic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR TOPIC',
            style: theme.textTheme.labelSmall?.copyWith(color: ModuleColors.speaking, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(topic, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'New Topic',
            icon: Icons.sync_alt,
            variant: AppButtonVariant.outlined,
            fullWidth: false,
            onPressed: onNewTopic,
          ),
        ],
      ),
    );
  }
}
