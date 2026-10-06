import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/app_error_view.dart';
import '../../../../../shared/widgets/app_loader.dart';
import '../../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../presentation/widgets/mock_exam_colors.dart';
import '../../../presentation/widgets/mock_exam_warning_dialog.dart';
import '../controllers/amcat_controller.dart';
import '../widgets/amcat_instructions_view.dart';
import '../widgets/amcat_landing_view.dart';
import '../widgets/amcat_palette_sheet.dart';
import '../widgets/amcat_question_view.dart';
import '../widgets/amcat_result_view.dart';
import '../widgets/amcat_section_transition_view.dart';
import '../widgets/amcat_timer_badge.dart';

/// W023 — CoCubes Mock Test. Reuses [AmcatController] (via
/// [cocubesControllerProvider], `variant: AmcatVariant.cocubes`) and every
/// AMCAT widget, only substituting CoCubes's own landing/instructions/
/// result copy — see `AmcatState`'s doc comment for the full, source-cited
/// comparison proving this reuse is correct, not forced.
///
/// A near-duplicate of [AmcatMockTestScreen] rather than a further-shared
/// scaffold: with only two variants and copy differences spread across
/// three different screens (landing/instructions/result), a config-object
/// covering all of it would be harder to read than this direct, explicit
/// composition — the underlying state machine and every stateful widget
/// (timer, palette, question view, section transition) are still the
/// exact same shared code either way.
class CocubesMockTestScreen extends ConsumerStatefulWidget {
  const CocubesMockTestScreen({super.key});

  @override
  ConsumerState<CocubesMockTestScreen> createState() =>
      _CocubesMockTestScreenState();
}

class _CocubesMockTestScreenState extends ConsumerState<CocubesMockTestScreen> {
  bool _showingInstructions = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cocubesControllerProvider);
    final controller = ref.read(cocubesControllerProvider.notifier);

    ref.listen<AmcatState>(cocubesControllerProvider, (previous, next) {
      if (next is AmcatLanding && _showingInstructions) {
        setState(() => _showingInstructions = false);
      }
    });

    final inExam = state is AmcatInSection;

    return PopScope(
      canPop: !inExam,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !inExam) return;
        final leave = await _confirmExit(context);
        if (leave && context.mounted) controller.exitTest();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: inExam ? MockExamColors.navy : null,
          foregroundColor: inExam ? Colors.white : null,
          title: Text(_titleFor(state)),
          actions: [
            if (state case AmcatInSection inSection) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: AmcatTimerBadge(
                    remainingSeconds: inSection.remainingSeconds,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.grid_view),
                tooltip: 'Question palette',
                onPressed: () => showAmcatPaletteSheet(
                  context,
                  state: inSection,
                  controller: controller,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Exit',
                onPressed: () async {
                  final leave = await _confirmExit(context);
                  if (leave) controller.exitTest();
                },
              ),
            ],
          ],
        ),
        body: Stack(
          children: [
            switch (state) {
              AmcatLanding() when _showingInstructions => AmcatInstructionsView(
                onStart: controller.start,
                sectionsSummary:
                    'The test consists of 4 sections: Aptitude, Technical / Domain (CSE-IT), '
                    'Computer Fundamentals, and Programming.',
                lastGeneralBullet:
                    'The Programming section is multiple-choice (hard coding & CS questions) and is '
                    'scored like the others.',
              ),
              AmcatLanding() => AmcatLandingView(
                onStart: () => setState(() => _showingInstructions = true),
                title: '🧪 CoCubes Mock Test',
                subtitle:
                    'Full-length simulated practice test — Aptitude, Technical/Domain, Computer '
                    'Fundamentals & Programming',
                structure: kCocubesStructure,
                note:
                    'Each section is individually timed. Once a section\'s time is up, it auto-submits and '
                    'moves to the next section. The Programming section is multiple-choice (hard coding / CS '
                    'questions) and is scored like the other sections.',
              ),
              AmcatLoading() => const AppLoader(
                message: 'Loading your test...',
              ),
              AmcatLoadFailed(:final failure) => AppErrorView(
                message: failure.message,
                onRetry: controller.start,
              ),
              AmcatInSection inSection => AmcatQuestionView(
                state: inSection,
                controller: controller,
              ),
              AmcatSectionTransition transition => AmcatSectionTransitionView(
                state: transition,
                onNextTask: controller.beginNextSection,
              ),
              AmcatSubmitting() => const AppLoader(
                message: 'Grading your test...',
              ),
              AmcatSubmitFailed(:final failure) => AppErrorView(
                message: failure.message,
                onRetry: controller.retrySubmit,
              ),
              AmcatSubmitted(:final sections, :final answers, :final result) =>
                AmcatResultView(
                  sections: sections,
                  answers: answers,
                  result: result,
                  onRetake: controller.backToLanding,
                  overallScoreLabel:
                      'Overall Score (MCQ · ${result.score}/${result.total})',
                ),
            },
            const BuddyChatbotOverlay(),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmExit(BuildContext context) => showMockExamWarningDialog(
    context,
    title: 'Exit the assessment?',
    message: 'Your progress in this test will be lost and cannot be resumed.',
  );

  String _titleFor(AmcatState state) {
    return switch (state) {
      AmcatInSection(:final currentSection) => currentSection.name,
      AmcatSubmitted() => 'CoCubes Results',
      _ => 'CoCubes Mock Test',
    };
  }
}
