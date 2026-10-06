import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/module_hero.dart';
import '../../../activities/domain/entities/exercise_attempt.dart';
import '../../../activities/presentation/controllers/mark_sub_complete_controller.dart';
import '../../../../core/utils/date_format.dart';
import '../controllers/ai_reading_controller.dart';
import '../widgets/reading_passage_card.dart';
import '../widgets/reading_recorder_card.dart';
import '../widgets/reading_result_card.dart';

/// `.module-hero`'s fixed gradient/badge for this module
/// (`reading.html:11-14,101`).
const _heroGradientStart = Color(0xFF713F12);
const _heroGradientEnd = Color(0xFFD97706);
// `text-yellow-100` (`reading.html:106-107`) has no matching CSS rule
// anywhere in the project (confirmed by grep) — Bootstrap's default link
// color, `#0d6efd`, is what actually renders. See `AiWritingScreen`'s
// identical finding.
const _heroBreadcrumbLink = Color(0xFF0D6EFD);

/// W017 — AI Reading (`templates/activities/modules/reading.html` +
/// `static/activities/js/reading.js`, both read in full). See
/// `AiReadingController`'s doc comment for the exact scope of what is and
/// isn't reproduced, and how this module's mechanics differ from Speaking/
/// Writing/Listening despite reusing pieces of each.
///
/// [previousAttempt] mirrors the web's server-rendered "Previous Score"
/// sidebar card — the same limitation already documented for W014/W015/
/// W016 regarding the JS-only full-feedback-restore behavior.
class AiReadingScreen extends ConsumerStatefulWidget {
  const AiReadingScreen({
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
  ConsumerState<AiReadingScreen> createState() => _AiReadingScreenState();
}

class _AiReadingScreenState extends ConsumerState<AiReadingScreen> {
  String _language = 'english';

  @override
  Widget build(BuildContext context) {
    final provider = aiReadingControllerProvider(widget.exerciseId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final inRecording = state is ReadingRecording;

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
        // `.module-hero` (`reading.html:11-14`) replaces the bare AppBar
        // title — see `AiSpeakingScreen`'s identical reasoning.
        appBar: AppBar(
          backgroundColor: _heroGradientStart,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (state is! ReadingRecording)
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
                  badgeIcon: Icons.menu_book,
                  badgeLabel: 'Reading Module',
                  activityTitle: widget.activityTitle,
                  breadcrumbLinkColor: _heroBreadcrumbLink,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      ReadingPassageCard(
                        passageTitle: state.passage.title,
                        passageText: state.passage.text,
                        level: state.level,
                        onLevelChanged: controller.setLevel,
                        onNewPassage: controller.pickNewPassage,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (state is ReadingResult)
                        ReadingResultCard(result: state.result, onTryAgain: controller.tryAgain)
                      else
                        ReadingRecorderCard(state: state, controller: controller),
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

/// Mirrors the unconditional "Mark Sub-Activity Complete" form — same
/// pattern as `AiSpeakingScreen`/`AiWritingScreen`/`AiListeningScreen`.
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
          Text('${attempt.score}/25', style: theme.textTheme.headlineMedium?.copyWith(color: ModuleColors.reading)),
          Text(formatMonthDayYear(attempt.completedAt), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
