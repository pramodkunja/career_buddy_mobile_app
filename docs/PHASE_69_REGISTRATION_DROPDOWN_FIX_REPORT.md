# Phase 69 — Registration Dropdown Overflow Fix

**Date:** 2026-10-28
**Scope:** the single `RenderFlex` overflow bug in `RegisterScreen`'s dropdown fields, discovered (and deliberately left unfixed) during Phase 68. No other screen or roadmap item was touched.

## Confirmed root cause and reproduction

**Reproduced before making any change**, via a scratch widget test pumping the real `RegisterScreen` at a 400-logical-pixel width (the same width Phase 68's own test used): exactly **3 distinct `RenderFlex` overflow exceptions** fired on the very first frame, each pointing at `register_screen.dart:590:12` — the `DropdownButtonFormField<String>` built by the shared `_dropdown()` helper. Overflow amounts: 65px, 65px, and 162px.

**Exact cause confirmed by reading `_dropdown()`** (`register_screen.dart`, pre-fix lines 584-599): it builds a `DropdownButtonFormField<String>` with no `isExpanded: true`. Flutter's default (`isExpanded: false`) sizes the closed button to the width of its single widest `DropdownMenuItem` among **every** option in the list — not just the selected one — which can exceed the field's actual available width once the field's own decoration/padding is accounted for. This is a standard, well-documented Flutter pitfall, exactly as the Phase 68 report predicted.

**Which option lists actually trigger it, confirmed by inspecting `kGenderOptions`/`kBloodGroupOptions`/`kEducationLevelOptions`/`kIndustryOptions`** (`lib/features/auth/domain/entities/student_registration_data.dart:135-184`) and cross-checking against the 3 reproduced exceptions:
- `kEducationLevelOptions`'s longest label, `"Under-Graduate / Degree"` (23 chars) — overflows at 65px. Used by **both** "Select Highest Education" and "Select Additional Education" (two separate call sites, same option list) — accounts for the two 65px overflows.
- `kIndustryOptions`'s longest label, `"Agriculture & Food Processing"` (30 chars) — overflows at 162px. Used by the single "Select Industry" call site.
- `kGenderOptions`'s longest label, `"Prefer not to say"` (18 chars), and `kBloodGroupOptions` (all 2-3 chars) do **not** overflow at this width — confirmed by the exception count being exactly 3, not 5.

All 3 overflowing fields share the exact same helper and root cause; no dropdown built outside `_dropdown()` (`_yearDropdown`, `_yesNoDropdown` — both short, fixed-content option lists: 4-digit years, "Yes"/"No") showed any overflow, confirmed by the same reproduction run, so neither was modified.

## Fix applied

**File changed:** `lib/features/auth/presentation/screens/register_screen.dart` — `_dropdown()` only. No other helper, call site, option list, or screen was touched.

```dart
return DropdownButtonFormField<String>(
  initialValue: value.isEmpty ? null : value,
  isExpanded: true,
  decoration: InputDecoration(labelText: hint, isDense: true),
  items: [
    for (final o in options)
      DropdownMenuItem(
        value: o.value,
        child: Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
  ],
  onChanged: (v) => onChanged(v ?? ''),
);
```

Two changes, both minimal:
1. **`isExpanded: true`** — the primary fix. Makes the closed button (and, since the popup menu's width is derived from the button's own render box, the opened menu too) fill the field's actual available width instead of sizing to the widest possible item.
2. **`maxLines: 1` + `overflow: TextOverflow.ellipsis`** on each item's `Text` — the companion fix the task's own "important distinction" called out: `isExpanded` alone only guarantees the *button* fits its parent; without a line/overflow limit, a label still too long for the available width would wrap instead of overflow horizontally, which would just move the same problem to a fixed-height row (both the closed selection display and each opened menu row reuse this same `Text`). With real option lengths (max 30 characters) at the narrowest tested width (320px), ellipsis never actually triggers in practice — it is a safety bound, not a behavior change for any current label.

No label text was shortened, renamed, or replaced. No dropdown items, selected values, hints, validators, requiredness, or `onChanged` callbacks were changed.

## Regression tests added/updated

**File:** `test/features/auth/presentation/screens/register_screen_test.dart` (rewritten; the file Phase 68 created).

**The Phase 68 exception-draining workaround was removed entirely**, not narrowed — it's no longer needed now that the root cause is fixed. Every test in the file now asserts `tester.takeException()` is `null` directly after the relevant pump/interaction, so a real regression would fail the test loudly instead of being absorbed.

New/changed coverage, matching the task's checklist:
1. **Renders at 400/360/320-logical-pixel widths with no layout exceptions** — 3 separate tests, each a direct, un-drained assertion (the 400px and 360px cases are exactly the widths that threw before this fix; 320px is an additional, narrower check).
2. **All 5 dropdown fields remain present** — `Select Gender`, `Select Blood Group`, `Select Highest Education`, `Select Additional Education`, `Select Industry`, found by widget type + label text.
3. **Long dropdown labels fit within the closed field** — checked two ways: no exception at 360px (behavioral), and directly reading the real, internal `DropdownButton<String>` widget's own `isExpanded` field for both the Education and Industry dropdowns (`DropdownButtonFormField` delegates to a `DropdownButton._formField` internally, which is where `isExpanded` actually lives — confirmed by reading the Flutter SDK source, since `DropdownButtonFormField` itself exposes no such getter).
4. **Opening a dropdown and selecting an option still works** — 3 tests: opening "Select Highest Education" and selecting its longest label ("Under-Graduate / Degree"), opening "Select Industry" and selecting its longest label ("Agriculture & Food Processing"), and opening "Select Gender" and selecting a short label ("Female") to confirm the fix didn't regress the simple case. Each confirms the popup actually shows the full label text and that the closed field reflects the selection afterward.
5. **Existing selected values and callbacks behave correctly** — covered by the same 3 selection tests above (the `onChanged` → `setState` → closed-field-display round trip is exactly what each test observes).
6. **Usable at another narrow viewport (320px)** — its own dedicated test, per point 1.
7. **The Phase 68 registration header remains correct** — the original `RegisterHeader` isolated tests are kept unchanged (icon, heading, subtitle, 320px no-overflow).
8. **Existing fields/validation/navigation unaffected** — kept the "existing form fields are still present" test, the AppBar-title-not-duplicated test, and added a new test confirming the required-field validator (`Validators.required`, "This field is required.") still fires correctly on an empty submit — exercising the exact same `_formKey.currentState!.validate()` path untouched by this phase.

## Test results (actually executed)

```
$ flutter test test/features/auth/presentation/screens/register_screen_test.dart
...
All tests passed! (13 tests)
```

```
$ flutter test test/features/auth/
...
All tests passed! (111 tests)
```

### Full test-suite results

```
$ flutter test
...
All tests passed!
```
**2,750 tests passed, 0 failed** (up from 2,741 at the end of Phase 68 — net +9 from this phase's rewritten test file: 13 tests now vs. the prior 4). Actually executed this session in full, not assumed from the historical 2,741 baseline the task brief cited.

### Analyzer result

```
$ flutter analyze
Analyzing Mobile_app...
No issues found!
```
Run after the source change and again at the end — clean throughout.

## Emulator verification (actually performed)

The emulator from prior phases was not running at session start (no Android process was found). Per the task's instruction to use the existing emulator rather than wipe or recreate one, the existing `Android_Emulator_34` AVD (already configured from prior phases, confirmed via `emulator -list-avds`) was simply **started** — not recreated, not wiped, no data cleared.

Rebuilt and launched the debug app, then live-verified on-device (screenshots in `docs/audit_evidence/phase69/`):
- **Closed fields**: scrolled to the Education and Industry dropdowns — both render correctly with no horizontal overflow, no clipped text, and the dropdown chevron icon correctly positioned at the field's right edge (`01_before_closed_fields_industry_education.png`).
- **Opened menu with a long label**: tapped "Select Industry" — the popup menu renders at the full field width, showing every option on one line each, including the two longest real labels, "Finance, Banking & Insurance" and "Agriculture & Food Processing", with no wrapping or clipping (`02_opened_industry_menu_long_labels.png`).
- **Selection works and fits**: tapped "Agriculture & Food Processing" — the closed field now displays the full selected label with no overflow and the chevron icon still correctly placed (`03_after_selected_longest_label_no_overflow.png`).
- **Scrolling**: the form scrolled normally before, during, and after this interaction.

No registration form was submitted; no OTP flow was triggered; no network request was made. All interaction was navigation, opening a dropdown, and selecting a value — purely a layout-fix verification.

## Remaining layout problems or limitations

None identified for this specific fix. The ellipsis safeguard means even a future, longer option label added to any of these lists would degrade gracefully (truncated with "…") rather than overflow — though that is a defensive bound, not something exercised by any current real option text.

## Confirmation: registration behavior preserved

- Every dropdown's options, order, values, and labels are byte-identical to before this phase.
- `onChanged` callbacks (`(v) => setState(() => _gender = v)` etc.) are unchanged — confirmed by the selection tests actually observing the closed field update after a tap.
- Validators, requiredness, the OTP email-verification gate, resume-upload gate, and the final `StudentRegistrationData`/`register()` submission path in `_submit()` were not touched at all.
- No backend API, Django template, or registration business rule was inspected for changes or modified — this was a pure Flutter-side layout fix, with the root cause and affected fields identified entirely from Flutter source and widget-test reproduction.

## Unrelated work deliberately left untouched

- All Phases 52-68 work (employer job-posting validation, Phase 66's sign-in/department-split/custom-skill fixes, Phase 67's subscription/role-picker/nav-drawer fixes, Phase 68's auth-screen banners/logo/header) — untouched; `git status --short` at the end of this phase shows only `register_screen.dart` and `register_screen_test.dart` changed, plus this report and its 3 screenshots.
- `_yearDropdown` and `_yesNoDropdown` — inspected, confirmed not affected, left unmodified.
- No other Phase 67/68 audit finding (Employer Login banner follow-ups, Create Resume's missing sections, the rest of the nav-drawer gap, Subscription's remaining cosmetic items, Employer screens' visual layout, Skill-Up WebView fullscreen, etc.) was started.
