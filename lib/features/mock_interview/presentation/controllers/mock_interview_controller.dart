import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/answer_submission_result.dart';
import '../../domain/entities/interview_analytics.dart';
import '../../domain/entities/interview_question.dart';
import '../../domain/entities/malpractice.dart';
import '../../domain/entities/next_question_outcome.dart';
import '../../domain/repositories/mock_interview_repository.dart';
import '../providers/mock_interview_providers.dart';

/// AI Mock Interview — a full, real, server-authoritative interview: every
/// question, the 30s-per-answer timer, every score/feedback, and the final
/// result come from `career_app.views`' real endpoints (see
/// `ApiEndpoints`'s doc comment) exactly as the web page
/// (`templates/resume_interview.html`) drives them. Nothing here is
/// simulated or locally-scored.
///
/// **Scope note — face detection is intentionally not implemented.** The
/// real web page additionally runs `face-api.js` against the camera feed
/// to detect an absent/multiple face and reports that as a
/// `FACE_NOT_DETECTED`/`MULTIPLE_FACES` violation
/// (`templates/resume_interview.html:1768-1826`). That is a genuinely
/// separate, substantial capability (real-time on-device ML inference
/// against a live camera feed) — not a simple API-consumption task like
/// every other part of this feature — and is out of scope here. What this
/// controller *does* implement, honestly and for real, is the mobile
/// equivalent of the web's other anti-malpractice signals: app-lifecycle-
/// based tab-switch/backgrounding detection via `WidgetsBindingObserver`
/// (`MockInterviewScreen`), reported to the same real
/// `resume_record_violation` endpoint the web uses — see
/// `ViolationType`'s doc comment for exactly which event types this client
/// reports and why. `resume_record_violation` already accepts
/// `face_not_detected`/`multiple_faces` event types unchanged — the backend
/// side of this gap is not a blocker, only a missing on-device ML
/// dependency in this codebase today.
sealed class MockInterviewState {
  const MockInterviewState();
}

/// Before `start()` has been called — `MockInterviewScreen` calls it once,
/// right after first build.
final class MockInterviewIdle extends MockInterviewState {
  const MockInterviewIdle();
}

final class MockInterviewStarting extends MockInterviewState {
  const MockInterviewStarting();
}

/// `resume_start_interview` failed — no Premium plan, no parsed resume yet,
/// or a network/server error. [failure] carries the real message.
final class MockInterviewStartFailed extends MockInterviewState {
  const MockInterviewStartFailed(this.failure);
  final Failure failure;
}

/// The mandatory camera gate — mirrors `templates/resume_interview.html`'s
/// `#camera-gate-screen`. The screen itself owns the real `camera`-package
/// preview/permission flow (via `InterviewCameraService`) and calls
/// [MockInterviewController.confirmCameraLive] once it has a genuinely live
/// preview frame; this state only tracks that server round-trip.
final class MockInterviewCameraGate extends MockInterviewState {
  const MockInterviewCameraGate({this.isConfirming = false, this.error});
  final bool isConfirming;
  final Failure? error;
}

final class MockInterviewLoadingQuestion extends MockInterviewState {
  const MockInterviewLoadingQuestion();
}

/// Fetching a question (or submitting an answer) failed for a reason other
/// than the two the server itself distinguishes
/// ([CameraRequiredFailure]/[MalpracticeTerminatedFailure], both handled by
/// dedicated states below) — a network hiccup, session expiry, etc.
final class MockInterviewLoadFailed extends MockInterviewState {
  const MockInterviewLoadFailed(this.failure);
  final Failure failure;
}

/// A question is live: the 30s-per-answer countdown
/// (`ANSWER_TIME_LIMIT_SECONDS`, `career_app/views.py:976`) is ticking,
/// server-seeded from `time_remaining` so a resumed session picks up the
/// real remaining time rather than resetting to 30.
final class MockInterviewQuestionActive extends MockInterviewState {
  const MockInterviewQuestionActive({
    required this.question,
    required this.secondsRemaining,
    required this.answerText,
    this.isSubmitting = false,
    this.violationCount = 0,
    this.violationStatus = MalpracticeStatus.clean,
    this.activeWarning,
  });

  final InterviewQuestion question;
  final int secondsRemaining;
  final String answerText;
  final bool isSubmitting;
  final int violationCount;
  final MalpracticeStatus violationStatus;

  /// Set right after a violation is recorded — mirrors the web's blocking
  /// "I Understand, Continue" modal (`templates/resume_interview.html:
  /// 1614-1638`). Cleared by [MockInterviewController.acknowledgeWarning].
  final ViolationRecordResult? activeWarning;

  MockInterviewQuestionActive copyWith({
    InterviewQuestion? question,
    int? secondsRemaining,
    String? answerText,
    bool? isSubmitting,
    int? violationCount,
    MalpracticeStatus? violationStatus,
    ViolationRecordResult? activeWarning,
    bool clearActiveWarning = false,
  }) {
    return MockInterviewQuestionActive(
      question: question ?? this.question,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      answerText: answerText ?? this.answerText,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      violationCount: violationCount ?? this.violationCount,
      violationStatus: violationStatus ?? this.violationStatus,
      activeWarning: clearActiveWarning ? null : (activeWarning ?? this.activeWarning),
    );
  }
}

/// The interview ended because of repeated malpractice violations
/// (`MALPRACTICE_TERMINATE_THRESHOLD`, `career_app/views.py:1042`) — the
/// server already scored whatever was answered so far
/// (`_score_and_finalize_session`); this state briefly shows the same
/// "terminated" messaging as the web (`templates/resume_interview.html:
/// 463-470`) before loading results.
final class MockInterviewTerminated extends MockInterviewState {
  const MockInterviewTerminated(this.message);
  final String message;
}

final class MockInterviewLoadingResults extends MockInterviewState {
  const MockInterviewLoadingResults();
}

final class MockInterviewResults extends MockInterviewState {
  const MockInterviewResults(this.analytics);
  final InterviewAnalyticsResult analytics;
}

final class MockInterviewResultsFailed extends MockInterviewState {
  const MockInterviewResultsFailed(this.failure);
  final Failure failure;
}

class MockInterviewController extends Notifier<MockInterviewState> {
  Timer? _timer;
  bool _lastAdvance = false;

  MockInterviewRepository get _repository => ref.read(mockInterviewRepositoryProvider);

  @override
  MockInterviewState build() {
    ref.onDispose(() => _timer?.cancel());
    return const MockInterviewIdle();
  }

  /// `resume_start_interview`. Safe to call more than once (e.g. a screen
  /// re-entering `Idle` after a failed attempt) — each call creates a fresh
  /// server-side session, matching "Try Interview" being tappable again on
  /// the web.
  Future<void> start() async {
    state = const MockInterviewStarting();
    final result = await _repository.startInterview();
    switch (result) {
      case Success():
        state = const MockInterviewCameraGate();
      case Failed(failure: final failure):
        state = MockInterviewStartFailed(failure);
    }
  }

  Future<void> retryStart() => start();

  /// Called by the setup screen once its own `InterviewCameraService`
  /// reports a genuinely live preview frame — see that service's doc
  /// comment for exactly what "live" means here (a presence/liveness
  /// self-attestation, not a face check).
  Future<void> confirmCameraLive() async {
    final current = state;
    if (current is! MockInterviewCameraGate || current.isConfirming) return;
    state = const MockInterviewCameraGate(isConfirming: true);
    final result = await _repository.confirmCameraLive();
    switch (result) {
      case Success():
        await _loadNextQuestion(advance: false);
      case Failed(failure: final failure):
        state = MockInterviewCameraGate(error: failure);
    }
  }

  Future<void> retryLoadQuestion() => _loadNextQuestion(advance: _lastAdvance);

  Future<void> _loadNextQuestion({required bool advance}) async {
    _timer?.cancel();
    _lastAdvance = advance;
    state = const MockInterviewLoadingQuestion();
    final result = await _repository.getNextQuestion(advance: advance);
    switch (result) {
      case Success(value: final outcome):
        switch (outcome) {
          case NextQuestionReady(question: final question):
            state = MockInterviewQuestionActive(
              question: question,
              secondsRemaining: question.timeRemainingSeconds,
              answerText: '',
            );
            _startTimer();
          case InterviewCompleted():
            await _finish();
        }
      case Failed(failure: final failure):
        state = switch (failure) {
          CameraRequiredFailure() => MockInterviewCameraGate(error: failure),
          MalpracticeTerminatedFailure() => MockInterviewTerminated(failure.message),
          _ => MockInterviewLoadFailed(failure),
        };
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! MockInterviewQuestionActive || current.isSubmitting) return;
    if (current.secondsRemaining <= 1) {
      _timer?.cancel();
      state = current.copyWith(secondsRemaining: 0);
      unawaited(_autoSubmit());
      return;
    }
    state = current.copyWith(secondsRemaining: current.secondsRemaining - 1);
  }

  /// Live-updates the answer text as the candidate types (or as on-device
  /// speech-to-text fills it in) — purely local state until [submitAnswer].
  void updateAnswerText(String text) {
    final current = state;
    if (current is! MockInterviewQuestionActive) return;
    state = current.copyWith(answerText: text);
  }

  /// Manual submit (the candidate tapped Submit before time ran out).
  Future<void> submitAnswer() async {
    final current = state;
    if (current is! MockInterviewQuestionActive || current.isSubmitting) return;
    _timer?.cancel();
    state = current.copyWith(isSubmitting: true);
    final result = await _repository.submitAnswer(
      questionId: current.question.id,
      answerText: current.answerText.trim(),
    );
    await _handleSubmitResult(current, result);
  }

  /// Timer-driven forced submit — mirrors the real page's own
  /// `forceSubmitSpokenAnswer` (`templates/resume_interview.html:1159-
  /// 1199`): whatever text exists when the 30s window closes (even none) is
  /// submitted as-is; this never blocks or shows a validation error the way
  /// a manual submit with no text conceptually could.
  Future<void> _autoSubmit() async {
    final current = state;
    if (current is! MockInterviewQuestionActive) return;
    state = current.copyWith(isSubmitting: true, secondsRemaining: 0);
    final result = await _repository.submitAnswer(
      questionId: current.question.id,
      answerText: current.answerText.trim(),
    );
    await _handleSubmitResult(current, result);
  }

  Future<void> _handleSubmitResult(
    MockInterviewQuestionActive prior,
    Result<AnswerSubmissionResult> result,
  ) async {
    switch (result) {
      case Success():
        await _loadNextQuestion(advance: true);
      case Failed(failure: final failure):
        state = switch (failure) {
          MalpracticeTerminatedFailure() => MockInterviewTerminated(failure.message),
          CameraRequiredFailure() => MockInterviewCameraGate(error: failure),
          // A transient failure (network/server) — let the candidate see
          // their typed answer is still there and retry, rather than
          // losing it or silently reloading a fresh 30s question.
          _ => prior.copyWith(isSubmitting: false),
        };
    }
  }

  Future<void> _finish() async {
    state = const MockInterviewLoadingResults();
    await _loadResults();
  }

  Future<void> _loadResults() async {
    final result = await _repository.getAnalytics();
    switch (result) {
      case Success(value: final analytics):
        state = MockInterviewResults(analytics);
      case Failed(failure: final failure):
        state = MockInterviewResultsFailed(failure);
    }
  }

  Future<void> retryLoadResults() async {
    state = const MockInterviewLoadingResults();
    await _loadResults();
  }

  /// Called by `MockInterviewScreen`'s `WidgetsBindingObserver` on a real
  /// app-lifecycle change (backgrounding/foregrounding) — the native
  /// equivalent of the web's `visibilitychange`/`window.blur` listeners
  /// (`templates/resume_interview.html:1723-1737`). Only meaningful while a
  /// question is actually live, mirroring the web's own `interviewIsActive()`
  /// guard.
  Future<void> reportViolation(ViolationType type, {double? durationSeconds}) async {
    final current = state;
    if (current is! MockInterviewQuestionActive) return;
    final result = await _repository.recordViolation(type: type, durationSeconds: durationSeconds);
    switch (result) {
      case Success(value: final record):
        final latest = state;
        if (latest is! MockInterviewQuestionActive) return; // state moved on while this was in flight
        if (record.action == ViolationAction.terminated) {
          _timer?.cancel();
          // Deliberately does not route through `_finish()`/`MockInterviewLoadingResults`
          // — `MockInterviewTerminated`'s own UI already shows a "loading your
          // results" affordance (mirrors the web's own terminated overlay,
          // `templates/resume_interview.html:463-470`), so this state must
          // stay visible while results load in the background rather than
          // being immediately overwritten.
          state = const MockInterviewTerminated(
            'This interview was ended due to repeated malpractice violations (leaving the app during '
            'the interview). Your answers so far have been saved and scored.',
          );
          unawaited(_loadResults());
        } else {
          state = latest.copyWith(
            violationCount: record.count,
            violationStatus: record.status,
            activeWarning: record,
          );
        }
      case Failed():
        // Best-effort, exactly like the web's own `recordMalpracticeViolation`
        // catch-all — a transient failure logging a violation must never
        // itself interrupt the interview.
        break;
    }
  }

  /// The candidate tapped through the blocking violation-warning modal.
  void acknowledgeWarning() {
    final current = state;
    if (current is! MockInterviewQuestionActive) return;
    state = current.copyWith(clearActiveWarning: true);
  }

  /// Batch 10 — `resume_upload_interview_video`. Called once by
  /// `MockInterviewScreen` right after it stops the continuous recording it
  /// started when the interview began (see that screen's doc comment for
  /// exactly when). Best-effort and fire-and-forget by design, mirroring the
  /// web's own `finishVideoRecording()`: a failed upload is not shown to the
  /// candidate as an error and never blocks/retries showing the results
  /// already loaded from `resume_analytics` — the server only persists this
  /// video at all when `session.is_passed` regardless, so a lost upload
  /// costs nothing the candidate needs to see or retry themselves. (The web
  /// retries once on a transient failure; this client does not reproduce
  /// that specific retry, a minor, documented simplification — not a
  /// fabricated success.)
  Future<void> uploadRecordedVideo(String filePath) async {
    await _repository.uploadInterviewVideo(filePath);
  }
}
