import 'package:flutter/material.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../presentation/widgets/mock_exam_colors.dart';

/// Mirrors the web's "Exam Structure" landing card
/// (`amcat_mock_test.html:307-318`, `renderStructure()`) — a static list,
/// hardcoded on the web itself (not derived from any API response), so
/// reproducing it as a Flutter const list is faithful, not invented.
const List<(String name, String subtitle)> kAmcatStructure = [
  ('Quantitative Ability', '16 Q · 18 min'),
  ('English Ability', '18 Q · 16 min'),
  ('Logical Reasoning', '14 Q · 16 min'),
  ('Personality Inventory', '90 Q · 20 min'),
  ('Domain Module (Programming)', '15 Q · 15 min'),
];

/// W023 — CoCubes's own landing structure, byte-diffed against
/// `amcat_mock_test.html` (`cocubes_mock_test.html:580-583`).
const List<(String name, String subtitle)> kCocubesStructure = [
  ('Aptitude', '50 Q · 50 min'),
  ('Technical / Domain (CSE-IT)', '25 Q · 25 min'),
  ('Computer Fundamentals', '25 Q · 25 min'),
  ('Programming', '50 Q · 50 min'),
];

/// The header/structure/note text is parameterized (defaulting to AMCAT's
/// own copy, so [AmcatMockTestScreen] needs no changes) since
/// `cocubes_mock_test.html`'s landing card is structurally identical but
/// has its own title/subtitle/structure/note — see `AmcatState`'s doc
/// comment for the full W023 reuse rationale.
class AmcatLandingView extends StatelessWidget {
  const AmcatLandingView({
    required this.onStart,
    this.title = '🧪 AMCAT Mock Test',
    this.subtitle = 'Full-length simulated practice test — Quant, English, Logical Reasoning, '
        'Personality & Domain Module',
    this.structure = kAmcatStructure,
    this.note = "Each section is individually timed. Once a section's time is up, it "
        'auto-submits and moves to the next section. The Personality Inventory has '
        'no right/wrong answers — answer honestly and consistently. Domain Module '
        'here uses Computer Programming as the sample track.',
    super.key,
  });

  final String title;
  final String subtitle;
  final List<(String name, String subtitle)> structure;
  final String note;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Text('Exam Structure', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (final (name, sub) in structure)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(child: Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                      Text(sub, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(note, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        // `.btn{background:var(--navy);color:#fff}` (`amcat_mock_test.html`)
        // — the landing page's CTA is navy, distinct from the in-exam
        // gold Next/Submit buttons.
        AppButton(
          label: 'Start Mock Test',
          icon: Icons.play_arrow,
          onPressed: onStart,
          backgroundColor: MockExamColors.navy,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}
