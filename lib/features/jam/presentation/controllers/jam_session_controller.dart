import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../ai_speaking/domain/services/audio_recorder_service.dart';
import '../../domain/entities/jam_assessment.dart';
import '../../domain/entities/jam_session_result.dart';
import '../../domain/entities/jam_session_start.dart';
import '../providers/jam_providers.dart';

/// JAM's real web flow (`session.html` + its inline JS, read in full) is a
/// single page with in-place state transitions — Instructions → Recording
/// (a hard 60-second cap, `let totalSeconds = 60;`) → Captured (upload
/// already fired automatically on stop) → "Get AI Feedback" → Result — with
/// two server round-trips (`save_audio` on stop, `complete_session` on
/// "Get AI Feedback"). This mirrors that shape.
///
/// One deliberate deviation, consistent with `AiSpeakingController`'s own
/// documented philosophy: the web's `saveSessionData` shows "Session
/// Captured Successfully" (and wires up the "Get AI Feedback" link)
/// **even when the `save_audio` POST itself fails** (its `catch` block does
/// the same UI update as success — `session.html`'s inline script). This
/// client instead surfaces a real, retryable [JamUploadFailed] state on a
/// failed upload rather than silently letting the user proceed to a
/// `complete_session` call for a session with no saved audio/duration
/// (which would score as "no speech detected" — not what actually
/// happened).
sealed class JamSessionState {
  const JamSessionState();
}

/// Before [JamSessionController.startSession] has been called yet.
final class JamSessionInitial extends JamSessionState {
  const JamSessionInitial();
}

final class JamStarting extends JamSessionState {
  const JamStarting();
}

final class JamStartFailed extends JamSessionState {
  const JamStartFailed(this.failure);
  final Failure failure;
}

/// Session created server-side; instructions/topic shown, not recording yet
/// — mirrors `session.html`'s instructions modal + idle timer ring reading
/// `1:00`.
final class JamReady extends JamSessionState {
  const JamReady({required this.session, this.micErrorMessage});
  final JamSessionStart session;
  final String? micErrorMessage;
}

final class JamRecordingInProgress extends JamSessionState {
  const JamRecordingInProgress({required this.session, required this.elapsedSeconds});
  final JamSessionStart session;
  final int elapsedSeconds;

  /// `session.html`: `let totalSeconds = 60;` — JAM is literally "Just A
  /// Minute"; the real web enforces exactly this, auto-stopping at 60s.
  static const int maxSeconds = 60;
}

/// `elapsed < 2` guard (`session.html`'s `handleRecordingStop` — "Recording
/// too short, please try again."). The same [session] can be re-recorded.
final class JamRecordingTooShort extends JamSessionState {
  const JamRecordingTooShort({required this.session});
  final JamSessionStart session;
}

final class JamUploading extends JamSessionState {
  const JamUploading({required this.session, required this.audioFilePath, required this.elapsedSeconds});
  final JamSessionStart session;
  final String? audioFilePath;
  final int elapsedSeconds;
}

/// Preserves the recording so [JamSessionController.retryUpload] can resend
/// the exact same file without re-recording.
final class JamUploadFailed extends JamSessionState {
  const JamUploadFailed({
    required this.session,
    required this.audioFilePath,
    required this.elapsedSeconds,
    required this.failure,
  });
  final JamSessionStart session;
  final String? audioFilePath;
  final int elapsedSeconds;
  final Failure failure;
}

/// Upload succeeded — "Session Captured Successfully" + "Get AI Feedback"
/// (`session.html`'s `submitArea`).
final class JamReadyForFeedback extends JamSessionState {
  const JamReadyForFeedback({required this.session, required this.elapsedSeconds});
  final JamSessionStart session;
  final int elapsedSeconds;
}

final class JamCompleting extends JamSessionState {
  const JamCompleting({required this.session});
  final JamSessionStart session;
}

/// Also used as retry from — [JamSessionController.getFeedback] resends the
/// same completion request.
final class JamCompleteFailed extends JamSessionState {
  const JamCompleteFailed({required this.session, required this.failure});
  final JamSessionStart session;
  final Failure failure;
}

final class JamResultReady extends JamSessionState {
  const JamResultReady(this.result);
  final JamSessionResult result;
}

/// Assessment-only terminal state: [getFeedback] reached stage 3's
/// `complete_session` call and the server responded with the final
/// diagnostic report (`jam:assessment_result`) rather than a normal
/// `session_detail.html` — see [JamAssessmentStageOutcome].
final class JamAssessmentResultReady extends JamSessionState {
  const JamAssessmentResultReady(this.result);
  final JamAssessmentResult result;
}

class JamSessionController extends Notifier<JamSessionState> {
  late final AudioRecorderService _recorder;
  Timer? _timer;
  String _language = 'english';

  @override
  JamSessionState build() {
    _recorder = ref.read(jamAudioRecorderServiceProvider);
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_recorder.cancel());
    });
    return const JamSessionInitial();
  }

  void setLanguage(String language) => _language = language;

  /// `jam:jam_session` ([topicId] `null`, a random active topic) /
  /// `jam:jam_session_topic` ([topicId] set).
  Future<void> startSession({int? topicId}) async {
    state = const JamStarting();
    final result = await ref.read(jamRepositoryProvider).startSession(topicId: topicId);
    state = switch (result) {
      Success(value: final session) => JamReady(session: session),
      Failed(failure: final failure) => JamStartFailed(failure),
    };
  }

  /// `jam:start_assessment` — begins the 3-stage Assessment flow, landing
  /// on stage 1 (`session.stage == 1`). From here on, the exact same
  /// recording/upload states above drive stage 1 as they would an ordinary
  /// practice session; only [getFeedback] branches differently for a
  /// [JamSessionStart.stage]-carrying session — see that method's doc
  /// comment.
  Future<void> startAssessment() async {
    state = const JamStarting();
    final result = await ref.read(jamAssessmentRepositoryProvider).startAssessment();
    state = switch (result) {
      Success(value: final session) => JamReady(session: session),
      Failed(failure: final failure) => JamStartFailed(failure),
    };
  }

  Future<void> startRecording() async {
    final JamSessionStart session;
    switch (state) {
      case JamReady(session: final s):
        session = s;
      case JamRecordingTooShort(session: final s):
        session = s;
      default:
        return;
    }

    final granted = await _recorder.hasPermission();
    if (!granted) {
      state = JamReady(
        session: session,
        micErrorMessage: 'Microphone access denied. Please allow microphone access in your device settings and try again.',
      );
      return;
    }
    await _recorder.start();
    state = JamRecordingInProgress(session: session, elapsedSeconds: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! JamRecordingInProgress) return;
    final next = current.elapsedSeconds + 1;
    if (next >= JamRecordingInProgress.maxSeconds) {
      unawaited(stopRecording());
      return;
    }
    state = JamRecordingInProgress(session: current.session, elapsedSeconds: next);
  }

  Future<void> stopRecording() async {
    final current = state;
    if (current is! JamRecordingInProgress) return;
    _timer?.cancel();
    final elapsed = current.elapsedSeconds;
    final path = await _recorder.stop();

    if (elapsed < 2) {
      state = JamRecordingTooShort(session: current.session);
      return;
    }
    await _uploadAndAdvance(session: current.session, audioFilePath: path, elapsedSeconds: elapsed);
  }

  Future<void> _uploadAndAdvance({
    required JamSessionStart session,
    required String? audioFilePath,
    required int elapsedSeconds,
  }) async {
    state = JamUploading(session: session, audioFilePath: audioFilePath, elapsedSeconds: elapsedSeconds);
    final result = await ref
        .read(jamRepositoryProvider)
        .saveAudio(
          sessionId: session.sessionId,
          audioFilePath: audioFilePath,
          durationSeconds: elapsedSeconds,
          language: _language,
        );
    state = switch (result) {
      Success() => JamReadyForFeedback(session: session, elapsedSeconds: elapsedSeconds),
      Failed(failure: final failure) => JamUploadFailed(
        session: session,
        audioFilePath: audioFilePath,
        elapsedSeconds: elapsedSeconds,
        failure: failure,
      ),
    };
  }

  /// Retries a failed [saveAudio] call, resending the exact same recording.
  Future<void> retryUpload() async {
    final current = state;
    if (current is! JamUploadFailed) return;
    await _uploadAndAdvance(
      session: current.session,
      audioFilePath: current.audioFilePath,
      elapsedSeconds: current.elapsedSeconds,
    );
  }

  /// "Get AI Feedback" / "Next Stage" / "Generate Diagnostic Report"
  /// (`jam:complete_session` — the same single endpoint for all 3 labels;
  /// `session.html`'s own submit button text is the only thing that varies,
  /// `session.html:158-183`) — also used as retry from [JamCompleteFailed].
  ///
  /// Branches purely on [JamSessionStart.stage] (set only for a session
  /// this client itself started via [startAssessment]/an assessment
  /// `JamReady` produced by a prior stage's own call here) — never sent to
  /// the server, which already knows independently whether the session
  /// belongs to an `AssessmentGroup` (`jam_app/views.py:684-701`) and
  /// redirects accordingly regardless of what this client believes; this
  /// is purely about parsing the response with the right shape:
  /// - not an assessment session → [JamResultReady], same as always.
  /// - an assessment session, stage 1→2/2→3 → back to [JamReady] with the
  ///   next stage's session already loaded (no separate "start" call
  ///   needed for it — see [JamAssessmentNextStage]'s doc comment).
  /// - an assessment session, stage 3 done → [JamAssessmentResultReady].
  Future<void> getFeedback() async {
    final JamSessionStart session;
    switch (state) {
      case JamReadyForFeedback(session: final s):
        session = s;
      case JamCompleteFailed(session: final s):
        session = s;
      default:
        return;
    }
    state = JamCompleting(session: session);

    if (session.stage != null) {
      final result = await ref.read(jamAssessmentRepositoryProvider).completeAssessmentStage(session.sessionId);
      state = switch (result) {
        Success(value: JamAssessmentNextStage(session: final next)) => JamReady(session: next),
        Success(value: JamAssessmentFinished(result: final r)) => JamAssessmentResultReady(r),
        Failed(failure: final failure) => JamCompleteFailed(session: session, failure: failure),
      };
      return;
    }

    final result = await ref.read(jamRepositoryProvider).completeSession(session.sessionId);
    state = switch (result) {
      Success(value: final r) => JamResultReady(r),
      Failed(failure: final failure) => JamCompleteFailed(session: session, failure: failure),
    };
  }
}
