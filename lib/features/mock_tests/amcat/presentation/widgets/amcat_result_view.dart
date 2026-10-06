import 'package:flutter/material.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../presentation/widgets/mock_exam_colors.dart';
import '../../domain/entities/amcat_question.dart';
import '../../domain/entities/amcat_section.dart';
import '../../domain/entities/amcat_submission_result.dart';

/// Mirrors `showResults()` (`amcat_mock_test.html:850-920`): an overall
/// percentage box (computed client-side from the section tallies, prepended
/// gold-highlighted) plus one score box per section, then a detailed
/// per-section review table. Deliberately shows no explanation text — the
/// web's own review table never reads `r.explanation` (see
/// `AmcatQuestionResult`'s doc comment) — and no qualitative message tier
/// (OOP/Subject Quiz's system; AMCAT's web page has none at all).
class AmcatResultView extends StatelessWidget {
  const AmcatResultView({
    required this.sections,
    required this.answers,
    required this.result,
    required this.onRetake,
    this.overallScoreLabel = 'Overall Score (all 5 modules)',
    super.key,
  });

  final List<AmcatSection> sections;
  final Map<String, List<int?>> answers;
  final AmcatSubmissionResult result;
  final VoidCallback onRetake;

  /// Defaults to AMCAT's own copy. `cocubes_mock_test.html` instead reads
  /// `'Overall Score (MCQ · ${gc}/${gt})'` — pass that computed string in
  /// for the CoCubes screen (see `AmcatState`'s doc comment).
  final String overallScoreLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('📊 Your Results', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              Text(
                '${result.overallPercentage.round()}%',
                style: theme.textTheme.headlineMedium?.copyWith(color: MockExamColors.navy, fontWeight: FontWeight.w800),
              ),
              Text(overallScoreLabel, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final section in sections) ...[
          _SectionScoreCard(section: section, score: result.sectionScores[section.key]),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Retake Test', icon: Icons.refresh, onPressed: onRetake),
        const SizedBox(height: AppSpacing.lg),
        Text('Detailed Review', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final section in sections) ...[
          Text(section.name, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < section.questions.length; i++) ...[
            _ReviewRow(index: i, question: section.questions[i], given: answers[section.key]![i], outcome: result.questionResults[section.questions[i].id]),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SectionScoreCard extends StatelessWidget {
  const _SectionScoreCard({required this.section, required this.score});

  final AmcatSection section;
  final AmcatSectionScore? score;

  @override
  Widget build(BuildContext context) {
    final correct = score?.correct ?? 0;
    final total = score?.total ?? section.questions.length;
    return AppCard(
      child: Row(
        children: [
          Expanded(child: Text(section.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(
            '$correct / $total',
            style: const TextStyle(fontWeight: FontWeight.w700, color: MockExamColors.navy),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.index, required this.question, required this.given, required this.outcome});

  final int index;
  final AmcatQuestion question;
  final int? given;
  final AmcatQuestionResult? outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String tagText;
    final Color tagBg;
    final Color tagColor;
    if (given == null) {
      tagText = 'Skipped';
      tagBg = MockExamColors.skipBg;
      tagColor = MockExamColors.skipText;
    } else if (outcome?.isCorrect == true) {
      tagText = 'Correct';
      tagBg = MockExamColors.successBg;
      tagColor = MockExamColors.success;
    } else {
      tagText = 'Wrong';
      tagBg = MockExamColors.dangerBg;
      tagColor = MockExamColors.danger;
    }
    final givenIndex = given;
    final givenText = givenIndex == null ? '—' : question.options[givenIndex];
    final correctIndex = outcome?.correctAnswerIndex;
    final correctText = correctIndex == null ? '—' : question.options[correctIndex];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('${index + 1}. ${question.questionText}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(20)),
                child: Text(tagText, style: TextStyle(color: tagColor, fontWeight: FontWeight.w700, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Your answer: $givenText', style: theme.textTheme.bodySmall),
          if (tagText == 'Wrong')
            Text(
              'Correct answer: $correctText',
              style: theme.textTheme.bodySmall?.copyWith(color: MockExamColors.success),
            ),
        ],
      ),
    );
  }
}
