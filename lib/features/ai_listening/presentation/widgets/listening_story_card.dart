import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../controllers/ai_listening_controller.dart';

/// Mirrors the "Premium Player" card (`listening.html:151-202`): level/
/// speed selectors, New Story, the story title/meta, the story text
/// (hidden until Play is first tapped), Play/Pause, a progress bar, and
/// status/pause-count chips.
class ListeningStoryCard extends StatelessWidget {
  const ListeningStoryCard({
    required this.state,
    required this.onLevelChanged,
    required this.onSpeedChanged,
    required this.onNewStory,
    required this.onPlay,
    required this.onPause,
    super.key,
  });

  final ListeningActive state;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onNewStory;
  final VoidCallback onPlay;
  final VoidCallback onPause;

  static const _levelLabels = {'beginner': 'Beginner', 'intermediate': 'Intermediate'};
  static final _speedLabels = {0.8: '0.8×', 1.0: '1.0×', 1.2: '1.2×'};

  String get _statusLabel => switch (state.status) {
    PlaybackStatus.ready => 'Ready',
    PlaybackStatus.playing => 'Playing',
    PlaybackStatus.paused => 'Paused',
    PlaybackStatus.completed => 'Completed',
    PlaybackStatus.terminated => 'Terminated',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = state.durationSeconds == 0 ? 0.0 : (state.elapsedSeconds / state.durationSeconds).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STORY',
            style: theme.textTheme.labelSmall?.copyWith(color: ModuleColors.listening, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(state.story.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            '${state.durationSeconds}s | ${_levelLabels[state.level]} | ${state.speed}x speed',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: state.level,
                  items: _levelLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (value) {
                    if (value != null) onLevelChanged(value);
                  },
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<double>(
                  value: state.speed,
                  items: _speedLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (value) {
                    if (value != null) onSpeedChanged(value);
                  },
                ),
              ),
              AppButton(
                label: 'New Story',
                icon: Icons.sync_alt,
                variant: AppButtonVariant.outlined,
                fullWidth: false,
                onPressed: onNewStory,
              ),
            ],
          ),
          if (state.storyRevealed) ...[
            const SizedBox(height: AppSpacing.md),
            // `.story-box` (`listening.html:30-33`) — a tinted blue box,
            // not the neutral page background.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                border: Border.all(color: const Color(0xFFBAE6FD)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.story.text,
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: const Color(0xFF0C4A6E)),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlayerButton(
                  icon: state.status == PlaybackStatus.playing ? Icons.stop : Icons.play_arrow,
                  primary: true,
                  onTap: onPlay,
                ),
                const SizedBox(width: AppSpacing.lg),
                _PlayerButton(icon: Icons.pause, primary: false, onTap: onPause),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: AppColors.background, color: ModuleColors.listening),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _StatChip(label: 'Status: $_statusLabel'),
              _StatChip(label: 'Pauses: ${state.pauseCount}/${ListeningActive.maxPauses}'),
            ],
          ),
          if (state.status == PlaybackStatus.terminated) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You have exceeded the maximum pause count.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerButton extends StatelessWidget {
  const _PlayerButton({required this.icon, required this.primary, required this.onTap});

  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = primary ? 64.0 : 48.0;
    return Material(
      shape: const CircleBorder(),
      color: primary ? ModuleColors.listening : AppColors.background,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: primary ? AppColors.textOnDark : AppColors.textMuted, size: primary ? 32 : 22),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
