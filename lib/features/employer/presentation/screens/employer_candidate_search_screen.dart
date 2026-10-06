import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../domain/entities/employer_candidate_search.dart';
import '../controllers/employer_candidate_search_controller.dart';

/// `jobs_app.views.search_candidates` (`templates/jobs/
/// candidate_search.html`) — searches registered students by skills,
/// location, and experience. No JSON API; parsed from server-rendered
/// HTML.
class EmployerCandidateSearchScreen extends ConsumerWidget {
  const EmployerCandidateSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employerCandidateSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Candidate Search'), leading: drawerAwareBackLeading(context)),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          switch (state) {
            AsyncData(value: final results) => _SearchBody(results: results),
            AsyncError() => AppErrorView(
              message: 'Could not search candidates.',
              onRetry: () => ref.read(employerCandidateSearchControllerProvider.notifier).retry(),
            ),
            _ => const AppLoader(),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _SearchBody extends ConsumerStatefulWidget {
  const _SearchBody({required this.results});

  final List<EmployerCandidateSearchResult> results;

  @override
  ConsumerState<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends ConsumerState<_SearchBody> {
  late final TextEditingController _query;
  late final TextEditingController _location;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(employerCandidateSearchControllerProvider.notifier);
    _query = TextEditingController(text: controller.query);
    _location = TextEditingController(text: controller.location);
  }

  @override
  void dispose() {
    _query.dispose();
    _location.dispose();
    super.dispose();
  }

  void _search() {
    final controller = ref.read(employerCandidateSearchControllerProvider.notifier);
    controller.search(query: _query.text.trim(), location: _location.text.trim(), experience: controller.experience);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(employerCandidateSearchControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _query,
                decoration: const InputDecoration(
                  labelText: 'Skills or Keywords',
                  hintText: 'e.g. Python, Marketing, Project Management',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location', hintText: 'City or Remote', isDense: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: controller.experience.isEmpty ? null : controller.experience,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Experience', isDense: true, border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Any')),
                  for (final o in kCandidateSearchExperienceOptions) DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                ],
                onChanged: (v) => controller.search(query: controller.query, location: controller.location, experience: v ?? ''),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Search', icon: Icons.search, onPressed: _search),
            ],
          ),
        ),
        Expanded(
          child: widget.results.isEmpty
              ? _EmptyState(hasFilters: controller.hasFilters)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  children: [
                    Text('Found ${widget.results.length} Candidates', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: AppSpacing.sm),
                    for (final c in widget.results) ...[
                      _CandidateCard(candidate: c),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final EmployerCandidateSearchResult candidate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 22, backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.person_outline, color: Color(0xFF185ADB))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(candidate.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (candidate.location.isNotEmpty)
                      Text(candidate.location, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
              if (candidate.skillCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(50)),
                  child: Text(
                    '${candidate.skillCount} match${candidate.skillCount == 1 ? '' : 'es'}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (candidate.experience.isNotEmpty) _infoLine('Experience', candidate.experience),
          if (candidate.industry.isNotEmpty) _infoLine('Industry', candidate.industry),
          if (candidate.education.isNotEmpty) _infoLine('Education', candidate.education),
          if (candidate.skills.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final s in candidate.skills) _skillChip(s)],
            ),
          ],
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.email_outlined, size: 20),
                tooltip: candidate.email,
                onPressed: candidate.email.isEmpty ? null : () => launchUrl(Uri.parse('mailto:${candidate.email}')),
              ),
              IconButton(
                icon: const Icon(Icons.phone_outlined, size: 20),
                tooltip: candidate.phone,
                onPressed: candidate.phone.isEmpty ? null : () => launchUrl(Uri.parse('tel:${candidate.phone}')),
              ),
              const Spacer(),
              if (candidate.resumeUrl != null)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(candidate.resumeUrl!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('View Resume'),
                )
              else
                const Text('No resume uploaded', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          children: [TextSpan(text: '$label: '), TextSpan(text: value, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600))],
        ),
      ),
    );
  }

  Widget _skillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(50)),
      child: Text(skill, style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_outlined, size: 40, color: Color(0xFFCBD5E1)),
            const SizedBox(height: AppSpacing.sm),
            Text(hasFilters ? 'No candidates found' : 'No candidates available', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              hasFilters ? 'Try adjusting your filters or searching for different skills.' : 'No registered candidates are available to search right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
