import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/jam_history_profile.dart';
import '../controllers/jam_history_controller.dart';

/// `jam:history` (`templates/jam/history.html`) — "Practice History":
/// completed non-assessment sessions (Regular Sessions tab) and completed
/// `AssessmentGroup`s (Assessments tab), each deletable.
class JamHistoryScreen extends ConsumerWidget {
  const JamHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jamHistoryControllerProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Practice History'),
          bottom: const TabBar(tabs: [Tab(text: 'Regular Sessions'), Tab(text: 'Assessments')]),
        ),
        body: Stack(
          children: [
            switch (state) {
              AsyncData(value: final page) => _HistoryBody(page: page),
              AsyncError(:final error) => AppErrorView(
                message: error is Failure ? error.message : 'Could not load your practice history.',
                onRetry: () => ref.read(jamHistoryControllerProvider.notifier).retry(),
              ),
              _ => const AppLoader(message: 'Loading history...'),
            },
            const BuddyChatbotOverlay(),
          ],
        ),
      ),
    );
  }
}

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({required this.page});

  final JamHistoryPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TabBarView(
      children: [
        page.sessions.isEmpty
            ? const _EmptyState(message: 'No regular sessions found.')
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (final s in page.sessions) ...[
                    _SessionCard(session: s),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
        page.assessments.isEmpty
            ? const _EmptyState(message: 'No diagnostic assessments found.')
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (final a in page.assessments) ...[
                    _AssessmentCard(assessment: a),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
      ],
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});

  final JamHistorySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push(RoutePaths.jamSessionDetail(session.sessionId)),
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.topicTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(50)),
                        child: Text(session.difficulty, style: const TextStyle(color: Color(0xFF185ADB), fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text(session.createdAt, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(session.durationDisplay, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                if (session.overallScore != null)
                  Text('★ ${session.overallScore}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E)),
              onPressed: () => _confirmDeleteSession(context, ref, session.sessionId),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSession(BuildContext context, WidgetRef ref, int sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      // Verbatim web wording (`history.html`'s `confirm('Delete this session?')`).
      builder: (context) => AlertDialog(
        content: const Text('Delete this session?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(jamHistoryControllerProvider.notifier).deleteSession(sessionId);
    if (!context.mounted) return;
    switch (result) {
      case Success():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your practice session has been removed from history.')),
        );
      case Failed(failure: final failure):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _AssessmentCard extends ConsumerWidget {
  const _AssessmentCard({required this.assessment});

  final JamHistoryAssessment assessment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push(RoutePaths.jamAssessmentDetail(assessment.assessmentId)),
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('3-STAGE DIAGNOSTIC', style: TextStyle(color: Color(0xFFF43F5E), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text('Assessment on ${assessment.createdAt}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
                ),
                const Text('Complete', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E)),
                  onPressed: () => _confirmDeleteAssessment(context, ref, assessment.assessmentId),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in [assessment.easyTopicTitle, assessment.mediumTopicTitle, assessment.hardTopicTitle])
                  if (t.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(50)),
                      child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAssessment(BuildContext context, WidgetRef ref, int assessmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      // Verbatim web wording (`history.html`'s
      // `confirm('Delete this assessment and all its sessions?')`).
      builder: (context) => AlertDialog(
        content: const Text('Delete this assessment and all its sessions?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(jamHistoryControllerProvider.notifier).deleteAssessment(assessmentId);
    if (!context.mounted) return;
    switch (result) {
      case Success():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessment and its practice sessions have been removed.')),
        );
      case Failed(failure: final failure):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: Color(0xFF94A3B8))),
    );
  }
}
