import 'package:flutter/material.dart';

/// Literal hex values verified against `static/css/exercises.css:139-167`
/// (`.match-item`/`#matching-result` and friends). None of these classes
/// are touched by the site's "BLACK & GOLD ELEGANCE" `!important` override
/// in `style.css` (confirmed by grep — see the earlier MCQ progress-bar fix
/// for the same methodology), so this exercise engine is genuinely blue,
/// not gold/navy like Mock Tests' `MockExamColors`. Kept as its own small
/// token set rather than `AppColors`, same reasoning as `MockExamColors`/
/// `ModuleColors`: these are page-specific literal values, not the app's
/// general-purpose palette.
abstract final class MatchingColors {
  static const border = Color(0xFFE2E8F0);
  static const blue = Color(0xFF2563EB);
  static const selectedBg = Color(0xFFEFF6FF);
  static const selectedText = Color(0xFF1D4ED8);
  static const correctBorder = Color(0xFF10B981);
  static const correctBg = Color(0xFFECFDF5);
  static const correctText = Color(0xFF065F46);
  static const wrongBorder = Color(0xFFEF4444);
  static const wrongBg = Color(0xFFFEF2F2);
  static const wrongText = Color(0xFF991B1B);
}
