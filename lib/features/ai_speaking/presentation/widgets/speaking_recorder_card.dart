import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../controllers/ai_speaking_controller.dart';

/// Mirrors the recorder panel (`speaking.html:347-404`): mic button, live
/// timer + status + pause count, Pause/Resume, then — once stopped — a
/// "Your Recording" section with a Submit for Analysis action.
///
/// Deliberately shows no live word count and no waveform/live-transcript
/// preview — both depend on the web's client-side Web Speech API
/// transcription, which has no Flutter equivalent here (see
/// `AiSpeakingRemoteDataSource`'s doc comment on `client_transcript`); the
/// timer, pause count, and recording/analysis flow itself are otherwise
/// unchanged.
class SpeakingRecorderCard extends StatelessWidget {
  const SpeakingRecorderCard({required this.state, required this.controller, super.key});

  final AiSpeakingState state;
  final AiSpeakingController controller;

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    return switch (state) {
      AiSpeakingIdle() => _IdleCard(state: state, controller: controller),
      AiSpeakingRecording() => _RecordingCard(state: state, controller: controller),
      AiSpeakingRecorded() => _RecordedCard(state: state, controller: controller),
      AiSpeakingSubmitting() => _RecordedCard.submitting(state: state),
      AiSpeakingSubmitFailed() => _RecordedCard.failed(state: state, controller: controller),
      AiSpeakingResult() => const SizedBox.shrink(),
    };
  }
}

class _IdleCard extends StatelessWidget {
  const _IdleCard({required this.state, required this.controller});

  final AiSpeakingIdle state;
  final AiSpeakingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicButton(recording: false, onTap: controller.startRecording),
          const SizedBox(height: AppSpacing.md),
          Text('Click to start recording', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          if (state.micErrorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.micErrorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.state, required this.controller});

  final AiSpeakingRecording state;
  final AiSpeakingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicButton(recording: true, onTap: controller.stopRecording),
          const SizedBox(height: AppSpacing.md),
          Text(
            state.paused ? 'Paused recording. Tap Resume to continue.' : 'Recording in progress. Tap Stop to finish.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _StatChip(icon: Icons.timer_outlined, label: '${state.elapsedSeconds}s'),
              _StatChip(icon: Icons.circle, label: state.paused ? 'Paused' : 'Recording'),
              _StatChip(icon: Icons.pause_circle_outline, label: 'Pauses: ${state.pauseCount}'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: state.paused ? 'Resume' : 'Pause',
            variant: AppButtonVariant.outlined,
            fullWidth: false,
            onPressed: state.paused ? controller.resumeRecording : controller.pauseRecording,
          ),
        ],
      ),
    );
  }
}

class _RecordedCard extends StatelessWidget {
  const _RecordedCard({required this.state, required this.controller}) : isSubmitting = false;

  const _RecordedCard.submitting({required AiSpeakingSubmitting this.state}) : controller = null, isSubmitting = true;

  const _RecordedCard.failed({required AiSpeakingSubmitFailed this.state, required this.controller}) : isSubmitting = false;

  final AiSpeakingState state;
  final AiSpeakingController? controller;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = state;
    final note = switch (s) {
      AiSpeakingRecorded(timeLimitReached: true) => 'Time limit reached (90 seconds). Ready to analyze.',
      AiSpeakingRecorded(pauseLimitExceeded: true) =>
        'Maximum pause limit (5) exceeded. Recording stopped — ready to analyze.',
      _ => 'Recording ready. Tap Submit for Analysis to generate your transcript and feedback.',
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.headphones, color: ModuleColors.speaking),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Your Recording', style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(note, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          if (s is AiSpeakingSubmitFailed) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(s.failure.message, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: isSubmitting ? 'Analyzing…' : (s is AiSpeakingSubmitFailed ? 'Retry Analysis' : 'Submit for Analysis'),
            icon: Icons.psychology_outlined,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : controller?.submitForAnalysis,
            backgroundColor: ModuleColors.speaking,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (controller != null && !isSubmitting)
            AppButton(
              label: 'Record Again',
              variant: AppButtonVariant.text,
              onPressed: controller!.startRecording,
            ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.recording, required this.onTap});

  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `#micBtn`/`#micBtn.rec` (`speaking.html:126-150`) — 120px, with its
    // own colored `box-shadow` (blue idle, red recording), not just a flat
    // fill.
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: recording ? AppColors.danger : ModuleColors.speaking,
        boxShadow: [
          BoxShadow(
            color: (recording ? const Color(0xFFDC2626) : const Color(0xFF2563EB)).withValues(alpha: recording ? 0.4 : 0.32),
            offset: Offset(0, recording ? 4 : 8),
            blurRadius: recording ? 16 : 24,
          ),
        ],
      ),
      child: Material(
        shape: const CircleBorder(),
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(recording ? Icons.stop : Icons.mic, color: AppColors.textOnDark, size: 44),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
