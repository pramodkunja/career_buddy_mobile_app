import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, outlined, text }

/// Standard button used everywhere instead of raw [ElevatedButton] /
/// [OutlinedButton] / [TextButton], so loading/disabled states and sizing
/// stay consistent across the app.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.width,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final double? width;

  /// Overrides [variant]'s default colors for [AppButtonVariant.primary]
  /// only — used by the 4 AI-module screens, each its own self-styled
  /// "mini brand" with its own accent color on the web (see
  /// `app/theme/module_colors.dart`), instead of the app's single global
  /// primary color. `null` (the default, used everywhere else) keeps the
  /// theme's usual styling untouched.
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Overrides [variant]'s default shape for [AppButtonVariant.primary]
  /// only — used by the AI-module Submit CTAs, whose web counterpart
  /// (`.btn-primary-solid{border-radius:50rem}`, every AI module template)
  /// is a fully-rounded pill, distinct from the app's usual 12px-radius
  /// buttons. `null` (the default) keeps the theme's usual shape.
  final BorderRadius? borderRadius;

  bool get _isDisabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        style: backgroundColor == null && foregroundColor == null && borderRadius == null
            ? null
            : ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                shape: borderRadius == null ? null : RoundedRectangleBorder(borderRadius: borderRadius!),
              ),
        onPressed: _isDisabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.secondary => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.primary,
        ),
        onPressed: _isDisabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: _isDisabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: _isDisabled ? null : onPressed,
        child: child,
      ),
    };

    return Semantics(
      button: true,
      enabled: !_isDisabled,
      label: label,
      child: SizedBox(
        width: fullWidth ? double.infinity : width,
        height: 48,
        child: button,
      ),
    );
  }
}
