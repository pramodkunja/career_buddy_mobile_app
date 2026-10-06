import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Centralized [ThemeData] for light and dark mode. Screens should read
/// styling from `Theme.of(context)` rather than hardcoding colors/paddings.
abstract final class AppTheme {
  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: AppColors.background,
    surface: AppColors.surface,
    border: AppColors.border,
    textTheme: AppTypography.light,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    border: AppColors.borderDark,
    textTheme: AppTypography.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color border,
    required TextTheme textTheme,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.action,
      secondary: AppColors.accent,
      error: AppColors.danger,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.action, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      // `.btn-primary`'s color is set THREE times on the web, in file
      // order: the original blue theme (`--primary:#185adb`, style.css:8),
      // a "BLACK & GOLD ELEGANCE" override (style.css:2625-2644) that
      // repaints it gold with `!important`, and finally — appended later
      // still, at the very end of the file (style.css:2899-2919, headed
      // "Reduce gold dominance") — a THIRD rule that repaints `.btn-primary`
      // back to **navy** (`#14213D`, white text), also `!important`,
      // explicitly stating "btn-primary (used across all cards/lists) =
      // NAVY structural button. Gold reserved for .btn-accent (few
      // intentional CTAs) + Pro badge." CSS resolves same-specificity
      // `!important` ties by source order, so this last rule is the one
      // that actually wins sitewide — confirmed by reading the full
      // cascade to the end of the file, not stopping at the first
      // `!important` match. `.btn-accent` (the still-gold class) is used
      // only on the pre-login Home/Landing page and the Employer Portal —
      // neither exists in this app yet — so no currently-implemented
      // screen's default primary button should be gold.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnDark,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // `.btn-outline-primary` (`static/css/style.css:2659-2669`): navy
      // border/text — untouched by the later "Reduce gold dominance" block
      // (which only redefines `.btn-primary` itself), so this one's
      // gold-on-hover behavior from the BLACK & GOLD block is still the
      // effective final state; hover has no mobile equivalent, so only the
      // base navy border/text applies here.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.action),
      ),
      dividerTheme: DividerThemeData(color: border, space: AppSpacing.lg),
    );
  }
}
