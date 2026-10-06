import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';

/// Mirrors the "Reading Passage" card (`reading.html:121-143`): level
/// selector, New, passage title, and the passage text itself — always
/// visible from the start, unlike Listening's hidden-until-played story
/// text (confirmed by reading `renderPassage()`: it replaces `passBox`'s
/// content immediately, with no reveal gate).
class ReadingPassageCard extends StatelessWidget {
  const ReadingPassageCard({
    required this.passageTitle,
    required this.passageText,
    required this.level,
    required this.onLevelChanged,
    required this.onNewPassage,
    super.key,
  });

  final String passageTitle;
  final String passageText;
  final int level;
  final ValueChanged<int> onLevelChanged;
  final VoidCallback onNewPassage;

  static const _levelLabels = {1: 'Level 1', 2: 'Level 2', 3: 'Level 3'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'READING PASSAGE',
            style: theme.textTheme.labelSmall?.copyWith(color: ModuleColors.reading, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(passageTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final entry in _levelLabels.entries)
                // `.lvl-btn`/`.lvl-btn.active` (`reading.html:86-91`) — the
                // active state is filled with the module's own orange, not
                // Flutter's default `ChoiceChip` selected color.
                ChoiceChip(
                  label: Text(entry.value, style: TextStyle(color: level == entry.key ? Colors.white : null)),
                  selected: level == entry.key,
                  onSelected: (_) => onLevelChanged(entry.key),
                  selectedColor: ModuleColors.reading,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: level == entry.key ? ModuleColors.reading : const Color(0xFFE2E8F0)),
                ),
              AppButton(
                label: 'New',
                icon: Icons.sync_alt,
                variant: AppButtonVariant.outlined,
                fullWidth: false,
                onPressed: onNewPassage,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // `.passage-box` (`reading.html:27-31`) — a tinted amber box, not
          // the neutral page background.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              passageText,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6, color: const Color(0xFF1C1917)),
            ),
          ),
        ],
      ),
    );
  }
}
