import 'package:flutter/material.dart';

/// Literal hex values verified against `static/css/exercises.css:187-279`
/// (`.bingo-cell`/`.bingo-status-bar`/`.bingo-swatch` and friends). None of
/// these classes are touched by the site's gold/navy override (confirmed
/// by grep, same methodology as `MatchingColors`), so this exercise engine
/// is genuinely its own slate/blue/green/red/gold palette — kept as its
/// own small token set for the same reason `MatchingColors`/`ModuleColors`
/// are: page-specific literal values, not the app's general-purpose
/// palette.
abstract final class BingoColors {
  static const cellBorder = Color(0xFFE2E8F0);
  static const cellBg = Color(0xFFF8FAFC);
  static const cellText = Color(0xFF334155);

  static const markedStart = Color(0xFF2563EB);
  static const markedEnd = Color(0xFF1D4ED8);

  static const correctStart = Color(0xFF16A34A);
  static const correctEnd = Color(0xFF15803D);

  static const wrongStart = Color(0xFFEF4444);
  static const wrongEnd = Color(0xFFDC2626);

  static const bingoLineRing = Color(0xFFFBBF24);
  static const bingoLineRingPulsed = Color(0xFFF59E0B);
  static const bingoLineGlow = Color(0xFFF59E0B);

  static const statusPlayingBg = Color(0xFFEFF6FF);
  static const statusPlayingText = Color(0xFF1D4ED8);
  static const statusBingoBg = Color(0xFFECFDF5);
  static const statusBingoText = Color(0xFF065F46);
}
