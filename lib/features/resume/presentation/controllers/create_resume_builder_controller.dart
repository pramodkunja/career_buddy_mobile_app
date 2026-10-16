import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';

/// Phase 39. The 5 sections this phase implements, in the order
/// `create_resume.py`'s own `SECTIONS` tuple lists them — display labels
/// only, [CreateResumeBuilderReady.currentStep] stores the numeric index.
const List<String> kCreateResumeStepLabels = [
  'Personal',
  'Summary',
  'Skills',
  'Experience',
  'Education',
];
const int kCreateResumeFirstStep = 1;
const int kCreateResumeLastStep = 5;

sealed class CreateResumeBuilderState {
  const CreateResumeBuilderState();
}

final class CreateResumeBuilderLoading extends CreateResumeBuilderState {
  const CreateResumeBuilderLoading();
}

final class CreateResumeBuilderLoadFailed extends CreateResumeBuilderState {
  const CreateResumeBuilderLoadFailed(this.failure);
  final Failure failure;
}

final class CreateResumeBuilderReady extends CreateResumeBuilderState {
  const CreateResumeBuilderReady({
    required this.form,
    this.currentStep = kCreateResumeFirstStep,
    this.saving = false,
    this.saveFailureMessage,
    this.lastSavedAt,
    this.serverErrors = const [],
  });

  final CreateResumeFormState form;
  final int currentStep;

  /// A save (explicit "Save" action — this feature has no autosave, matching
  /// the real web's own one-tap-to-persist drafts model, confirmed directly:
  /// `draft_save` is only ever called from the builder's own Save button,
  /// never on a timer) is in flight.
  final bool saving;

  /// The most recent save's failure message, if any — cleared the moment a
  /// new save starts or succeeds. Never silently swallowed, per the task's
  /// explicit "clear save success/failure feedback" requirement.
  final String? saveFailureMessage;

  final DateTime? lastSavedAt;

  /// The most recent `preview`/`pdf`/`pages` submission's returned errors
  /// (`{field, section, message}`) — this feature has no separate
  /// client-side validator (see the Phase 39 report for why that's a
  /// deliberate scope decision), so every piece of field-level validation
  /// feedback this screen shows comes from the server's own live response.
  final List<CreateResumeValidationError> serverErrors;

  CreateResumeBuilderReady copyWith({
    CreateResumeFormState? form,
    int? currentStep,
    bool? saving,
    String? saveFailureMessage,
    bool clearSaveFailure = false,
    DateTime? lastSavedAt,
    List<CreateResumeValidationError>? serverErrors,
  }) => CreateResumeBuilderReady(
    form: form ?? this.form,
    currentStep: currentStep ?? this.currentStep,
    saving: saving ?? this.saving,
    saveFailureMessage: clearSaveFailure
        ? null
        : (saveFailureMessage ?? this.saveFailureMessage),
    lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    serverErrors: serverErrors ?? this.serverErrors,
  );
}

/// Owns the in-progress [CreateResumeFormState] and every field-level edit —
/// no local persistence of its own (see [CreateResumeBuilderReady]'s own
/// doc comment): closing the builder without tapping Save discards unsaved
/// changes, exactly matching the real web (confirmed directly: the real
/// builder's own `beforeunload` warning is its only unsaved-changes
/// safeguard, which this screen's own "discard changes?" confirmation
/// mirrors — see `CreateResumeBuilderScreen`). Not `.autoDispose`, matching
/// every other builder controller in this app, so it is included wherever
/// `_invalidateUserScopedProviders()` already resets user-scoped state on
/// logout/account switch.
class CreateResumeBuilderController extends Notifier<CreateResumeBuilderState> {
  @override
  CreateResumeBuilderState build() => const CreateResumeBuilderLoading();

  /// Starts a blank resume. Called once from the screen's `initState` (via
  /// a post-frame callback, never directly, to avoid writing `state` while
  /// the widget tree is still building).
  void startBlank() {
    state = const CreateResumeBuilderReady(form: CreateResumeFormState());
  }

  /// Opens an existing draft, fetched by [CreateResumeDraftsController]'s
  /// own "Open" action.
  void startFromDraft(CreateResumeFormState form) {
    state = CreateResumeBuilderReady(form: form);
  }

  void updateForm(
    CreateResumeFormState Function(CreateResumeFormState form) update,
  ) {
    final current = state;
    if (current is! CreateResumeBuilderReady) return;
    state = current.copyWith(
      form: update(current.form),
      clearSaveFailure: true,
    );
  }

  void updatePersonal(
    CreateResumePersonalInfo Function(CreateResumePersonalInfo personal) update,
  ) {
    updateForm((f) => f.copyWith(personal: update(f.personal)));
  }

  void setSummary(String value) =>
      updateForm((f) => f.copyWith(summary: value));

  void setTemplate(String value) =>
      updateForm((f) => f.copyWith(template: value));

  void updateSkills(
    CreateResumeSkills Function(CreateResumeSkills skills) update,
  ) {
    updateForm((f) => f.copyWith(skills: update(f.skills)));
  }

  void addExperience() => updateForm(
    (f) => f.copyWith(
      experience: [...f.experience, const CreateResumeExperienceEntry()],
    ),
  );

  void removeExperience(int index) => updateForm(
    (f) => f.copyWith(experience: [...f.experience]..removeAt(index)),
  );

  void updateExperience(
    int index,
    CreateResumeExperienceEntry Function(CreateResumeExperienceEntry) update,
  ) {
    updateForm((f) {
      final list = [...f.experience];
      list[index] = update(list[index]);
      return f.copyWith(experience: list);
    });
  }

  void addEducation() => updateForm(
    (f) => f.copyWith(
      education: [...f.education, const CreateResumeEducationEntry()],
    ),
  );

  void removeEducation(int index) => updateForm(
    (f) => f.copyWith(education: [...f.education]..removeAt(index)),
  );

  void updateEducation(
    int index,
    CreateResumeEducationEntry Function(CreateResumeEducationEntry) update,
  ) {
    updateForm((f) {
      final list = [...f.education];
      list[index] = update(list[index]);
      return f.copyWith(education: list);
    });
  }

  /// Free navigation between steps — this builder has no step-blocking
  /// validation of its own (unlike the Manual builder's `nextStep`): since
  /// every field-level rule lives server-side only (see this class's own
  /// doc comment on [CreateResumeBuilderReady.serverErrors]), there is
  /// nothing to check client-side before letting the candidate move on.
  void goToStep(int step) {
    final current = state;
    if (current is! CreateResumeBuilderReady) return;
    state = current.copyWith(
      currentStep: step.clamp(kCreateResumeFirstStep, kCreateResumeLastStep),
    );
  }

  void previousStep() {
    final current = state;
    if (current is! CreateResumeBuilderReady) return;
    if (current.currentStep > kCreateResumeFirstStep) {
      goToStep(current.currentStep - 1);
    }
  }

  void nextStep() {
    final current = state;
    if (current is! CreateResumeBuilderReady) return;
    if (current.currentStep < kCreateResumeLastStep) {
      goToStep(current.currentStep + 1);
    }
  }

  /// Called by [CreateResumePreviewController]/[CreateResumePdfController]
  /// the moment a submission comes back with errors, so returning to this
  /// screen already shows which fields need attention.
  void setServerErrors(List<CreateResumeValidationError> errors) {
    final current = state;
    if (current is! CreateResumeBuilderReady) return;
    state = current.copyWith(serverErrors: errors);
  }

  void clearServerErrors() {
    final current = state;
    if (current is! CreateResumeBuilderReady || current.serverErrors.isEmpty) {
      return;
    }
    state = current.copyWith(serverErrors: const []);
  }

  /// Explicit Save — creates a new draft or updates the one already open
  /// (tracked via [CreateResumeFormState.draftId]). A no-op while already
  /// saving — duplicate-submit prevention, same as every other submission
  /// controller in this feature.
  Future<void> save() async {
    final current = state;
    if (current is! CreateResumeBuilderReady || current.saving) return;
    state = current.copyWith(saving: true, clearSaveFailure: true);
    final result = await ref
        .read(createResumeRepositoryProvider)
        .saveDraft(current.form);
    final after = state;
    if (after is! CreateResumeBuilderReady) return;
    switch (result) {
      case Success(value: final id):
        state = after.copyWith(
          form: after.form.copyWith(draftId: id),
          saving: false,
          lastSavedAt: DateTime.now(),
        );
        ref.invalidate(createResumeDraftsControllerProvider);
      case Failed(failure: final failure):
        state = after.copyWith(
          saving: false,
          saveFailureMessage: failure.message,
        );
    }
  }

  /// True once any field holds real content — used to decide whether
  /// leaving the builder needs a "discard changes?" confirmation.
  bool get hasUnsavedContent {
    final current = state;
    if (current is! CreateResumeBuilderReady) return false;
    final f = current.form;
    return f.personal.toJson().values.any((v) => v.toString().isNotEmpty) ||
        f.summary.isNotEmpty ||
        f.skills.technical.isNotEmpty ||
        f.skills.functional.isNotEmpty ||
        f.skills.soft.isNotEmpty ||
        f.skills.tools.isNotEmpty ||
        f.experience.any((e) => !e.isBlank) ||
        f.education.any((e) => !e.isBlank);
  }
}
