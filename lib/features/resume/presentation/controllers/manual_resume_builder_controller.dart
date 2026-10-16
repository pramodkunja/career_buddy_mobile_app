import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/level_common_suggestions.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/entities/resume_role.dart';
import '../../domain/validation/manual_resume_validation.dart';
import '../providers/resume_providers.dart';

/// The five named steps `career_app/resume_document.py:60` numbers 1-5
/// (`STEP_PERSONAL`..`STEP_SUMMARY`) — display labels only, the numeric
/// value itself is what [ManualResumeDraft.currentStep] actually stores.
const List<String> kManualResumeStepLabels = [
  'Personal',
  'Career & Skills',
  'Experience',
  'Education',
  'Summary',
];

sealed class ManualResumeBuilderState {
  const ManualResumeBuilderState();
}

final class ManualResumeBuilderLoading extends ManualResumeBuilderState {
  const ManualResumeBuilderLoading();
}

final class ManualResumeBuilderLoadFailed extends ManualResumeBuilderState {
  const ManualResumeBuilderLoadFailed(this.failure);
  final Failure failure;
}

final class ManualResumeBuilderReady extends ManualResumeBuilderState {
  const ManualResumeBuilderReady({
    required this.draft,
    this.role,
    this.levelCommon = const {},
    this.touched = const {},
    this.showAllErrors = false,
    this.saveFailed = false,
    this.roleCatalogLoadFailed = false,
    this.serverErrors = const [],
  });

  final ManualResumeDraft draft;

  /// The full role object matching [ManualResumeDraft.role] (looked up
  /// from the catalog on restore, or supplied directly by the Role Picker
  /// on a fresh entry — see `setRoleIfBlank`'s doc comment). `null` means
  /// "not resolved yet" (e.g. a custom/no-template role, or the catalog
  /// fetch failed) — validation already has its own, correct "select a
  /// role" error for the genuinely-blank case, so this is never faked.
  final ResumeRole? role;

  /// Role-independent per-level suggestions (soft skills, achievements) —
  /// `{}` when not yet loaded or the fetch failed; suggestion chips simply
  /// don't render rather than the screen failing.
  final Map<String, LevelCommonSuggestions> levelCommon;

  /// Field keys (matching [ManualResumeValidationError.field]) whose error,
  /// if any, should be shown — set on blur and when a blocked "Next" names
  /// the current step's own offending fields. Mirrors the real builder's
  /// own `touched` tracking (verified, `landing.html:8819`/`8845`).
  final Set<String> touched;

  /// Set by [ManualResumeBuilderController.reviewAll] — every error becomes
  /// visible everywhere, regardless of [touched] (verified,
  /// `landing.html:8671-8676`'s `showAll` flag).
  final bool showAllErrors;

  /// The most recent debounced local save failed — surfaced so the screen
  /// can show it, never silently swallowed (the task's explicit
  /// requirement). Cleared optimistically the moment a new edit is made.
  final bool saveFailed;

  /// The role-catalog/level-common fetch failed — suggestion chips and
  /// role-specific skill groups are degraded (absent) but the draft itself
  /// is still fully editable; never blocks the whole screen the way
  /// [ManualResumeBuilderLoadFailed] does, since the draft's own local
  /// persistence is the only thing that must not fail silently.
  final bool roleCatalogLoadFailed;

  /// The most recent `preview_api` validation-rejection errors (Phase 27) —
  /// same `{field, step, message}` shape as [errors], reused verbatim
  /// (confirmed identical to the server's own, see
  /// `ManualResumePreviewOutcome`'s doc comment). Unlike client errors,
  /// these are shown unconditionally the moment they arrive (the candidate
  /// just explicitly submitted for preview, so there is no "not yet
  /// touched" state to gate them behind) — cleared by a fresh preview
  /// attempt (success or a new rejection replaces them), never by an
  /// unrelated field edit.
  final List<ManualResumeValidationError> serverErrors;

  /// The faithful client-side port of `validate_state()`
  /// (`manual_resume_validation.dart`) — recomputed from the current draft
  /// on every read, never cached/stale.
  List<ManualResumeValidationError> get errors => validateManualResumeDraft(draft, role);

  /// Client errors take priority per field — a server error is only added
  /// for a field with no currently-visible client error of its own, so the
  /// same field is never shown twice at once.
  List<ManualResumeValidationError> get visibleErrors {
    final clientVisible = errors.where((e) => showAllErrors || touched.contains(e.field)).toList();
    final clientFields = clientVisible.map((e) => e.field).toSet();
    return [...clientVisible, ...serverErrors.where((e) => !clientFields.contains(e.field))];
  }

  ManualResumeBuilderReady copyWith({
    ManualResumeDraft? draft,
    ResumeRole? role,
    bool clearRole = false,
    Map<String, LevelCommonSuggestions>? levelCommon,
    Set<String>? touched,
    bool? showAllErrors,
    bool? saveFailed,
    bool? roleCatalogLoadFailed,
    List<ManualResumeValidationError>? serverErrors,
  }) => ManualResumeBuilderReady(
    draft: draft ?? this.draft,
    role: clearRole ? null : (role ?? this.role),
    levelCommon: levelCommon ?? this.levelCommon,
    touched: touched ?? this.touched,
    showAllErrors: showAllErrors ?? this.showAllErrors,
    saveFailed: saveFailed ?? this.saveFailed,
    roleCatalogLoadFailed: roleCatalogLoadFailed ?? this.roleCatalogLoadFailed,
    serverErrors: serverErrors ?? this.serverErrors,
  );
}

/// Splits/trims/deduplicates (case-insensitively, keeping the first
/// occurrence) exactly like the server's own `_list()`
/// (`resume_document.py:97-111`) would, so what the candidate sees in the
/// field already matches what gets validated/stored.
List<String> _splitSkillText(String raw) {
  final out = <String>[];
  final seen = <String>{};
  for (final part in raw.split(RegExp(r'[,\n;]'))) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (seen.add(key)) out.add(trimmed);
  }
  return out;
}

bool _containsCaseInsensitive(Iterable<String> items, String value) =>
    items.any((i) => i.toLowerCase() == value.toLowerCase());

bool _lineAlreadyPresent(String block, String candidate) =>
    block.split('\n').map((l) => l.trim().toLowerCase()).contains(candidate.trim().toLowerCase());

String _appendLine(String block, String line) => block.isEmpty ? line : '$block\n$line';

/// Loads/saves/clears one account's [ManualResumeDraft], tracks which of
/// the five wizard steps is current, and owns every field-level edit the
/// real form makes (Phase 26). Not `.autoDispose` (matching every other
/// controller in `_invalidateUserScopedProviders()`), so it is added to
/// that method's list — without that, the previous account's in-memory
/// draft (names, phone numbers, employment history) would still be visible
/// to whichever account logs in next in the same app process, the exact
/// cross-account leak class that method exists to prevent.
class ManualResumeBuilderController extends Notifier<ManualResumeBuilderState> {
  Timer? _saveDebounce;

  /// 300ms — matches the real builder's own `sessionStorage` debounce
  /// exactly (verified, `landing.html:8350`). Unlike the web (which only
  /// persists per-tab via `sessionStorage`), Phase 25's explicit product
  /// decision was to persist across app restarts — a deliberate, approved
  /// divergence, not an oversight.
  static const Duration saveDebounce = Duration(milliseconds: 300);

  @override
  ManualResumeBuilderState build() {
    ref.onDispose(() => _saveDebounce?.cancel());
    return const ManualResumeBuilderLoading();
  }

  /// `null` when the caller isn't authenticated — the route that opens this
  /// screen already requires auth (not in `publicRoutes`/`universalRoutes`),
  /// so this is only ever reached mid-session if a session expires while
  /// the screen is still open; every method below treats that as "can't
  /// identify whose draft this is" rather than guessing.
  String? get _username {
    final authState = ref.read(authControllerProvider);
    return authState is AuthAuthenticated ? authState.user.username : null;
  }

  /// Called once from the screen's `initState` via a post-frame callback
  /// (never directly, to avoid writing `state` while the widget tree is
  /// still building — the exact crash Phase 23's `RolePickerController`
  /// hit first). Restores a saved draft if one exists; otherwise starts
  /// blank. Also resolves the draft's own `role` slug against the role
  /// catalog (needed on a restore, where only the slug was persisted) and
  /// fetches level-independent suggestion data — both best-effort: a
  /// failure here degrades suggestions/skill groups, it never blocks the
  /// draft itself from loading.
  Future<void> load() async {
    state = const ManualResumeBuilderLoading();
    final username = _username;
    if (username == null) {
      state = const ManualResumeBuilderLoadFailed(UnauthorizedFailure());
      return;
    }
    final result = await ref.read(manualResumeDraftRepositoryProvider).loadDraft(username);
    switch (result) {
      case Success(value: final loaded):
        final draft = loaded ?? ManualResumeDraft.blank();
        state = ManualResumeBuilderReady(draft: draft);
        await _loadRoleCatalog(draft.role);
      case Failed(failure: final failure):
        state = ManualResumeBuilderLoadFailed(failure);
    }
  }

  Future<void> _loadRoleCatalog(String roleSlug) async {
    final repository = ref.read(resumeRepositoryProvider);
    final rolesResult = await repository.getRoles();
    final levelCommonResult = await repository.getLevelCommonSuggestions();
    final current = state;
    if (current is! ManualResumeBuilderReady) return;

    ResumeRole? resolvedRole;
    var failed = false;
    switch (rolesResult) {
      case Success(value: final roles):
        if (roleSlug.isNotEmpty) {
          resolvedRole = roles.where((r) => r.slug == roleSlug).cast<ResumeRole?>().firstWhere(
                (r) => true,
                orElse: () => null,
              );
        }
      case Failed():
        failed = true;
    }
    Map<String, LevelCommonSuggestions> levelCommon = const {};
    switch (levelCommonResult) {
      case Success(value: final value):
        levelCommon = value;
      case Failed():
        failed = true;
    }
    state = current.copyWith(role: resolvedRole, levelCommon: levelCommon, roleCatalogLoadFailed: failed);
  }

  Future<void> retryLoad() => load();

  Future<void> retryRoleCatalogLoad() async {
    final current = state;
    if (current is! ManualResumeBuilderReady) return;
    await _loadRoleCatalog(current.draft.role);
  }

  /// Every field-level mutation funnels through here: applies [update] to
  /// the current draft, updates state immediately (so the UI never waits
  /// on a debounce to reflect what was typed), and schedules a debounced
  /// save. A failed save surfaces via [ManualResumeBuilderReady.saveFailed]
  /// rather than being silently swallowed — the task's explicit "a failed
  /// local save must not silently imply data was saved" requirement.
  void updateDraft(ManualResumeDraft Function(ManualResumeDraft draft) update) {
    final current = state;
    if (current is! ManualResumeBuilderReady) return;
    final updated = update(current.draft);
    state = current.copyWith(draft: updated, saveFailed: false);
    _scheduleSave(updated);
  }

  void _scheduleSave(ManualResumeDraft draft) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(saveDebounce, () => _saveNow(draft));
  }

  Future<void> _saveNow(ManualResumeDraft draft) async {
    final username = _username;
    if (username == null) return;
    final result = await ref.read(manualResumeDraftRepositoryProvider).saveDraft(username, draft);
    final current = state;
    if (current is ManualResumeBuilderReady) {
      state = current.copyWith(saveFailed: result is Failed);
    }
  }

  /// Marks [field] as having been blurred — its error (if any) becomes
  /// visible from now on. A no-op once [ManualResumeBuilderReady.showAllErrors]
  /// is already true.
  void markTouched(String field) {
    final current = state;
    if (current is! ManualResumeBuilderReady || current.touched.contains(field)) return;
    state = current.copyWith(touched: {...current.touched, field});
  }

  /// Fills the draft's role only when it doesn't already have one — opening
  /// the builder for an in-progress draft of a *different* role must never
  /// silently overwrite it just because the Role Picker was used again.
  /// Also stores the full [role] object directly (no extra catalog fetch
  /// needed): the Role Picker already resolved it.
  void setRoleIfBlank(ResumeRole role) {
    final current = state;
    if (current is! ManualResumeBuilderReady) return;
    if (current.draft.role.isNotEmpty) return;
    state = current.copyWith(draft: current.draft.copyWith(role: role.slug), role: role);
    _scheduleSave(current.draft.copyWith(role: role.slug));
  }

  Future<void> _persistStep(ManualResumeDraft draft) async {
    final current = state;
    if (current is! ManualResumeBuilderReady) return;
    state = current.copyWith(draft: draft);
    final username = _username;
    if (username == null) return;
    final result = await ref.read(manualResumeDraftRepositoryProvider).saveDraft(username, draft);
    final after = state;
    if (after is ManualResumeBuilderReady) state = after.copyWith(saveFailed: result is Failed);
  }

  /// Free navigation — matches the real builder's step tabs/Back button,
  /// neither of which validate (verified, `landing.html:8840-8841`).
  Future<void> goToStep(int step) async {
    final current = state;
    if (current is! ManualResumeBuilderReady) return;
    await _persistStep(current.draft.copyWith(currentStep: step));
  }

  Future<void> previousStep() async {
    final current = state;
    if (current is! ManualResumeBuilderReady) return;
    if (current.draft.currentStep <= kManualResumeFirstStep) return;
    await _persistStep(current.draft.copyWith(currentStep: current.draft.currentStep - 1));
  }

  /// The only gated transition (verified, `landing.html:8842-8846`): blocked
  /// when the *current* step has a validation error, in which case those
  /// fields become visible (added to `touched`) instead of advancing.
  /// Returns `true` when it actually advanced.
  Future<bool> nextStep() async {
    final current = state;
    if (current is! ManualResumeBuilderReady) return false;
    if (current.draft.currentStep >= kManualResumeLastStep) return false;
    final blocking = current.errors.where((e) => e.step == current.draft.currentStep).map((e) => e.field).toSet();
    if (blocking.isNotEmpty) {
      state = current.copyWith(touched: {...current.touched, ...blocking});
      return false;
    }
    await _persistStep(current.draft.copyWith(currentStep: current.draft.currentStep + 1));
    return true;
  }

  /// "Review Missing Information" (verified, `landing.html:8671-8676`):
  /// validates everything, makes every error visible, and jumps to the
  /// first one's own step. Returns that first error, or `null` when the
  /// draft is already fully valid.
  ManualResumeValidationError? reviewAll() {
    final current = state;
    if (current is! ManualResumeBuilderReady) return null;
    final errors = current.errors;
    if (errors.isEmpty) {
      state = current.copyWith(showAllErrors: true);
      return null;
    }
    final first = errors.first;
    state = current.copyWith(showAllErrors: true, draft: current.draft.copyWith(currentStep: first.step));
    return first;
  }

  /// Explicit, user-confirmed removal only — never invoked by logout or
  /// session-expiry handling (see `ManualResumeDraftRepository`'s doc
  /// comment for why those must stay separate: a draft loss on top of a
  /// forced logout a candidate didn't ask for would be a second, unrelated
  /// data-loss surprise).
  Future<void> clearDraft() async {
    _saveDebounce?.cancel();
    final username = _username;
    if (username == null) return;
    await ref.read(manualResumeDraftRepositoryProvider).clearDraft(username);
    state = ManualResumeBuilderReady(draft: ManualResumeDraft.blank());
  }

  /// Called by [ManualResumePreviewController] the moment a preview
  /// submission comes back rejected (Phase 27) — makes every server error
  /// visible immediately and jumps to the first one's own step, so
  /// returning from the preview screen (by any means — a specific "fix
  /// this" action or just the plain back button) already shows the right
  /// step with the right fields flagged, exactly like [reviewAll] does for
  /// client-side errors.
  void setServerErrors(List<ManualResumeValidationError> errors) {
    final current = state;
    if (current is! ManualResumeBuilderReady) return;
    final step = errors.isEmpty ? current.draft.currentStep : errors.first.step;
    state = current.copyWith(serverErrors: errors, draft: current.draft.copyWith(currentStep: step));
  }

  /// Called on a successful preview — any stale server errors from an
  /// earlier, now-corrected submission must not linger.
  void clearServerErrors() {
    final current = state;
    if (current is! ManualResumeBuilderReady || current.serverErrors.isEmpty) return;
    state = current.copyWith(serverErrors: const []);
  }

  // ------------------------------------------------------------------- //
  //  Step 1 — Personal
  // ------------------------------------------------------------------- //

  void updatePersonal(ManualResumePersonalInfo Function(ManualResumePersonalInfo personal) update) {
    updateDraft((d) => d.copyWith(personal: update(d.personal)));
  }

  // ------------------------------------------------------------------- //
  //  Step 2 — Career & Skills
  // ------------------------------------------------------------------- //

  void setLevel(String level) => updateDraft((d) => d.copyWith(level: level));

  void setTargetTitle(String value) => updateDraft((d) => d.copyWith(targetTitle: value));

  void setDomain(String value) => updateDraft((d) => d.copyWith(domain: value));

  void setYears(String value) => updateDraft((d) => d.copyWith(years: value));

  void toggleGroupSkill(String groupKey, String skill) {
    updateDraft((d) {
      final groups = {...d.skills.groups};
      final current = List<String>.from(groups[groupKey] ?? const []);
      if (_containsCaseInsensitive(current, skill)) {
        current.removeWhere((s) => s.toLowerCase() == skill.toLowerCase());
      } else {
        current.add(skill);
      }
      groups[groupKey] = current;
      return d.copyWith(skills: d.skills.copyWith(groups: groups));
    });
  }

  /// Adds a free-text skill to a role field's own group (the "Add your own
  /// skill" box next to each skill-group chip list, verified,
  /// `landing.html:8491-8499`/`8823-8829`). Returns an error message when
  /// [skill] is outside `kSkillMin..kSkillMax` characters or already
  /// present (case-insensitively) — `null` on success.
  String? addCustomGroupSkill(String groupKey, String skill) {
    final trimmed = skill.trim().replaceAll(RegExp(r'\s{2,}'), ' ');
    if (trimmed.length < kSkillMin || trimmed.length > kSkillMax) {
      return 'Each skill must be $kSkillMin–$kSkillMax characters.';
    }
    final current = state;
    if (current is! ManualResumeBuilderReady) return null;
    final existing = current.draft.skills.groups[groupKey] ?? const [];
    if (_containsCaseInsensitive(existing, trimmed)) return null;
    updateDraft((d) {
      final groups = {...d.skills.groups};
      groups[groupKey] = [...(groups[groupKey] ?? const []), trimmed];
      return d.copyWith(skills: d.skills.copyWith(groups: groups));
    });
    return null;
  }

  void toggleSuggestedSkill(String skill) {
    updateDraft((d) {
      final current = List<String>.from(d.skills.suggested);
      if (_containsCaseInsensitive(current, skill)) {
        current.removeWhere((s) => s.toLowerCase() == skill.toLowerCase());
      } else {
        current.add(skill);
      }
      return d.copyWith(skills: d.skills.copyWith(suggested: current));
    });
  }

  void toggleSoftSkill(String skill) {
    updateDraft((d) {
      final current = List<String>.from(d.skills.soft);
      if (_containsCaseInsensitive(current, skill)) {
        current.removeWhere((s) => s.toLowerCase() == skill.toLowerCase());
      } else {
        current.add(skill);
      }
      return d.copyWith(skills: d.skills.copyWith(soft: current));
    });
  }

  /// Bound to the free-text "Other skills (comma separated)" field
  /// (verified, `landing.html:8586`) — [raw] is the field's full text,
  /// split/deduped the same way the server's own `_list()` would.
  void setOtherSkillsText(String raw) {
    updateDraft((d) => d.copyWith(skills: d.skills.copyWith(other: _splitSkillText(raw))));
  }

  // ------------------------------------------------------------------- //
  //  Step 3 — Experience (employment / internships / projects)
  // ------------------------------------------------------------------- //

  void addEmployment() => updateDraft(
    (d) => d.employment.length >= kMaxItems ? d : d.copyWith(employment: [...d.employment, const ManualResumeJobEntry()]),
  );

  void removeEmployment(int index) =>
      updateDraft((d) => d.copyWith(employment: [...d.employment]..removeAt(index)));

  void updateEmployment(int index, ManualResumeJobEntry Function(ManualResumeJobEntry) update) {
    updateDraft((d) {
      final list = [...d.employment];
      list[index] = update(list[index]);
      return d.copyWith(employment: list);
    });
  }

  void addInternship() => updateDraft(
    (d) => d.internships.length >= kMaxItems ? d : d.copyWith(internships: [...d.internships, const ManualResumeJobEntry()]),
  );

  void removeInternship(int index) =>
      updateDraft((d) => d.copyWith(internships: [...d.internships]..removeAt(index)));

  void updateInternship(int index, ManualResumeJobEntry Function(ManualResumeJobEntry) update) {
    updateDraft((d) {
      final list = [...d.internships];
      list[index] = update(list[index]);
      return d.copyWith(internships: list);
    });
  }

  void addProject() => updateDraft(
    (d) => d.projects.length >= kMaxItems ? d : d.copyWith(projects: [...d.projects, const ManualResumeProjectEntry()]),
  );

  /// Creates a project pre-filled with [name] — the fresher-level "project
  /// idea" suggestion chips (verified, `landing.html:8508-8513`/`8862-8863`),
  /// which create a whole new entry rather than appending to one.
  void addProjectNamed(String name) => updateDraft(
    (d) => d.projects.length >= kMaxItems ? d : d.copyWith(projects: [...d.projects, ManualResumeProjectEntry(name: name)]),
  );

  void removeProject(int index) => updateDraft((d) => d.copyWith(projects: [...d.projects]..removeAt(index)));

  void updateProject(int index, ManualResumeProjectEntry Function(ManualResumeProjectEntry) update) {
    updateDraft((d) {
      final list = [...d.projects];
      list[index] = update(list[index]);
      return d.copyWith(projects: list);
    });
  }

  /// Appends [suggestion] as a new line to employment entry [index]'s
  /// bullets, unless that exact line (case-insensitively) is already
  /// present — matches the real chip's intent (verified,
  /// `landing.html:8857-8861`) without ever creating a visible duplicate
  /// line (the exact "re-click an already-used chip" behavior wasn't
  /// independently confirmed beyond its `.used` styling).
  void appendEmploymentBulletSuggestion(int index, String suggestion) {
    updateDraft((d) {
      final list = [...d.employment];
      final entry = list[index];
      if (_lineAlreadyPresent(entry.bullets, suggestion)) return d;
      list[index] = entry.copyWith(bullets: _appendLine(entry.bullets, suggestion));
      return d.copyWith(employment: list);
    });
  }

  void appendInternshipBulletSuggestion(int index, String suggestion) {
    updateDraft((d) {
      final list = [...d.internships];
      final entry = list[index];
      if (_lineAlreadyPresent(entry.bullets, suggestion)) return d;
      list[index] = entry.copyWith(bullets: _appendLine(entry.bullets, suggestion));
      return d.copyWith(internships: list);
    });
  }

  // ------------------------------------------------------------------- //
  //  Step 4 — Education (education / certifications / training)
  // ------------------------------------------------------------------- //

  void addEducation() => updateDraft(
    (d) => d.education.length >= kMaxItems ? d : d.copyWith(education: [...d.education, const ManualResumeEducationEntry()]),
  );

  void removeEducation(int index) => updateDraft((d) => d.copyWith(education: [...d.education]..removeAt(index)));

  void updateEducation(int index, ManualResumeEducationEntry Function(ManualResumeEducationEntry) update) {
    updateDraft((d) {
      final list = [...d.education];
      list[index] = update(list[index]);
      return d.copyWith(education: list);
    });
  }

  void addCertification() => updateDraft(
    (d) => d.certifications.length >= kMaxItems
        ? d
        : d.copyWith(certifications: [...d.certifications, const ManualResumeCertificationEntry()]),
  );

  /// Role certification-suggestion chips create a new, named entry
  /// (verified, `landing.html:8601`).
  void addCertificationNamed(String name) => updateDraft(
    (d) => d.certifications.length >= kMaxItems
        ? d
        : d.copyWith(certifications: [...d.certifications, ManualResumeCertificationEntry(name: name)]),
  );

  void removeCertification(int index) =>
      updateDraft((d) => d.copyWith(certifications: [...d.certifications]..removeAt(index)));

  void updateCertification(int index, ManualResumeCertificationEntry Function(ManualResumeCertificationEntry) update) {
    updateDraft((d) {
      final list = [...d.certifications];
      list[index] = update(list[index]);
      return d.copyWith(certifications: list);
    });
  }

  void addTraining() => updateDraft(
    (d) => d.training.length >= kMaxItems ? d : d.copyWith(training: [...d.training, const ManualResumeTrainingEntry()]),
  );

  /// Role training-suggestion chips (sourced from the selected level's own
  /// suggestions) create a new, named entry (verified, `landing.html:8602`).
  void addTrainingNamed(String name) => updateDraft(
    (d) => d.training.length >= kMaxItems ? d : d.copyWith(training: [...d.training, ManualResumeTrainingEntry(name: name)]),
  );

  void removeTraining(int index) => updateDraft((d) => d.copyWith(training: [...d.training]..removeAt(index)));

  void updateTraining(int index, ManualResumeTrainingEntry Function(ManualResumeTrainingEntry) update) {
    updateDraft((d) {
      final list = [...d.training];
      list[index] = update(list[index]);
      return d.copyWith(training: list);
    });
  }

  // ------------------------------------------------------------------- //
  //  Step 5 — Summary
  // ------------------------------------------------------------------- //

  void setSummary(String value) => updateDraft((d) => d.copyWith(summary: value));

  /// Replaces the summary outright — the caller (the screen) is
  /// responsible for confirming first when a non-empty summary already
  /// exists, matching the real builder's own confirm-before-replace
  /// behavior (verified, `landing.html:8864-8869`).
  void applySummaryTemplate(String template) => setSummary(template);

  void setAchievements(String value) => updateDraft((d) => d.copyWith(achievements: value));

  /// Appends a `LEVEL_COMMON` achievement suggestion as a new line, unless
  /// already present (verified, `landing.html:8612-8613`).
  void appendAchievementSuggestion(String suggestion) {
    updateDraft((d) {
      if (_lineAlreadyPresent(d.achievements, suggestion)) return d;
      return d.copyWith(achievements: _appendLine(d.achievements, suggestion));
    });
  }

  void setLanguages(String value) => updateDraft((d) => d.copyWith(languages: value));

  void setAdditional(String value) => updateDraft((d) => d.copyWith(additional: value));

  void setDeclaration(bool value) => updateDraft((d) => d.copyWith(declaration: value));

  void setPlace(String value) => updateDraft((d) => d.copyWith(place: value));

  void setDeclDate(String value) => updateDraft((d) => d.copyWith(declDate: value));

  /// "Fill [placeholders] from my details" (verified, `landing.html:8906-8916`):
  /// substitutes the known tokens the real builder substitutes, from data
  /// already on the draft — never invents a value it doesn't have.
  void fillPlaceholders() {
    updateDraft((d) {
      var summary = d.summary;
      if (d.years.isNotEmpty) summary = summary.replaceAll('[X]', d.years);
      if (d.domain.isNotEmpty) summary = summary.replaceAll('[industry or domain]', d.domain);
      final topSkills = [
        for (final group in d.skills.groups.values) ...group,
        ...d.skills.suggested,
      ].take(3).join(', ');
      if (topSkills.isNotEmpty) summary = summary.replaceAll('[verified skills]', topSkills);
      final firstDegree = d.education.map((e) => e.degree).firstWhere((v) => v.isNotEmpty, orElse: () => '');
      if (firstDegree.isNotEmpty) summary = summary.replaceAll('[degree / qualification]', firstDegree);
      return d.copyWith(summary: summary);
    });
  }
}
