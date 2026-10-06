import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../domain/entities/employer_application_detail.dart';
import '../../domain/entities/my_application_detail.dart';
import '../controllers/my_application_detail_controller.dart';

/// `jobs_app.views.my_application_detail` (`templates/jobs/
/// my_application.html`) — a student's read-only view of their own job
/// application, reached from the status-update email.
class MyApplicationDetailScreen extends ConsumerWidget {
  const MyApplicationDetailScreen({required this.applicationId, super.key});

  final int applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myApplicationDetailControllerProvider(applicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Your Application')),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final data) => _DetailBody(data: data),
            AsyncError() => AppErrorView(
              message: 'Could not load this application.',
              onRetry: () => ref.read(myApplicationDetailControllerProvider(applicationId).notifier).retry(),
            ),
            _ => const AppLoader(),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.data});

  final MyApplicationDetail data;

  String get _statusLabel {
    for (final o in kApplicationStatusOptions) {
      if (o.value == data.status) return o.label;
    }
    return data.status;
  }

  Color get _statusColor => switch (data.status) {
    'rejected' => const Color(0xFFDC2626),
    'offered' || 'shortlisted' || 'interview' => const Color(0xFF16A34A),
    _ => const Color(0xFF185ADB),
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                border: Border.all(color: const Color(0xFFBFDBFE)),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                'Application #${data.applicationId}',
                style: const TextStyle(color: Color(0xFF185ADB), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(data.jobTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              [data.companyName, data.jobLocation].where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Text('Current status', style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(_statusLabel, style: TextStyle(color: _statusColor, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _infoTile('Applied on', data.appliedAt)),
                Expanded(child: _infoTile('Last updated', data.updatedAt)),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _infoTile('Applied as', '${data.applicantName} · ${data.applicantEmail}')),
                Expanded(child: _infoTile('Job type', '${data.jobType} · ${data.jobExperience}')),
              ],
            ),
            if (data.coverLetter != null && data.coverLetter!.isNotEmpty) ...[
              const Divider(height: AppSpacing.lg),
              const Text('Your cover letter', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(data.coverLetter!),
            ],
            if (data.jobIsActive && data.jobId != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.publicJobDetail(data.jobId!)),
                icon: const Icon(Icons.work_outline, size: 18),
                label: const Text('View job posting'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
