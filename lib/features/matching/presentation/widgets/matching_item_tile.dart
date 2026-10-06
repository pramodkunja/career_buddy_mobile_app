import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import 'matching_colors.dart';

/// Mirrors `.match-item`'s 5 states (`static/css/exercises.css:149-160`):
/// default, `.selected`/`.matched` (same blue tint, `.matched` additionally
/// tints the text), `.correct` (post-submission only), `.wrong-match`
/// (post-submission only).
enum MatchItemVisualState { normal, selected, matched, correct, wrong }

/// One `.match-item` — a left or right column tile in the Matching grid.
class MatchingItemTile extends StatelessWidget {
  const MatchingItemTile({required this.text, required this.state, required this.onTap, super.key});

  final String text;
  final MatchItemVisualState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (borderColor, bgColor, textColor, fontWeight) = switch (state) {
      MatchItemVisualState.normal => (MatchingColors.border, Colors.white, null, FontWeight.w500),
      MatchItemVisualState.selected => (MatchingColors.blue, MatchingColors.selectedBg, MatchingColors.selectedText, FontWeight.w700),
      MatchItemVisualState.matched => (MatchingColors.blue, MatchingColors.selectedBg, MatchingColors.selectedText, FontWeight.w500),
      MatchItemVisualState.correct => (MatchingColors.correctBorder, MatchingColors.correctBg, MatchingColors.correctText, FontWeight.w500),
      MatchItemVisualState.wrong => (MatchingColors.wrongBorder, MatchingColors.wrongBg, MatchingColors.wrongText, FontWeight.w500),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 50),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: fontWeight),
        ),
      ),
    );
  }
}
