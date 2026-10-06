import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../domain/entities/job_openings.dart';
import '../controllers/job_openings_controller.dart';

enum _JobFilter { all, own, seeded }

/// `jobs_app.views.job_openings` (`templates/employer/job_openings.html`)
/// — every active job (employer-posted + seeded). The web's filter tabs
/// are client-side-only JS toggling card visibility (no server filter
/// param), reproduced the same way here. Tapping a card reuses the
/// already-built [RoutePaths.publicJobDetailPattern] ("View Job
/// Description" on the web) rather than a second job-detail
/// implementation.
class JobOpeningsScreen extends ConsumerStatefulWidget {
  const JobOpeningsScreen({super.key});

  @override
  ConsumerState<JobOpeningsScreen> createState() => _JobOpeningsScreenState();
}

class _JobOpeningsScreenState extends ConsumerState<JobOpeningsScreen> {
  _JobFilter _filter = _JobFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobOpeningsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Job Openings'), leading: drawerAwareBackLeading(context)),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final page) => _buildBody(page),
            AsyncError() => AppErrorView(
              message: 'Could not load job openings.',
              onRetry: () => ref.read(jobOpeningsControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody(JobOpeningsPage page) {
    final jobs = switch (_filter) {
      _JobFilter.all => page.jobs,
      _JobFilter.own => page.jobs.where((j) => !j.isSeeded).toList(),
      _JobFilter.seeded => page.jobs.where((j) => j.isSeeded).toList(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            key: const Key('jobFilterScroll'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            children: [
              _filterChip('All Jobs', _JobFilter.all),
              const SizedBox(width: 6),
              _filterChip('My Postings', _JobFilter.own),
              const SizedBox(width: 6),
              _filterChip('Career Buddy Listed', _JobFilter.seeded),
            ],
          ),
        ),
        Expanded(
          child: jobs.isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  children: [
                    for (final job in jobs) ...[
                      _JobCard(job: job),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, _JobFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final JobOpeningListItem job;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(RoutePaths.publicJobDetail(job.jobId)),
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 18, backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.work_outline, size: 18, color: Color(0xFF185ADB))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                      if (job.companyName.isNotEmpty)
                        Text(job.companyName, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: job.isSeeded ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
                    border: Border.all(color: job.isSeeded ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE)),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    job.isSeeded ? 'CB' : 'Mine',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: job.isSeeded ? const Color(0xFFB45309) : const Color(0xFF185ADB)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (job.jobType.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(50)),
                    child: Text(job.jobType, style: const TextStyle(color: Color(0xFF185ADB), fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                for (final s in job.skills)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(6)),
                    child: Text(s, style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
            if (job.location.isNotEmpty || job.experience.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [job.location, job.experience].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
            if (job.salaryDisplay.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(job.salaryDisplay, style: const TextStyle(color: Color(0xFF185ADB), fontSize: 12, fontWeight: FontWeight.w700)),
            ],
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
            const Icon(Icons.work_off_outlined, size: 40, color: Color(0xFFCBD5E1)),
            const SizedBox(height: AppSpacing.sm),
            const Text('No active job openings found.', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Start by posting your first job listing.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
