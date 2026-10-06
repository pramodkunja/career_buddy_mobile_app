import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';

/// Mirrors the "What Did You Understand?" answer panel
/// (`listening.html:205-214`). Unlike Writing's live char-range gate, the
/// web never disables this button based on live input length — it starts
/// enabled and only validates on tap (`analyzeText()`'s
/// `hasMeaningfulText` check), so this card doesn't show a live counter
/// either. Once evaluated successfully, the form **permanently locks**
/// (`attemptEvaluated`) — [isLocked] disables both the textarea and the
/// button, with no way to resubmit short of restarting the exercise
/// (fetching a fresh `attempt_token`).
class ListeningAnswerCard extends StatelessWidget {
  const ListeningAnswerCard({
    required this.controller,
    required this.isSubmitting,
    required this.isLocked,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final bool isLocked;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18, color: ModuleColors.listening),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('What Did You Understand?', style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            maxLines: 6,
            minLines: 4,
            enabled: !isSubmitting && !isLocked,
            decoration: const InputDecoration(
              hintText: 'Write the story in your own words here...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: isSubmitting ? 'Analyzing…' : (isLocked ? 'Already Submitted' : 'Submit for Analysis'),
            icon: Icons.psychology_outlined,
            isLoading: isSubmitting,
            onPressed: (isSubmitting || isLocked) ? null : onSubmit,
            backgroundColor: ModuleColors.listening,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}
