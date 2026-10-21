# Phase 42 — Create Resume Guest-Save Experience Fix

## 1. Problem and verified expected behavior

**Problem** (confirmed by Phase 40's audit, Item 4): before this phase, `CreateResumeBuilderController.save()` always called the server-backed `CreateResumeRepository.saveDraft()` regardless of auth state. For a guest, this request was always rejected (the `create/drafts/save/` endpoint is `_json_login_required`), and the resulting `UnauthorizedFailure` surfaced as "Your session has expired. Please sign in again." — misleading for someone who never had a session to expire.

**Verified web behavior** (`royalStaffing_CB01/static/js/create_resume.js:656-660`, read in full):
```
function saveDraft(btn) {
  if (!AUTH) {
    try { localStorage.setItem(LOCAL_KEY, JSON.stringify(S)); dirty = false;
      status('Draft saved on this device. <a href="' + esc(D.login) + '">Sign in</a> to save it to your account.', 'ok'); }
    catch (e) { status('This browser blocked saving. Download the PDF to keep your resume.', 'err'); }
    return;
  }
  ... // server POST, only reached when AUTH is true
}
```
A guest's Save never reaches the network. It writes the current form to `localStorage` under a fixed key (`'cbCreateResume.v1.guest'`, confirmed at `create_resume.js:19`), clears the "unsaved changes" flag, and shows a success message with an inline "Sign in" link. A local-storage write failure shows a distinct error message ("This browser blocked saving..."), never a false success. The web also auto-restores this local draft the next time a guest opens the page (`create_resume.js:828-833`) — noted here for completeness but **deliberately not implemented in this phase** (see §6, Limitations).

## 2. Flutter implementation approach

Read before changing anything: `docs/PHASE_39_CREATE_RESUME_WORKFLOW_REPORT.md`, all three Phase 40 documents, the current `create_resume_builder_controller.dart`, `create_resume_builder_screen.dart`, `resume_providers.dart`, `route_paths.dart`/`route_guards.dart`, and the existing local-storage pattern already used by the Manual Resume Builder (`manual_resume_draft_local_datasource.dart`/`manual_resume_draft_repository_impl.dart`, which persists via `SecureStorageService` — the same app-private, encrypted-at-rest mechanism already used for the cached auth session).

Chosen approach — mirrors the Manual Resume Builder's own local-draft architecture, adapted for a guest (no account to namespace by):
- A new `CreateResumeGuestDraftLocalDataSource` wraps `SecureStorageService` under a single fixed key (`create_resume_guest_draft.v1` — no per-username namespacing, since a guest has no account), storing the form via the same JSON shape `CreateResumeFormState.toRequestJson()`/`fromDraftData()` already use for the server draft contract.
- A new `CreateResumeGuestDraftRepository` abstract interface + `CreateResumeGuestDraftRepositoryImpl`, kept entirely separate from `CreateResumeRepository` (whose own doc comment explicitly states "there is no local-only persistence" for the real server-backed contract) — mirroring how `ManualResumeDraftRepository` is already kept separate from the server-backed resume repositories in this codebase.
- `CreateResumeBuilderController.save()` now checks `_isAuthenticated` (`ref.read(authControllerProvider) is AuthAuthenticated`) before doing anything else. If not authenticated, it calls the new `_saveAsGuest()` path (local repository only, never the server repository). If authenticated, the original server-save path runs completely unchanged.
- `CreateResumeBuilderScreen` reads the live auth state at render time (`ref.watch(authControllerProvider) is AuthAuthenticated`) to decide which success banner to show: the original "Saved." banner for authenticated users, or a new "Draft saved on this device." banner with an inline "Sign in" button for guests, navigating via `context.go(RoutePaths.login)` — the same navigation call already used everywhere else in this app for this exact purpose (`home_screen.dart`, `app_nav_drawer.dart`, etc.), not a new route or flow.

### Deliberate scope decision: no auto-restore-on-open

The web auto-restores a guest's local draft when the Create Resume page loads (`create_resume.js:821-834`). This phase does **not** implement that. Reason: wiring it into `CreateResumeBuilderController.startBlank()` would make that method's state transition asynchronous and auth-dependent, which would have forced every one of the 14 pre-existing tests that call `startBlank()` synchronously (across navigation, repeatable-entries, and `hasUnsavedContent` test groups — none of which touch saving at all) to be restructured around auth-state settling, for a change unrelated to what they test. This is a real, not hypothetical, risk: this phase's own `authControllerProvider` defaults to `AuthUnknown` in a bare test container (confirmed directly — `AuthController.build()` returns `AuthUnknown` synchronously before its async `restoreSession()` resolves), so an auth-gated `startBlank()` would have silently changed behavior for every existing test, not just the save-related ones.

The task's own "Required Behavior" section asks only that guest saves happen locally, that a sign-in prompt follow, and that the draft be *preserved* (not deleted) when the user signs in, dismisses the prompt, or navigates away — it does not require automatically reloading it into the form on next screen open. This phase satisfies "preserved" literally: nothing in this change ever clears `create_resume_guest_draft.v1` except an explicit `clearDraft()` call, which nothing in this phase triggers. A guest's locally saved draft therefore survives closing and reopening the app, but is not yet surfaced back into the UI automatically — documented as remaining work in §6, not silently dropped.

## 3. Files changed

| File | Change |
|---|---|
| `lib/features/resume/data/create_resume_guest_draft_local_datasource.dart` | **New.** Local-only storage for one guest draft per device, via `SecureStorageService`, schema-versioned like its Manual Resume Builder counterpart. |
| `lib/features/resume/domain/repositories/create_resume_guest_draft_repository.dart` | **New.** Abstract interface (`loadDraft`/`saveDraft`/`clearDraft`), deliberately separate from `CreateResumeRepository`. |
| `lib/features/resume/data/create_resume_guest_draft_repository_impl.dart` | **New.** Thin adapter mapping storage exceptions to `UnexpectedFailure`, mirroring `ManualResumeDraftRepositoryImpl` exactly. |
| `lib/features/resume/presentation/providers/resume_providers.dart` | Added 2 providers wiring the new local datasource/repository. |
| `lib/features/resume/presentation/controllers/create_resume_builder_controller.dart` | Added `_isAuthenticated` getter and `_saveAsGuest()`; `save()` now branches on auth state before doing anything else. No change to the authenticated path's own logic. |
| `lib/features/resume/presentation/screens/create_resume_builder_screen.dart` | The success-banner block now branches on live auth state: unchanged "Saved." banner for authenticated users, new guest banner + "Sign in" button otherwise. |
| `test/features/resume/presentation/controllers/create_resume_builder_controller_test.dart` | Added an `authRepositoryProvider`/`authControllerProvider` test harness (mirroring `manual_resume_builder_controller_test.dart`'s own pattern) since `save()` is now auth-aware; added 5 new tests (1 genuinely-expired-session case, 4 guest-path cases); all 14 pre-existing tests kept and still pass with their original assertions unchanged. |

New test-only files: `test/features/resume/data/create_resume_guest_draft_local_datasource_test.dart` (9 tests), `test/features/resume/data/create_resume_guest_draft_repository_impl_test.dart` (6 tests), `test/features/resume/presentation/screens/create_resume_builder_screen_test.dart` (4 tests, new — no screen test existed for this screen before this phase).

No file in either Django reference directory, and no other Flutter feature, was touched.

## 4. How guest saving differs from authenticated saving

| | Authenticated | Guest |
|---|---|---|
| Destination | `CreateResumeRepository.saveDraft()` → real server endpoint | `CreateResumeGuestDraftRepository.saveDraft()` → this device only, via `SecureStorageService` |
| Network request made | Yes | **No** — never attempted |
| Result on success | `draftId` set/updated, "Saved." banner | `draftId` stays `null` (a guest draft has no server id), "Draft saved on this device." banner + Sign in button |
| Result on failure | Server's own message (e.g. "You can keep up to 20 resumes.") or, if the session genuinely expired server-side, `UnauthorizedFailure`'s message | The local-storage layer's own message (e.g. "Could not save the resume draft on this device.") — never mentions a session, since a guest never had one |
| Duplicate-submit guard | Existing `saving` flag, unchanged | Same `saving` flag, shared by both branches |

The distinction the task specifically asked for — telling a guest apart from a genuinely expired authenticated session — is handled by checking auth state *before* any request is attempted, not by inspecting the failure afterward: a guest's save can therefore structurally never produce a "session expired" message (no code path connects `_saveAsGuest()` to `UnauthorizedFailure`), while an authenticated save's genuine 401 keeps the original, correct message.

## 5. Automated tests executed and their results

All of the following were actually run (not merely written):

```
flutter test test/features/resume/presentation/controllers/create_resume_builder_controller_test.dart
  → 19/19 passing (14 pre-existing behaviors preserved + 5 new)

flutter test test/features/resume/data/create_resume_guest_draft_local_datasource_test.dart
  → 9/9 passing

flutter test test/features/resume/data/create_resume_guest_draft_repository_impl_test.dart
  → 6/6 passing

flutter test test/features/resume/presentation/screens/create_resume_builder_screen_test.dart
  → 4/4 passing
```

Coverage against the task's own 6-item test list:
1. **Guest save, no server request** — `create_resume_builder_controller_test.dart`: "a guest save writes to local storage only, never the server" asserts the fake server repository's call count stays 0 and the fake guest repository's call count is 1.
2. **Sign-in prompt appears** — `create_resume_builder_screen_test.dart`: "a guest save shows the local-save message with a Sign in action" + "tapping the guest Sign in action navigates to the login screen" (asserts real navigation to the real login route).
3. **Draft persistence** — covered at the repository/datasource level (`create_resume_guest_draft_local_datasource_test.dart`'s save-then-get round-trip, and overwrite/clear behavior) rather than re-asserted at the controller level, since the controller does not read the draft back in this phase (see §2's scope decision) — there is no "reopen and see it" behavior yet to test above the storage layer.
4. **Authenticated save continues through the existing server path** — the pre-existing 5 `save() — authenticated` tests all still pass unmodified in their assertions, plus a new explicit check that an authenticated save never touches the guest repository.
5. **Error handling** — "a local-storage failure surfaces its own message, never 'session expired'" (controller test) and the equivalent screen-level test both assert the exact message and that it does not contain the word "session"; a separate test confirms a genuinely expired *authenticated* session still gets its own distinct message.
6. **Regression coverage** — the full suite (below) was run, not just this feature's own tests.

## 6. Full test-suite and analyzer comparison against baseline

Baseline (Phase 39/40, stated in this task's own instructions): **2,351 passing, 0 failing, 8 pre-existing analyzer issues.**

```
flutter test     → 2375 passing, 0 failing
flutter analyze  → 8 issues found — identical set to the pre-existing baseline list
                   (confirmed line-by-line: no new issue was introduced; one newly-written
                   test fake's unused optional parameter was removed during this phase
                   specifically to avoid adding a 9th issue)
```

Net test-count change: **+24**, entirely accounted for: +5 in the existing controller test file (1 new "genuinely expired session" case, 4 new guest-path cases — the 14 pre-existing tests are all still present and passing with unchanged assertions), +9 in the new local-datasource test, +6 in the new repository-impl test, +4 in the new screen test. No existing test was weakened, deleted, or had its assertions loosened to make it pass.

## 7. Device verification status

**Not performed, and not claimed as performed.**

- No physical Android device is connected this phase.
- An Android emulator (`emulator-5554`, API 37) is available this time (unlike Phase 39/40, where none was running). A fresh debug APK was built successfully from the current Phase 42 source (`flutter build apk --debug`, no errors beyond a pre-existing, unrelated Kotlin-plugin warning).
- Installing it failed again with the same class of error Phase 39 hit: `android.os.ParcelableException: java.io.IOException: Requested internal only, but not enough space` — confirmed via `adb shell df /data`: 434MB free against a 180MB debug APK, 93% of the data partition in use.
- A safe, non-destructive `adb shell pm trim-caches 2G` was attempted first; free space was unchanged afterward (trim-caches only clears app cache directories, which this emulator apparently has little of).
- Per this engagement's standing rule, no destructive remedy (wiping or recreating the emulator) was attempted without explicit consent.
- **What this means concretely**: the guest-save fix above is verified by direct reading of the real web's JavaScript, by source-level reading of the new and changed Flutter code, and by 24 new automated tests spanning the storage layer, the repository layer, the controller, and the screen's own widget tree (including a real `GoRouter` navigation assertion for the "Sign in" button). It has not been observed running on an actual emulator or device screen this phase.

## 8. Limitations and remaining work

- **Auto-restore of a guest's local draft on next app open is not implemented** (see §2's scope decision) — the draft is safely written and never deleted by this phase's code, but nothing yet reads it back into the builder automatically the way the web does. This is the one piece of the web's own guest-save behavior this phase deliberately did not reproduce, for the regression-risk reasons explained in §2, not because it was overlooked.
- Guest→account draft migration after signing in is **not implemented on the web either** (confirmed directly: the real `localStorage` key is never read back after login) — correctly treated as out of scope here too, per Phase 40's own audit finding on this exact point.
- No device/emulator verification was possible this phase (see §7) — this should be attempted the next time a physical device or an emulator with sufficient free storage is available.

## Completion

Per this phase's own scope boundary: the guest-save flow now matches the web's verified behavior (local save, no unauthenticated server request, a clear sign-in prompt, and an error message that can never be mistaken for a session expiry); authenticated saving and the existing draft list/open/update/delete operations are unchanged and still pass their full existing test coverage; the full suite and analyzer results are reported accurately above. Stopping here — waiting for explicit approval before Phase 41, Phase 43, or any other change.
