import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../controllers/mock_test_controller.dart';
import 'mock_exam_colors.dart';

/// Free-navigation question grid — mirrors the web's side palette
/// (`005 oop-mastery.html:2649-2651,2688-2696`, `#examPal`): tap any
/// question number to jump straight to it, regardless of answered state.
/// Shown as a bottom sheet on mobile rather than a permanent side panel,
/// since there's no room for a persistent sidebar at phone widths — the
/// same "Answered / Marked for review / Not answered" legend and jump
/// behavior are preserved, only the container changed.
Future<void> showMockTestPaletteSheet(BuildContext context, {required MockTestInProgress state, required MockTestController controller}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PaletteSheet(state: state, controller: controller),
  );
}

class _PaletteSheet extends StatelessWidget {
  const _PaletteSheet({required this.state, required this.controller});

  final MockTestInProgress state;
  final MockTestController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question palette', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Answered ${state.answeredCount} / ${state.questions.length}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: state.questions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                ),
                itemBuilder: (context, index) {
                  final question = state.questions[index];
                  final isAnswered = state.answers.containsKey(question.id);
                  final isMarked = state.marked.contains(question.id);
                  final isCurrent = index == state.currentIndex;

                  final Color background;
                  final Color foreground;
                  if (isMarked) {
                    background = MockExamColors.markedBg;
                    foreground = MockExamColors.markedText;
                  } else if (isAnswered) {
                    background = MockExamColors.navy;
                    foreground = Colors.white;
                  } else {
                    background = Colors.white;
                    foreground = MockExamColors.navy;
                  }

                  return InkWell(
                    onTap: () {
                      controller.goToQuestion(index);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrent ? MockExamColors.navy : MockExamColors.border,
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Text('${index + 1}', style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _Legend(),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: const [
        _LegendItem(color: MockExamColors.navy, label: 'Answered'),
        _LegendItem(color: MockExamColors.markedBg, label: 'Marked for review'),
        _LegendItem(color: MockExamColors.border, label: 'Not answered'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
