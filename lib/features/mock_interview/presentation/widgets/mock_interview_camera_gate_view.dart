import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../domain/services/interview_camera_service.dart';
import '../controllers/mock_interview_controller.dart';
import '../providers/mock_interview_providers.dart';

/// Mirrors `templates/resume_interview.html`'s `#camera-gate-screen`: a live
/// preview, an "Enable Camera" step, and a "Start Interview" step disabled
/// until a genuinely live frame is confirmed. See
/// `InterviewCameraService`'s doc comment for exactly what "live" means here
/// (a presence/liveness self-attestation for `resume_camera_verified`, never
/// a face-visibility check).
class MockInterviewCameraGateView extends ConsumerStatefulWidget {
  const MockInterviewCameraGateView({required this.state, required this.cameraService, super.key});

  final MockInterviewCameraGate state;

  /// Batch 10 — owned by the parent `MockInterviewScreen`, not created here
  /// anymore: its lifetime must span the whole interview (camera gate →
  /// questions → results) so the continuous video recording started once
  /// the gate is passed survives this view being unmounted, not just this
  /// screen's own live preview. See `MockInterviewScreen`'s doc comment.
  final InterviewCameraService cameraService;

  @override
  ConsumerState<MockInterviewCameraGateView> createState() => _MockInterviewCameraGateViewState();
}

class _MockInterviewCameraGateViewState extends ConsumerState<MockInterviewCameraGateView> {
  bool _isRequesting = false;
  bool _isLive = false;
  String _status = 'Camera access has not been granted yet.';
  bool _hasError = false;

  Future<void> _requestCamera() async {
    setState(() {
      _isRequesting = true;
      _hasError = false;
      _status = 'Requesting camera access…';
    });
    final live = await widget.cameraService.start();
    if (!mounted) return;
    setState(() {
      _isRequesting = false;
      _isLive = live;
      _hasError = !live;
      _status = live
          ? 'Camera connected. You can now start the interview.'
          : 'Camera access is required to attend the interview. Please allow camera access and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(mockInterviewControllerProvider.notifier);
    final camController = widget.cameraService.controller;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.videocam, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('Camera Access Required', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'This AI Mock Interview requires your camera to stay on for the entire session. '
            'Grant camera access and confirm your preview below before starting.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: const Color(0xFF0F172A),
                child: _isLive && camController != null && camController.value.isInitialized
                    ? CameraPreview(camController)
                    : const Center(
                        child: Icon(Icons.videocam_off, color: Colors.white54, size: 40),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            key: const Key('camera-gate-status'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _hasError
                  ? Theme.of(context).colorScheme.error
                  : (_isLive ? Colors.green : Theme.of(context).textTheme.bodySmall?.color),
              fontWeight: (_hasError || _isLive) ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (widget.state.error != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.state.error!.message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          if (!_isLive)
            AppButton(
              label: _isRequesting ? 'Requesting…' : 'Enable Camera',
              icon: Icons.videocam,
              isLoading: _isRequesting,
              onPressed: _isRequesting ? null : _requestCamera,
            )
          else
            AppButton(
              label: 'Start Interview',
              icon: Icons.play_arrow,
              isLoading: widget.state.isConfirming,
              onPressed: widget.state.isConfirming ? null : controller.confirmCameraLive,
            ),
        ],
      ),
    );
  }
}
