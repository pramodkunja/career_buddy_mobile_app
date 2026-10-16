import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../domain/entities/create_resume_draft_summary.dart';
import '../providers/resume_providers.dart';

/// Phase 39 — "My Resumes" (`drafts_list`/`draft_detail`/`draft_delete`,
/// all `@login_required` on the real backend, confirmed directly). Reached
/// from [CreateResumeBuilderScreen]'s own folder icon; this route itself is
/// authenticated-only (see `RoutePaths.createResumeDrafts`'s own doc
/// comment).
class CreateResumeDraftsScreen extends ConsumerWidget {
  const CreateResumeDraftsScreen({super.key});

  Future<void> _openDraft(BuildContext context, WidgetRef ref, int id) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    final result = await ref.read(createResumeRepositoryProvider).loadDraft(id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    switch (result) {
      case Success(value: final form):
        ref
            .read(createResumeBuilderControllerProvider.notifier)
            .startFromDraft(form);
        context.push(RoutePaths.createResumeBuilder);
      case Failed(failure: final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _deleteDraft(
    BuildContext context,
    WidgetRef ref,
    CreateResumeDraftSummary draft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this resume?'),
        content: Text(
          '"${draft.title}" will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(createResumeDraftsControllerProvider.notifier)
        .deleteDraft(draft.id);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this resume. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createResumeDraftsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Resumes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(createResumeBuilderControllerProvider.notifier).startBlank();
          context.push(RoutePaths.createResumeBuilder);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Resume'),
      ),
      body: switch (state) {
        AsyncData(value: final drafts) => RefreshIndicator(
          onRefresh: () =>
              ref.read(createResumeDraftsControllerProvider.notifier).retry(),
          child: drafts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _EmptyDrafts(
                      onCreate: () {
                        ref
                            .read(
                              createResumeBuilderControllerProvider.notifier,
                            )
                            .startBlank();
                        context.push(RoutePaths.createResumeBuilder);
                      },
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: drafts.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final draft = drafts[index];
                    return _DraftCard(
                      draft: draft,
                      onOpen: () => _openDraft(context, ref, draft.id),
                      onDelete: () => _deleteDraft(context, ref, draft),
                    );
                  },
                ),
        ),
        AsyncError(:final error) => AppErrorView(
          message: error is Failure
              ? error.message
              : 'Something went wrong. Please try again.',
          onRetry: () =>
              ref.read(createResumeDraftsControllerProvider.notifier).retry(),
        ),
        _ => const AppLoader(message: 'Loading your resumes…'),
      },
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.onOpen,
    required this.onDelete,
  });

  final CreateResumeDraftSummary draft;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.background,
          child: Icon(Icons.description_outlined, color: AppColors.action),
        ),
        title: Text(draft.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Updated ${_formatDate(draft.updatedAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        onTap: onOpen,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          tooltip: 'Delete',
          onPressed: onDelete,
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

class _EmptyDrafts extends StatelessWidget {
  const _EmptyDrafts({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No resumes yet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a new resume and save it to find it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Create Resume',
            fullWidth: false,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}
