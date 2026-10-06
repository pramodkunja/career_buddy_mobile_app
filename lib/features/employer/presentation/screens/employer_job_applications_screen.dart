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
import '../../domain/entities/employer_job_applications.dart';
import '../controllers/employer_job_applications_controller.dart';

/// `jobs_app.views.job_applications` (`templates/employer/
/// applications.html`) — one job's candidate list. Tapping a candidate
/// reuses the already-built [RoutePaths.employerApplicationDetail] rather
/// than a second application-detail implementation.
class EmployerJobApplicationsScreen extends ConsumerWidget {
  const EmployerJobApplicationsScreen({required this.jobId, super.key});

  final int jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employerJobApplicationsControllerProvider(jobId));

    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final page) => _ApplicationsBody(jobId: jobId, page: page),
            AsyncError() => AppErrorView(
              message: 'Could not load applications for this job.',
              onRetry: () => ref.read(employerJobApplicationsControllerProvider(jobId).notifier).retry(),
            ),
            _ => const AppLoader(),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _ApplicationsBody extends ConsumerWidget {
  const _ApplicationsBody({required this.jobId, required this.page});

  final int jobId;
  final EmployerJobApplicationsPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(employerJobApplicationsControllerProvider(jobId).notifier);
    final activeFilter = ref.watch(employerJobApplicationsControllerProvider(jobId).notifier).statusFilter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(page.jobTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${page.applications.length} candidate submission(s) for this job opening.',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _FilterChip(
                label: 'All Candidates',
                selected: activeFilter.isEmpty,
                onTap: () => controller.setStatusFilter(''),
              ),
              for (final o in kApplicationStatusOptions) ...[
                const SizedBox(width: 6),
                _FilterChip(
                  label: o.label,
                  selected: activeFilter == o.value,
                  onTap: () => controller.setStatusFilter(o.value),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: page.applications.isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    for (final app in page.applications) ...[
                      _CandidateCard(app: app),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.app});

  final EmployerJobApplicationListItem app;

  String get _statusLabel {
    for (final o in kApplicationStatusOptions) {
      if (o.value == app.status) return o.label;
    }
    return app.status;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(RoutePaths.employerApplicationDetail(app.applicationId)),
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF185ADB),
              child: Text(
                app.applicantName.isEmpty ? '?' : app.applicantName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.applicantName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(app.applicantEmail, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${app.yearsExperience} yr(s) experience', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(50)),
                  child: Text(_statusLabel, style: const TextStyle(color: Color(0xFF185ADB), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 40, color: Color(0xFFCBD5E1)),
            const SizedBox(height: AppSpacing.sm),
            const Text('No applications found for this status.', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Try selecting another filter or viewing all candidates.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
