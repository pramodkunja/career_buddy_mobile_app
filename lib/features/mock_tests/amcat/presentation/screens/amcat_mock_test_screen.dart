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

/// W022 — AMCAT Mock Test. See `AmcatController`'s doc comment for the full
/// list of confirmed behavioral differences from W020/W021 that make this
/// its own screen/controller rather than a `MockQuizScaffold` variant.
class AmcatMockTestScreen extends ConsumerStatefulWidget {
  const AmcatMockTestScreen({super.key});

  @override
  ConsumerState<AmcatMockTestScreen> createState() =>
      _AmcatMockTestScreenState();
}

class _AmcatMockTestScreenState extends ConsumerState<AmcatMockTestScreen> {
  bool _showingInstructions = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(amcatControllerProvider);
    final controller = ref.read(amcatControllerProvider.notifier);

    // Landing/Instructions reset whenever the controller itself resets to
    // AmcatLanding (Exit, or "Retake Test" from the result screen).
    ref.listen<AmcatState>(amcatControllerProvider, (previous, next) {
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
        // `.exam-header{background:var(--navy)}` — navy only during the
        // live, full-screen section takeover; landing/instructions/result
        // keep the app's standard AppBar.
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
              ),
              AmcatLanding() => AmcatLandingView(
                onStart: () => setState(() => _showingInstructions = true),
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
      AmcatSubmitted() => 'AMCAT Results',
      _ => 'AMCAT Mock Test',
    };
  }
}
