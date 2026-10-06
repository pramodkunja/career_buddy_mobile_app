import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import 'mock_exam_colors.dart';

/// One option in the exam question pane — mirrors the web exam engine's
/// `.exam-opt`/`.opt` (`005 oop-mastery.html:2434-2438`, and — after the
/// `#amcat-oop-skin` override that repaints AMCAT/CoCubes to match — the
/// EFFECTIVE `.opt`/`.opt.selected`/`.opt-badge` rules in
/// `amcat_mock_test.html`). Confirmed both exam engines render this
/// identically: navy selection (not gold, not the Activities-MCQ blue),
/// and a *rounded-square* letter badge (`border-radius:7px`), not a
/// circle. Deliberately NOT sharing `McqOptionButton`'s colors/shape —
/// these are separate, independently-styled exam engines on the web
/// itself, not a shared design system.
///
/// Also renders the post-submission correct/incorrect coloring for the
/// result review list, same dual-purpose approach as `McqOptionButton`.
class MockTestOptionTile extends StatelessWidget {
  const MockTestOptionTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.onTap,
    this.isCorrect = false,
    this.isWrongSelection = false,
    super.key,
  });

  final int index;
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  final bool isCorrect;
  final bool isWrongSelection;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color fillColor;
    final Color badgeBg;
    final Color badgeText;
    if (isCorrect) {
      borderColor = MockExamColors.success;
      fillColor = MockExamColors.successBg;
      badgeBg = MockExamColors.success;
      badgeText = Colors.white;
    } else if (isWrongSelection) {
      borderColor = MockExamColors.danger;
      fillColor = MockExamColors.dangerBg;
      badgeBg = MockExamColors.danger;
      badgeText = Colors.white;
    } else if (selected) {
      borderColor = MockExamColors.navy;
      fillColor = MockExamColors.selectedBg;
      badgeBg = MockExamColors.navy;
      badgeText = Colors.white;
    } else {
      borderColor = MockExamColors.border;
      fillColor = Colors.white;
      badgeBg = MockExamColors.badgeBg;
      badgeText = MockExamColors.navy;
    }

    final letter = String.fromCharCode(65 + index);

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: selected || isCorrect || isWrongSelection ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(7)),
                child: Text(
                  letter,
                  style: TextStyle(color: badgeText, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MockExamColors.ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isCorrect) Icon(Icons.check_circle, color: MockExamColors.success, size: 20),
              if (isWrongSelection) Icon(Icons.cancel, color: MockExamColors.danger, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
