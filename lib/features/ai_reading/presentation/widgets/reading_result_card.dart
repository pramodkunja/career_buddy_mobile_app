import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/reading_analysis_result.dart';
import '../../domain/entities/reading_issue.dart';

/// Mirrors the Evaluation card (`reading.html:179-219`): score out of 25,
/// Mistakes Review, Improved Version, Overall Feedback, then "Try Again".
/// Unlike Speaking/Listening, [result.feedback]/[result.quickTip] are
/// shown **verbatim from the server** — confirmed the web itself does
/// this, not a client-side banding function.
class ReadingResultCard extends StatelessWidget {
  const ReadingResultCard({required this.result, required this.onTryAgain, super.key});

  final ReadingAnalysisResult result;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart, color: ModuleColors.reading),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Evaluation', style: theme.textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Reading Score', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  ),
                  Text(
                    '${result.score25}/25',
                    style: theme.textTheme.headlineSmall?.copyWith(color: ModuleColors.reading),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              Text('Mistakes Review', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Text(result.text, style: theme.textTheme.bodyMedium),
              ),
              if (result.issues.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                for (final issue in result.issues) ...[
                  _IssueTile(issue: issue),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
              const SizedBox(height: AppSpacing.md),
              _Section(icon: Icons.star_border, label: 'Improved Version', color: AppColors.warning, text: result.improvedPassage),
              const SizedBox(height: AppSpacing.md),
              _Section(icon: Icons.mode_comment_outlined, label: 'Overall Feedback', color: AppColors.success, text: result.feedback),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Quick Tip', style: theme.textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(result.quickTip, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Try Again', icon: Icons.refresh, onPressed: onTryAgain),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.label, required this.color, required this.text});

  final IconData icon;
  final String label;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final ReadingIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                child: Text(issue.type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text('"${issue.phrase}"', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(issue.message, style: theme.textTheme.bodySmall),
          if (issue.suggestion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Suggestion: ${issue.suggestion}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.success)),
          ],
        ],
      ),
    );
  }
}
