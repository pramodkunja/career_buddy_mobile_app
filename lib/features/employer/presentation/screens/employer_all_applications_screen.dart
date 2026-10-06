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
import '../../domain/entities/employer_all_applications.dart';
import '../../domain/entities/employer_application_detail.dart';
import '../controllers/employer_all_applications_controller.dart';

/// `jobs_app.views.all_applications` (`templates/employer/
/// all_applications.html`) — every application across all of the caller's
/// own job postings. Tapping a candidate reuses the already-built
/// [RoutePaths.employerApplicationDetail] rather than a second
/// application-detail implementation.
class EmployerAllApplicationsScreen extends ConsumerWidget {
  const EmployerAllApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employerAllApplicationsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All Applications'), leading: drawerAwareBackLeading(context)),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final page) => _ApplicationsBody(page: page),
            AsyncError() => AppErrorView(
              message: 'Could not load applications.',
              onRetry: () => ref.read(employerAllApplicationsControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _ApplicationsBody extends ConsumerStatefulWidget {
  const _ApplicationsBody({required this.page});

  final EmployerAllApplicationsPage page;

  @override
  ConsumerState<_ApplicationsBody> createState() => _ApplicationsBodyState();
}

class _ApplicationsBodyState extends ConsumerState<_ApplicationsBody> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(employerAllApplicationsControllerProvider.notifier).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyFilters({String? statusFilter, String? sourceFilter}) {
    final controller = ref.read(employerAllApplicationsControllerProvider.notifier);
    controller.applyFilters(
      query: _search.text.trim(),
      statusFilter: statusFilter ?? controller.statusFilter,
      sourceFilter: sourceFilter ?? controller.sourceFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(employerAllApplicationsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search candidate name or email...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _applyFilters()),
                ),
                onSubmitted: (_) => _applyFilters(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      hint: 'All Statuses',
                      value: controller.statusFilter,
                      options: [for (final o in kApplicationStatusOptions) (o.value, o.label)],
                      onChanged: (v) => _applyFilters(statusFilter: v ?? ''),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _dropdown(
                      hint: 'All Sources',
                      value: controller.sourceFilter,
                      options: kApplicationSourceOptions,
                      onChanged: (v) => _applyFilters(sourceFilter: v ?? ''),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.page.applications.isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  children: [
                    for (final app in widget.page.applications) ...[
                      _ApplicationCard(app: app),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String hint,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(labelText: hint, isDense: true, border: const OutlineInputBorder()),
      items: [for (final o in options) DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
      onChanged: onChanged,
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app});

  final EmployerAllApplicationListItem app;

  String get _statusLabel {
    for (final o in kApplicationStatusOptions) {
      if (o.value == app.status) return o.label;
    }
    return app.status;
  }

  @override
  Widget build(BuildContext context) {
    final isParsed = app.source == 'resume_parsed';
    return InkWell(
      onTap: () => context.push(RoutePaths.employerApplicationDetail(app.applicationId)),
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(app.applicantName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isParsed ? const Color(0xFFF3E8FF) : const Color(0xFFECFDF5),
                    border: Border.all(color: isParsed ? const Color(0xFFD8B4FE) : const Color(0xFFA7F3D0)),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    isParsed ? 'Resume Parsed' : 'Direct Apply',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isParsed ? const Color(0xFF7E22CE) : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(app.applicantEmail, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
              child: Text(app.jobTitle, style: const TextStyle(color: Color(0xFF185ADB), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('Applied: ${app.appliedAt}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(50)),
                  child: Text(_statusLabel, style: const TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
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
            const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFFCBD5E1)),
            const SizedBox(height: AppSpacing.sm),
            const Text('No applications found', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Try clearing your search query or filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
