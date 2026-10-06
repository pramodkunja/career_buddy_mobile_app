import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/exercise_summary.dart';
import 'exercise_type_style.dart';

/// Mirrors the web sub-activity page's exercise card —
/// `templates/activities/sub_activity.html` — showing the exercise type
/// and, if attempted before, `"Last score: {score}/{max_score}"`.
///
/// `mcq`/`matching`/`bingo`/`fill_blank`/`writing`/`timer` exercises, and —
/// as of W014/W015/W016/W017 — exercises under a Speaking-, Writing-,
/// Listening-, or Reading-module Activity (`isSpeakingModule`/
/// `isWritingModule`/`isListeningModule`/`isReadingModule`, set by the
/// caller from `isSpeakingModuleActivity`/`isWritingModuleActivity`/
/// `isListeningModuleActivity`/`isReadingModuleActivity`) have a working
/// mobile screen. `matching`/`bingo`/`fill_blank`/`writing`/`timer`
/// (W008-W010, W013, Timer) read via HTML extraction rather than a JSON
/// API — see `docs/EXERCISE_FEASIBILITY_AUDIT.md` — but are genuinely
/// working, gradeable screens, not placeholders. Every other type is still
/// tappable — `onTap` is always invoked — but the caller
/// (`SubActivityDetailScreen`) routes it to an honest "not available"
/// explanation instead of a real exercise screen (no JSON API exposes
/// their question content — confirmed by reading every `*_api` view in
/// `activities/views.py`, not assumed).
class ExerciseTile extends StatelessWidget {
  const ExerciseTile({
    required this.exercise,
    required this.onTap,
    this.isSpeakingModule = false,
    this.isWritingModule = false,
    this.isListeningModule = false,
    this.isReadingModule = false,
    super.key,
  });

  final ExerciseSummary exercise;
  final VoidCallback onTap;
  final bool isSpeakingModule;
  final bool isWritingModule;
  final bool isListeningModule;
  final bool isReadingModule;

  bool get _hasWorkingScreen =>
      exercise.exerciseType == 'mcq' ||
      exercise.exerciseType == 'matching' ||
      exercise.exerciseType == 'bingo' ||
      exercise.exerciseType == 'fill_blank' ||
      // W013 — Generic Writing. Note this is `exercise.exerciseType`
      // (the DB's `Exercise.exercise_type` field), distinct from
      // `isWritingModule` below (the *parent Activity's title* matching
      // the AI Writing module) — an AI-module Activity's own exercises
      // also carry `exercise_type == 'writing'` in the DB, but route to
      // the AI Writing screen instead (`isWritingModule` is checked first
      // by the caller, mirroring `get_module_template()`'s own
      // precedence — see `SubActivityDetailScreen`).
      exercise.exerciseType == 'writing' ||
      // Timer ("Timed Activity") — reads via HTML extraction like
      // `matching`/`bingo`/`fill_blank`/`writing` above; captures a spoken
      // answer via on-device speech-to-text within a 60-second per-task
      // window instead of a typed textarea. See `TimerExerciseScreen`.
      exercise.exerciseType == 'timer' ||
      isSpeakingModule ||
      isWritingModule ||
      isListeningModule ||
      isReadingModule;

  @override
  Widget build(BuildContext context) {
    final attempt = exercise.lastAttempt;
    final typeStyle = ExerciseTypeStyle.forType(exercise.exerciseType);

    final card = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // `.exercise-type-icon` (`static/css/style.css:1826-1836`):
              // 48×48, radius 8, a gradient fill distinct per
              // `exercise_type`.
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: typeStyle.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeStyle.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(exercise.exerciseTypeDisplay, style: Theme.of(context).textTheme.bodySmall),
                    if (attempt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Last score: ${attempt.score}/${attempt.maxScore}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.action),
                      ),
                    ],
                  ],
                ),
              ),
              if (attempt != null) _PercentageBadge(percentage: attempt.percentage),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // The web always labels this "Start", regardless of attempt
          // history (`sub_activity.html:148-150`) — it's not a
          // Continue/Review verb on this page.
          if (_hasWorkingScreen)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.play_arrow, size: 16, color: AppColors.action),
                const SizedBox(width: 4),
                Text('Start', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.action)),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Not available in the app yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
                const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
              ],
            ),
        ],
      ),
    );

    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: card);
  }
}

class _PercentageBadge extends StatelessWidget {
  const _PercentageBadge({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 80
        ? AppColors.success
        : percentage >= 50
        ? AppColors.warning
        : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        '$percentage%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
