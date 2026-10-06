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
import '../../domain/services/writing_validation.dart';
import '../controllers/ai_writing_controller.dart';
import '../widgets/writing_input_card.dart';
import '../widgets/writing_result_card.dart';
import '../widgets/writing_topic_card.dart';

/// `.module-hero`'s fixed gradient/badge for this module
/// (`writing.html:10-13,115`).
const _heroGradientStart = Color(0xFF14532D);
const _heroGradientEnd = Color(0xFF16A34A);
// `text-green-200` (`writing.html:120-121`) has no matching CSS rule
// anywhere in the project (confirmed by grep) — the browser falls back to
// Bootstrap's default link color, `#0d6efd`, not a module-tinted green. A
// genuine web quirk, reproduced rather than "fixed".
const _heroBreadcrumbLink = Color(0xFF0D6EFD);

/// W015 — AI Writing (`templates/activities/modules/writing.html` +
/// `static/activities/js/writing.js`, both read in full). See
/// `AiWritingController`'s doc comment for the exact scope of what is and
/// isn't reproduced, and why this screen's layout (input always visible,
/// result appended below) differs from `AiSpeakingScreen`'s
/// mutually-exclusive states — it mirrors the web's own, genuinely
/// different, continuous-page structure rather than forcing Speaking's
/// pattern onto a different flow.
///
/// [previousAttempt] mirrors the web's server-rendered "Previous Score"
/// sidebar card (`writing.html:219-223`), the same limitation as
/// `AiSpeakingScreen` regarding the JS-only full-feedback-restore
/// behavior — see `docs/W015_AI_WRITING.md`.
class AiWritingScreen extends ConsumerStatefulWidget {
  const AiWritingScreen({
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
  ConsumerState<AiWritingScreen> createState() => _AiWritingScreenState();
}

class _AiWritingScreenState extends ConsumerState<AiWritingScreen> {
  final _textController = TextEditingController();
  String _language = 'english';
  int _nonSpaceChars = 0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _recount() {
    setState(() => _nonSpaceChars = countNonSpaceChars(_textController.text));
  }

  void _clearAndResetTopic(VoidCallback resetTopic) {
    _textController.clear();
    resetTopic();
    _recount();
  }

  @override
  Widget build(BuildContext context) {
    final provider = aiWritingControllerProvider(widget.exerciseId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final isSubmitting = state is WritingSubmitting;

    return Scaffold(
      // `.module-hero` (`writing.html:10-13`) replaces the bare AppBar
      // title — see `AiSpeakingScreen`'s identical reasoning.
      appBar: AppBar(
        backgroundColor: _heroGradientStart,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
                badgeIcon: Icons.edit,
                badgeLabel: 'Writing Module',
                activityTitle: widget.activityTitle,
                breadcrumbLinkColor: _heroBreadcrumbLink,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    WritingTopicCard(
                      topic: state.topic,
                      writingType: state.writingType,
                      onNewTopic: () => _clearAndResetTopic(controller.pickNewTopic),
                      onTypeChanged: (type) => _clearAndResetTopic(() => controller.setWritingType(type)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    WritingInputCard(
                      controller: _textController,
                      nonSpaceChars: _nonSpaceChars,
                      isSubmitting: isSubmitting,
                      onChanged: _recount,
                      onSubmit: () => controller.submit(_textController.text),
                    ),
                    if (state is WritingSubmitFailed) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                state.failure.message,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (state is WritingResult) ...[
                      const SizedBox(height: AppSpacing.md),
                      WritingResultCard(result: state.result),
                    ],
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
    );
  }
}

/// Mirrors the unconditional "Mark Sub-Activity Complete" form
/// (`writing.html:195-203`) — same pattern as `AiSpeakingScreen`'s.
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
          Text('${attempt.score}/25', style: theme.textTheme.headlineMedium?.copyWith(color: ModuleColors.writing)),
          Text(formatMonthDayYear(attempt.completedAt), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
