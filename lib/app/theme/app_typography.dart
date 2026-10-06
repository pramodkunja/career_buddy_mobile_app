import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Text styles built on the web app's font stack (`templates/base.html`):
/// Outfit for body/UI text, Newsreader for display/heading text.
abstract final class AppTypography {
  static TextTheme textTheme(Color primaryText, Color mutedText) {
    final outfit = GoogleFonts.outfitTextTheme();
    final newsreader = GoogleFonts.newsreaderTextTheme();

    return outfit
        .copyWith(
          displayLarge: newsreader.displayLarge,
          displayMedium: newsreader.displayMedium,
          displaySmall: newsreader.displaySmall,
          headlineLarge: newsreader.headlineLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: newsreader.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: newsreader.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: primaryText, displayColor: primaryText)
        .copyWith(
          bodySmall: outfit.bodySmall?.copyWith(color: mutedText),
          labelSmall: outfit.labelSmall?.copyWith(color: mutedText),
        );
  }

  static final TextTheme light = textTheme(
    AppColors.textPrimary,
    AppColors.textMuted,
  );
  static final TextTheme dark = textTheme(
    AppColors.textPrimaryOnDark,
    AppColors.textMutedOnDark,
  );
}
