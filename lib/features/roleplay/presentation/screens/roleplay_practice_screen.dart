import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../data/roleplay_topics_data.dart';
import '../../domain/entities/roleplay_topic.dart';
import '../controllers/roleplay_controller.dart';
import '../widgets/roleplay_locked_view.dart';
import '../widgets/roleplay_result_card.dart';

const _heroGradientStart = Color(0xFF0F172A);
const _heroGradientEnd = Color(0xFF1E293B);
const _heroAccent = Color(0xFFF59E0B);

/// One Roleplay Workshop sub-feature's practice/session screen — mirrors
/// `templates/activities/modules/roleplay.html` + its inline JS (both read
/// in full). See `RoleplayController`'s doc comment for exactly how the
/// real single-page, in-place-state-transition flow (Setup -> Reading ->
/// per-question Recording -> Result) is reproduced.
///
/// [topicSlug] must be one of `RoleplayTopicsData.all`'s slugs — this
/// screen is only ever reached via `RoleplayHomeScreen`'s own cards, which
/// only offer valid slugs.
class RoleplayPracticeScreen extends ConsumerStatefulWidget {
  const RoleplayPracticeScreen({required this.topicSlug, super.key});

  final String topicSlug;

  @override
  ConsumerState<RoleplayPracticeScreen> createState() =>
      _RoleplayPracticeScreenState();
}

class _RoleplayPracticeScreenState
    extends ConsumerState<RoleplayPracticeScreen> {
  final _promptController = TextEditingController();
  String _language = 'english';

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topic = RoleplayTopicsData.bySlug(widget.topicSlug)!;
    final provider = roleplayControllerProvider(widget.topicSlug);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    // Keeps the prompt `TextField` in sync whenever the controller's own
    // idea of the prompt text changes for a reason other than the user
    // typing in this exact field — an example chip tap, a generation
    // failure preserving what was typed, or `tryAgain`/`location.reload()`
    // clearing it back to empty.
    ref.listen<RoleplayState>(provider, (previous, next) {
      final promptText = switch (next) {
        RoleplaySetup(promptText: final p) => p,
        RoleplayGenerateFailed(promptText: final p) => p,
        RoleplayLocked(promptText: final p) => p,
        _ => null,
      };
      if (promptText != null && promptText != _promptController.text) {
        _promptController.text = promptText;
      }
    });

    final inRecording = state is RoleplayRecording;

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
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if ((leave ?? false) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _heroGradientStart,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(topic.pageTitle),
          actions: [
            if (state is! RoleplayRecording)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Center(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _language,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontSize: 13,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'english',
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: 'vietnam',
                          child: Text('Vietnamese'),
                        ),
                        DropdownMenuItem(
                          value: 'arabic',
                          child: Text('Arabic'),
                        ),
                        DropdownMenuItem(
                          value: 'russian',
                          child: Text('Russian'),
                        ),
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
                _Hero(topic: topic),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: _bodyChildren(context, state, controller, topic),
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

  List<Widget> _bodyChildren(
    BuildContext context,
    RoleplayState state,
    RoleplayController controller,
    RoleplayTopic topic,
  ) {
    return switch (state) {
      RoleplaySetup() => _setupChildren(
        topic,
        controller,
        validationError: state.validationError,
      ),
      RoleplayGenerateFailed() => _setupChildren(
        topic,
        controller,
        failureMessage: state.failure.message,
      ),
      RoleplayLocked() => [RoleplayLockedView(message: state.message)],
      RoleplayGenerating() => const [
        AppLoader(message: 'Creating your session...'),
      ],
      RoleplayReading() => _readingChildren(state, controller),
      RoleplayRecording() => _recordingChildren(state, controller),
      RoleplaySubmitting() => const [
        AppLoader(message: 'Analyzing your performance...'),
      ],
      RoleplaySubmitFailed() => _submitFailedChildren(state, controller),
      RoleplayResult() => [
        RoleplayResultCard(
          result: state.result,
          onTryAgain: controller.tryAgain,
        ),
      ],
    };
  }

  List<Widget> _setupChildren(
    RoleplayTopic topic,
    RoleplayController controller, {
    String? validationError,
    String? failureMessage,
  }) {
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DESCRIBE YOUR SCENARIO',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _promptController,
              maxLength: 120,
              decoration: InputDecoration(hintText: topic.inputPlaceholder),
              onChanged: controller.updatePrompt,
            ),
            if (validationError != null) ...[
              Text(
                validationError,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (failureMessage != null) ...[
              Text(
                failureMessage,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final example in topic.examples)
                  ActionChip(
                    label: Text(example),
                    onPressed: () {
                      _promptController.text = example;
                      controller.updatePrompt(example);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Create Session',
              icon: Icons.rocket_launch,
              onPressed: controller.generate,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _readingChildren(
    RoleplayReading state,
    RoleplayController controller,
  ) {
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.content.contentHeading,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.content.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.content.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Take a moment to read the context above. When you're ready to answer questions, tap below.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            if (state.micErrorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.micErrorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: "I'm Ready - Start Questions",
              icon: Icons.record_voice_over,
              onPressed: controller.startQuestions,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _recordingChildren(
    RoleplayRecording state,
    RoleplayController controller,
  ) {
    final total = state.content.followUps.length;
    final question = state.content.followUps[state.questionIndex];
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${state.questionIndex + 1} of $total',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(question, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.mic, color: AppColors.danger),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${state.elapsedSeconds}s',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!state.isLastQuestion)
              AppButton(
                label: 'Done - Next Question',
                icon: Icons.check_circle,
                onPressed: controller.nextQuestion,
              )
            else
              AppButton(
                label: 'Analyze Performance',
                icon: Icons.analytics,
                backgroundColor: _heroAccent,
                foregroundColor: Colors.black,
                onPressed: controller.finishAndAnalyze,
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _submitFailedChildren(
    RoleplaySubmitFailed state,
    RoleplayController controller,
  ) {
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.failure.message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Retry Analysis',
              icon: Icons.analytics,
              onPressed: controller.retryAnalysis,
            ),
          ],
        ),
      ),
    ];
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.topic});

  final RoleplayTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_heroGradientStart, _heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.pageTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: _heroAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            topic.pageDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
