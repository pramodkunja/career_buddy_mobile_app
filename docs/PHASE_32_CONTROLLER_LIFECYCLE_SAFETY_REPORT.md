# Phase 32 — Manual Resume Async Controller Lifecycle Safety

**Scope as instructed**: only `ManualResumePreviewController`, `ManualResumePagePreviewController`, `ManualResumePdfController`, their 3 directly-relevant test files, and this report were changed.

## 1. The issue and its impact

Phase 31 found that a preview/page-preview/PDF request still in flight when the user logs out (or logs in as a different account) resolves against a controller whose provider has already been invalidated, and predicted this would throw `UnmountedRefException` from the subsequent `state = ...` write.

**This phase's own direct verification (Work Item 1) found Phase 31's prediction was only half right, and the actual risk is more serious than "an unhandled exception."** Confirmed by reading `riverpod: 3.4.3`'s own source and then proving it with a disposable diagnostic test (removed before finalizing): for a plain, non-`autoDispose` `NotifierProvider` — which all three of these controllers are — `ref.invalidate()`/`container.invalidate()` does **not** unmount `ref` or replace the `Notifier` object. It re-runs `build()` on the *same* instance (confirmed: `$ClassProviderElement.create()` caches the notifier object via `classListenable.result ??= ...` and only ever constructs it once per element lifetime; invalidation re-invokes `build()`, not `create()`). So `ref.mounted` stays `true` for the entire lifetime of the controller object, and a stale request's eventual `state = ...` write does **not** throw — it **silently succeeds**, overwriting whatever the freshly-invalidated (just-reset-to-idle) state was with the old account's result.

**Concretely**, before this phase's fix: User A taps "Generate PDF," the request is still in flight, User A logs out and User B logs in, and then — simply because the slow network request from User A's session finally resolves — User B's screen could show User A's PDF-ready/preview/page-image result, or have User A's server-validation errors pushed into the (now User-B-owned) `ManualResumeBuilderController`. This is a real cross-account data-exposure risk, not merely log noise, and is a correctness issue strictly worse than Phase 31's "fails safe by throwing" characterization.

This is documented here as required by Work Item 2's own escape clause: *"If the installed Riverpod API or actual controller flow differs from the Phase 31 report, follow the verified current implementation and document the difference."*

## 2. The three controllers inspected and changed

- `lib/features/resume/presentation/controllers/manual_resume_preview_controller.dart`
- `lib/features/resume/presentation/controllers/manual_resume_page_preview_controller.dart`
- `lib/features/resume/presentation/controllers/manual_resume_pdf_controller.dart`

Every `await` point in all three was located and traced to its next `ref`/`state` use (Work Item 1):
- `ManualResumePreviewController.generate()` — one `await` (the repository call), followed immediately by `ref.read(manualResumeBuilderControllerProvider.notifier)` and `state = ...` in every branch.
- `ManualResumePagePreviewController.generate()` — identical shape.
- `ManualResumePdfController.generateAndOpen()` — one `await` (the repository call), followed by `state =`/`ref.read(...)` in every branch; the success branch additionally calls `_saveAndOpen()`, which itself has **two more** `await`s (`getTemporaryDirectory()`/`file.writeAsBytes()`, then `OpenFile.open()`), each followed by its own `state = ...`, plus a `catch` block that also writes `state`.

## 3. The exact lifecycle guards added, and why each is needed

Each controller gained an `int _generation` field, incremented in `build()`:

```dart
int _generation = 0;

@override
ManualResumeXState build() {
  _generation++;
  return const ManualResumeXIdle();
}
```

Each async method captures `_generation` **before** its first `await`, and checks it against the current value at every point execution resumes after an `await`, immediately before the next `ref`/`state` use:

```dart
final requestGeneration = _generation;
...
final result = await ...;
if (!ref.mounted || requestGeneration != _generation) return;
```

- **`!ref.mounted`** is kept as a cheap, correct-but-insufficient-alone first check — it remains the right guard for a genuine full disposal (e.g. the whole `ProviderContainer` being torn down, which does fully dispose the element and would make this throw if unguarded). It is deliberately not removed, since it costs nothing and is still correct for that case.
- **`requestGeneration != _generation`** is the guard that actually catches the real logout/account-switch scenario (§1), since `build()` demonstrably re-runs (and thus increments `_generation`) on invalidation even though the same object/`ref` persists.

**`ManualResumePreviewController`** and **`ManualResumePagePreviewController`**: one guard each, immediately after their single `await`, covering every subsequent branch (success/rejected) since no further `await` occurs before those branches complete.

**`ManualResumePdfController`**: the guard was needed in **four** places, since `requestGeneration` had to be threaded through to `_saveAndOpen()` as a parameter (it isn't a field capture point of its own — it's called mid-flight from `generateAndOpen()`):
1. In `generateAndOpen()`, right after its own `await`, before the `switch` on the repository result (covers the `Failed` and `ManualResumePdfRejected` branches, and the entry into the `ManualResumePdfReady` branch).
2. In `_saveAndOpen()`, after `await file.writeAsBytes(...)`, before `state = const ManualResumePdfIdle();`.
3. In `_saveAndOpen()`, after `await OpenFile.open(...)`, before the `result.type != ResultType.done` branch's `state = ...`.
4. In `_saveAndOpen()`'s `on Object catch` block, before its own `state = ManualResumePdfFailed(...)` — a genuine file-system exception can legitimately occur after the controller has already become stale, and this write needed the same guard as every other one in the method.

The already-written PDF file on disk is deliberately left in place when the guard fires mid-`_saveAndOpen()` (not deleted) — it is harmless to leave behind (same reasoning `ProtectedMediaDownloadController`'s own downloads already rely on), and deleting it would be new behavior outside this phase's scope.

`reset()` was left unchanged — it is called synchronously and directly by the UI, never after an `await` inside this class, so it was never at risk and needed no guard.

## 4. Regression tests added and what each proves

One new test per controller, each using the exact mechanism described in Work Item 3 (a controllable `Completer` + `container.invalidate()`, no arbitrary delays):

- **`manual_resume_preview_controller_test.dart`**: extends `_FakeResumeRepository` with a `previewCompleter` field so `previewManualResume()` can be held open. The test starts `generate()`, confirms `Loading`, calls `container.invalidate(manualResumePreviewControllerProvider)` followed immediately by a `read()` (confirming the state is already freshly reset to `Idle` — proving the rebuild genuinely happened), then completes the held `Future` with a ready result. Asserts: the original `generate()` future `completes` without throwing, **and** the controller (read fresh afterward) is still `Idle`, not overwritten by the stale result.
- **`manual_resume_page_preview_controller_test.dart`**: identical shape, with `pagePreviewCompleter`.
- **`manual_resume_pdf_controller_test.dart`**: identical shape, with `pdfCompleter`, plus one extra, higher-stakes assertion: `fakeOpenFile.lastFilePath` is `isNull` afterward — proving the stale PDF-ready result never even reached the file-save/`OpenFile.open` step, since the very first guard (in `generateAndOpen()`, before ever calling `_saveAndOpen()`) already stopped it.

**What these 3 tests prove**: that the exact real-world trigger (an invalidation racing an in-flight request) no longer produces an unhandled exception and no longer lets a stale response reach `state`/`OpenFile`/the Builder controller — the precise scenario Phase 31 flagged, now demonstrated end-to-end with a deterministic `Completer`, not a timing guess.

**What they do not prove, and the limitation this phase is explicit about**: no test exercises the guard inside `_saveAndOpen()` itself (guard points 2–4 in §3) with a `Completer`-driven file-write/`OpenFile.open` race — doing so would require extending the shared `test/support/fake_open_file_platform.dart`/`fake_path_provider_platform.dart` fakes (used by other, unrelated tests, e.g. `protected_media_download_controller_test.dart`) to support a controllable completion, which falls outside this phase's explicit "only the three targeted controller files, their directly relevant tests" boundary. Those three guard points are verified by direct code inspection and by the same `_generation`-mismatch reasoning already proven to work at the controller's own entry point — not by their own dedicated completer-driven test. This is stated plainly rather than implied.

All existing tests in all three files (28 of them, pre-dating this phase) were re-run and pass unchanged — no existing assertion was weakened, and no mounted-controller behavior changed.

## 5. Focused tests, full-suite, and analyzer results

```
$ flutter test test/features/resume/presentation/controllers/manual_resume_preview_controller_test.dart \
    test/features/resume/presentation/controllers/manual_resume_page_preview_controller_test.dart \
    test/features/resume/presentation/controllers/manual_resume_pdf_controller_test.dart
...
+30: All tests passed!
```
**31 tests, 0 failed** (28 pre-existing + 3 new lifecycle tests, one per controller).

```
$ flutter test test/features/resume/ test/features/auth/ test/app/
...
+521: All tests passed!
```
**522 tests, 0 failed.**

```
$ flutter test
...
+2295: All tests passed!
```
**2296 tests, 0 failed** — up from the Phase 31 baseline of **2293** by exactly **3** (the 3 new tests added this phase; no other test count changed).

```
$ flutter analyze
...
7 issues found.
```
**7 warnings, 0 errors** — up from Phase 31's 4. The 3 new warnings are `unused_element_parameter` on the new `previewCompleter`/`pagePreviewCompleter`/`pdfCompleter` optional constructor parameters, each only ever set via a field assignment after construction rather than passed as a named constructor argument — the identical, already-established style already present for the 4 pre-existing warnings in this codebase (e.g. `manual_resume_preview_screen_test.dart`'s own `previewCompleter` field uses the same pattern). Not a new category of issue, not related to production code, and not a defect.

No test failed, and none was investigated as a failure, since none occurred.

## 6. Limitations and scenarios that remain unverified

- The `_saveAndOpen()`-internal guard points (§3, points 2–4) are verified by code inspection and the same proven mechanism, not by their own dedicated `Completer`-driven test — see §4's explicit limitation.
- This phase did not verify the fix live, on a real device, against a real backend. No emulator was booted and no authorized test account was used — consistent with every prior phase's disclosed environment constraints. All evidence in this report is automated-test and static-inspection evidence.
- The underlying Riverpod behavior this phase relied on (`build()` re-running on the same object on invalidation, rather than replacing it) was verified against the exact pinned version (`riverpod: 3.4.3`) directly. A future Riverpod upgrade could in principle change this internal behavior; the `_generation` counter is written to be correct regardless of *why* `build()` re-runs (it only cares that it does), so it is not fragile to that specific internal detail changing, but this was not re-verified against any other Riverpod version.
- This phase did not investigate whether the same class of issue exists in any *other* controller in this codebase (e.g. `ManualResumeBuilderController` itself, or controllers in unrelated features) — out of scope per the stop conditions, and not attempted.

## 7. Confirmation: nothing else was changed

- Both Django/web reference directories (`Career_Buddy_LMS/`, `royalStaffing_CB01/`) were not read, written, or otherwise touched this phase at all.
- No dependency was added or changed — `pubspec.yaml`/`pubspec.lock` are unchanged (the `riverpod`/`flutter_riverpod` versions cited above were read from the already-resolved `pubspec.lock` and the already-downloaded package cache, not newly fetched).
- No route, authentication logic, or local draft persistence code was changed. `git status --porcelain` shows the identical 18 pre-existing modified tracked files and the same untracked-file list as the Phase 31 baseline — only the content of the 3 targeted controller files and their 3 test files changed, plus this new report.
- No signing file, credential, API key, or deployment setting was inspected, printed, exposed, or modified.
- No account was fabricated, no OTP or authentication restriction was bypassed, and no production data was used anywhere in this phase.

---

**Phase 32 is complete.** No Phase 33 work has been started, and none of the explicitly-excluded items (live completeness indicator, PDF tap-simulation investigation, a connected two-account integration test, `CancelToken` support) was touched. Returning this report for review; awaiting explicit approval before any further phase.
