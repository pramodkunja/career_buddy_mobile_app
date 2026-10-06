import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/malpractice.dart';
import '../../domain/services/interview_camera_service.dart';
import '../controllers/mock_interview_controller.dart';
import '../providers/mock_interview_providers.dart';
import '../widgets/mock_interview_camera_gate_view.dart';
import '../widgets/mock_interview_question_view.dart';
import '../widgets/mock_interview_results_view.dart';

/// AI Mock Interview — one screen owns every phase of the session (camera
/// gate → questions → results), the same "one URL, several state bodies"
/// pattern `ResumeBuilderScreen` already uses for the ATS flow this feature
/// continues from. See `MockInterviewController`'s doc comment for the exact
/// scope of what is/isn't implemented (the one deliberate gap is live face
/// detection).
///
/// Anti-malpractice: mixes in [WidgetsBindingObserver] to detect real app
/// backgrounding/foregrounding — the native equivalent of the web's
/// `document.visibilitychange`/`window.blur` listeners
/// (`templates/resume_interview.html:1723-1737`) — and reports it to the
/// real `resume_record_violation` endpoint via
/// [MockInterviewController.reportViolation]. Mapping (documented precisely
/// here since there's no 1:1 native equivalent of the web's two distinct
/// events): [AppLifecycleState.paused]/`hidden` (the app is no longer
/// visible at all) reports [ViolationType.tabSwitch] — the closest native
/// match for `document.hidden`; [AppLifecycleState.inactive] (transitioning,
/// e.g. an incoming call, notification shade, or app-switcher) reports
/// [ViolationType.windowBlur] — the closest match for a focus change that
/// doesn't fully hide the app. On some platforms a single real backgrounding
/// event passes through `inactive` on its way to `paused`, which can record
/// both violation types for one real event — an honest consequence of
/// mapping two web events onto Flutter's own lifecycle model, not a bug
/// masked as one.
class MockInterviewScreen extends ConsumerStatefulWidget {
  const MockInterviewScreen({super.key});

  @override
  ConsumerState<MockInterviewScreen> createState() =>
      _MockInterviewScreenState();
}

class _MockInterviewScreenState extends ConsumerState<MockInterviewScreen>
    with WidgetsBindingObserver {
  /// Batch 10 — owned here, not by `MockInterviewCameraGateView`, precisely
  /// so its lifetime spans the whole interview: the continuous video
  /// recording started in [_onStateChanged] once the candidate passes the
  /// camera gate must keep running underneath the question screens too,
  /// mirroring the web keeping one `cameraStream` alive for the entire
  /// session (`templates/resume_interview.html`) rather than only during its
  /// own camera-check step.
  late final InterviewCameraService _cameraService;
  bool _recordingStarted = false;
  bool _videoHandled = false;

  @override
  void initState() {
    super.initState();
    _cameraService = ref.read(interviewCameraServiceFactoryProvider)();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(mockInterviewControllerProvider);
      if (state is MockInterviewIdle) {
        ref.read(mockInterviewControllerProvider.notifier).start();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraService.dispose());
    super.dispose();
  }

  /// Starts the continuous interview recording the first time the candidate
  /// leaves the camera gate, and stops + uploads it the first time the
  /// interview ends (normally or via malpractice termination) — mirrors the
  /// web's `startVideoRecording()`/`finishVideoRecording()` call sites
  /// exactly (right alongside `loadNextQuestion()` and right alongside
  /// showing results, respectively). Guarded by the two booleans above so a
  /// rebuild never starts/stops/uploads more than once per interview.
  void _onStateChanged(MockInterviewState? previous, MockInterviewState next) {
    if (!_recordingStarted &&
        previous is MockInterviewCameraGate &&
        next is! MockInterviewCameraGate) {
      _recordingStarted = true;
      unawaited(_cameraService.startVideoRecording());
    }
    if (!_videoHandled &&
        (next is MockInterviewResults || next is MockInterviewTerminated)) {
      _videoHandled = true;
      unawaited(_stopAndUploadVideo());
    }
  }

  Future<void> _stopAndUploadVideo() async {
    final path = await _cameraService.stopVideoRecording();
    if (path == null || !mounted) return;
    await ref
        .read(mockInterviewControllerProvider.notifier)
        .uploadRecordedVideo(path);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(mockInterviewControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        controller.reportViolation(ViolationType.tabSwitch);
      case AppLifecycleState.inactive:
        controller.reportViolation(ViolationType.windowBlur);
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockInterviewControllerProvider);
    final controller = ref.read(mockInterviewControllerProvider.notifier);

    ref.listen<MockInterviewState>(
      mockInterviewControllerProvider,
      _onStateChanged,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('AI Mock Interview')),
      body: Stack(
        children: [
          SafeArea(
            child: switch (state) {
              MockInterviewIdle() || MockInterviewStarting() => const AppLoader(
                message: 'Starting your interview…',
              ),
              MockInterviewStartFailed(failure: final failure) => AppErrorView(
                message: failure.message,
                onRetry: controller.retryStart,
              ),
              MockInterviewCameraGate() => MockInterviewCameraGateView(
                state: state,
                cameraService: _cameraService,
              ),
              MockInterviewLoadingQuestion() => const AppLoader(
                message: 'Loading your next question…',
              ),
              MockInterviewLoadFailed(failure: final failure) => AppErrorView(
                message: failure.message,
                onRetry: controller.retryLoadQuestion,
              ),
              MockInterviewQuestionActive() => MockInterviewQuestionView(
                state: state,
              ),
              MockInterviewTerminated(:final message) => _TerminatedView(
                message: message,
              ),
              MockInterviewLoadingResults() => const AppLoader(
                message: 'Scoring your interview…',
              ),
              MockInterviewResultsFailed(failure: final failure) =>
                AppErrorView(
                  message: failure.message,
                  onRetry: controller.retryLoadResults,
                ),
              MockInterviewResults(:final analytics) =>
                MockInterviewResultsView(analytics: analytics),
            },
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _TerminatedView extends StatelessWidget {
  const _TerminatedView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Interview Terminated',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Loading your results…'),
          ],
        ),
      ),
    );
  }
}
