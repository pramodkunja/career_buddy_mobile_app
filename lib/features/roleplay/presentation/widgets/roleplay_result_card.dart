import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/roleplay_analysis_result.dart';
import '../../domain/entities/roleplay_issue.dart';

/// Mirrors `renderResults()` (`roleplay.html:703-738`): a 4-tile score grid
/// (Overall/Fluency/Grammar/Clarity — `scores.clarity || scores.pronunciation
/// || 0` for the 4th, read verbatim), then a Feedback section. The web
/// shows the raw 0-100-ish score numbers with no "/100" suffix and no
/// separate `score_25` (there is none in this response — see
/// `RoleplayAnalysisResult`'s doc comment) — reproduced the same way here,
/// not converted to a fraction that would misrepresent what the API sent.
///
/// Also shows `issues`/`quick_tip` (real API fields the web itself simply
/// doesn't render) the same way `SpeakingResultCard` shows `ai_speaking`'s
/// issues — extra genuine data, not fabricated.
class RoleplayResultCard extends StatelessWidget {
  const RoleplayResultCard({required this.result, required this.onTryAgain, super.key});

  final RoleplayAnalysisResult result;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scores = result.scores;
    final overall = scores['overall'] ?? 0;
    final fluency = scores['fluency'] ?? 0;
    final grammar = scores['grammar'] ?? 0;
    final clarity = scores['clarity'] ?? scores['pronunciation'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Color(0xFFF59E0B)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Your Analysis', style: theme.textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: _ScoreTile(label: 'Overall', value: overall, color: const Color(0xFFD97706))),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _ScoreTile(label: 'Fluency', value: fluency, color: const Color(0xFF4F46E5))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: _ScoreTile(label: 'Grammar', value: grammar, color: const Color(0xFF059669))),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _ScoreTile(label: 'Clarity', value: clarity, color: const Color(0xFFE11D48))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Feedback', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              // `data.feedback || "Good job practicing!"` — the literal
              // real-web fallback string, not invented.
              Text(
                (result.feedback != null && result.feedback!.trim().isNotEmpty) ? result.feedback! : 'Good job practicing!',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (result.quickTip != null && result.quickTip!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Quick Tip', style: theme.textTheme.titleSmall)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(result.quickTip!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
        if (result.issues.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mistakes Review', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                for (final issue in result.issues) ...[
                  _IssueTile(issue: issue),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Practice Again', icon: Icons.restart_alt, onPressed: onTryAgain),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.value, required this.color});

  final String label;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final RoleplayIssue issue;

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
              Expanded(child: Text('"${issue.phrase}"', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
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
