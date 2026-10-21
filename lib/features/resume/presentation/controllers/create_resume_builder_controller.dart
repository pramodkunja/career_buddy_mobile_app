import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
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
    this.restoredFromLocalDraft = false,
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

  /// Phase 45 — `true` for exactly one render after
  /// [CreateResumeBuilderController.restoreGuestDraftIfAvailable] has
  /// filled [form] from a guest's previously saved local draft, so the
  /// screen can show the same "Restored the draft saved on this device."
  /// message the real web shows (`static/js/create_resume.js:829`,
  /// confirmed directly). Superseded the moment [lastSavedAt] is set by an
  /// actual save — see `_WizardBody`'s banner precedence — so this never
  /// needs its own explicit clear.
  final bool restoredFromLocalDraft;

  CreateResumeBuilderReady copyWith({
    CreateResumeFormState? form,
    int? currentStep,
    bool? saving,
    String? saveFailureMessage,
    bool clearSaveFailure = false,
    DateTime? lastSavedAt,
    List<CreateResumeValidationError>? serverErrors,
    bool? restoredFromLocalDraft,
  }) => CreateResumeBuilderReady(
    form: form ?? this.form,
    currentStep: currentStep ?? this.currentStep,
    saving: saving ?? this.saving,
    saveFailureMessage: clearSaveFailure
        ? null
        : (saveFailureMessage ?? this.saveFailureMessage),
    lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    serverErrors: serverErrors ?? this.serverErrors,
    restoredFromLocalDraft: restoredFromLocalDraft ?? this.restoredFromLocalDraft,
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
  /// Phase 45 — see `CreateResumePreviewController._generation`'s doc
  /// comment for the full reasoning (verified directly against this
  /// project's installed `riverpod: 3.4.3`): a plain (non-`autoDispose`)
  /// `NotifierProvider` re-runs [build] on the *same* instance when
  /// invalidated (e.g. `_invalidateUserScopedProviders()` on logout), so
  /// `ref.mounted` alone cannot catch a guest-draft restoration that was
  /// still in flight when that happened. [restoreGuestDraftIfAvailable]
  /// captures this before its only `await` and re-checks it after.
  int _generation = 0;

  /// Phase 45 — sentinel for "has a guest-draft restoration already been
  /// claimed for the current [startBlank]/[startFromDraft] session". Reset
  /// by [startBlank] (a fresh blank session permits exactly one restore
  /// attempt) and set unconditionally by [startFromDraft] (an explicitly
  /// opened draft must never be silently replaced by the local guest
  /// draft). Claimed synchronously, before any `await`, in
  /// [restoreGuestDraftIfAvailable] itself, so two overlapping calls in the
  /// same session can't both proceed.
  bool _guestDraftRestoreClaimed = false;

  @override
  CreateResumeBuilderState build() {
    _generation++;
    return const CreateResumeBuilderLoading();
  }

  /// Starts a blank resume. Called once from the screen's `initState` (via
  /// a post-frame callback, never directly, to avoid writing `state` while
  /// the widget tree is still building). Synchronous and unchanged in
  /// signature/behavior from before Phase 45 — [restoreGuestDraftIfAvailable]
  /// is a deliberately separate call the screen makes right after this one,
  /// not folded into this method, so none of the many existing tests that
  /// call `startBlank()` directly and assert synchronously are affected.
  void startBlank() {
    _guestDraftRestoreClaimed = false;
    state = const CreateResumeBuilderReady(form: CreateResumeFormState());
  }

  /// Opens an existing draft, fetched by [CreateResumeDraftsController]'s
  /// own "Open" action.
  void startFromDraft(CreateResumeFormState form) {
    // An explicitly opened draft (authenticated server draft or — not
    // currently reachable, but guarded regardless — any other caller of
    // this method) must never be silently replaced by the guest's locally
    // saved draft.
    _guestDraftRestoreClaimed = true;
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

  /// `true` only once the client's own auth state confirms a signed-in
  /// session — `AuthUnknown`/`AuthRefreshing` are deliberately treated the
  /// same as `AuthUnauthenticated` here (never optimistically "probably
  /// signed in"), so [save] never fires an unauthenticated server request
  /// merely to discover the obvious. A session that genuinely expires
  /// *after* this check still surfaces as a real
  /// [UnauthorizedFailure]-driven message via the normal authenticated
  /// path below — that is the one case this controller still calls
  /// "session expired", distinct from a guest who never had one.
  bool get _isAuthenticated => ref.read(authControllerProvider) is AuthAuthenticated;

  /// Explicit Save — creates a new draft or updates the one already open
  /// (tracked via [CreateResumeFormState.draftId]). A no-op while already
  /// saving — duplicate-submit prevention, same as every other submission
  /// controller in this feature.
  Future<void> save() async {
    final current = state;
    if (current is! CreateResumeBuilderReady || current.saving) return;
    if (!_isAuthenticated) {
      await _saveAsGuest(current);
      return;
    }
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

  /// Phase 42 — mirrors the real web's own guest branch exactly
  /// (`static/js/create_resume.js:656-660`, confirmed directly): a guest's
  /// Save never reaches the server at all, it writes to this device only.
  /// [CreateResumeBuilderScreen] reads the live auth state itself (not a
  /// flag on this state) to decide whether the resulting "Saved" banner
  /// should read as a plain confirmation or as a sign-in prompt — so a
  /// guest who signs in between taps always sees the correct banner for
  /// whichever branch the *next* save actually took.
  Future<void> _saveAsGuest(CreateResumeBuilderReady current) async {
    state = current.copyWith(saving: true, clearSaveFailure: true);
    final result = await ref
        .read(createResumeGuestDraftRepositoryProvider)
        .saveDraft(current.form);
    final after = state;
    if (after is! CreateResumeBuilderReady) return;
    switch (result) {
      case Success():
        state = after.copyWith(saving: false, lastSavedAt: DateTime.now());
      case Failed(failure: final failure):
        state = after.copyWith(
          saving: false,
          saveFailureMessage: failure.message,
        );
    }
  }

  /// Phase 45 — mirrors the real web's own guest auto-restore exactly
  /// (`static/js/create_resume.js:821-831`, confirmed directly): a guest
  /// who reopens Create Resume gets their last locally-saved draft back
  /// automatically. Called by the screen once, right after [startBlank] —
  /// never folded into [startBlank] itself (see that method's own doc
  /// comment for why).
  ///
  /// The web's own `localStorage` read is synchronous, so it can safely
  /// run before the user could possibly have typed anything. This device's
  /// [SecureStorageService] read is asynchronous, so a real race is
  /// possible here that has no web equivalent: [hasUnsavedContent] is
  /// checked both immediately (skip entirely if the guest somehow already
  /// has content — e.g. a future caller passing a non-empty starting form)
  /// and again after the `await` resolves, immediately before the restored
  /// form is applied, so nothing the guest typed while this was in flight
  /// is ever clobbered.
  ///
  /// A read failure (genuine storage/platform exception — corrupt or
  /// schema-mismatched *data* is already handled one layer down, inside
  /// [CreateResumeGuestDraftLocalDataSource.getDraft], which returns `null`
  /// for that rather than throwing) simply leaves the blank form in place;
  /// this must never crash or indefinitely block the builder.
  Future<void> restoreGuestDraftIfAvailable() async {
    if (_guestDraftRestoreClaimed) return;
    _guestDraftRestoreClaimed = true;
    if (_isAuthenticated) return;
    if (hasUnsavedContent) return;
    final requestGeneration = _generation;
    final result = await ref
        .read(createResumeGuestDraftRepositoryProvider)
        .loadDraft();
    if (!ref.mounted || requestGeneration != _generation) return;
    if (hasUnsavedContent) return;
    final current = state;
    if (current is! CreateResumeBuilderReady) return;
    switch (result) {
      case Success(value: final draft):
        if (draft != null) {
          state = current.copyWith(form: draft, restoredFromLocalDraft: true);
        }
      case Failed():
        break;
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
