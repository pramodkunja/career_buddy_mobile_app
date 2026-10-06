import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

/// A single MCQ option — mirrors the web's `.option-btn` (letter badge +
/// text), state-driven from the controller's `selectedAnswers` instead of
/// DOM class toggling. Also renders the post-submission correct/incorrect
/// coloring when [isCorrect]/[isWrongSelection] are set.
///
/// Colors/radius/border-width are the exact flat values from
/// `static/css/exercises.css:61-95` (`.option-btn`/`.selected`/`.correct`/
/// `.wrong`), not theme-derived alpha blends — the web uses flat pastel
/// fills with a distinct, darker text color per state, not a tinted
/// overlay on the default text color.
class McqOptionButton extends StatelessWidget {
  const McqOptionButton({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
    this.isCorrect = false,
    this.isWrongSelection = false,
    super.key,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  /// Post-submission only: this is the correct answer.
  final bool isCorrect;

  /// Post-submission only: this was selected but is wrong.
  final bool isWrongSelection;

  static const _defaultBorder = Color(0xFFE2E8F0);
  static const _defaultFill = Color(0xFFF8FAFC);
  static const _defaultLetterBg = Color(0xFFE2E8F0);
  static const _defaultLetterText = Color(0xFF475569);
  static const _defaultText = Color(0xFF334155);

  static const _selectedBorder = Color(0xFF2563EB);
  static const _selectedFill = Color(0xFFEFF6FF);
  static const _selectedText = Color(0xFF1D4ED8);

  static const _correctBorder = Color(0xFF10B981);
  static const _correctFill = Color(0xFFECFDF5);
  static const _correctText = Color(0xFF065F46);

  static const _wrongBorder = Color(0xFFEF4444);
  static const _wrongFill = Color(0xFFFEF2F2);
  static const _wrongText = Color(0xFF991B1B);

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color fillColor;
    final Color textColor;
    if (isCorrect) {
      borderColor = _correctBorder;
      fillColor = _correctFill;
      textColor = _correctText;
    } else if (isWrongSelection) {
      borderColor = _wrongBorder;
      fillColor = _wrongFill;
      textColor = _wrongText;
    } else if (selected) {
      borderColor = _selectedBorder;
      fillColor = _selectedFill;
      textColor = _selectedText;
    } else {
      borderColor = _defaultBorder;
      fillColor = _defaultFill;
      textColor = _defaultText;
    }
    final letterBg = selected || isCorrect || isWrongSelection ? borderColor : _defaultLetterBg;
    final letterText = selected || isCorrect || isWrongSelection ? Colors.white : _defaultLetterText;

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: letterBg,
                child: Text(
                  letter.toUpperCase(),
                  style: TextStyle(color: letterText, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.w500),
                ),
              ),
              if (isCorrect) const Icon(Icons.check_circle, color: _correctBorder, size: 20),
              if (isWrongSelection) const Icon(Icons.cancel, color: _wrongBorder, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
