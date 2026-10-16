import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../domain/entities/create_resume_state.dart';
import '../controllers/create_resume_builder_controller.dart';
import '../controllers/create_resume_preview_controller.dart';
import '../providers/resume_providers.dart';
import '../widgets/create_resume_document_view.dart';

/// Phase 39 — submits [form] to the real `preview_api` and shows the
/// server's own assembled resume. Simpler than `ManualResumePreviewScreen`:
/// this endpoint never rejects (see [CreateResumePreviewController]'s own
/// doc comment), so any outstanding field errors are shown inline above the
/// document — a real, honest "here's what you have so far, and here's
/// what's still missing" view — rather than blocking the preview entirely.
class CreateResumePreviewScreen extends ConsumerStatefulWidget {
  const CreateResumePreviewScreen({required this.form, super.key});

  final CreateResumeFormState form;

  @override
  ConsumerState<CreateResumePreviewScreen> createState() =>
      _CreateResumePreviewScreenState();
}

class _CreateResumePreviewScreenState
    extends ConsumerState<CreateResumePreviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(createResumePreviewControllerProvider.notifier).generate(widget.form);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createResumePreviewControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Resume Preview')),
      body: switch (state) {
        CreateResumePreviewIdle() || CreateResumePreviewLoading() =>
          const AppLoader(message: 'Generating your resume preview…'),
        CreateResumePreviewFailed(failure: final failure) => AppErrorView(
          message: failure.message,
          onRetry: () => ref
              .read(createResumePreviewControllerProvider.notifier)
              .retry(widget.form),
        ),
        CreateResumePreviewReadyState(:final document) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _OutstandingItemsBanner(),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: CreateResumeDocumentView(document: document),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Builder'),
              ),
            ],
          ),
        ),
      },
    );
  }
}

class _OutstandingItemsBanner extends ConsumerWidget {
  const _OutstandingItemsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builderState = ref.watch(createResumeBuilderControllerProvider);
    final errors = builderState is CreateResumeBuilderReady
        ? builderState.serverErrors
        : const [];
    if (errors.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Still missing for a downloadable PDF:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          for (final e in errors)
            Text('•  ${e.message}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
