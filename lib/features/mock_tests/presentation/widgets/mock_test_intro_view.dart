import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/mock_test_attempt_record.dart';
import 'mock_exam_colors.dart';

/// Mirrors the web's exam splash screen
/// (`005 oop-mastery.html:2607-2626`, `showSplash()`).
///
/// Deliberately omits the web's separate "Exam rules" list (fullscreen,
/// no tab/window switching, 3-warning auto-submit, screenshot/copy/
/// right-click blocking) — none of that proctoring is meaningfully or
/// appropriately reproducible on a native mobile app (there are no browser
/// "tabs" to switch between, iOS/Android cannot block app-switching the way
/// `fullscreenchange`/`visibilitychange` can on the web, and punishing an
/// incoming phone call or a permission dialog with a warning strike would be
/// poor UX). This is a deliberate, documented adaptation, not an oversight —
/// see the W020 final report.
class MockTestIntroView extends StatelessWidget {
  const MockTestIntroView({required this.title, required this.history, required this.onStart, super.key});

  /// The bare quiz name, e.g. "OOP Mastery" or "DSA Mastery" — composed the
  /// same way the web splash does: `"🎯 $title — Mock Test"`
  /// (`005 oop-mastery.html:2609`, byte-identical across every subject page
  /// verified for W021).
  final String title;
  final List<MockTestAttemptRecord> history;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('🎯 $title — Mock Test', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A timed, exam-style assessment modelled on real technical screening tests.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _RuleBullet('50 questions to attempt'),
              _RuleBullet('60-minute timer — the test auto-submits when time is up'),
              _RuleBullet('Navigate freely, mark questions for review, then submit'),
              _RuleBullet('Results and explanations are shown only after you submit'),
            ],
          ),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Your attempts on this device', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HistoryRow(label: 'Top score', record: _bestOf(history)),
                for (final record in history.take(5)) _HistoryRow(record: record),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        // `.start{background:navy;color:#fff}`
        // (`aptitude_mock_test.html`, and OOP Mastery's own splash "Start
        // Test" button) — navy, distinct from the in-exam gold buttons.
        AppButton(
          label: 'Start Test',
          icon: Icons.play_arrow,
          onPressed: onStart,
          backgroundColor: MockExamColors.navy,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }

  MockTestAttemptRecord _bestOf(List<MockTestAttemptRecord> records) {
    return records.reduce((a, b) => b.percentage > a.percentage ? b : a);
  }
}

class _RuleBullet extends StatelessWidget {
  const _RuleBullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({this.label, required this.record});

  final String? label;
  final MockTestAttemptRecord record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label ?? _formatDate(record.completedAt),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '${record.score} / ${record.total} (${record.percentage}%)',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }
}
