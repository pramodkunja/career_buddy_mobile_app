# Phase 45 — Restore Guest Create Resume Drafts Automatically

## 1. Root cause of the missing automatic restoration

Read `docs/PHASE_42_CREATE_RESUME_GUEST_SAVE_REPORT.md`,
`docs/PHASE_43_IT_NONIT_CAREER_BROWSING_REPORT.md`, and
`docs/PHASE_44_BUDDY_OVERLAY_LAYOUT_FIX_REPORT.md` first, then the
existing implementation in full: `create_resume_builder_controller.dart`,
`create_resume_guest_draft_local_datasource.dart`,
`create_resume_guest_draft_repository.dart`/`_impl.dart`,
`create_resume_builder_screen.dart`, and the Phase 42 tests.

Phase 42's own report (§2, "Deliberate scope decision") states the reason
directly: wiring auto-restore into `startBlank()` would have made that
method's state transition asynchronous and auth-dependent, which would
have forced every pre-existing test calling `startBlank()` synchronously
to be restructured for a change unrelated to what those tests actually
test. Phase 42 therefore implemented the full storage round-trip
(`CreateResumeGuestDraftLocalDataSource.getDraft()` and
`CreateResumeGuestDraftRepository.loadDraft()` both already existed,
fully implemented and already unit-tested) but never called `loadDraft()`
from anywhere in the controller or screen — the draft was written and
preserved correctly, just never read back automatically.

**Verified real web behavior** (`royalStaffing_CB01/static/js/create_resume.js:819-831`,
read directly, not assumed):
```js
if (AUTH) {
  loadDrafts().then(...);
} else {
  try {
    var saved = JSON.parse(localStorage.getItem(LOCAL_KEY) || 'null');
    if (saved && saved.personal) { useState(merge(saved)); status('Restored the draft saved on this device. <a href="...">Sign in</a> to save it to your account.', 'ok'); }
    else schedulePreview(true);
  } catch (e) { schedulePreview(true); }
}
```
A guest's page load synchronously reads `localStorage`; if a valid draft
is present it replaces the blank starting state and shows a status
message naming the restoration and offering sign-in. The web's read is
synchronous, so there is no window in which the user could type before it
resolves — a structural difference from this device's `SecureStorageService`
read, which is asynchronous and genuinely can race with user input. This
is the one safety concern the web's own implementation has no equivalent
of, and is addressed explicitly below.

## 2. Implementation approach and how initialization races were prevented

`startBlank()` is **unchanged in signature and behavior** — still
synchronous, still a plain state assignment, called exactly as before. A
new, separate method, `CreateResumeBuilderController.restoreGuestDraftIfAvailable()`,
is called by the screen immediately after `startBlank()` (only on the
"start blank" path, never after `startFromDraft()`), fire-and-forget. This
keeps every one of the many pre-existing tests that call `startBlank()`
directly, synchronously, and assert immediately completely unaffected —
confirmed by running them unmodified (see §5).

`restoreGuestDraftIfAvailable()`:
1. Returns immediately if `_isAuthenticated` (never restores a guest-local
   draft into a signed-in session — matches the explicit "do not silently
   merge a guest-local draft into a server account" instruction).
2. Returns immediately if `hasUnsavedContent` is already true (defends
   against a hypothetical future caller passing a non-blank starting
   form).
3. Calls `CreateResumeGuestDraftRepository.loadDraft()` — purely local
   (`SecureStorageService`), no network request possible.
4. After the `await`, checks `hasUnsavedContent` **again** before applying
   anything — this is the real, mobile-specific race the web's own
   synchronous read never has: if the guest started typing while the read
   was still in flight, the restoration is discarded rather than
   clobbering what they typed. Verified directly with a test that holds
   the fake repository's `loadDraft()` open via a `Completer`, types into
   the form while it's pending, then lets it resolve — the stale
   restoration does not apply (see §5).
5. On `Failed` (a genuine storage/platform exception — corrupt or
   schema-mismatched *data* is already handled one layer down by
   `CreateResumeGuestDraftLocalDataSource.getDraft()`, which returns
   `null` for that rather than throwing), simply leaves the blank form in
   place — never crashes, never leaves the screen stuck loading (the
   screen is already in `CreateResumeBuilderReady` from `startBlank()`
   before this runs at all).

**Duplicate/overlapping-attempt guard**: a private `_guestDraftRestoreClaimed`
flag is claimed synchronously, before the `await`, so two overlapping
calls in the same session can't both proceed. It is reset to `false` by
`startBlank()` (a fresh blank session permits exactly one restore
attempt) and set unconditionally by `startFromDraft()` (an explicitly
opened draft must never be replaced by the guest's local draft).

**Stale-generation guard**: reused this codebase's own existing idiom for
this exact class of problem, found already in use in
`CreateResumePreviewController`/`ManualResumePreviewController`/
`CreateResumePdfController` (`_generation`, incremented in `build()`,
captured before the `await`, compared after it alongside `ref.mounted`) —
their own doc comments explain why `ref.mounted` alone is insufficient: a
plain (non-`autoDispose`) `NotifierProvider` re-runs `build()` on the
*same* instance when invalidated (e.g. logout's
`_invalidateUserScopedProviders()`), so a stale in-flight restoration
could otherwise still write into a logically new session.

A new `restoredFromLocalDraft` boolean on `CreateResumeBuilderReady`
drives a one-time informational banner mirroring the real web's own
message exactly ("Restored the draft saved on this device." + a
"Sign in" button). It needs no explicit clearing: the screen's banner
block checks `saveFailureMessage` → `lastSavedAt` (an actual save) →
`restoredFromLocalDraft`, in that precedence order, so the moment the
guest saves again the normal save-success banner takes over — verified
directly on the emulator (see §7).

## 3. Files changed

| File | Change |
|---|---|
| `lib/features/resume/presentation/controllers/create_resume_builder_controller.dart` | Added `restoredFromLocalDraft` to `CreateResumeBuilderReady`; added `_generation`/`_guestDraftRestoreClaimed` fields; `build()` now increments `_generation`; `startBlank()` resets the claim flag (otherwise unchanged); `startFromDraft()` now claims it immediately; added `restoreGuestDraftIfAvailable()`. |
| `lib/features/resume/presentation/screens/create_resume_builder_screen.dart` | `initState`'s post-frame callback now calls `controller.restoreGuestDraftIfAvailable()` right after `startBlank()` (never after `startFromDraft`); the banner block gained a third, mutually-exclusive branch for the restored-draft message, ordered after the save-success banners. |
| `test/features/resume/presentation/controllers/create_resume_builder_controller_test.dart` | Fake guest-draft repository extended with `loadResult`/`loadCallCount`/a `loadGate` `Completer` for race testing; added a `restoreGuestDraftIfAvailable() — Phase 45` group (10 tests, see §5). |
| `test/features/resume/presentation/screens/create_resume_builder_screen_test.dart` | Fake guest-draft repository extended with `loadResult`; `_pump` extended with a `guestLoadResult` parameter; added a `Phase 45 guest draft restoration` group (5 tests). |

No other file was touched. `CreateResumeGuestDraftLocalDataSource`,
`CreateResumeGuestDraftRepository`/`Impl`, and every other Phase 42 file
are completely unmodified — this phase only wires up calls that already
existed and were already tested.

No file in either Django reference directory was touched (confirmed
again — see §9).

## 4. Restoration behavior by storage state

| Storage state | Behavior |
|---|---|
| Nothing saved yet | `loadDraft()` returns `Success(null)`; the blank form from `startBlank()` is left exactly as is; `restoredFromLocalDraft` stays `false`; no banner. |
| A valid draft saved | The blank form is replaced with the restored one; `restoredFromLocalDraft` becomes `true`; the "Restored the draft saved on this device." banner shows with its Sign in action. |
| Corrupt/schema-mismatched data | Already handled one layer down — `CreateResumeGuestDraftLocalDataSource.getDraft()` returns `null` for this (confirmed by its own existing, unmodified Phase 42 tests), so this behaves identically to "nothing saved yet." |
| A genuine storage/platform read exception | `loadDraft()` returns `Failed(...)`; `restoreGuestDraftIfAvailable()`'s `Failed` branch is a deliberate no-op — the blank, fully usable builder remains exactly as `startBlank()` left it; nothing crashes, nothing is stuck loading. |
| User already typing when the read resolves | The second `hasUnsavedContent` check (after the `await`) discards the (now-stale) restoration; whatever the guest typed is left untouched. |

## 5. Automated tests

**Focused runs, all actually executed:**
```
flutter test test/features/resume/presentation/controllers/create_resume_builder_controller_test.dart
  → 29/29 passing (19 pre-existing + 10 new Phase 45 tests)

flutter test test/features/resume/presentation/screens/create_resume_builder_screen_test.dart
  → 9/9 passing (4 pre-existing Phase 42 + 5 new Phase 45 tests)

flutter test test/features/resume/data/create_resume_guest_draft_local_datasource_test.dart
  → 9/9 passing, unmodified

flutter test test/features/resume/data/create_resume_guest_draft_repository_impl_test.dart
  → 6/6 passing, unmodified

flutter test test/features/resume/ test/shared/widgets/buddy_chatbot_overlay_test.dart \
             test/app/router/route_guards_test.dart test/features/home/.../home_screen_test.dart \
             test/features/mock_tests/.../oop_mastery_mock_test_screen_test.dart
  → 563/563 passing
```

Coverage against the task's own required-scenario list (all in
`create_resume_builder_controller_test.dart`'s new `restoreGuestDraftIfAvailable() — Phase 45`
group unless noted):
- "a guest with no saved draft opens a normal blank builder" ✓
- "a guest with a saved draft has it restored automatically, including
  multiple experience and education entries" — fixture has 2 experience
  + 2 education entries, personal/summary/skills/experience/education all
  asserted field-by-field ✓
- "editing a restored draft and saving again persists the latest values" ✓
- "a malformed/unreadable saved draft does not crash the builder"
  (`Failed` result) ✓
- "restoration does not overwrite text entered before it completes" — the
  `Completer`-gated race test described in §2 ✓
- "repeated restoration attempts in the same session do not restore
  twice" + "a fresh `startBlank()` call permits a new restoration
  attempt" (`loadCallCount` asserted at each step) ✓
- "`startFromDraft()` is never followed by a guest-draft restore" ✓
- "guest restoration makes no server requests" (`_FakeCreateResumeRepository.saveCallCount == 0`) ✓
- "an authenticated session never triggers a guest-draft restore" ✓
- Screen-level: restored banner renders with restored field content, no
  banner when nothing is saved, no banner for an authenticated user,
  Sign-in action navigates to the real login route, saving after a
  restore replaces the restored banner with the normal guest-save banner
  (`create_resume_builder_screen_test.dart`) ✓
- "Existing Phase 42 guest-save tests continue to pass" — all 4
  pre-existing screen tests and all 17 pre-existing controller tests
  (including the 5 Phase 42 guest-path ones) pass with their original,
  unmodified assertions ✓

**Full suite**: **2419 passing, 0 failing** (baseline before this phase:
2404 passing, 0 failing — net +15, exactly accounted for: +10 in the
controller test file (19 pre-existing → 29) and +5 in the screen test
file (4 pre-existing → 9), confirmed against the baseline and this
phase's own focused runs above). No existing test was weakened, deleted,
or had its assertions loosened.

## 6. Analyzer

`flutter analyze`: **8 issues**, identical to the pre-phase baseline (the
same pre-existing `unused_element_parameter` warnings in unrelated test
files). No new issues introduced.

## 7. Emulator verification (actually performed)

### Device

`emulator-5556` (Android 14, API 34, "sdk gphone64 arm64") — the same
device Phase 43/44 used. `/data` had 622MB free this session; the fresh
debug build was installed after uninstalling this app's own stale prior
install (the same non-destructive routine as the previous two phases). No
emulator was wiped, recreated, or had any unrelated app/data removed.

### Interactions actually tested, live, in order

1. Built and installed the fresh debug APK; launched via
   `adb shell am start`; confirmed focus via `dumpsys window`.
2. Opened Create Resume as a guest from the landing page — blank builder,
   no restoration banner (nothing saved yet).
3. Entered personal info (Full name "Jordan Test", Professional title
   "Senior Software Engineer", Email "Jordan.test@example.com"), one
   technical skill ("Flutter"), one experience entry ("Acme Corp" /
   "Software Engineer"), one education entry ("State University" /
   "B.Sc. Computer Science").
4. Tapped Save — the real "Draft saved on this device." confirmation
   banner appeared (the existing Phase 42 behavior, confirmed still
   working).
5. Left the builder (system/in-app back → "Discard changes?" dialog,
   expected since the form has content — tapped Discard, which is safe
   since the draft was already persisted to local storage independently
   of the in-memory form being discarded).
6. Reopened Create Resume — the new "Restored the draft saved on this
   device." banner appeared immediately, with Full name, Professional
   title, and Email all correctly pre-filled. Checked the Skills,
   Experience, and Education steps in turn: the "Flutter" skill chip,
   the "Acme Corp"/"Software Engineer" experience entry, and the "State
   University"/"B.Sc. Computer Science" education entry were all present
   exactly as saved.
7. Edited the Full name field (to "J Updated") and tapped Save again —
   the banner correctly switched from the restored-draft message back to
   the plain "Draft saved on this device." guest-save banner (confirming
   the precedence logic described in §2 live, not just in a widget test).
8. Left and reopened Create Resume once more — the **updated** value
   ("J Updated", not the original "Jordan Test") was what came back,
   confirming the edit-then-resave-then-restore round trip works
   end-to-end on-device.
9. The restored form scrolled normally and all controls (step tabs,
   Previous/Next, Save, text fields) remained fully usable throughout.
10. Checked `adb logcat` across the whole session, filtered for Flutter
    exceptions/fatals: none found; the app's own process (confirmed via
    `pidof`) stayed alive throughout.

### Screenshot directory

`/tmp/cb_phase45_screens/` — files `01_launch.png` through
`32_reopened_after_edit.png`, covering the blank builder, each field
being filled, the initial save, leaving the builder, the restored state
across all 4 populated steps, the edit, the re-save, and the final
restored-with-updated-value state.

## 8. Remaining limitations / unverified behavior

- **A pre-existing, unrelated layout overflow was observed and is
  explicitly not fixed by this phase** (out of scope — "implement only
  guest draft restoration"): on the Personal/Experience steps, when the
  on-screen keyboard is open *and* a PDF-validation-error message is
  showing at the bottom of the screen (e.g. "Please enter your email
  address."), a debug-mode "BOTTOM OVERFLOWED BY N PIXELS" indicator
  appears. This is a layout issue in `CreateResumeBuilderScreen`'s
  existing fixed bottom button/validation-text block versus the
  available height once the keyboard shrinks the viewport — present
  before this phase (this phase added no new always-rendered bottom
  content, and the restored-draft banner is mutually exclusive with and
  positioned above this area). No `FlutterError`/exception was logged for
  it (confirmed via `adb logcat`), and the app did not crash — it is a
  cosmetic, debug-build-only indicator. Documented here for visibility,
  not fixed, per this phase's explicit scope boundary.
- Multiple experience/education entries (plural) were verified via the
  automated controller test's 2-entry fixture, not by adding a second
  entry live on the emulator (one of each was added live, to keep the
  manual session focused — the task's own live-verification steps ask
  for "work experience, and education," not explicitly plural live
  entries, and the automated test already proves the multi-entry restore
  path field-by-field).
- No fabricated production account was used or needed — every live
  interaction was as an unauthenticated guest, exactly as the feature
  requires.

## 9. Confirmation: Phase 42/43/44 and both Django reference projects preserved

- Full suite (2419/2419 passing) includes all pre-existing Phase 42
  guest-save tests (unmodified assertions), all Phase 43 career-browsing
  tests, and all Phase 44 Buddy-overlay tests — all pass unchanged.
- `git status` confirms only the 4 files listed in §3 were changed by
  this phase; every other modified/untracked file in the working tree is
  pre-existing, prior-phase uncommitted work, left exactly as found.
- `find Career_Buddy_LMS royalStaffing_CB01 -newer Mobile_app/pubspec.yaml -type f`
  returned no results — neither read-only Django reference project was
  touched.

## 10. Summary

A guest who saves a Create Resume draft locally now has it restored
automatically — including repeatable work-experience and education
sections — the next time they reopen Create Resume, mirroring the real
web's own verified behavior while adding an explicit, tested safeguard
the web doesn't need (this device's asynchronous storage read can race
with user input; the web's synchronous one cannot). `startBlank()` is
untouched in signature and behavior; restoration is a separate,
idempotent, race-guarded call the screen makes right after it. Editing a
restored draft and saving again persists correctly, verified both in
automated tests and live on an Android emulator across all 5 builder
steps. 2419/2419 tests pass (+15 net, 0 regressions), analyzer is at the
pre-existing 8-issue baseline, and authenticated draft behavior, Phase 43
career browsing, Phase 44 Buddy overlay behavior, and both Django
reference projects are all confirmed unaffected.

**Phase 45 is complete. No further phase has been started.**
