import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/recent_result.dart';

/// Mirrors the web dashboard's "Recent Results" sidebar —
/// `dashboard.html:249-274`, including its `{% empty %}` copy
/// (`dashboard.html:267-271`).
class RecentResultsList extends StatelessWidget {
  const RecentResultsList({required this.results, super.key});

  final List<RecentResult> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const AppCard(
        child: Text('No exercises completed yet.'),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < results.length; i++) ...[
            if (i > 0) const Divider(height: AppSpacing.lg),
            _ResultRow(result: results[i]),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});

  final RecentResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                result.activityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ScoreBadge(score: result.score, maxScore: result.maxScore, percentage: result.percentage),
      ],
    );
  }
}

/// `.score-badge`/`.score-high`/`.score-mid`/`.score-low`
/// (`static/css/style.css:1446-1465`): a solid-fill pill, not a tinted
/// overlay. `.score-mid` is the post-rebrand gold `#FCA311` with **navy**
/// text (the only tier where the web overrides text color away from
/// white) — a literal value here, not `AppColors.warning`, since that
/// token is still the app's pre-rebrand amber and changing it globally
/// would recolor unrelated warning states across the whole app.
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.maxScore, required this.percentage});

  final num score;
  final num maxScore;
  final double percentage;

  static const _gold = Color(0xFFFCA311);

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (percentage >= 80) {
      background = AppColors.success;
      foreground = Colors.white;
    } else if (percentage >= 50) {
      background = _gold;
      foreground = AppColors.primary;
    } else {
      background = AppColors.danger;
      foreground = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        '$score/$maxScore',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}
