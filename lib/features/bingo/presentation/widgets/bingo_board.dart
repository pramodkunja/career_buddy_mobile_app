import 'package:flutter/material.dart';

import '../../domain/entities/bingo_card.dart';
import '../controllers/bingo_exercise_controller.dart';
import 'bingo_cell_tile.dart';

/// `.bingo-board{display:grid;grid-template-columns:repeat(5,1fr)}`
/// (`static/css/exercises.css:187-190`).
///
/// The web's own `@media (max-width:640px)` rule switches this to
/// `repeat(4,1fr)` (`static/css/exercises.css:567`) — **deliberately not
/// reproduced here**: the win-line detection (rows/columns/diagonals,
/// `BingoExerciseController._evaluateAndSubmit`) is defined entirely in
/// terms of a 5-per-row board layout, matching the web's own JS, which
/// indexes cells assuming 5 columns regardless of how many the CSS
/// happens to display at a given width. Following the web's 4-column
/// mobile CSS literally would make a visual "line" on screen no longer
/// correspond to a real winning line at all — keeping 5 columns at every
/// width is the mobile-appropriate adaptation, not a design deviation.
class BingoBoard extends StatelessWidget {
  const BingoBoard({
    required this.cards,
    required this.cellStateFor,
    required this.onCellTap,
    this.bingoLineWords = const {},
    super.key,
  });

  final List<BingoCard> cards;
  final BingoCellState Function(String word) cellStateFor;
  final void Function(String word)? onCellTap;
  final Set<String> bingoLineWords;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return BingoCellTile(
          word: card.word,
          state: cellStateFor(card.word),
          isBingoLine: bingoLineWords.contains(card.word),
          onTap: onCellTap == null ? null : () => onCellTap!(card.word),
        );
      },
    );
  }
}
