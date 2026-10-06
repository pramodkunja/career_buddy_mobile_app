import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/mcq_question.dart';
import 'mcq_option_button.dart';

/// One question — text + its options. Purely presentational: selection
/// state and correctness (post-submission) are passed in, not looked up.
///
/// `.question-card` (`static/css/exercises.css:33-37`) — a real white,
/// bordered, 14px-radius card, not bare content on the page background.
/// [questionNumber] renders `.question-number` (line 42-45): a bold,
/// uppercase, letter-spaced "QUESTION N" eyebrow label above the question
/// text.
class McqQuestionCard extends StatelessWidget {
  const McqQuestionCard({
    required this.question,
    required this.questionNumber,
    required this.selectedLetter,
    required this.onSelect,
    this.correctLetter,
    super.key,
  });

  final McqQuestion question;
  final int questionNumber;
  final String? selectedLetter;
  final ValueChanged<String>? onSelect;

  /// Set only once a result is available (post-submission) — enables the
  /// correct/incorrect coloring and disables further selection.
  final String? correctLetter;

  @override
  Widget build(BuildContext context) {
    final letters = question.options.keys.toList()..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28), // `1.75rem 2rem`
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUESTION $questionNumber',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(question.questionText, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (final letter in letters) ...[
            McqOptionButton(
              letter: letter,
              text: question.options[letter]!,
              selected: selectedLetter == letter,
              isCorrect: correctLetter != null && correctLetter == letter,
              isWrongSelection: correctLetter != null && selectedLetter == letter && selectedLetter != correctLetter,
              onTap: correctLetter != null || onSelect == null ? null : () => onSelect!(letter),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
