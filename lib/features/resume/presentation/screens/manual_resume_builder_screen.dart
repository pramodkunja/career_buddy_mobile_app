import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/entities/resume_role.dart';
import '../controllers/manual_resume_builder_controller.dart';
import '../controllers/manual_resume_pdf_controller.dart';
import '../providers/resume_providers.dart';
import '../widgets/manual_resume_career_step.dart';
import '../widgets/manual_resume_education_step.dart';
import '../widgets/manual_resume_experience_step.dart';
import '../widgets/manual_resume_personal_step.dart';
import '../widgets/manual_resume_summary_step.dart';

/// Phase 26's Manual Resume Builder — the real five-step form on top of
/// Phase 25's foundation (draft model, local persistence, wizard shell).
/// Server preview, page previews and PDF generation remain out of scope
/// for this screen (separately approved future phases). [role] is the role
/// tapped from the Role Picker's "Build Resume" tile — `null` is handled
/// defensively for a restored draft reopened without that navigation
/// context (the draft's own `role` slug is resolved from the catalog by
/// the controller's own `load()` in that case).
class ManualResumeBuilderScreen extends ConsumerStatefulWidget {
  const ManualResumeBuilderScreen({this.role, super.key});

  final ResumeRole? role;

  @override
  ConsumerState<ManualResumeBuilderScreen> createState() => _ManualResumeBuilderScreenState();
}

class _ManualResumeBuilderScreenState extends ConsumerState<ManualResumeBuilderScreen> {
  @override
  void initState() {
    super.initState();
    // Same Riverpod-safety pattern as `RolePickerScreen`/`MockInterviewScreen`
    // — `load()` writes to `state` synchronously on its first line, so it
    // can't be called directly from `initState`.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = ref.read(manualResumeBuilderControllerProvider.notifier);
      await controller.load();
      final role = widget.role;
      if (role != null && mounted) controller.setRoleIfBlank(role);
    });
  }

  Future<void> _confirmClearDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Draft'),
        content: const Text(
          'This will permanently delete everything you have entered in this resume draft. This action '
          'cannot be undone.\n\nAre you sure you want to clear this draft?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear Draft', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(manualResumeBuilderControllerProvider.notifier).clearDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manualResumeBuilderControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Resume'),
        actions: [
          if (state is ManualResumeBuilderReady)
            IconButton(
              key: const Key('clear-draft-button'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Draft',
              onPressed: _confirmClearDraft,
            ),
        ],
      ),
      body: switch (state) {
        ManualResumeBuilderLoading() => const AppLoader(message: 'Loading your draft…'),
        ManualResumeBuilderLoadFailed(failure: final failure) => AppErrorView(
          message: failure.message,
          onRetry: () => ref.read(manualResumeBuilderControllerProvider.notifier).retryLoad(),
        ),
        ManualResumeBuilderReady() => _WizardBody(state: state),
      },
    );
  }
}

class _WizardBody extends ConsumerWidget {
  const _WizardBody({required this.state});

  final ManualResumeBuilderReady state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(manualResumeBuilderControllerProvider.notifier);
    final draft = state.draft;
    final visibleErrors = state.visibleErrors;
    final pdfState = ref.watch(manualResumePdfControllerProvider);
    final pdfGenerating = pdfState is ManualResumePdfGenerating;

    // A one-shot notification per state change, not part of the normal
    // field-error display — the field-level errors themselves are already
    // shown inline via `visibleErrors` (fed by `setServerErrors`, same
    // mechanism the document/page preview controllers use).
    ref.listen(manualResumePdfControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      switch (next) {
        case ManualResumePdfFailed(failure: final failure):
          messenger.showSnackBar(SnackBar(content: Text(failure.message)));
        case ManualResumePdfValidationFailed():
          messenger.showSnackBar(
            const SnackBar(content: Text('The PDF could not be generated yet — see the errors below.')),
          );
        case ManualResumePdfIdle():
        case ManualResumePdfGenerating():
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepIndicator(currentStep: draft.currentStep, onTap: controller.goToStep),
        if (state.saveFailed)
          Container(
            color: AppColors.danger.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: const Text(
              'Your last change could not be saved on this device. Edits are shown but may be lost — check your '
              'device storage.',
              key: Key('save-failed-banner'),
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        if (state.roleCatalogLoadFailed)
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Some suggestions could not be loaded.', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: controller.retryRoleCatalogLoad,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(
          child: switch (draft.currentStep) {
            1 => ManualResumePersonalStep(draft: draft, visibleErrors: visibleErrors),
            2 => ManualResumeCareerStep(
              draft: draft,
              role: state.role,
              levelCommon: state.levelCommon,
              visibleErrors: visibleErrors,
            ),
            3 => ManualResumeExperienceStep(draft: draft, role: state.role, visibleErrors: visibleErrors),
            4 => ManualResumeEducationStep(draft: draft, role: state.role, visibleErrors: visibleErrors),
            _ => ManualResumeSummaryStep(
              draft: draft,
              role: state.role,
              levelCommon: state.levelCommon,
              visibleErrors: visibleErrors,
            ),
          },
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('wizard-previous-button'),
                      onPressed: draft.currentStep > kManualResumeFirstStep ? controller.previousStep : null,
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const Key('wizard-next-button'),
                      onPressed: draft.currentStep < kManualResumeLastStep ? controller.nextStep : null,
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
              TextButton(
                key: const Key('wizard-review-button'),
                onPressed: () {
                  final firstError = controller.reviewAll();
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        firstError == null
                            ? 'All required information is complete.'
                            : 'Please fix: ${firstError.message}',
                      ),
                    ),
                  );
                },
                child: const Text('Review Missing Information'),
              ),
              OutlinedButton(
                key: const Key('wizard-preview-button'),
                onPressed: () => context.push(RoutePaths.manualResumePreview, extra: draft),
                child: const Text('Preview Resume'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: const Key('wizard-page-preview-button'),
                onPressed: () => context.push(RoutePaths.manualResumePagePreview, extra: draft),
                child: const Text('Page Preview'),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const Key('wizard-generate-pdf-button'),
                onPressed: pdfGenerating
                    ? null
                    : () => ref.read(manualResumePdfControllerProvider.notifier).generateAndOpen(draft),
                child: pdfGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnDark),
                      )
                    : const Text('Generate PDF'),
              ),
              if (pdfState case ManualResumePdfValidationFailed(errors: final errors))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    errors.isEmpty
                        ? 'The PDF could not be generated yet.'
                        : 'The PDF could not be generated yet: ${errors.first.message}',
                    key: const Key('pdf-validation-error'),
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.onTap});

  final int currentStep;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          for (var i = 0; i < kManualResumeStepLabels.length; i++) ...[
            if (i > 0) Expanded(child: Container(height: 2, color: AppColors.border)),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => onTap(i + kManualResumeFirstStep),
                child: _StepDot(label: kManualResumeStepLabels[i], active: i + kManualResumeFirstStep == currentStep),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: active ? AppColors.action : AppColors.surface,
          foregroundColor: active ? AppColors.textOnDark : AppColors.textMuted,
          child: Icon(active ? Icons.edit : Icons.circle_outlined, size: 14),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: active ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
