# Phase 70 — Create Resume Builder Implementation Report

See `docs/PHASE_70_RESUME_BUILDER_PARITY_AUDIT.md` for the full section-by-section parity
matrix and the exact Django source references (`create_resume.py` line numbers,
`create_resume.js` line numbers) this implementation was built against. This report covers
what changed, what was tested, and what was verified live.

## Summary

- 1 gap closed in an existing, previously-"matched" section: `profile_url` added to Personal
  Information.
- 5 new wizard steps added, matching the real site's actual 10-tab structure exactly
  (Projects; Certifications & Training; Achievements & Awards; the combined
  Internships & Volunteering tab; the combined Languages & Additional Information tab) —
  not 7 separate steps, because the website itself combines Internships+Volunteering and
  Languages+Additional into one tab each.
- No backend changes. No new endpoints, fields, or persistence behavior invented — every
  field name sent matches the server's own `ENTRY_FIELDS`/`ADDITIONAL_FIELDS` keys exactly.
- All pre-existing sections, controllers, save/load/guest-draft/error-display behavior
  preserved unchanged and re-verified by the full test suite.

## Flutter files changed

**Modified:**
- `lib/features/resume/domain/entities/create_resume_state.dart` — added `profileUrl` to
  `CreateResumePersonalInfo`; added 7 new entity classes (`CreateResumeProjectEntry`,
  `CreateResumeCertificationEntry`, `CreateResumeAchievementEntry`,
  `CreateResumeInternshipEntry`, `CreateResumeVolunteeringEntry`, `CreateResumeLanguageEntry`,
  `CreateResumeAdditionalInfo`), each with `isBlank`, `copyWith`, `toJson`/`fromJson`; extended
  `CreateResumeFormState` with 7 new fields and rewrote `toRequestJson()`/`fromDraftData()` to
  carry real data for these sections instead of the previous hardcoded-empty placeholders.
- `lib/features/resume/presentation/controllers/create_resume_builder_controller.dart` —
  `kCreateResumeStepLabels` expanded from 5 to 10 entries (matching the site's own tab names,
  including the combined "Internships & Volunteering" and "Languages & Additional Info"
  labels); `kCreateResumeLastStep` changed from 5 to 10; added 19 new
  add/remove/update/updateAdditional methods following the file's existing pattern; extended
  `hasUnsavedContent`.
- `lib/features/resume/presentation/screens/create_resume_builder_screen.dart` — wired the 5
  new step widgets into the wizard's `switch (state.currentStep)` (cases 6–10); made the step
  indicator horizontally scrollable with fixed-width dots (previously `Expanded`-per-dot, which
  would have squeezed 10 labels into illegibility on a phone-width screen — see "Narrow-screen
  verification" below).
- `lib/features/resume/presentation/widgets/create_resume_personal_step.dart` — added the
  `profileUrl` field after `website`, matching the site's own field order.

**New:**
- `lib/features/resume/presentation/widgets/create_resume_projects_step.dart`
- `lib/features/resume/presentation/widgets/create_resume_certifications_step.dart`
- `lib/features/resume/presentation/widgets/create_resume_achievements_step.dart`
- `lib/features/resume/presentation/widgets/create_resume_internships_volunteering_step.dart`
- `lib/features/resume/presentation/widgets/create_resume_languages_additional_step.dart`

All 5 new step widgets reuse the existing shared form widgets
(`ManualResumeTextField`, `ManualResumeEntryCard`, `ManualResumeMonthField`,
`confirmRemoveEntry`) from `manual_resume_form_widgets.dart` — no new widget primitives, no new
dependencies, no competing state-management mechanism. Field-level error display uses the
existing `serverErrors.where((e) => e.field == '$section.$index.$field')` lookup pattern
unchanged — no new client-side validator was introduced, consistent with this feature's
established server-validation-only design.

## Per-section verification

| Section | Fields verified | Required/optional verified | Repeatable behavior verified | Persistence verified |
|---|---|---|---|---|
| Personal (`profile_url`) | ✅ field renders after Website | ✅ optional, matches site | n/a | ✅ round-trips through `toRequestJson`/`fromDraftData` |
| Projects | ✅ all 11 fields, order | ✅ only `title` required | ✅ add/remove/edit tested (unit + widget) | ✅ `toRequestJson` test asserts real data, not hardcoded empty |
| Certifications | ✅ all 9 fields, order | ✅ `name`/`issuer` required | ✅ add/remove/edit tested | ✅ |
| Achievements | ✅ all 6 fields, order | ✅ `title` required | ✅ add/remove/edit tested | ✅ |
| Internships | ✅ all 8 fields, order | ✅ `organization`/`title`/`start_year` required | ✅ add/remove/edit tested, independent of Volunteering list | ✅ |
| Volunteering | ✅ all 7 fields, order | ✅ `organization`/`role` required (no start_year requirement, confirmed different from Internships) | ✅ add/remove/edit tested, independent of Internships list | ✅ |
| Languages | ✅ name + proficiency, inline row (not card) | ✅ **both** fields required-for-completeness | ✅ add/remove tested | ✅ |
| Additional | ✅ all 6 flat fields, exact order/labels | ✅ all optional, flat dict (not a list) | n/a (not repeatable) | ✅ |

## Tests added/updated and results

**`test/features/resume/domain/entities/create_resume_state_test.dart`** — rewrote the one
stale test (`'toRequestJson() sends the not-yet-editable sections as empty, never omitted'`,
which asserted `json['additional']` was an empty map — no longer true now that `additional`
always sends its 6 keys, even when blank) into two tests covering the new real behavior; added
a `fromDraftData()` round-trip test for all 7 new sections; added `isBlank`/`toJson`/`fromJson`
round-trip tests for each of the 7 new entity classes, including the "flag-only fields don't
count as content" check for `current`/`type` where applicable, and Languages'
"requires BOTH name and proficiency" check. **Result: 35/35 passing.**

**`test/features/resume/presentation/controllers/create_resume_builder_controller_test.dart`**
— added one test per new repeatable section's add/remove/update methods, one for
`updateAdditional`, a dedicated test confirming Internships and Volunteering lists are
mutated independently (adding/removing one never touches the other, despite sharing a wizard
step), and extended the `hasUnsavedContent` test to cover all 7 new sections via a
table-driven test. **Result: 37/37 passing.**

**`test/features/resume/presentation/screens/create_resume_builder_screen_test.dart`** — added
a "Phase 70 new resume sections" group covering, against the real rendered widget tree (not
just controller state): every pre-existing step remains reachable alongside the 5 new ones in
the site's own order; each new step renders its real required/optional fields; adding two
Project entries and editing one never overwrites the other; removing one entry preserves the
others; data entered on the Projects step survives navigating to another step and back; the
combined Internships & Volunteering tab renders both sub-sections and adding one never adds to
the other; the combined Languages & Additional Information tab renders the repeatable list and
all 6 flat fields; typing into an Additional Information field updates shared state; saving a
form with Phase 70 section data carries it through the **existing** save path and
`toRequestJson()` with the server's own field names (verified via a fake repository's
`lastSavedState`, not just local widget state — per this phase's explicit instruction never to
claim persistence that only changed local state); and a narrow (320×640, density 1.0)
phone-width viewport shows no layout-overflow exception on the busiest new step. No test
asserts only that a heading exists — each test checks actual field presence, actual data
state, or actual behavior. **Result: 22/22 passing.**

While writing these tests, a real widget-test-environment effect was found and is worth
recording: this builder's step body is a plain `ListView(children: [...])`, which is still
backed by a lazy sliver — widgets scrolled more than one cache-extent past the test viewport
are not mounted until scrolled into view. This is expected, real behavior (identical to how a
short phone screen would need to scroll to reach a button below several open fields) — tests
that tap a since-scrolled-past button now scroll to it first via `scrollUntilVisible`, exactly
as a real user would.

## Full suite results

- `flutter test test/features/resume/domain/entities/create_resume_state_test.dart`: **35/35 passed**
- `flutter test test/features/resume/presentation/controllers/create_resume_builder_controller_test.dart`: **37/37 passed**
- `flutter test test/features/resume/presentation/screens/create_resume_builder_screen_test.dart`: **22/22 passed**
- `flutter test test/features/resume/`: **543/543 passed**
- `flutter test` (complete suite): **2,797/2,797 passed**
- `flutter analyze` (whole project): **No issues found.**

These are the actual results of this session's runs, not the historical 2,750/0 baseline
quoted in prior phases' context.

## Emulator verification

Used the existing Android emulator (`emulator-5554`, Android 14/API 34, 1080×1920 physical,
420dpi ≈ 411×731dp — a standard phone viewport) already running at the start of this phase;
it was not wiped or recreated. Launched the real app (`flutter run -d emulator-5554`), opened
Create Resume as a guest (no login, no OTP, no payment/subscription flow touched), and
navigated every new step live:

- Confirmed all 10 step-indicator dots are present and reachable via the new horizontally
  scrollable indicator, in the real site's order, with the combined tabs' long labels
  ("Internships & V…", "Languages & …") truncating cleanly instead of overflowing.
- Confirmed the Personal step's new "Professional profile URL (optional)" field renders
  immediately after "Website", matching the site's field order.
- Confirmed the Projects step's "Add project" button creates a "Project 1" entry card with
  all fields (title, type dropdown, organisation, start month, ongoing checkbox, etc.);
  confirmed live keyboard text input updates both the field and the entry card's own title
  header in real time.
- Confirmed the combined Internships & Volunteering tab renders both "Internships" and
  "Volunteering" sub-headings with their own independent "Add" buttons and help text, exactly
  as the real site structures it.
- Confirmed the combined Languages & Additional Information tab renders the "Languages"
  heading, "Add language" button, and "Additional information" heading with its first two
  flat fields; tapping "Add language" produces the real site's bespoke inline row (a Language
  text field beside a Proficiency dropdown, with a remove button), not a collapsible card.

No resume data was submitted to the server and no production data was changed — this was
guest-only, local-state verification of the UI, consistent with the task's scope limits.
Narrow-screen behavior (320×640 logical) was verified via the automated widget test above
rather than by reconfiguring the live emulator's density, since the widget test gives a
precise, repeatable overflow check and the task explicitly permits distinguishing automated
verification from live device verification where appropriate.

**Screenshots** (`docs/audit_evidence/phase70/`, all captured at 1080×1920 physical pixels /
~411×731dp on the emulator described above):

| File | What it shows |
|---|---|
| `01_personal_step_overview_1080x1920px.png` | Personal step, first 4 steps of the indicator visible |
| `02_step_indicator_projects_certifications_1080x1920px.png` | Step indicator scrolled to show Projects/Certifications |
| `03_step_indicator_achievements_internships_languages_1080x1920px.png` | Step indicator scrolled to show the remaining 3 new steps |
| `04_personal_step_profile_url_field_1080x1920px.png` | The new "Professional profile URL" field, after Website |
| `05_projects_step_empty_1080x1920px.png` | Projects step, empty state, "Add project" button |
| `06_projects_entry_fields_1080x1920px.png` | "Project 1" entry card with all fields after tapping Add |
| `07_projects_entry_live_input_1080x1920px.png` | Live-typed title updating both the field and the card header |
| `08_internships_volunteering_combined_tab_1080x1920px.png` | Combined tab, both sub-sections, empty state |
| `09_languages_additional_combined_tab_1080x1920px.png` | Combined tab, Languages + first Additional fields |
| `10_languages_entry_row_1080x1920px.png` | A Language entry's inline name+proficiency row |

## Remaining differences from the real website (by design, not oversight)

See the parity audit's "Gaps closed vs. deliberately out of scope" section for the full
reasoning. In summary: no Edit/Done collapse or manual reorder for any repeatable section
(matches the existing Experience/Education steps' own simpler interaction, not a regression);
`order` always sent as `{}` (server already defaults this to `'auto'`); Languages' duplicate-
name check is server-enforced only, matching this feature's no-client-validator design.

## Confirmation of scope discipline

- Only Flutter project files were modified. Both Django reference directories
  (`royalStaffing_CB01`, `Career_Buddy_LMS`) were read-only throughout.
- `git status` confirms the working tree's diff is limited to exactly the files listed above,
  this report, the parity audit, and `docs/audit_evidence/phase70/`'s 10 screenshots — no
  prior-phase modified or untracked files were touched or discarded.
- No auth/OTP/authorization/subscription/payment code was touched. No unrelated navigation,
  employer-login, or registration changes were made.
- No new dependencies were added; no existing shared widget's public behavior was changed in
  a way that could affect other features (only new usages of already-shared widgets).
