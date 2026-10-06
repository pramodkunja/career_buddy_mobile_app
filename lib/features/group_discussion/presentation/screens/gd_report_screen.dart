import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/gd_report.dart';

/// The final performance report — `GD_app:session_report`
/// (`templates/GD_app/report.html`, read in full). [report] comes straight
/// from the WebSocket's own `type: 'report'` event
/// (`GdSessionController`/`GdReportEvent`) when reached from a just-finished
/// live discussion; the exact same entity is also what
/// `GdRepository.getSessionReport`/`parseGdReportHtml` produce when reading
/// a past session's report over plain HTTP — every field below is real,
/// never fabricated client-side.
class GdReportScreen extends StatelessWidget {
  const GdReportScreen({required this.report, super.key});

  final GdReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Discussion Analysis')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Center(
                child: Column(
                  children: [
                    Text(
                      '${report.overallScore}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      'OVERALL SCORE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _DimensionCard(
                label: 'Fluency',
                dimension: report.fluency,
                color: AppColors.action,
              ),
              const SizedBox(height: AppSpacing.sm),
              _DimensionCard(
                label: 'Grammar',
                dimension: report.grammar,
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DimensionCard(
                label: 'Relevance',
                dimension: report.relevance,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.sm),
              _DimensionCard(
                label: 'Confidence',
                dimension: report.confidence,
                color: const Color(0xFFD97706),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (report.strengths.isNotEmpty)
                _InsightCard(
                  title: 'Key Strengths',
                  items: report.strengths,
                  dark: true,
                ),
              if (report.strengths.isNotEmpty)
                const SizedBox(height: AppSpacing.sm),
              if (report.improvements.isNotEmpty)
                _InsightCard(
                  title: 'Areas for Growth',
                  items: report.improvements,
                  dark: false,
                ),
              if (report.summary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '"${report.summary}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Back to Activities',
                variant: AppButtonVariant.text,
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _DimensionCard extends StatelessWidget {
  const _DimensionCard({
    required this.label,
    required this.dimension,
    required this.color,
  });

  final String label;
  final GdReportDimension dimension;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                '${dimension.score}/25',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (dimension.feedback.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              dimension.feedback,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.items,
    required this.dark,
  });

  final String title;
  final List<String> items;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white70 : AppColors.textMuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.primary : Colors.white,
        border: dark ? null : Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: dark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    dark ? Icons.check_circle : Icons.arrow_circle_up,
                    size: 16,
                    color: dark ? AppColors.success : AppColors.action,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: textColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
