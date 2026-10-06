import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';

/// `.bingo-header` (`static/css/exercises.css:176-185`): the word/
/// definition display on the left, Start/Restart + Next Word controls on
/// the right — wraps to a stacked column on narrow widths (`flex-wrap:
/// wrap` on the web; here via `Wrap`/`Column` at the same intent).
class BingoHeader extends StatelessWidget {
  const BingoHeader({
    required this.currentWordText,
    required this.roundText,
    required this.startLabel,
    required this.onStart,
    required this.onNext,
    super.key,
  });

  /// `#bingo-current-word` — despite the id, this shows the **definition**
  /// text during play (`wordEl.textContent = w.definition`,
  /// `static/js/exercises.js:555`), not the word itself.
  final String currentWordText;

  /// `#bingo-definition` — actually the round counter ("Word X of Y"),
  /// despite ITS id (the web's own ids are swapped from what they display
  /// — verified directly, not a typo introduced here).
  final String roundText;

  final String startLabel;
  final VoidCallback onStart;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Definition:',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(currentWordText, style: Theme.of(context).textTheme.titleMedium),
          if (roundText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(roundText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(label: startLabel, variant: AppButtonVariant.outlined, fullWidth: true, onPressed: onStart),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(label: 'Next Word', fullWidth: true, onPressed: onNext),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
