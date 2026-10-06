import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/roleplay_topic.dart';

/// Per-sub-feature icon/color, read directly from `roleplay_home.html`'s
/// inline `<style>` (`.icon-storytelling`/`.icon-situations`/`.icon-roleplay`)
/// and its `{% if key == 'storytelling' %}auto_stories{% elif key ==
/// 'situations' %}psychology{% else %}theater_comedy{% endif %}` — kept
/// local to this feature rather than added to the shared `ModuleColors`
/// (that file is reserved for the 4 AI modules, per its own doc comment).
(IconData, Color) roleplayTopicIconAndColor(String slug) {
  return switch (slug) {
    'storytelling' => (Icons.auto_stories, const Color(0xFF2563EB)),
    'situations' => (Icons.psychology, const Color(0xFF16A34A)),
    _ => (Icons.theater_comedy, const Color(0xFF9333EA)),
  };
}

/// Mirrors one `.feature-card` (`roleplay_home.html:130-148`): icon badge,
/// title, description, "Start Session" + an examples-count note.
class RoleplayTopicCard extends StatelessWidget {
  const RoleplayTopicCard({required this.topic, required this.onTap, super.key});

  final RoleplayTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = roleplayTopicIconAndColor(topic.slug);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(topic.pageTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text(topic.pageDescription, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              AppButton(label: 'Start Session', fullWidth: false, onPressed: onTap),
              Text('${topic.examples.length} Examples', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
