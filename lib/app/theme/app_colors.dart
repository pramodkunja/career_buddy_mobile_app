import 'package:flutter/material.dart';

/// Color tokens mirrored from the web app's `:root` CSS variables
/// (`static/css/style.css`, navy/gold design pass), so the mobile app stays
/// visually consistent with the existing product rather than inventing a
/// new palette.
abstract final class AppColors {
  static const Color primary = Color(0xFF14213D); // --primary / --navy
  static const Color primaryDark = Color(0xFF0B1526); // --primary-dark

  // The web login CTA uses a blue gradient distinct from --primary.
  static const Color action = Color(0xFF185ADB);
  static const Color actionDark = Color(0xFF1D4ED8);

  static const Color accent = Color(0xFFFCA311); // --accent / --gold
  static const Color accentDark = Color(0xFFE0900C);

  /// Text/icon color used ON [accent] — matches the web's `.btn-primary`
  /// override, `color: #000 !important` (`static/css/style.css:2628`, the
  /// "BLACK & GOLD ELEGANCE" block), literal black, not navy.
  static const Color onAccent = Color(0xFF000000);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Dark theme surfaces: no dark-mode tokens exist on the web app to mirror,
  // so these follow Material's standard dark-surface convention instead.
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryOnDark = Color(0xFFF1F5F9);
  static const Color textMutedOnDark = Color(0xFF94A3B8);
}
