import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/validation/manual_resume_validation.dart';
import '../controllers/manual_resume_preview_controller.dart';
import '../providers/resume_providers.dart';
import '../widgets/manual_resume_document_view.dart';

/// Phase 27 — submits [draft] to the real `preview_api` and shows the
/// server's own assembled resume. This screen never edits the draft: every
/// correction happens back in the builder (see [_goToStepAndReturn]),
/// which is why it only ever needs a frozen snapshot, not a live
/// reference. Returning (by any route — the AppBar back arrow or a
/// targeted "Go fix this" action) never clears or replaces the local
/// draft; this screen has no write path to it at all.
class ManualResumePreviewScreen extends ConsumerStatefulWidget {
  const ManualResumePreviewScreen({required this.draft, super.key});

  final ManualResumeDraft draft;

  @override
  ConsumerState<ManualResumePreviewScreen> createState() => _ManualResumePreviewScreenState();
}

class _ManualResumePreviewScreenState extends ConsumerState<ManualResumePreviewScreen> {
  @override
  void initState() {
    super.initState();
    // Same Riverpod-safety pattern as every other screen in this feature —
    // `generate()` writes to `state` synchronously on its first line.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(manualResumePreviewControllerProvider.notifier).generate(widget.draft);
    });
  }

  void _goToStepAndReturn(int step) {
    ref.read(manualResumeBuilderControllerProvider.notifier).goToStep(step);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manualResumePreviewControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Resume Preview')),
      body: switch (state) {
        ManualResumePreviewIdle() || ManualResumePreviewLoading() => const AppLoader(
          message: 'Generating your resume preview…',
        ),
        ManualResumePreviewFailed(failure: final failure) => AppErrorView(
          message: failure.message,
          onRetry: () => ref.read(manualResumePreviewControllerProvider.notifier).retry(widget.draft),
        ),
        ManualResumePreviewValidationFailed(errors: final errors) => _ValidationFailedView(
          errors: errors,
          onGoToStep: _goToStepAndReturn,
          onRetry: () => ref.read(manualResumePreviewControllerProvider.notifier).retry(widget.draft),
        ),
        ManualResumePreviewReadyState(:final document, :final warnings, :final completeness) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Overall completeness: ${completeness.overall}%',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final warning in warnings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(warning, style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ManualResumeDocumentView(document: document),
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

class _ValidationFailedView extends StatelessWidget {
  const _ValidationFailedView({required this.errors, required this.onGoToStep, required this.onRetry});

  final List<ManualResumeValidationError> errors;
  final void Function(int step) onGoToStep;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text(
          "The resume couldn't be generated yet:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final error in errors)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              title: Text(error.message),
              subtitle: error.field.isEmpty ? null : Text(error.field, style: const TextStyle(fontSize: 11)),
              trailing: error.step > 0 ? const Icon(Icons.chevron_right) : null,
              onTap: error.step > 0 ? () => onGoToStep(error.step) : null,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
