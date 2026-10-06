import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/listening_analysis_result.dart';
import '../../domain/entities/listening_issue.dart';
import '../../domain/services/listening_feedback.dart';

/// Mirrors the Mistakes Review + Evaluation cards
/// (`listening.html:216-257`). [feedback]/[quickTip] are **not** the
/// server's raw `feedback`/`quick_tip` strings — they're computed here
/// via `buildListeningFeedback`/`buildListeningQuickTip`, driven by the
/// server's authoritative `contentMatchPercent`, exactly mirroring
/// `analyzeText()`'s own client-side banding (see `listening_feedback.dart`'s
/// doc comment for why this differs from both Speaking and Writing).
class ListeningResultCard extends StatelessWidget {
  const ListeningResultCard({required this.result, required this.onTryAgain, super.key});

  final ListeningAnalysisResult result;

  /// `<button ... onclick="location.reload()">Try Again</button>`
  /// (`listening.html:251-254`) — a full page reload, which is exactly
  /// what `AiListeningController.retry()` does (re-fetches a fresh
  /// attempt token and resets to a new Ready state).
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedback = buildListeningFeedback(
      matchPercent: result.contentMatchPercent,
      issues: result.issues,
      fallbackFeedback: result.feedback,
    );
    final quickTip = buildListeningQuickTip(matchPercent: result.contentMatchPercent, issues: result.issues);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Mistakes Review', style: theme.textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Text(result.text.isEmpty ? 'No response to evaluate.' : result.text, style: theme.textTheme.bodyMedium),
              ),
              if (result.issues.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                for (final issue in result.issues) ...[
                  _IssueTile(issue: issue),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
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
                  const Icon(Icons.bar_chart, color: ModuleColors.listening),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Evaluation', style: theme.textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Total Score', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  ),
                  Text(
                    '${result.score25}/25',
                    style: theme.textTheme.headlineSmall?.copyWith(color: ModuleColors.listening),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Content Match', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  ),
                  Text('${result.contentMatchPercent}% Match', style: theme.textTheme.titleSmall),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              _Section(icon: Icons.star_border, label: 'Improved Version', color: AppColors.warning, text: result.improvedPassage),
              const SizedBox(height: AppSpacing.md),
              _Section(icon: Icons.mode_comment_outlined, label: 'Overall Feedback', color: AppColors.success, text: feedback),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Try Again', icon: Icons.refresh, variant: AppButtonVariant.outlined, onPressed: onTryAgain),
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
              Text(quickTip, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
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

  final ListeningIssue issue;

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
