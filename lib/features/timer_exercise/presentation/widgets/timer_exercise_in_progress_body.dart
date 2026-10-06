import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../activities/domain/entities/exercise_attempt.dart';
import '../controllers/timer_exercise_controller.dart';

/// Mirrors the web's `timer` branch (`templates/activities/exercise.html:
/// 322-383`): one task visible at a time, a 60-second countdown ring,
/// Start/Stop controls, live transcript + word count, and a Submit action
/// once every task is complete.
class TimerExerciseInProgressBody extends StatelessWidget {
  const TimerExerciseInProgressBody({required this.state, required this.controller, this.previousAttempt, super.key});

  final TimerExerciseInProgress state;
  final TimerExerciseController controller;

  /// Mirrors the web's "Previous Score" sidebar (`all_attempts.0`) — same
  /// reasoning as `GenericWritingInProgressBody`'s own previous-score card.
  final ExerciseAttempt? previousAttempt;

  @override
  Widget build(BuildContext context) {
    final listening = state.phase == TimerTaskPhase.listening;
    final taskDone = state.currentTaskCompleted;
    final task = state.currentTask;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (previousAttempt != null) ...[
                _PreviousScoreCard(attempt: previousAttempt!),
                const SizedBox(height: AppSpacing.md),
              ],
              _TaskDots(state: state, onTapDot: controller.goToTask),
              const SizedBox(height: AppSpacing.lg),
              Center(child: _CountdownRing(secondsLeft: state.secondsLeft, listening: listening)),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Task ${state.taskIndex + 1}: ${task.questionText}', style: theme.textTheme.titleMedium),
                    if (task.guide != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(task.guide!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                    ],
                    if (listening || taskDone) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        state.liveTranscript.isEmpty ? 'Listening...' : state.liveTranscript,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        taskDone
                            ? '${state.currentWordCount} words recorded'
                            : '${state.currentWordCount} words',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                    if (state.speechError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(state.speechError!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (state.submitError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Text(
              state.submitError!.message,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: state.allTasksCompleted
                ? AppButton(
                    label: 'Submit',
                    isLoading: state.isSubmitting,
                    onPressed: controller.submit,
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  )
                : Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: listening
                              ? 'Stop Recording'
                              : taskDone
                              ? 'Select Task ${state.taskIndex + 2}'
                              : 'Start Task ${state.taskIndex + 1}',
                          onPressed: listening ? controller.stop : controller.start,
                          backgroundColor: listening ? AppColors.danger : AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: controller.reset,
                        icon: const Icon(Icons.replay),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _TaskDots extends StatelessWidget {
  const _TaskDots({required this.state, required this.onTapDot});

  final TimerExerciseInProgress state;

  /// Mirrors the real page's `.timer-dot` click handler — always wired up
  /// here (every dot is nominally tappable), with [TimerExerciseController
  /// .goToTask] itself enforcing the real "only the immediate next task,
  /// only once the current one is done" gating, so an ineligible tap is a
  /// genuine, silent no-op, exactly matching the real web.
  final ValueChanged<int> onTapDot;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < state.totalTasks; i++)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onTapDot(i),
            child: Chip(
              label: Text('Task ${i + 1}'),
              avatar: Icon(
                state.completed.contains(i) ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: state.completed.contains(i) ? AppColors.success : AppColors.textMuted,
              ),
              backgroundColor: i == state.taskIndex ? AppColors.action.withValues(alpha: 0.12) : null,
            ),
          ),
      ],
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.secondsLeft, required this.listening});

  final int secondsLeft;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final fraction = secondsLeft / timerTaskDurationSeconds;
    final color = !listening
        ? AppColors.action
        : fraction <= 0.25
        ? AppColors.danger
        : fraction <= 0.5
        ? AppColors.warning
        : AppColors.action;

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: fraction.clamp(0, 1),
              strokeWidth: 8,
              color: color,
              backgroundColor: AppColors.border,
            ),
          ),
          Text('$secondsLeft', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _PreviousScoreCard extends StatelessWidget {
  const _PreviousScoreCard({required this.attempt});

  final ExerciseAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.history, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text('Previous score: ', style: theme.textTheme.bodySmall),
          Text('${attempt.score}/${attempt.maxScore}', style: theme.textTheme.titleSmall),
          const Spacer(),
          Text(formatMonthDayYear(attempt.completedAt), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
