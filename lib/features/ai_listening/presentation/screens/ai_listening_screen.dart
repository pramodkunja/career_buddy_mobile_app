import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/module_hero.dart';
import '../../../activities/domain/entities/exercise_attempt.dart';
import '../../../activities/presentation/controllers/mark_sub_complete_controller.dart';
import '../controllers/ai_listening_controller.dart';
import '../widgets/listening_answer_card.dart';
import '../widgets/listening_result_card.dart';
import '../widgets/listening_story_card.dart';

/// `.module-hero`'s fixed gradient/badge for this module
/// (`listening.html:11-14,134`).
const _heroGradientStart = Color(0xFF164E63);
const _heroGradientEnd = Color(0xFF0891B2);
// `text-cyan-200` (`listening.html:139-140`) has no matching CSS rule
// anywhere in the project (confirmed by grep) — Bootstrap's default link
// color, `#0d6efd`, is what actually renders. See `AiWritingScreen`'s
// identical finding.
const _heroBreadcrumbLink = Color(0xFF0D6EFD);

/// W016 — AI Listening (`templates/activities/modules/listening.html` +
/// `static/activities/js/listening.js`, both read in full). See
/// `AiListeningController`'s doc comment for the exact scope of what is
/// and isn't reproduced.
///
/// [previousAttempt] mirrors the web's server-rendered "Previous Score"
/// sidebar card, the same limitation already documented for W014/W015
/// regarding the JS-only full-feedback-restore behavior.
class AiListeningScreen extends ConsumerStatefulWidget {
  const AiListeningScreen({
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
  ConsumerState<AiListeningScreen> createState() => _AiListeningScreenState();
}

class _AiListeningScreenState extends ConsumerState<AiListeningScreen> {
  final _textController = TextEditingController();
  String _language = 'english';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = aiListeningControllerProvider(widget.exerciseId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return Scaffold(
      // `.module-hero` (`listening.html:11-14`) replaces the bare AppBar
      // title — see `AiSpeakingScreen`'s identical reasoning. Only shown
      // once the exercise has actually loaded (`ListeningActive`); the
      // web itself has no client-side loading/error state to match here.
      appBar: AppBar(
        backgroundColor: state is ListeningActive ? _heroGradientStart : null,
        foregroundColor: state is ListeningActive ? Colors.white : null,
        elevation: state is ListeningActive ? 0 : null,
        actions: [
          if (state is ListeningActive)
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
          switch (state) {
            ListeningLoading() => const AppLoader(message: 'Preparing your listening exercise...'),
            ListeningLoadFailed(:final failure) => AppErrorView(message: failure.message, onRetry: controller.retry),
            ListeningActive() => _ActiveContent(
              state: state,
              controller: controller,
              textController: _textController,
              activityId: widget.activityId,
              subActivityId: widget.subActivityId,
              activityTitle: widget.activityTitle,
              previousAttempt: widget.previousAttempt,
            ),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _ActiveContent extends StatelessWidget {
  const _ActiveContent({
    required this.state,
    required this.controller,
    required this.textController,
    required this.activityId,
    required this.subActivityId,
    required this.activityTitle,
    required this.previousAttempt,
  });

  final ListeningActive state;
  final AiListeningController controller;
  final TextEditingController textController;
  final int activityId;
  final int subActivityId;
  final String activityTitle;
  final ExerciseAttempt? previousAttempt;

  @override
  Widget build(BuildContext context) {
    final submission = state.submission;
    return Column(
      children: [
        ModuleHero(
          gradientStart: _heroGradientStart,
          gradientEnd: _heroGradientEnd,
          badgeIcon: Icons.headphones,
          badgeLabel: 'Listening Module',
          activityTitle: activityTitle,
          breadcrumbLinkColor: _heroBreadcrumbLink,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              ListeningStoryCard(
          state: state,
          onLevelChanged: (level) {
            textController.clear();
            controller.setLevel(level);
          },
          onSpeedChanged: controller.setSpeed,
          onNewStory: () {
            textController.clear();
            controller.pickNewStory();
          },
          onPlay: controller.play,
          onPause: controller.pause,
        ),
        const SizedBox(height: AppSpacing.md),
        ListeningAnswerCard(
          controller: textController,
          isSubmitting: submission is SubmissionInFlight,
          isLocked: submission is SubmissionSucceeded,
          onSubmit: () => controller.submit(textController.text),
        ),
        if (submission is SubmissionFailed) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    submission.failure.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (submission is SubmissionSucceeded) ...[
          const SizedBox(height: AppSpacing.md),
          ListeningResultCard(result: submission.result, onTryAgain: controller.retry),
        ],
              const SizedBox(height: AppSpacing.md),
              _MarkCompleteButton(activityId: activityId, subActivityId: subActivityId),
              if (previousAttempt != null) ...[
                const SizedBox(height: AppSpacing.md),
                _PreviousScoreCard(attempt: previousAttempt!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Mirrors the unconditional "Mark Sub-Activity Complete" form — same
/// pattern as `AiSpeakingScreen`/`AiWritingScreen`.
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
          Text('${attempt.score}/25', style: theme.textTheme.headlineMedium?.copyWith(color: ModuleColors.listening)),
          Text(formatMonthDayYear(attempt.completedAt), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
