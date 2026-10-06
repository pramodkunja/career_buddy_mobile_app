import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../presentation/widgets/mock_exam_colors.dart';
import '../../../presentation/widgets/mock_test_option_tile.dart';
import '../controllers/amcat_controller.dart';

/// The live section question pane — mirrors `renderQuestion()`
/// (`amcat_mock_test.html:663-701`): section eyebrow, question, options,
/// then Previous / Skip / Next (or "Submit Section →" on the last
/// question) — deliberately no "Mark for review" control, since AMCAT's
/// own palette has no such state (confirmed: only `.answered`/`.current`
/// CSS classes exist, unlike OOP/Subject Quiz).
class AmcatQuestionView extends StatelessWidget {
  const AmcatQuestionView({required this.state, required this.controller, super.key});

  final AmcatInSection state;
  final AmcatController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = state.currentSection;
    final question = section.questions[state.questionIndex];
    final selected = state.currentSectionAnswers[state.questionIndex];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Question ${state.questionIndex + 1} of ${section.questions.length}',
          style: theme.textTheme.labelLarge?.copyWith(color: MockExamColors.eyebrow),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(question.questionText, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < question.options.length; i++) ...[
          MockTestOptionTile(index: i, text: question.options[i], selected: selected == i, onTap: () => controller.selectAnswer(i)),
          if (i != question.options.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Previous',
                icon: Icons.arrow_back,
                variant: AppButtonVariant.outlined,
                onPressed: state.questionIndex == 0 ? null : controller.previousQuestion,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(label: 'Skip', variant: AppButtonVariant.outlined, onPressed: controller.goForward),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // `#nextBtn{background:#FCA311;color:#14213D}`
        // (`amcat_mock_test.html`'s `#amcat-oop-skin` override) — gold with
        // navy text, a page-specific skin distinct from the app-wide
        // default primary button, which is itself navy/white (`.btn-
        // primary`'s own final, latest override, `style.css:2899-2919`),
        // not gold — the two "distinct" colors happen to be reversed from
        // each other, not merely different shades of the same pairing.
        AppButton(
          label: state.isLastQuestionInSection ? 'Submit Section' : 'Next',
          icon: state.isLastQuestionInSection ? null : Icons.arrow_forward,
          onPressed: controller.goForward,
          backgroundColor: MockExamColors.gold,
          foregroundColor: MockExamColors.navy,
        ),
        if (state.showValidation) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Please answer all questions before submitting this section.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
