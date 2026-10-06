import 'package:flutter/material.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../presentation/widgets/mock_exam_colors.dart';
import '../controllers/amcat_controller.dart';

/// The current section's question palette — mirrors `renderReviewJump()`
/// (`amcat_mock_test.html:703-723`, `#reviewJump`): tap any number to jump
/// within THIS section. Only "Answered" / "Not answered" states exist —
/// no "marked for review" (see `AmcatQuestionView`'s doc comment).
///
/// The base AMCAT CSS colors "answered" green (`.review-jump
/// span.answered{background:var(--success-bg)...}`), but the page's own
/// `#amcat-oop-skin` override style block repaints it navy with
/// `!important` (`.review-jump span.answered{background:#14213D
/// !important;...}`) to match the OOP engine — confirmed the override
/// wins the cascade, so navy (not green) is what actually renders.
Future<void> showAmcatPaletteSheet(BuildContext context, {required AmcatInSection state, required AmcatController controller}) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => _PaletteSheet(state: state, controller: controller));
}

class _PaletteSheet extends StatelessWidget {
  const _PaletteSheet({required this.state, required this.controller});

  final AmcatInSection state;
  final AmcatController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = state.currentSection;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Answered ${state.answeredInSectionCount} / ${section.questions.length}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: section.questions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                ),
                itemBuilder: (context, index) {
                  final isAnswered = state.currentSectionAnswers[index] != null;
                  final isCurrent = index == state.questionIndex;

                  final Color background = isAnswered ? MockExamColors.navy : MockExamColors.badgeBg;
                  final Color foreground = isAnswered ? Colors.white : MockExamColors.navy;

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
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: const [
                _LegendItem(color: MockExamColors.navy, label: 'Answered'),
                _LegendItem(color: MockExamColors.border, label: 'Not answered'),
              ],
            ),
          ],
        ),
      ),
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
