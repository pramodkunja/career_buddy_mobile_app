import 'package:flutter/material.dart';

/// Standard text field. Set [obscureText] to show a password-visibility
/// toggle automatically — callers don't manage that state themselves.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.readOnly = false,
    this.enabled = true,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.fillColor,
    this.borderRadius,
    this.borderColor,
    this.focusedBorderColor,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  /// Per-instance overrides of the ambient `InputDecorationTheme` — used
  /// only by screens with their own verified, page-specific field styling
  /// (e.g. Login's `.auth-form .form-control`, distinct from the app's
  /// usual field look). `null` (the default, used everywhere else) keeps
  /// the theme's usual styling untouched.
  final Color? fillColor;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Color? focusedBorderColor;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.obscureText;
    final hasOverride =
        widget.fillColor != null ||
        widget.borderRadius != null ||
        widget.borderColor != null ||
        widget.focusedBorderColor != null;

    var decoration = InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      errorText: widget.errorText,
      prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              tooltip: _obscured ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscured = !_obscured),
            )
          : widget.suffixIcon == null
          ? null
          : Icon(widget.suffixIcon),
    );

    if (hasOverride) {
      final radius = widget.borderRadius ?? BorderRadius.circular(12);
      final border = OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: widget.borderColor ?? const Color(0xFFCBD5E1)),
      );
      decoration = decoration.copyWith(
        filled: true,
        fillColor: widget.fillColor,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: widget.focusedBorderColor ?? widget.borderColor ?? const Color(0xFFCBD5E1), width: 1.5),
        ),
      );
    }

    return TextFormField(
      controller: widget.controller,
      obscureText: isPassword && _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      decoration: decoration,
    );
  }
}
