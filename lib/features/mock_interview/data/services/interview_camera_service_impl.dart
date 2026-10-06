import 'package:camera/camera.dart';

import '../../domain/services/interview_camera_service.dart';

class InterviewCameraServiceImpl implements InterviewCameraService {
  CameraController? _controller;

  @override
  CameraController? get controller => _controller;

  @override
  bool get isLive {
    final c = _controller;
    return c != null && c.value.isInitialized && !c.value.hasError;
  }

  @override
  Future<bool> start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // `enableAudio: true` — same reasoning as the web's own camera-gate
      // stream (`templates/resume_interview.html`'s `requestCameraAccess`):
      // requested together with audio so a later interview-video recording
      // (see `ApiEndpoints.resumeUploadInterviewVideo`) wouldn't be silent —
      // this app doesn't record continuous video today (see this feature's
      // top-level doc comment), but keeping the mic live costs nothing and
      // avoids a second, separate permission prompt if that's added later.
      final newController = CameraController(front, ResolutionPreset.low, enableAudio: true);
      await newController.initialize();
      _controller = newController;
      return newController.value.isInitialized && !newController.value.hasError;
    } catch (_) {
      _controller = null;
      return false;
    }
  }

  bool _recording = false;

  @override
  Future<void> startVideoRecording() async {
    final c = _controller;
    if (c == null || !isLive || _recording || c.value.isRecordingVideo) return;
    try {
      await c.startVideoRecording();
      _recording = true;
    } catch (_) {
      // Best-effort, same as the web's own `try { ... } catch { videoRecorder
      // = null; }` — a failed recorder must never block the interview.
      _recording = false;
    }
  }

  @override
  Future<String?> stopVideoRecording() async {
    final c = _controller;
    if (c == null || !_recording) return null;
    _recording = false;
    try {
      final file = await c.stopVideoRecording();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        if (_recording) await c.stopVideoRecording();
      } catch (_) {
        // Best-effort.
      }
      try {
        await c.dispose();
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }
}
