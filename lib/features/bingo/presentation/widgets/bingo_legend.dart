import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import 'bingo_colors.dart';

/// `.bingo-legend`/`.bingo-swatch` (`static/css/exercises.css:256-272`) —
/// the same 5 fixed labels, in the same order, as the web.
class BingoLegend extends StatelessWidget {
  const BingoLegend({super.key});

  static const _items = [
    (label: 'Unselected', color: BingoColors.cellBg, border: BingoColors.cellBorder, ring: false),
    (label: 'Selected', color: BingoColors.markedStart, border: BingoColors.markedEnd, ring: false),
    (label: 'Correct', color: BingoColors.correctStart, border: BingoColors.correctEnd, ring: false),
    (label: 'Incorrect', color: BingoColors.wrongStart, border: BingoColors.wrongEnd, ring: false),
    (label: 'Bingo line (5 in a row)', color: BingoColors.correctStart, border: BingoColors.bingoLineRing, ring: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final item in _items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: item.border, width: item.ring ? 2 : 1.5),
                ),
              ),
              const SizedBox(width: 4),
              Text(item.label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}
