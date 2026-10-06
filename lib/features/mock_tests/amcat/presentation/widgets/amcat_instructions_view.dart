import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../presentation/widgets/mock_exam_colors.dart';

/// Mirrors `amcat_mock_test.html:321-377`'s Exam Instructions card — every
/// bullet is the web's own copy. The "I have read and understood..."
/// checkbox gate ("Start Test" stays disabled until checked,
/// `toggleStartButton()`) is local, ephemeral UI state (no network, no
/// timer involved yet), so it lives here rather than in the controller —
/// same reasoning as OOP's submit-confirmation dialog being UI-layer.
///
/// Deliberately omits the "Full-Screen Mode"/"3 warnings" proctoring
/// bullets and the standalone security-copy list — consistent with this
/// app's established, documented decision (W020/W021) not to reproduce
/// fullscreen/tab-switch proctoring on mobile.
///
/// [sectionsSummary] and [lastGeneralBullet] are parameterized (defaulting
/// to AMCAT's own copy) since `cocubes_mock_test.html`'s instructions card
/// is structurally identical but names its own 4 sections and replaces the
/// Personality-specific bullet with one about Programming being graded
/// like the other sections — the other 2 "General" bullets and the whole
/// "Answering Questions" card are byte-identical between the two, so those
/// stay fixed. See `AmcatState`'s doc comment for the full W023 rationale.
class AmcatInstructionsView extends StatefulWidget {
  const AmcatInstructionsView({
    required this.onStart,
    this.sectionsSummary = 'The test consists of 5 sections: Quantitative Ability, English Ability, Logical '
        'Reasoning, Personality Inventory, and a Domain Module.',
    this.lastGeneralBullet = 'The Personality Inventory has no right or wrong answers — respond honestly and '
        'consistently.',
    super.key,
  });

  final VoidCallback onStart;
  final String sectionsSummary;
  final String lastGeneralBullet;

  @override
  State<AmcatInstructionsView> createState() => _AmcatInstructionsViewState();
}

class _AmcatInstructionsViewState extends State<AmcatInstructionsView> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('📋 Exam Instructions', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text('Please read the instructions carefully before you begin the test.', style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🕒 General', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              _Bullet(widget.sectionsSummary),
              const _Bullet("Each section has its own individual timer. When a section's time runs out, it "
                  'will auto-submit and move to the next section.'),
              const _Bullet('You cannot go back to a previous section once it is submitted.'),
              _Bullet(widget.lastGeneralBullet),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Answering Questions', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              const _Bullet('You must answer every question in a section before you can submit that section.'),
              const _Bullet("If any question is left unanswered, you'll see a message asking you to complete "
                  'all questions before submitting.'),
              const _Bullet('Use the numbered grid within a section to jump to any question and review your '
                  'answers.'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(
            "💡 Tip: Make sure you're in a quiet environment with a stable internet connection before you "
            'begin. Once started, the timer cannot be paused.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          value: _agreed,
          onChanged: (value) => setState(() => _agreed = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('I have read and understood the instructions above, and I agree to follow them '
              'during the test.'),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Start Test',
          onPressed: _agreed ? widget.onStart : null,
          backgroundColor: MockExamColors.navy,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
