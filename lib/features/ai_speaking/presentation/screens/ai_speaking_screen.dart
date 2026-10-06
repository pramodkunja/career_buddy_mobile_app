import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/module_hero.dart';
import '../../../activities/domain/entities/exercise_attempt.dart';
import '../../../activities/presentation/controllers/mark_sub_complete_controller.dart';
import '../controllers/ai_speaking_controller.dart';
import '../widgets/speaking_recorder_card.dart';
import '../widgets/speaking_result_card.dart';
import '../widgets/speaking_topic_card.dart';

/// `.module-hero`'s fixed gradient/badge for this module
/// (`speaking.html:26-30,312`).
const _heroGradientStart = Color(0xFF1E3A5F);
const _heroGradientEnd = Color(0xFF2563EB);
const _heroBreadcrumbLink = Color(0xFF0DCAF0); // Bootstrap default `--bs-info` (`.text-info`, unstyled by this project)

/// W014 — AI Speaking (`templates/activities/modules/speaking.html` +
/// `static/activities/js/speaking.js`, both read in full). See
/// `AiSpeakingController`'s doc comment for the exact scope of what is and
/// isn't reproduced.
///
/// [previousAttempt] mirrors the web's server-rendered "Previous Score"
/// sidebar card (`speaking.html:460-468`, `previous_result.score`/
/// `.completed_at` — NOT the separate JS-only full-feedback-card restore
/// driven by `previous-result-data`/`previousResultData`, which needs the
/// full stored `result_data` blob; no existing JSON API exposes that for
/// non-MCQ exercises — see `docs/W014_AI_SPEAKING.md` for the confirmed
/// limitation). Passed in by the caller (`SubActivityDetailScreen`, which
/// already has this exact `ExerciseAttempt` from
/// `sub_activity_detail_api`'s `last_attempt`) rather than re-fetched here,
/// since no endpoint alone serves it for a single exercise.
///
/// Does not reproduce the `isElevatorPitchTimed` 60-second special case for
/// one specific activity/sub-activity/exercise combination
/// (`speaking.html:480`) — using the standard 90-second cap for every
/// exercise is a deliberate, minor simplification, not a data error.
class AiSpeakingScreen extends ConsumerStatefulWidget {
  const AiSpeakingScreen({
    required this.exerciseId,
    required this.activityId,
    required this.subActivityId,
    required this.activityTitle,
    this.previousAttempt,
    super.key,
  });

  final int exerciseId;

  /// See `MatchingRouteArgs.activityId`'s doc comment.
  final int activityId;
  final int subActivityId;
  final String activityTitle;
  final ExerciseAttempt? previousAttempt;

  @override
  ConsumerState<AiSpeakingScreen> createState() => _AiSpeakingScreenState();
}

class _AiSpeakingScreenState extends ConsumerState<AiSpeakingScreen> {
  String _language = 'english';

  @override
  Widget build(BuildContext context) {
    final provider = aiSpeakingControllerProvider(widget.exerciseId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final inRecording = state is AiSpeakingRecording;

    return PopScope(
      canPop: !inRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !inRecording) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave without saving?'),
            content: const Text('Your recording in progress will be lost.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
            ],
          ),
        );
        if ((leave ?? false) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        // `.module-hero` (`speaking.html:26-30`) replaces the bare AppBar
        // title — this AppBar now only carries the back button + language
        // selector, blended into the hero's own gradient start color
        // rather than the app's default flat theme.
        appBar: AppBar(
          backgroundColor: _heroGradientStart,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (state is! AiSpeakingRecording)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Center(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _language,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.textOnDark, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'english', child: Text('English')),
                        DropdownMenuItem(value: 'vietnam', child: Text('Vietnamese')),
                        DropdownMenuItem(value: 'arabic', child: Text('Arabic')),
                        DropdownMenuItem(value: 'russian', child: Text('Russian')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _language = value);
                        controller.setLanguage(value);
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                ModuleHero(
                  gradientStart: _heroGradientStart,
                  gradientEnd: _heroGradientEnd,
                  badgeIcon: Icons.mic,
                  badgeLabel: 'Speaking Module',
                  activityTitle: widget.activityTitle,
                  breadcrumbLinkColor: _heroBreadcrumbLink,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      SpeakingTopicCard(topic: state.topic, onNewTopic: controller.pickNewTopic),
                      const SizedBox(height: AppSpacing.md),
                      if (state is AiSpeakingResult)
                        SpeakingResultCard(result: state.result, quickTip: state.quickTip, onTryAgain: controller.tryAgain)
                      else
                        SpeakingRecorderCard(state: state, controller: controller),
                      const SizedBox(height: AppSpacing.md),
                      _MarkCompleteButton(activityId: widget.activityId, subActivityId: widget.subActivityId),
                      if (widget.previousAttempt != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _PreviousScoreCard(attempt: widget.previousAttempt!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const BuddyChatbotOverlay(),
          ],
        ),
      ),
    );
  }
}

/// Mirrors the unconditional "Mark Sub-Activity Complete" form
/// (`speaking.html:435-442`) — unlike the regular sub-activity page
/// (`MarkCompleteSection`), this template shows no "all exercises done"
/// gating at all; the button is always present and always enabled.
class _MarkCompleteButton extends ConsumerWidget {
  const _MarkCompleteButton({required this.activityId, required this.subActivityId});

  final int activityId;
  final int subActivityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (activityId: activityId, subActivityId: subActivityId);
    final state = ref.watch(markSubCompleteControllerProvider(key));
    final isSubmitting = state is MarkCompleteSubmitting;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Mark Sub-Activity Complete', style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          ),
          if (state is MarkCompleteFailed) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(state.failure.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Mark Sub-Activity Complete',
            icon: Icons.check,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : () => ref.read(markSubCompleteControllerProvider(key).notifier).submit(),
          ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Text('Previous Score', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('${attempt.score}/25', style: theme.textTheme.headlineMedium?.copyWith(color: ModuleColors.speaking)),
          Text(formatMonthDayYear(attempt.completedAt), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
