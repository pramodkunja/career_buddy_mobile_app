import 'package:flutter/material.dart';

import '../../domain/entities/interview_analytics.dart';

/// Mirrors `resume_analytics.html`'s summary + per-question breakdown —
/// every number here is exactly what `resume_analytics` returned (see
/// `mock_interview_html_parser.dart`), never locally computed.
class MockInterviewResultsView extends StatelessWidget {
  const MockInterviewResultsView({required this.analytics, super.key});

  final InterviewAnalyticsResult analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passColor = analytics.isPassed ? Colors.green.shade700 : Colors.red.shade700;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: analytics.isPassed ? Colors.green.shade50 : Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  analytics.isPassed ? 'Qualified Candidate' : 'Action Required',
                  style: theme.textTheme.titleMedium?.copyWith(color: passColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${analytics.totalScore}',
                  key: const Key('total-score-value'),
                  style: theme.textTheme.displayMedium?.copyWith(color: passColor, fontWeight: FontWeight.w800),
                ),
                Text('TOTAL SCORE / 100', style: theme.textTheme.labelMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Answered', value: '${analytics.answeredCount}/${analytics.totalQuestions}')),
            Expanded(child: _StatTile(label: 'Avg Score', value: '${analytics.avgScore.toStringAsFixed(1)}/5')),
          ],
        ),
        const SizedBox(height: 20),
        Text('Question Breakdown', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final q in analytics.questionResults) _QuestionResultTile(result: q),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _QuestionResultTile extends StatelessWidget {
  const _QuestionResultTile({required this.result});
  final InterviewQuestionResult result;

  @override
  Widget build(BuildContext context) {
    final scoreColor = result.score >= 4
        ? Colors.green.shade700
        : result.score >= 2
            ? Colors.orange.shade800
            : Colors.red.shade700;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(result.topic, style: Theme.of(context).textTheme.labelLarge)),
                Chip(
                  label: Text('${result.score}/5'),
                  backgroundColor: scoreColor.withValues(alpha: 0.12),
                  labelStyle: TextStyle(color: scoreColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(result.question, style: Theme.of(context).textTheme.bodyMedium),
            if (result.feedback.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                result.feedback,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
