import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/validation/manual_resume_validation.dart';
import '../controllers/manual_resume_page_preview_controller.dart';
import '../providers/resume_providers.dart';

/// Phase 28, Part A — the real page-image preview
/// (`manual_resume_pages`/`preview_pages_api`), kept as its own screen,
/// visually distinct from Phase 27's native structured-document preview.
/// Reuses the same carousel shape as `GrammarImageCarouselSheet`
/// (prev/next chevrons + dot indicators over `Image.memory`) rather than a
/// new pattern, and the same frozen-draft-snapshot design as
/// `ManualResumePreviewScreen`: this screen has no editing capability of
/// its own, so a correction always means popping back to the builder
/// first — which never clears or replaces the local draft, since this
/// screen has no write path to it at all beyond the shared
/// `setServerErrors`/`clearServerErrors` signal already established in
/// Phase 27.
class ManualResumePagePreviewScreen extends ConsumerStatefulWidget {
  const ManualResumePagePreviewScreen({required this.draft, super.key});

  final ManualResumeDraft draft;

  @override
  ConsumerState<ManualResumePagePreviewScreen> createState() => _ManualResumePagePreviewScreenState();
}

class _ManualResumePagePreviewScreenState extends ConsumerState<ManualResumePagePreviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(manualResumePagePreviewControllerProvider.notifier).generate(widget.draft);
    });
  }

  void _goToStepAndReturn(int step) {
    ref.read(manualResumeBuilderControllerProvider.notifier).goToStep(step);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manualResumePagePreviewControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Page Preview')),
      body: switch (state) {
        ManualResumePagePreviewIdle() || ManualResumePagePreviewLoading() => const AppLoader(
          message: 'Rendering your resume pages…',
        ),
        ManualResumePagePreviewFailed(failure: final failure) => AppErrorView(
          message: failure.message,
          onRetry: () => ref.read(manualResumePagePreviewControllerProvider.notifier).retry(widget.draft),
        ),
        ManualResumePagePreviewValidationFailed(errors: final errors) => _ValidationFailedView(
          errors: errors,
          onGoToStep: _goToStepAndReturn,
          onRetry: () => ref.read(manualResumePagePreviewControllerProvider.notifier).retry(widget.draft),
        ),
        ManualResumePagePreviewReadyState(:final pages, :final total) =>
          pages.isEmpty ? const _EmptyPagesView() : _PageCarousel(pages: pages, total: total),
      },
    );
  }
}

class _EmptyPagesView extends StatelessWidget {
  const _EmptyPagesView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'No page preview is available for this resume right now. You can still generate the PDF directly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _PageCarousel extends StatefulWidget {
  const _PageCarousel({required this.pages, required this.total});

  final List<Uint8List> pages;
  final int total;

  @override
  State<_PageCarousel> createState() => _PageCarouselState();
}

class _PageCarouselState extends State<_PageCarousel> {
  int _index = 0;

  void _show(int newIndex) {
    setState(() => _index = (newIndex + widget.pages.length) % widget.pages.length);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.total > widget.pages.length)
          Container(
            width: double.infinity,
            color: AppColors.background,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              'Showing the first ${widget.pages.length} of ${widget.total} pages. Download the PDF to view the '
              'full resume.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    key: ValueKey<int>(_index),
                    padding: const EdgeInsets.all(10),
                    child: InteractiveViewer(
                      child: Image.memory(widget.pages[_index], fit: BoxFit.contain),
                    ),
                  ),
                ),
                if (widget.pages.length > 1) ...[
                  Positioned(
                    left: 4,
                    child: IconButton(
                      key: const Key('page-preview-previous'),
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                      onPressed: () => _show(_index - 1),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    child: IconButton(
                      key: const Key('page-preview-next'),
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                      onPressed: () => _show(_index + 1),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < widget.pages.length; i++)
                          GestureDetector(
                            onTap: () => _show(i),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _index ? Colors.white : Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text('Page ${_index + 1} of ${widget.pages.length}', textAlign: TextAlign.center),
        ),
      ],
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
          "The page preview couldn't be generated yet:",
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
