import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../controllers/jam_session_controller.dart';
import '../providers/jam_providers.dart';
import '../widgets/jam_locked_view.dart';
import 'jam_assessment_result_screen.dart';
import 'jam_result_screen.dart';

/// `jam:jam_session`/`jam:jam_session_topic` + `templates/jam/session.html`
/// (read in full, including its inline JS) — topic instructions, a
/// 60-second recording with a live countdown, automatic upload on stop,
/// then "Get AI Feedback". See `JamSessionController`'s doc comment for the
/// exact state machine and its one deliberate deviation from the web.
///
/// Also used, unchanged, to drive every one of the 3-stage Assessment
/// flow's stages ([startAsAssessment]) — the real `session.html` is the
/// exact same template either way (`jam_app/views.py:283-303`), just with
/// `is_assessment`/`stage` context added, which this screen shows as the
/// "Assessment Journey" stage indicator (`session.html:62-77`) whenever
/// [JamSessionState]'s current session carries a `stage`. Stage 2/3 land
/// back on this same running screen instance via [JamSessionController]'s
/// own `getFeedback` → `JamReady` transition — no navigation, no second
/// `startSession`-style call — see that method's doc comment.
class JamRecordingScreen extends ConsumerStatefulWidget {
  const JamRecordingScreen({
    this.topicId,
    this.startAsAssessment = false,
    super.key,
  });

  /// `null` starts a random topic (`jam:jam_session`); otherwise a specific
  /// topic (`jam:jam_session_topic`) — the id come from
  /// [JamTopicsScreen]/`parseJamTopicsHtml`. Ignored when
  /// [startAsAssessment] is `true`.
  final int? topicId;

  /// `true` calls `jam:start_assessment` instead of `jam:jam_session`/
  /// `jam:jam_session_topic` — reached from [JamTopicsScreen]'s "Start
  /// Assessment" action once `JamAssessmentEligibilityController` reports
  /// the user eligible.
  final bool startAsAssessment;

  @override
  ConsumerState<JamRecordingScreen> createState() => _JamRecordingScreenState();
}

class _JamRecordingScreenState extends ConsumerState<JamRecordingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Guarded on `JamSessionInitial` — without this, remounting this
      // screen (or, in a widget test, seeding the controller with a fixed
      // non-initial state to render a specific step of the flow) would
      // unconditionally kick off a second `startSession` call, clobbering
      // whatever state was already there.
      if (ref.read(jamSessionControllerProvider) is JamSessionInitial) {
        if (widget.startAsAssessment) {
          ref.read(jamSessionControllerProvider.notifier).startAssessment();
        } else {
          ref
              .read(jamSessionControllerProvider.notifier)
              .startSession(topicId: widget.topicId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jamSessionControllerProvider);
    final inRecording = state is JamRecordingInProgress;

    ref.listen<JamSessionState>(jamSessionControllerProvider, (previous, next) {
      if (next is JamResultReady) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => JamResultScreen(result: next.result),
          ),
        );
      } else if (next is JamAssessmentResultReady) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => JamAssessmentResultScreen(result: next.result),
          ),
        );
      }
    });

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
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('JAM Session')),
        body: Stack(
          children: [
            Column(
              children: [
                // `session.html:62-77`'s "Assessment Journey" stage dots +
                // "Stage N of 3" — shown whenever the current session is one
                // stage of the Assessment flow (`session.stage != null`),
                // absent for an ordinary practice session.
                if (_stageOf(state) case final stage?)
                  _StageIndicator(stage: stage),
                Expanded(
                  child: switch (state) {
                    JamSessionInitial() || JamStarting() => const AppLoader(
                      message: 'Preparing your topic...',
                    ),
                    JamStartFailed(failure: final failure)
                        when failure is ForbiddenFailure =>
                      JamLockedView(message: failure.message),
                    JamStartFailed(failure: final failure) => AppErrorView(
                      message: failure.message,
                      onRetry: () => widget.startAsAssessment
                          ? ref
                                .read(jamSessionControllerProvider.notifier)
                                .startAssessment()
                          : ref
                                .read(jamSessionControllerProvider.notifier)
                                .startSession(topicId: widget.topicId),
                    ),
                    JamReady(
                      session: final session,
                      micErrorMessage: final micError,
                    ) =>
                      _InstructionsView(
                        topicTitle: session.topicTitle,
                        topicDescription: session.topicDescription,
                        topicDifficulty: session.topicDifficulty,
                        micErrorMessage: micError,
                        onStart: () => ref
                            .read(jamSessionControllerProvider.notifier)
                            .startRecording(),
                      ),
                    JamRecordingInProgress(elapsedSeconds: final elapsed) =>
                      _RecordingView(
                        elapsedSeconds: elapsed,
                        onStop: () => ref
                            .read(jamSessionControllerProvider.notifier)
                            .stopRecording(),
                      ),
                    JamRecordingTooShort() => _TooShortView(
                      onTryAgain: () => ref
                          .read(jamSessionControllerProvider.notifier)
                          .startRecording(),
                    ),
                    JamUploading() => const AppLoader(
                      message: 'Saving your recording...',
                    ),
                    JamUploadFailed(failure: final failure) => AppErrorView(
                      message: failure.message,
                      onRetry: () => ref
                          .read(jamSessionControllerProvider.notifier)
                          .retryUpload(),
                    ),
                    JamReadyForFeedback(
                      elapsedSeconds: final elapsed,
                      session: final session,
                    ) =>
                      _CapturedView(
                        elapsedSeconds: elapsed,
                        stage: session.stage,
                        onGetFeedback: () => ref
                            .read(jamSessionControllerProvider.notifier)
                            .getFeedback(),
                      ),
                    JamCompleting() => const AppLoader(
                      message: 'Analyzing your session...',
                    ),
                    JamCompleteFailed(failure: final failure) => AppErrorView(
                      message: failure.message,
                      onRetry: () => ref
                          .read(jamSessionControllerProvider.notifier)
                          .getFeedback(),
                    ),
                    JamResultReady() => const AppLoader(),
                    JamAssessmentResultReady() => const AppLoader(
                      message: 'Building your diagnostic report...',
                    ),
                  },
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

/// `session.stage` of whichever [JamSessionState] variant is current, or
/// `null` for a state with no session yet (`JamSessionInitial`/
/// `JamStarting`/a failure) or a state whose session is never an
/// assessment one in practice — kept exhaustive-by-wildcard rather than
/// enumerating every non-session state explicitly, since new non-session
/// states added later shouldn't need to touch this.
int? _stageOf(JamSessionState state) => switch (state) {
  JamReady(session: final s) => s.stage,
  JamRecordingInProgress(session: final s) => s.stage,
  JamRecordingTooShort(session: final s) => s.stage,
  JamUploading(session: final s) => s.stage,
  JamUploadFailed(session: final s) => s.stage,
  JamReadyForFeedback(session: final s) => s.stage,
  JamCompleting(session: final s) => s.stage,
  JamCompleteFailed(session: final s) => s.stage,
  _ => null,
};

class _StageIndicator extends StatelessWidget {
  const _StageIndicator({required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'ASSESSMENT JOURNEY',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          for (var i = 1; i <= 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stage >= i ? AppColors.accent : Colors.white24,
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Stage $stage of 3',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionsView extends StatelessWidget {
  const _InstructionsView({
    required this.topicTitle,
    required this.topicDescription,
    required this.topicDifficulty,
    required this.micErrorMessage,
    required this.onStart,
  });

  final String topicTitle;
  final String topicDescription;
  final String topicDifficulty;
  final String? micErrorMessage;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'JAM.',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Just A Minute',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              "You'll speak on the topic below for 60 seconds without hesitation, repetition, or deviation.",
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFFDE68A)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'YOUR TOPIC',
                        style: TextStyle(
                          color: AppColors.accentDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      if (topicDifficulty.isNotEmpty) ...[
                        const Spacer(),
                        Text(
                          topicDifficulty.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topicTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (topicDescription.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      topicDescription,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (micErrorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                micErrorMessage!,
                style: const TextStyle(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: "I'm Ready — Start Session",
              icon: Icons.mic,
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingView extends StatelessWidget {
  const _RecordingView({required this.elapsedSeconds, required this.onStop});

  final int elapsedSeconds;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final remaining = (JamRecordingInProgress.maxSeconds - elapsedSeconds)
        .clamp(0, JamRecordingInProgress.maxSeconds);
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final label = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final progress = elapsedSeconds / JamRecordingInProgress.maxSeconds;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1).toDouble(),
                      strokeWidth: 8,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(
                        elapsedSeconds > 45
                            ? AppColors.danger
                            : elapsedSeconds > 30
                            ? AppColors.warning
                            : AppColors.accent,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'RECORDING LIVE',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Stop',
              icon: Icons.stop,
              backgroundColor: AppColors.danger,
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}

class _TooShortView extends StatelessWidget {
  const _TooShortView({required this.onTryAgain});

  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_off, size: 40, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Recording too short, please try again.',
              style: TextStyle(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Your recording was too short to analyse. Press Start Session again and speak for at least a few seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Try Again',
              icon: Icons.mic,
              fullWidth: false,
              onPressed: onTryAgain,
            ),
          ],
        ),
      ),
    );
  }
}

class _CapturedView extends StatelessWidget {
  const _CapturedView({
    required this.elapsedSeconds,
    required this.onGetFeedback,
    this.stage,
  });

  final int elapsedSeconds;
  final VoidCallback onGetFeedback;

  /// `null` for an ordinary practice session ("Get AI Feedback",
  /// `session.html:176-182`). `1`/`2` for an assessment stage with more
  /// stages to go ("Next Stage...", `session.html:159-165`); `3` for the
  /// last stage ("Generate Diagnostic Report", `session.html:166-173`).
  final int? stage;

  @override
  Widget build(BuildContext context) {
    final (
      String caption,
      String buttonLabel,
      IconData buttonIcon,
    ) = switch (stage) {
      1 => (
        'Great job! Ready for the next stage of your assessment?',
        'Next Stage (Medium)',
        Icons.arrow_forward,
      ),
      2 => (
        'Great job! Ready for the next stage of your assessment?',
        'Next Stage (Hard)',
        Icons.arrow_forward,
      ),
      3 => (
        'Final stage complete! Your diagnostic report is being generated.',
        'Generate Diagnostic Report',
        Icons.analytics,
      ),
      _ => (
        'Your session is ready for AI analysis and feedback.',
        'Get AI Feedback',
        Icons.auto_awesome,
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 40, color: AppColors.success),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Session Captured Successfully',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'You spoke for $elapsedSeconds seconds.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: buttonLabel,
              icon: buttonIcon,
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              fullWidth: false,
              onPressed: onGetFeedback,
            ),
          ],
        ),
      ),
    );
  }
}
