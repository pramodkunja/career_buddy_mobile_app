import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';

/// Mirrors the "Writing Topic" card (`writing.html:134-149`): topic text,
/// a writing-type selector, and "New Topic".
class WritingTopicCard extends StatelessWidget {
  const WritingTopicCard({
    required this.topic,
    required this.writingType,
    required this.onNewTopic,
    required this.onTypeChanged,
    super.key,
  });

  final String topic;
  final String writingType;
  final VoidCallback onNewTopic;
  final ValueChanged<String> onTypeChanged;

  static const _typeLabels = {'general': 'General', 'story': 'Story', 'opinion': 'Opinion'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WRITING TOPIC',
            style: theme.textTheme.labelSmall?.copyWith(color: ModuleColors.writing, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(topic, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: writingType,
                  items: _typeLabels.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onTypeChanged(value);
                  },
                ),
              ),
              AppButton(
                label: 'New Topic',
                icon: Icons.sync_alt,
                variant: AppButtonVariant.outlined,
                fullWidth: false,
                onPressed: onNewTopic,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
