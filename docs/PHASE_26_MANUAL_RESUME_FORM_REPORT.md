# Phase 26 — Manual Resume Builder Form and Validation

## Scope delivered

The real five-step Manual Resume Builder form on top of Phase 25's
foundation: all form fields, repeatable sections (employment, internships,
projects, education, certifications, training), skill selection (role
skill groups, suggested skills, soft skills, free-text "other" skills),
client-side validation faithfully ported from the Django source, and
debounced local autosave. Server preview, page-image preview, and PDF
generation remain out of scope, as instructed.

## Files changed

**New (domain)**
- `lib/features/resume/domain/validation/manual_resume_validation.dart` —
  a line-by-line Dart port of `career_app/resume_document.py`'s
  `validate_state()` and every helper it calls (`length_error`,
  `is_valid_email`, `is_valid_phone`, `is_valid_name`, `is_valid_link`,
  `has_placeholder`, `_month_key`, `_lines`, `valid_jobs`/`valid_projects`/
  `valid_education`/`valid_named`, `role_skill_groups`,
  `relevant_skill_count`). All constants (`MAX_TEXT`, `MAX_ITEMS`,
  `SKILL_MIN`/`MAX`, per-field length rules, phone/email/passport bounds)
  and every error message string were copied verbatim from the Python
  source, including its exact punctuation (en dashes, curly quotes).
- `lib/features/resume/domain/entities/level_common_suggestions.dart` —
  `kManualResumeLevelKeys`/`kManualResumeLevelLabels` and
  `LevelCommonSuggestions` (role-independent soft-skill/achievement
  suggestions per experience level, `resume_roles.py`'s `LEVEL_COMMON`).

**Modified (domain/data) — extending, not replacing, Phase 23's work**
- `lib/features/resume/domain/entities/resume_role.dart` — `ResumeRole`
  gained `fields` (skill groups), `levels` (per-level suggestions),
  `summaries` (editable summary templates), `recommendedSkills`,
  `certifications`, `experienceLabel` — all optional, defaulting to empty,
  so the Role Picker (Phase 22/23) is completely unaffected.
- `lib/features/resume/data/resume_role_parser.dart` — extended to parse
  those new fields from the same `manual_resume_roles` response it already
  fetched (previously discarded); added `parseLevelCommon()`.
- `lib/features/resume/domain/repositories/resume_repository.dart`,
  `resume_remote_datasource.dart`, `resume_repository_impl.dart` — added
  `getLevelCommonSuggestions()`, fetched via a second request to the same
  endpoint `getRoles()` already uses (never changing `getRoles()`'s own
  shape, to keep the Role Picker's existing, tested code path untouched).

**New (presentation)**
- `lib/features/resume/presentation/widgets/manual_resume_form_widgets.dart`
  — shared primitives: `ManualResumeTextField` (blur-tracking, for
  touched-based error display), `ManualResumeCharCounter`,
  `ManualResumeChipGroup` (toggle chips), `ManualResumeSuggestionRow`
  (insert chips), `ManualResumeEntryCard`, `confirmRemoveEntry()`,
  `ManualResumeMonthField` (a compact month+year picker — Flutter has no
  built-in month-only input, unlike the web's native `<input type="month">`).
- `manual_resume_personal_step.dart`, `manual_resume_career_step.dart`,
  `manual_resume_experience_step.dart`, `manual_resume_education_step.dart`,
  `manual_resume_summary_step.dart` — the five real step widgets.
- `manual_resume_builder_controller.dart` — fully rewritten:
  `ManualResumeBuilderReady` now carries the resolved `role`, `levelCommon`
  suggestions, `touched` fields, `showAllErrors`, `saveFailed`, and
  `roleCatalogLoadFailed`, plus computed `errors`/`visibleErrors`. Added a
  field-level mutator for every section (`updatePersonal`, `setLevel`,
  `toggleGroupSkill`, `addCustomGroupSkill`, `addEmployment`/`removeEmployment`/
  `updateEmployment` and the same for internships/projects/education/
  certifications/training, suggestion-chip actions, `setSummary`,
  `applySummaryTemplate`, `appendAchievementSuggestion`, `fillPlaceholders`,
  `setDeclaration`/`setPlace`/`setDeclDate`), a 300ms debounced autosave
  (`updateDraft`), gated `nextStep()`, free `goToStep()`/`previousStep()`,
  `markTouched()`, and `reviewAll()`.
- `manual_resume_builder_screen.dart` — rewritten to host the five real
  steps, a tappable step indicator, a save-failed banner, a degraded-
  suggestions banner with retry, and a "Review Missing Information" action.

**Modified (wiring)** — `resume_providers.dart` (no new providers needed;
existing ones already cover the new controller dependency on
`resumeRepositoryProvider`), `role_picker_screen_test.dart`/
`resume_builder_controller_test.dart`/`resume_builder_screen_test.dart`/
`resume_history_screen_test.dart`/`client_flow_test.dart`/
`auth_controller_test.dart` — each gained the new
`getLevelCommonSuggestions()` method on their local `ResumeRepository`
fakes (an interface addition every implementer must satisfy); none of
their actual test logic changed.

No Django file in either reference tree was touched, and no new backend
endpoint was added — the draft and every edit stay entirely on-device.

## Implemented fields and validation rules

**Step 1 — Personal**: full name (required, 2–80 chars, letters/spaces/
hyphens/apostrophes only), email (required, format-checked), phone
(required, 10–15 digits), location (optional, 2–100 chars once entered),
LinkedIn/portfolio (optional links), date of birth (optional, must be
past), passport (optional, 6–12 alphanumeric, auto-uppercased to match the
server's own normalization).

**Step 2 — Career & Skills**: experience level (required, from the real
`fresher`/`1-3`/`3-5`/`5+` keys), target title (optional, placeholder =
role title), industry/domain and years of experience (shown only once a
non-fresher level is picked, exactly as verified), the role's own skill
groups as toggleable chips plus a free-text "add your own skill" box per
group (2–50 chars, deduped case-insensitively), suggested skills (the
level's own suggestions + the role's recommended skills), professional/
soft skills (role-independent, per level), and a bottom free-text "Other
skills" field — all reusing the Phase 23 role catalog, never a hardcoded
list.

**Step 3 — Experience**: employment/internships/projects, each capped at
15 entries (`kMaxItems`), with month-only start/end pickers, a Current/
Ongoing checkbox that disables (not clears) the end date, a bullets
textarea with a live character counter and a 15-line cap, and suggestion
chips (responsibilities for jobs/internships; project-idea chips that
create a whole new project entry, for freshers). Removing an entry with
any content asks for confirmation first; a blank entry is removed
immediately.

**Step 4 — Education**: education/certifications/training, same
repeatable-entry/remove-confirmation/15-item-cap pattern, with
certification/training suggestion chips sourced from the role's own data.

**Step 5 — Summary**: professional summary with the role's own editable
templates for the selected level (replacing a non-empty summary asks for
confirmation first), a "Fill [placeholders] from my details" button,
achievements with `LEVEL_COMMON` suggestion chips, languages, additional
information, and the declaration (checkbox + place + date — `decl_date`
is never auto-filled with today's date, confirmed directly against the
real builder's own initial state).

**Validation**: every mandatory-field rule, length rule, date-range/
future-date check, partially-filled-entry check, the fresher-vs-experienced
conditional experience requirement, the skill-count and per-skill-length
checks, and the `[placeholder]`-rejection rule are ported from
`validate_state()`. Errors show beside their field only once that field is
blurred (`touched`) or "Review Missing Information" is used (`showAllErrors`)
— matching the real builder's own behavior exactly, not a simplification.
"Next" is the only gated transition (blocked by the *current* step's own
errors); the step tabs and "Previous" always navigate freely, exactly as
verified. Nothing is silently cleared: every field keeps exactly what the
candidate typed, valid or not.

## Source behavior that could not be fully reproduced or verified

- **Email validation**: the regex check is reproduced exactly, but
  Django's `validate_email()` (also called server-side) has additional
  checks (per-label length, domain-literal/punycode handling) not
  replicated here — a client-side approximation, explicitly never claimed
  as a full match, consistent with the task's own "never describe
  client-side validation as server verification" instruction.
- **Unicode name matching**: Python's `[^\W\d_]` (any Unicode "word"
  character that isn't a digit or underscore) is approximated with Dart's
  `\p{L}` (Unicode letters). Practically identical for the vast majority of
  real names; may diverge on some combining-mark edge cases.
- **`_lines()`'s pre-cleaning step**: the server's own `_lines()` first
  runs the submitted text through `_clean()` (NFC normalization, control-
  character stripping, whitespace collapsing) before splitting into
  bullet lines; this port splits/trims/dedupes the lines directly without
  that NFC/whitespace-collapse pre-pass. Practically identical for normal
  typed input; could diverge on exotic Unicode whitespace.
- **The exact JS behavior for re-tapping an already-inserted suggestion
  chip**: the real builder styles a used chip with a `.used` class but the
  underlying click handler's behavior on a second tap wasn't independently
  confirmed beyond that styling. This implementation treats re-tapping as
  a safe no-op (never inserts a visible duplicate line) — the conservative
  interpretation, not a guess presented as verified fact.
- **The completeness/progress meter** (`#rbComp`, the top percentage bar
  with per-category jump buttons) was not implemented — it is not part of
  this phase's explicit field/validation/persistence scope, and omitting
  it does not affect correctness of the form or its validation.
- **Visual fidelity** (exact spacing, the amber `.rb-hl` flash animation
  when jumping to an error, the floating validation-summary panel's exact
  styling): approximated with this app's existing design system
  (`AppColors`/`AppSpacing`) rather than pixel-matched to the web's CSS,
  per the task's "use the existing application's design system" instruction.

## Tests executed and actual results

- `flutter analyze` (whole project): **No issues found**, except two
  harmless `unused_element_parameter` info-level warnings on an unused
  optional fake-repository parameter in two test files — not an error, not
  a behavior concern.
- `flutter test test/features/resume/ test/features/auth/ test/app/client_flow_test.dart`
  — **320 passed, 0 failed.**
- `flutter test` (full suite) — **2147 passed, 0 failed** (up from 2054
  before this phase; no existing test was weakened, skipped, or deleted).

New/updated test files:
- `test/features/resume/domain/validation/manual_resume_validation_test.dart`
  (62 tests) — every validation category required by the task: required
  vs. optional fields, valid/invalid email/phone/name/link/passport/dob,
  role/level/years requiredness, skill-count and per-skill-length rules,
  partially-filled employment/internship/project/education/certification/
  training entries, date-range and future-date checks (including the
  current/ongoing exemption), the fresher-vs-experienced conditional
  experience requirement (all 6 sub-cases), length rules (including the
  15-bullet cap), and `[placeholder]` rejection across summary/
  achievements/bullets.
- `test/features/resume/presentation/controllers/manual_resume_builder_controller_test.dart`
  (33 tests) — load/restore/role-catalog-resolution/role-catalog-failure-
  degrades-gracefully, free vs. gated step navigation (including the exact
  blocked-fields-become-touched behavior), `setRoleIfBlank`'s
  never-overwrite rule, debounced autosave (immediate state update,
  elapsed-debounce persistence, rapid-edit coalescing into one save), save
  failure surfacing and its optimistic-clear-on-next-edit behavior, skill
  toggle/custom-add/dedup, repeatable-entry add/remove/max-item-cap/
  targeted-update, suggestion-chip actions (project/bullet/achievement,
  including the no-duplicate-line guarantee), `fillPlaceholders`,
  `markTouched`/`reviewAll`, and `clearDraft` (including that it cancels a
  pending debounced save so it can never resurrect the cleared draft).
- `test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart`
  (17 tests) — real field presence on every step, Next gating (blocked on
  an invalid step, advances once valid), free Previous/step-indicator
  navigation, the selected role and its skill groups rendering on Career &
  Skills, a skill chip's selected state surviving a step round-trip,
  Experience add/remove with and without the confirmation dialog,
  Education step fields, Summary template application, Clear Draft
  confirm/cancel, a load failure's retryable error state, and no
  horizontal overflow at 320px for every one of the five steps.
- Regression coverage (all still passing, unchanged logic): Phase 19's
  resume-analysis quota counter and the full Resume Parsing & Interview
  upload/result flow (`resume_builder_controller_test.dart`,
  `resume_builder_screen_test.dart`), Phase 23's Role-Fit Picker
  (`role_picker_screen_test.dart`, including its own narrow-width and
  Resume-Parsing-confirm/cancel/error tests), `resume_history_screen_test.dart`,
  the end-to-end `client_flow_test.dart` journeys, and every existing
  `auth_controller_test.dart` cross-account-invalidation test.

### Two real bugs found and fixed during testing

1. **`setOtherSkillsText` never deduplicated** — the server's own
   `_list()` dedupes case-insensitively; the first implementation only
   split/trimmed. Caught by its own new test, fixed before being shipped.
2. **`ManualResumeMonthField`'s two `DropdownButtonFormField`s overflowed**
   inside their constrained `Row` at normal and narrow phone widths — a
   genuine, user-visible layout bug (Flutter's dropdown sizes to its
   widest menu item unless told otherwise). Fixed with `isExpanded: true`
   on both, confirmed by the Experience-step narrow-width test.

### A test-infrastructure lesson (not a product bug)

Several widget tests initially failed with "A Timer is still pending even
after the widget tree was disposed." The debounced-autosave `Timer` lives
inside the same `FakeAsync` zone the widget test itself runs in;
`tester.runAsync()` (used correctly elsewhere in this codebase to let a
real, zone-independent `Future` resolve) does **not** advance that zone's
own clock, so it never fires a pending `Timer` created inside it.
`tester.pump(duration)` — which genuinely advances the fake clock — is the
correct way to let the debounce elapse inside a widget test; applied
consistently afterward.

## Draft persistence and account isolation

Unchanged from Phase 25's design and verification — the new field-level
mutators (`updateDraft`) funnel through the same `saveDraft`/`loadDraft`/
`clearDraft` calls, username-namespaced at rest and invalidated in-memory
on logout via `AuthController._invalidateUserScopedProviders()` (already
listing `manualResumeBuilderControllerProvider`, confirmed by the existing
Phase 25 test, re-verified passing this phase with the richer state shape).
New this phase: a failed debounced save sets
`ManualResumeBuilderReady.saveFailed = true`, shown to the candidate as an
inline banner rather than silently discarded, and is optimistically
cleared the moment the candidate makes another edit (so a stale failure
banner never lingers past a successful subsequent save).

## Emulator/device testing status

**Not performed.** As found and disclosed in Phase 24 and again in Phase
25, this environment has no Android emulator or connected device
(`flutter devices` lists only macOS/Chrome; no `adb`). All verification in
this phase is `flutter analyze` and `flutter test` (unit + widget tests
using Flutter's test binding), not an on-device run. No claim of on-device
testing is made.

## Django trees — untouched

- `royalStaffing_CB01/` is not a git repository; confirmed via file
  modification timestamps (`stat`) on every source file read this phase
  (`resume_document.py`, `manual_resume_views.py`, `resume_roles.py`) —
  all show their pre-existing Oct 10 timestamp, unchanged by today's reads.
- `Career_Buddy_LMS/` (git): `git status --short` shows the same
  pre-existing modifications already disclosed in the Phase 25 report
  (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`)
  and pre-existing untracked files, plus one additional untracked file
  (`activities/tests_mcq_exercise_api.py`) that appeared sometime after
  Phase 25 — **none of these were touched by this phase**, which never ran
  any command inside `Career_Buddy_LMS/` at all. All are the user's own
  pre-existing, uncommitted work from outside this phase's scope, left
  exactly as found.

## Git status (Mobile_app)

```
 M lib/app/router/app_router.dart
 M lib/app/router/route_paths.dart
 M lib/features/auth/presentation/controllers/auth_controller.dart
 M lib/features/resume/data/resume_remote_datasource.dart
 M lib/features/resume/data/resume_repository_impl.dart
 M lib/features/resume/data/resume_role_parser.dart
 M lib/features/resume/domain/entities/resume_role.dart
 M lib/features/resume/domain/repositories/resume_repository.dart
 M lib/features/resume/presentation/providers/resume_providers.dart
 M lib/features/resume/presentation/screens/role_picker_screen.dart
 M test/app/client_flow_test.dart
 M test/features/auth/auth_controller_test.dart
 M test/features/resume/presentation/controllers/resume_builder_controller_test.dart
 M test/features/resume/presentation/screens/resume_builder_screen_test.dart
 M test/features/resume/presentation/screens/resume_history_screen_test.dart
 M test/features/resume/presentation/screens/role_picker_screen_test.dart
?? docs/PHASE_24_MANUAL_RESUME_BUILDER_AUDIT.md          (pre-existing, from Phase 24)
?? docs/PHASE_25_MANUAL_RESUME_FOUNDATION_REPORT.md      (pre-existing, from Phase 25)
?? lib/features/resume/data/manual_resume_draft_local_datasource.dart       (Phase 25)
?? lib/features/resume/data/manual_resume_draft_repository_impl.dart        (Phase 25)
?? lib/features/resume/domain/entities/level_common_suggestions.dart       (new, Phase 26)
?? lib/features/resume/domain/entities/manual_resume_draft.dart            (Phase 25)
?? lib/features/resume/domain/repositories/manual_resume_draft_repository.dart (Phase 25)
?? lib/features/resume/domain/validation/                                  (new, Phase 26)
?? lib/features/resume/presentation/controllers/manual_resume_builder_controller.dart (Phase 25, rewritten Phase 26)
?? lib/features/resume/presentation/screens/manual_resume_builder_screen.dart (Phase 25, rewritten Phase 26)
?? lib/features/resume/presentation/widgets/manual_resume_*.dart            (new, Phase 26)
?? test/features/resume/data/manual_resume_draft_local_datasource_test.dart (Phase 25)
?? test/features/resume/data/manual_resume_draft_repository_impl_test.dart  (Phase 25)
?? test/features/resume/domain/                                            (new, Phase 26)
?? test/features/resume/presentation/controllers/manual_resume_builder_controller_test.dart (Phase 25, rewritten Phase 26)
?? test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart (Phase 25, rewritten Phase 26)
```

No pre-existing uncommitted work in `Mobile_app/` was lost or altered —
the only pre-existing items in the tree (the Phase 24/25 docs) remain
exactly as they were.

---

**Stopping here, as instructed.** No work on server preview, page-image
preview, or PDF generation has been started. Awaiting explicit approval
before proceeding.
