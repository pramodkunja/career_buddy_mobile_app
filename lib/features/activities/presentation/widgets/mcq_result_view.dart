import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/mcq_exercise.dart';
import '../../domain/entities/mcq_question_result.dart';
import '../../domain/entities/mcq_submission_result.dart';
import 'mcq_question_card.dart';

/// The server-computed result — score, max score, percentage, attempt
/// number, and per-question correct/incorrect + explanation. Nothing here
/// is computed on the client; every value is read straight from
/// [result] (see `docs/PHASE_3_EXERCISE_ARCHITECTURE.md`).
///
/// The score circle's color/emoji/message and the per-question
/// explanation box's tint match the web's exact tiers, verbatim from
/// `showResultPanel()` (`static/js/exercises.js:81-108`) and
/// `.correct-exp`/`.wrong-exp` (`static/css/exercises.css:97-107`).
class McqResultView extends StatelessWidget {
  const McqResultView({required this.exercise, required this.result, super.key});

  final McqExercise exercise;
  final McqSubmissionResult result;

  static const _excellentGradient = [Color(0xFF10B981), Color(0xFF059669)];
  static const _goodGradient = [Color(0xFF2563EB), Color(0xFF1D4ED8)];
  static const _averageGradient = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const _lowGradient = [Color(0xFFEF4444), Color(0xFFDC2626)];

  (List<Color>, String, String) _tierFor(int percentage) {
    if (percentage == 100) return (_excellentGradient, '🏆', 'Perfect Score!');
    if (percentage >= 90) return (_excellentGradient, '🌟', 'Excellent!');
    if (percentage >= 80) return (_excellentGradient, '✨', 'Very Good!');
    if (percentage >= 60) return (_goodGradient, '👍', 'Good Job!');
    if (percentage >= 40) return (_averageGradient, '💪', 'Average');
    return (_lowGradient, '📚', 'Keep Practising');
  }

  @override
  Widget build(BuildContext context) {
    final (gradient, emoji, message) = _tierFor(result.percentage);
    final questionById = {for (final q in exercise.questions) q.id: q};

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(message, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text('${result.score} / ${result.maxScore}', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text('${result.percentage}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: gradient.first)),
              const SizedBox(height: AppSpacing.xs),
              Text('Attempt ${result.attemptNumber}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Review', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, questionResult) in result.questions.indexed) ...[
          if (questionById[questionResult.questionId] case final question?)
            // `McqQuestionCard` now carries its own `.question-card` white/
            // border/radius styling — no outer `AppCard` needed (that
            // would double the card chrome the web never has).
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                McqQuestionCard(
                  question: question,
                  questionNumber: index + 1,
                  selectedLetter: questionResult.selected,
                  correctLetter: questionResult.correct,
                  onSelect: null,
                ),
                if ((questionResult.explanation ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ExplanationBox(questionResult: questionResult),
                ],
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// `.correct-exp`/`.wrong-exp` (`static/css/exercises.css:97-107`): a
/// tinted box, not plain muted text, prefixed "✓ Correct!"/"✗ Incorrect."
class _ExplanationBox extends StatelessWidget {
  const _ExplanationBox({required this.questionResult});

  final McqQuestionResult questionResult;

  static const _correctBg = Color(0xFFECFDF5);
  static const _correctBorder = Color(0xFFA7F3D0);
  static const _correctText = Color(0xFF065F46);
  static const _wrongBg = Color(0xFFFEF2F2);
  static const _wrongBorder = Color(0xFFFECACA);
  static const _wrongText = Color(0xFF991B1B);

  @override
  Widget build(BuildContext context) {
    final isCorrect = questionResult.isCorrect;
    final prefix = isCorrect ? '✓ Correct! ' : '✗ Incorrect. ';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isCorrect ? _correctBg : _wrongBg,
        border: Border.all(color: isCorrect ? _correctBorder : _wrongBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: prefix, style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: questionResult.explanation ?? ''),
          ],
        ),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: isCorrect ? _correctText : _wrongText, height: 1.5),
      ),
    );
  }
}
