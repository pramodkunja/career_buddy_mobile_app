import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../controllers/ai_reading_controller.dart';

/// Mirrors the recording panel (`reading.html:145-177`): mic button, live
/// timer + status + pause count, Pause/Resume, then — once stopped — a
/// "Submit for Analysis" action. No live word count/transcript preview
/// (see `AiReadingRemoteDataSource`'s doc comment on why — no Flutter
/// equivalent to the web's `SpeechRecognition` live capture).
class ReadingRecorderCard extends StatelessWidget {
  const ReadingRecorderCard({required this.state, required this.controller, super.key});

  final ReadingState state;
  final AiReadingController controller;

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    return switch (state) {
      ReadingIdle() => _IdleCard(state: state, controller: controller),
      ReadingRecording() => _RecordingCard(state: state, controller: controller),
      ReadingRecorded() => _RecordedCard(state: state, controller: controller),
      ReadingSubmitting() => _RecordedCard.submitting(state: state),
      ReadingSubmitFailed() => _RecordedCard.failed(state: state, controller: controller),
      ReadingResult() => const SizedBox.shrink(),
    };
  }
}

class _IdleCard extends StatelessWidget {
  const _IdleCard({required this.state, required this.controller});

  final ReadingIdle state;
  final AiReadingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicButton(recording: false, onTap: controller.startRecording),
          const SizedBox(height: AppSpacing.md),
          Text('Tap to Start Recording', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
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

  final ReadingRecording state;
  final AiReadingController controller;

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
            state.paused ? 'Paused. Tap Resume to continue.' : 'Recording... Tap the mic to stop.',
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

  const _RecordedCard.submitting({required ReadingSubmitting this.state}) : controller = null, isSubmitting = true;

  const _RecordedCard.failed({required ReadingSubmitFailed this.state, required this.controller}) : isSubmitting = false;

  final ReadingState state;
  final AiReadingController? controller;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = state;
    final note = s is ReadingSubmitFailed
        ? s.failure.message
        : 'Recording ready. Tap Submit for Analysis to generate your transcript and feedback.';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.headphones, color: ModuleColors.reading),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Your Recording', style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(color: s is ReadingSubmitFailed ? AppColors.danger : AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: isSubmitting ? 'Analyzing…' : (s is ReadingSubmitFailed ? 'Retry Analysis' : 'Submit for Analysis'),
            icon: Icons.psychology_outlined,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : controller?.submitForAnalysis,
            backgroundColor: ModuleColors.reading,
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
    // `#micBtn`/`#micBtn.rec` (`reading.html:53-61`) — 72px, with its own
    // colored `box-shadow` (orange idle, red recording).
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: recording ? AppColors.danger : ModuleColors.reading,
        boxShadow: [
          BoxShadow(
            color: (recording ? const Color(0xFFDC2626) : const Color(0xFFD97706)).withValues(alpha: 0.3),
            offset: const Offset(0, 10),
            blurRadius: 15,
          ),
        ],
      ),
      child: Material(
        shape: const CircleBorder(),
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(recording ? Icons.stop : Icons.mic, color: AppColors.textOnDark, size: 28),
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
