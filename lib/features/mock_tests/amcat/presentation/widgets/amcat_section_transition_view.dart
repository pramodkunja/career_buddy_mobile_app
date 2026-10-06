import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../presentation/widgets/mock_exam_colors.dart';
import '../controllers/amcat_controller.dart';

/// "Section Completed" — mirrors `renderSectionStatus()`
/// (`amcat_mock_test.html:789-813`): a status list with a tick for every
/// completed section, an "Up Next" highlight for the section "Next Task"
/// will unlock, and a lock icon for everything further down. The next
/// section never starts on its own — only `beginNextSection()`, wired to
/// this screen's own button tap, advances.
class AmcatSectionTransitionView extends StatelessWidget {
  const AmcatSectionTransitionView({required this.state, required this.onNextTask, super.key});

  final AmcatSectionTransition state;
  final VoidCallback onNextTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextSection = state.nextSection;
    final nextMinutes = (nextSection.timeSeconds / 60).round();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('✅ Section Completed', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Nice work — you've completed ${state.finishedSection.name}. Next up: ${nextSection.name} "
          '(${nextSection.questions.length} questions, $nextMinutes minutes) — locked until you\'re ready.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < state.sections.length; i++) ...[
          _SectionStatusTile(
            name: state.sections[i].name,
            status: state.completedSectionKeys.contains(state.sections[i].key)
                ? _Status.done
                : i == state.finishedSectionIndex + 1
                ? _Status.upNext
                : _Status.locked,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          'The next section stays locked until you click below.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Next Task', icon: Icons.arrow_forward, onPressed: onNextTask),
      ],
    );
  }
}

enum _Status { done, upNext, locked }

/// `.status-list li`/`.status-list li.done/.current/.locked` and
/// `.status-badge.done/.current/.locked` (`amcat_mock_test.html`'s base
/// CSS — not touched by the `#amcat-oop-skin` override, confirmed by
/// re-reading that block, so these stay the page's own green/gold/muted
/// tones): done = green border+tint with a filled `.tick-icon` circle;
/// current ("Up Next" here) = gold border+tint; locked = the same neutral
/// card at 65% opacity, not a color change.
class _SectionStatusTile extends StatelessWidget {
  const _SectionStatusTile({required this.name, required this.status});

  final String name;
  final _Status status;

  @override
  Widget build(BuildContext context) {
    final Color border;
    final Color background;
    final Color badgeColor;
    final String badgeText;
    switch (status) {
      case _Status.done:
        border = MockExamColors.success;
        background = MockExamColors.successBg;
        badgeColor = MockExamColors.success;
        badgeText = 'Completed';
      case _Status.upNext:
        border = MockExamColors.gold;
        background = MockExamColors.skipBg;
        badgeColor = MockExamColors.skipText;
        badgeText = 'Up Next';
      case _Status.locked:
        border = MockExamColors.border;
        background = MockExamColors.badgeBg;
        badgeColor = AppColors.textMuted;
        badgeText = 'Locked';
    }

    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (status == _Status.done)
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: MockExamColors.success, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 12),
            )
          else
            Icon(
              status == _Status.upNext ? Icons.play_circle_outline : Icons.lock_outline,
              color: badgeColor,
              size: 20,
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, color: MockExamColors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(badgeText, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );

    return status == _Status.locked ? Opacity(opacity: 0.65, child: tile) : tile;
  }
}
