import 'package:camera/camera.dart';

/// A thin, testable seam over `package:camera` — the same "define an
/// interface for a platform capability, inject it" pattern already used for
/// `AudioRecorderService` (`lib/features/ai_speaking/domain/services/
/// audio_recorder_service.dart`). Lets `MockInterviewController`/the setup
/// screen be tested without a real camera.
///
/// This service is used for exactly one thing: showing a live front-camera
/// preview and confirming a real frame is flowing, for the
/// `resume_camera_verified` self-attestation gate (a boolean, not
/// server-verified — the real web does the exact same self-attestation, see
/// `verifyCameraStream` in `templates/resume_interview.html`). It
/// deliberately does **not** run any face-detection ML against the frames it
/// exposes — see the mock_interview feature's top-level doc comment
/// (`mock_interview_controller.dart`) for why that's explicitly out of
/// scope for this batch.
abstract class InterviewCameraService {
  /// Requests camera permission (if needed) and starts a live front-camera
  /// preview. Returns `true` once a genuinely live, initialized preview is
  /// flowing — mirrors the web's own `verifyCameraStream` (a live video
  /// track that has actually decoded a frame), not merely that the OS
  /// permission prompt was accepted.
  Future<bool> start();

  /// The real preview controller once [start] has succeeded — `null` before
  /// that, after a failed [start], or after [dispose]. Widgets use this to
  /// build a `CameraPreview`.
  CameraController? get controller;

  /// `true` once [start] succeeded and the underlying controller is still
  /// initialized with no error — the honest "camera is live" check behind
  /// `resume_camera_verified`. This is a presence/liveness check only; it is
  /// not, and must never be presented as, a face-visibility check.
  bool get isLive;

  /// Batch 10 — starts recording the live preview to a local file, the
  /// mobile-native equivalent of the web's own `startVideoRecording()`
  /// (`templates/resume_interview.html:792-815`, a continuous `MediaRecorder`
  /// capture that begins right after camera verification and runs for the
  /// whole interview). No-op if [isLive] is false or a recording is already
  /// in progress.
  Future<void> startVideoRecording();

  /// Stops the in-progress recording and returns the local file path to
  /// upload — mirrors `finishVideoRecording()`
  /// (`templates/resume_interview.html:877-906`). Returns `null` if no
  /// recording was ever started (never a fabricated/empty file).
  Future<String?> stopVideoRecording();

  Future<void> dispose();
}
