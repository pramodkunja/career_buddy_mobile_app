import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import 'bingo_colors.dart';

/// `.bingo-status-bar`/`.bingo-status-playing`/`.bingo-status-bingo`
/// (`static/css/exercises.css:274-279`) — a pill-shaped status message.
/// The web also has a `.text-danger` tone for the "click a word first"
/// validation message (`static/js/exercises.js:569`); reproduced here as
/// [BingoStatusTone.error] using the app's existing danger color rather
/// than inventing a new one.
enum BingoStatusTone { playing, bingo, error }

class BingoStatusBar extends StatelessWidget {
  const BingoStatusBar({required this.text, required this.tone, super.key});

  final String text;
  final BingoStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BingoStatusTone.playing => (BingoColors.statusPlayingBg, BingoColors.statusPlayingText),
      BingoStatusTone.bingo => (BingoColors.statusBingoBg, BingoColors.statusBingoText),
      BingoStatusTone.error => (const Color(0xFFFEF2F2), const Color(0xFF991B1B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
