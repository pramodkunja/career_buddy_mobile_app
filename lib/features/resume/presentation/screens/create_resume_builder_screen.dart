import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/create_resume_state.dart';
import '../controllers/create_resume_builder_controller.dart';
import '../controllers/create_resume_pdf_controller.dart';
import '../providers/resume_providers.dart';
import '../widgets/create_resume_education_step.dart';
import '../widgets/create_resume_experience_step.dart';
import '../widgets/create_resume_personal_step.dart';
import '../widgets/create_resume_skills_step.dart';
import '../widgets/create_resume_summary_step.dart';

/// Phase 39 — the free-form Create Resume builder's own 5-step wizard shell
/// (Personal/Summary/Skills/Experience/Education — the sections this phase
/// implements; see this feature's own doc comments for the remaining ones
/// not yet editable here). [initialForm] is the already-loaded state from
/// [CreateResumeDraftsScreen]'s "Open" action, or `null` to start blank.
class CreateResumeBuilderScreen extends ConsumerStatefulWidget {
  const CreateResumeBuilderScreen({this.initialForm, super.key});

  final CreateResumeFormState? initialForm;

  @override
  ConsumerState<CreateResumeBuilderScreen> createState() =>
      _CreateResumeBuilderScreenState();
}

class _CreateResumeBuilderScreenState
    extends ConsumerState<CreateResumeBuilderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(
        createResumeBuilderControllerProvider.notifier,
      );
      final initial = widget.initialForm;
      if (initial != null) {
        controller.startFromDraft(initial);
      } else {
        controller.startBlank();
        // Phase 45 — fire-and-forget: a guest's local draft (if any) fills
        // in moments after the blank form first renders, never blocking
        // this frame. See the controller method's own doc comment for the
        // full race-safety reasoning.
        controller.restoreGuestDraftIfAvailable();
      }
    });
  }

  Future<bool> _confirmDiscard() async {
    final controller = ref.read(createResumeBuilderControllerProvider.notifier);
    if (!controller.hasUnsavedContent) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Leaving now will lose them unless you save first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createResumeBuilderControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Resume'),
          actions: [
            IconButton(
              key: const Key('create-resume-my-resumes-button'),
              icon: const Icon(Icons.folder_outlined),
              tooltip: 'My Resumes',
              onPressed: () => context.push(RoutePaths.createResumeDrafts),
            ),
          ],
        ),
        body: switch (state) {
          CreateResumeBuilderLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          CreateResumeBuilderLoadFailed(failure: final failure) => Center(
            child: Text(failure.message),
          ),
          CreateResumeBuilderReady() => _WizardBody(state: state),
        },
      ),
    );
  }
}

class _WizardBody extends ConsumerWidget {
  const _WizardBody({required this.state});
  final CreateResumeBuilderReady state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(createResumeBuilderControllerProvider.notifier);
    final form = state.form;
    final errors = state.serverErrors;
    final pdfState = ref.watch(createResumePdfControllerProvider);
    final pdfGenerating = pdfState is CreateResumePdfGenerating;
    // Read fresh at render time, not cached on [state] — this is what the
    // controller's own `_saveAsGuest` doc comment means by "the screen
    // decides": a save that just completed reflects whichever branch
    // [CreateResumeBuilderController.save] actually took, and re-reading
    // auth here keeps that decision correct even if sign-in happens in a
    // different tab/screen while this one stays open.
    final isAuthenticated = ref.watch(authControllerProvider) is AuthAuthenticated;

    ref.listen(createResumePdfControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      switch (next) {
        case CreateResumePdfFailed(failure: final failure):
          messenger.showSnackBar(SnackBar(content: Text(failure.message)));
        case CreateResumePdfValidationFailed():
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'The PDF could not be generated yet — see the errors below.',
              ),
            ),
          );
        case CreateResumePdfIdle():
        case CreateResumePdfGenerating():
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepIndicator(
          currentStep: state.currentStep,
          onTap: controller.goToStep,
        ),
        if (state.saveFailureMessage != null)
          Container(
            color: AppColors.danger.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              state.saveFailureMessage!,
              key: const Key('save-failed-banner'),
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          )
        else if (state.lastSavedAt != null && !state.saving)
          if (isAuthenticated)
            Container(
              color: AppColors.success.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: const Text(
                'Saved.',
                key: Key('save-success-banner'),
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            // Phase 42 — mirrors the real web's own guest-save message
            // exactly (`static/js/create_resume.js:658`, confirmed
            // directly): "Draft saved on this device. Sign in to save it
            // to your account." with the sign-in action right alongside,
            // never a plain "Saved." that could be mistaken for a saved
            // server copy the candidate could reopen from another device.
            Container(
              key: const Key('save-success-guest-banner'),
              color: AppColors.success.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Draft saved on this device.',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('save-success-guest-sign-in-button'),
                    onPressed: () => context.go(RoutePaths.login),
                    child: const Text('Sign in', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
        else if (state.restoredFromLocalDraft && !state.saving)
          // Phase 45 — mirrors the real web's own restore message exactly
          // (`static/js/create_resume.js:829`, confirmed directly):
          // "Restored the draft saved on this device. Sign in to save it
          // to your account." Only ever reachable for a guest —
          // [CreateResumeBuilderController.restoreGuestDraftIfAvailable]
          // never runs for an authenticated session — so there is no
          // authenticated counterpart to this banner the way the save
          // banners above have one.
          Container(
            key: const Key('restored-local-draft-banner'),
            color: AppColors.success.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Restored the draft saved on this device.',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('restored-local-draft-sign-in-button'),
                  onPressed: () => context.go(RoutePaths.login),
                  child: const Text('Sign in', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        Expanded(
          child: switch (state.currentStep) {
            1 => CreateResumePersonalStep(
              personal: form.personal,
              serverErrors: errors,
            ),
            2 => CreateResumeSummaryStep(
              summary: form.summary,
              serverErrors: errors,
            ),
            3 => CreateResumeSkillsStep(
              skills: form.skills,
              serverErrors: errors,
            ),
            4 => CreateResumeExperienceStep(
              entries: form.experience,
              serverErrors: errors,
            ),
            _ => CreateResumeEducationStep(
              entries: form.education,
              serverErrors: errors,
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
                      onPressed: state.currentStep > kCreateResumeFirstStep
                          ? controller.previousStep
                          : null,
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const Key('wizard-next-button'),
                      onPressed: state.currentStep < kCreateResumeLastStep
                          ? controller.nextStep
                          : null,
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: const Key('wizard-save-button'),
                onPressed: state.saving ? null : controller.save,
                child: state.saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: const Key('wizard-preview-button'),
                onPressed: () =>
                    context.push(RoutePaths.createResumePreview, extra: form),
                child: const Text('Preview Resume'),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const Key('wizard-generate-pdf-button'),
                onPressed: pdfGenerating
                    ? null
                    : () => ref
                          .read(createResumePdfControllerProvider.notifier)
                          .generateAndOpen(form),
                child: pdfGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnDark,
                        ),
                      )
                    : const Text('Download PDF'),
              ),
              if (pdfState case CreateResumePdfValidationFailed(
                errors: final pdfErrors,
              ))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    pdfErrors.isEmpty
                        ? 'The PDF could not be generated yet.'
                        : 'The PDF could not be generated yet: ${pdfErrors.first.message}',
                    key: const Key('pdf-validation-error'),
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < kCreateResumeStepLabels.length; i++) ...[
            if (i > 0)
              Expanded(child: Container(height: 2, color: AppColors.border)),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => onTap(i + kCreateResumeFirstStep),
                child: _StepDot(
                  label: kCreateResumeStepLabels[i],
                  active: i + kCreateResumeFirstStep == currentStep,
                ),
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
          maxLines: 1,
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
