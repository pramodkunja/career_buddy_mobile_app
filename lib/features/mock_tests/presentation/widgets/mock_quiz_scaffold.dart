import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../controllers/mock_test_controller.dart';
import 'mock_exam_colors.dart';
import 'mock_exam_warning_dialog.dart';
import 'mock_test_intro_view.dart';
import 'mock_test_palette_sheet.dart';
import 'mock_test_question_view.dart';
import 'mock_test_result_view.dart';
import 'mock_test_submit_confirmation_dialog.dart';
import 'mock_test_timer_badge.dart';

/// The shared "mock quiz" screen body — intro → live exam (free navigation,
/// client-side 60-minute timer, palette, mark-for-review) → server-graded
/// result — used by both W020 (OOP Mastery) and W021 (Subject Quiz), which
/// were verified to share this exact UI/behavior contract (see the W021
/// final report): identical splash rules copy, identical timer/palette/
/// confirm-dialog behavior, identical result-tier messages, down to a
/// confirmed copy-paste artifact in the ≥85% tier message that still reads
/// "...strong command of OOP..." on every subject's own web page, not just
/// OOP's — reproduced faithfully here rather than silently "fixed", since
/// the web page is the source of truth.
///
/// [title] is the bare subject/quiz name (e.g. "OOP Mastery", "DSA
/// Mastery", "Claude Code") — every screen composes it the same way the web
/// does: `"$title — Mock Test"` (AppBar), `"🎯 $title — Mock Test"` (intro
/// splash), `"Result — $title Mock Test"` (result header).
class MockQuizScaffold extends StatelessWidget {
  const MockQuizScaffold({
    required this.title,
    required this.state,
    required this.controller,
    super.key,
  });

  final String title;
  final MockTestState state;
  final MockTestController controller;

  @override
  Widget build(BuildContext context) {
    final state = this.state; // local copy so `is` checks below promote
    return PopScope(
      canPop: state is! MockTestInProgress,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || state is! MockTestInProgress) return;
        final leave = await showMockExamWarningDialog(
          context,
          title: 'Leave test?',
          message: 'Your progress will be lost if you leave now.',
          cancelLabel: 'Stay',
          confirmLabel: 'Leave',
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        // `.exam-top`/`.exam-header` (`005 oop-mastery.html:2427`,
        // `amcat_mock_test.html:65-69`): navy background, white text — but
        // only for the live, full-screen exam takeover; the intro/result
        // pages live inside the ordinary (non-navy-banner) guide page on
        // the web, so they keep the app's standard AppBar.
        appBar: AppBar(
          backgroundColor: state is MockTestInProgress
              ? MockExamColors.navy
              : null,
          foregroundColor: state is MockTestInProgress ? Colors.white : null,
          title: Text('$title — Mock Test'),
          actions: [
            if (state case MockTestInProgress inProgress) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: MockTestTimerBadge(
                    remainingSeconds: inProgress.remainingSeconds,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.grid_view),
                tooltip: 'Question palette',
                onPressed: () => showMockTestPaletteSheet(
                  context,
                  state: inProgress,
                  controller: controller,
                ),
              ),
            ],
          ],
        ),
        body: Stack(
          children: [
            switch (state) {
              MockTestIntro(:final history) => MockTestIntroView(
                title: title,
                history: history,
                onStart: controller.start,
              ),
              MockTestLoading() => const AppLoader(
                message: 'Loading your test...',
              ),
              MockTestLoadFailed(:final failure) => AppErrorView(
                message: failure.message,
                onRetry: controller.start,
              ),
              MockTestInProgress inProgress => MockTestQuestionView(
                state: inProgress,
                controller: controller,
              ),
              MockTestSubmitted(
                :final questions,
                :final answers,
                :final result,
              ) =>
                MockTestResultView(
                  title: title,
                  questions: questions,
                  answers: answers,
                  result: result,
                  onRetake: controller.retakeTest,
                  onClose: controller.backToIntro,
                ),
            },
            const BuddyChatbotOverlay(),
          ],
        ),
        bottomNavigationBar: state is MockTestInProgress
            ? _SubmitBar(state: state, controller: controller)
            : null,
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.state, required this.controller});

  final MockTestInProgress state;
  final MockTestController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      // `.exam-btn.submit{background:#FCA311;color:#14213D}`
      // (`005 oop-mastery.html:2437`) — gold, navy text, not the app's
      // default primary button color.
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: MockExamColors.gold,
          foregroundColor: MockExamColors.navy,
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: state.isSubmitting ? null : () => _handleSubmit(context),
        child: state.isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: MockExamColors.navy,
                ),
              )
            : Text(
                'Submit Test (${state.answeredCount}/${state.questions.length} answered)',
              ),
      ),
    );
  }

  Future<void> _handleSubmit(BuildContext context) async {
    final confirmed = await showMockTestSubmitConfirmationDialog(
      context,
      unansweredCount: state.unansweredCount,
    );
    if (confirmed) await controller.submit();
  }
}
