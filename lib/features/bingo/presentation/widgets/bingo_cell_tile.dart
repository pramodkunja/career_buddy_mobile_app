import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/bingo_exercise_controller.dart';
import 'bingo_colors.dart';

/// One `.bingo-cell` (`static/css/exercises.css:194-243`) — a square,
/// word-labelled board tile, including its per-state `box-shadow` glow and
/// the `.bingo-line` gold ring's `bingoPulse` animation (`exercises.css:
/// 228-234`: `0.8s ease infinite alternate`, spread 3px→5px, blur 18px→22px,
/// glow alpha .5→.75).
///
/// [isBingoLine] **replaces** the state glow entirely rather than adding to
/// it — CSS `box-shadow` on a later, equal-specificity rule
/// (`.bingo-cell.bingo-line`, declared after `.bingo-cell.bingo-win` in the
/// stylesheet) fully overrides the earlier declaration rather than
/// layering with it, so a winning-line cell shows only the pulsing gold
/// ring, never the green win-glow underneath.
class BingoCellTile extends StatefulWidget {
  const BingoCellTile({required this.word, required this.state, required this.onTap, this.isBingoLine = false, super.key});

  final String word;
  final BingoCellState state;
  final VoidCallback? onTap;
  final bool isBingoLine;

  @override
  State<BingoCellTile> createState() => _BingoCellTileState();
}

class _BingoCellTileState extends State<BingoCellTile> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.isBingoLine) _startPulse();
  }

  @override
  void didUpdateWidget(covariant BingoCellTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBingoLine && _pulseController == null) {
      _startPulse();
    } else if (!widget.isBingoLine && _pulseController != null) {
      _pulseController!.dispose();
      _pulseController = null;
    }
  }

  void _startPulse() {
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (gradient, borderColor, textColor) = switch (widget.state) {
      BingoCellState.neutral => (null, BingoColors.cellBorder, BingoColors.cellText),
      BingoCellState.marked => ([BingoColors.markedStart, BingoColors.markedEnd], BingoColors.markedEnd, Colors.white),
      BingoCellState.correct => ([BingoColors.correctStart, BingoColors.correctEnd], BingoColors.correctEnd, Colors.white),
      BingoCellState.wrong => ([BingoColors.wrongStart, BingoColors.wrongEnd], BingoColors.wrongEnd, Colors.white),
    };

    // Per-state `box-shadow` (`exercises.css:206-225`) — suppressed
    // entirely when `isBingoLine`, per this widget's own doc comment.
    final stateGlow = widget.isBingoLine
        ? null
        : switch (widget.state) {
            BingoCellState.marked => BoxShadow(
              color: BingoColors.markedEnd.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
            BingoCellState.correct => BoxShadow(
              color: BingoColors.correctStart.withValues(alpha: 0.40),
              offset: const Offset(0, 4),
              blurRadius: 14,
            ),
            BingoCellState.wrong => BoxShadow(
              color: BingoColors.wrongEnd.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
            BingoCellState.neutral => null,
          };

    Widget cell = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: gradient == null ? BingoColors.cellBg : null,
        gradient: gradient == null
            ? null
            : LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: stateGlow == null ? null : [stateGlow],
      ),
      child: Text(
        widget.word,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: textColor, fontWeight: FontWeight.w700),
      ),
    );

    final pulseController = _pulseController;
    if (widget.isBingoLine && pulseController != null) {
      cell = AnimatedBuilder(
        animation: pulseController,
        child: cell,
        builder: (context, child) {
          final t = pulseController.value;
          final spread = lerpDouble(3, 5, t)!;
          final blur = lerpDouble(18, 22, t)!;
          final glowAlpha = lerpDouble(0.5, 0.75, t)!;
          final ringColor = Color.lerp(BingoColors.bingoLineRing, BingoColors.bingoLineRingPulsed, t)!;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: ringColor, blurRadius: 0, spreadRadius: spread),
                BoxShadow(color: BingoColors.bingoLineGlow.withValues(alpha: glowAlpha), offset: const Offset(0, 6), blurRadius: blur),
              ],
            ),
            child: child,
          );
        },
      );
    }

    return InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(10), child: AspectRatio(aspectRatio: 1, child: cell));
  }
}
