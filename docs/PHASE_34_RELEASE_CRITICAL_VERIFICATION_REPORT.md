# Phase 34 — Release-Critical Environment, Scoring & Resume Navigation Verification

## 1. Summary of changes

| Task | Outcome |
|---|---|
| 1. Environment/login verification | **No code change.** Findings confirm/refine Phase 33's hypothesis; no device was available to complete the live check (§2). |
| 2. MCQ/Matching scoring compatibility | **No code change needed.** Direct source comparison found the Phase 16 fix (already committed 2026-10-13, before this phase) is correct and complete against the current `activities/grading.py` contract, with existing passing regression tests already covering the exact historical anomaly. See §3. |
| 3. Create Resume navigation | **Code changed.** `lib/features/home/presentation/screens/home_screen.dart` — the CTA now opens a small choice sheet between the two existing, real resume workflows instead of a single hardcoded destination. See §4. |

Files changed: `lib/features/home/presentation/screens/home_screen.dart`, `test/features/home/presentation/screens/home_screen_test.dart`. Nothing else.

## 2. Environment configuration and backend URL findings (Task 1)

**Confirmed facts** (re-verified directly this phase, not assumed from Phase 33):

- `lib/app/config/environment.dart`: `Environment.dev`'s `baseUrl` resolves to `http://10.0.2.2:8000` on Android or `http://127.0.0.1:8000` otherwise; `Environment.production` resolves to `https://careerbuddy4u.com`. Selection is via `String.fromEnvironment('ENV', ...)`, read at compile time from `--dart-define=ENV=...`.
- **The exact command for a production-configured run**: `flutter run -d <device> --dart-define=ENV=production` (or, for an installable artifact, `flutter build apk --release --dart-define=ENV=production`, matching `scripts/build_release.sh`). A plain `flutter run` with no flag defaults to `Environment.dev`.
- The debug-mode fail-fast guard in `EnvironmentConfig.resolve()` only triggers when `kReleaseMode` is true — a debug build silently proceeds on `Environment.dev` with no warning.
- The only build artifact present anywhere in this project (`build/app/outputs/flutter-apk/app-debug.apk`) is a debug build from 2026-10-15, built without `--dart-define=ENV=production` (this session's own earlier Phase 29 smoke test).
- The local Django server running on this machine (confirmed again this phase, same long-running process) serves `Career_Buddy_LMS/` — the original, pre-update codebase — not `royalStaffing_CB01/`.

**Attempted this phase, and its result**: `flutter devices` lists `macOS (desktop)` and `Chrome (web)` — no Android/iOS emulator or physical device is currently connected. An attempt was made to use Chrome as a safe, no-credential-needed way to at least confirm the app builds and starts with `--dart-define=ENV=production` (`flutter run -d chrome --dart-define=ENV=production`). **This failed immediately with `"This application is not configured to build on the web"`** — the project has no `web/` platform directory at all, so Chrome is not a usable target for this app regardless of what `flutter devices` lists (that listing reflects the Flutter SDK's general capability, not this specific project's configuration). The process was stopped; no workaround (such as adding web support) was attempted, since that would be a project-configuration change outside this phase's scope.

**Result: the production-flag live check (Task 1 item 5) could not be performed — no usable emulator/device exists in this environment.** This is a confirmed environment limitation, not a finding about the code.

**Next manual verification step** (exact, no credentials needed): on a machine with an Android emulator or a connected device, run `flutter run -d <device-id> --dart-define=ENV=production` and confirm the unauthenticated home screen loads without a connection error. If it does, the same device can then be used for a credentialed login test once an authorized test account is available.

**Login code itself**: unchanged from Phase 33's finding — `git diff HEAD` on `lib/core/network/api_client.dart`, `lib/features/auth/data/datasources/auth_remote_datasource.dart`, and `lib/app/config/environment.dart` is still empty, re-confirmed this phase. No authentication behavior was modified, no bypass was added, and no credential was fabricated or used. **Login was not reproduced, tested, or claimed fixed this phase** — only the environment/configuration facts surrounding it were re-confirmed.

## 3. MCQ/Matching scoring compatibility (Task 2)

### 3.1 Source comparison (traced end-to-end, file-and-line level)

**Server contract** (`activities/grading.py`, read in full directly from `royalStaffing_CB01/` this phase):
- `mcq`: for each question at its 1-based position `i` (`exercise.questions.all()` order), `_answer(answers, i).get('chosen')` is compared (case/whitespace-insensitive) against `Question.correct_answer`.
- `matching`: for each position `i` from 1 to n, `_answer(answers, i).get('paired')` must equal `str(i)` — **checked unconditionally, including for a correct pair**, and `_answer()` returns `{}` (silently) for any non-dict value.

**Flutter's current implementation** (re-read directly this phase):
- `lib/features/activities/data/datasources/mcq_exercise_remote_datasource.dart:submitMcqExercise` — builds `{"1": {"chosen": "..."}, "2": {...}, ...}` keyed by each question's real 1-based position (derived from `questionOrder`, itself built from `exercise.questions`'s own parse order in `mcq_exercise_controller.dart:125`, `[for (final q in exercise.questions) q.id]` — the same order the page/JSON lists them in, matching the server's `exercise.questions.all()` iteration). The `chosen` value is the selected option letter (`MCQ_exercise_controller.dart`'s `selectedAnswers: Map<int, String>`, explicitly documented as "questionId -> selected option letter"), matching the format `Question.correct_answer` is compared against.
- `lib/features/matching/data/repositories/matching_exercise_repository_impl.dart:submitMatchingExercise` — builds `{"1": {"result": "correct"|"wrong", "paired": "<position>"}, ...}` for **every** position, including correct ones (`'paired': paired.toString()` is set unconditionally) — matching `grading.py`'s unconditional read exactly.

**Conclusion: both payload shapes already match the current server contract exactly.** This is not a new fix — it was already made and committed (`git log`: commit `082712c`, 2026-10-13, "Phase 13-18: ... MCQ/Matching grading-contract fix ...") **before** this phase began. No concrete mismatch was found this phase, so **no Flutter-side fix was made**, per this task's own explicit instruction to fix only when a concrete mismatch is identified.

### 3.2 The previously reported Matching anomaly — investigated specifically, not assumed resolved

`docs/PRODUCTION_E2E_VERIFICATION_REPORT.md` (2026-09-30) recorded a live production submission that was objectively correct but scored 0. That report **predates** the 2026-10-13 fix commit (confirmed via `git log` dates: the E2E report is Sep 30, the fix commit is Oct 13) — so the anomaly it observed was real, live, and from the *unfixed* code. The fix commit's own doc comment in `matching_exercise_repository_impl.dart` names the exact root cause directly: the previous code omitted the `paired` key entirely for a correct match (a stale assumption that only the wrong-pair case needed it), so the server's `_answer()` always saw `{}` for a correct submission and scored it as wrong — this is precisely the Sep 30 symptom, root-caused and already fixed, with the fix's logic re-verified by me directly against the current `grading.py` source this phase (§3.1).

**This phase does not mark the anomaly "resolved" merely because tests pass** (per this task's own explicit instruction) — the regression tests (§3.3) prove the *payload* is now correct by construction; whether a live submission against the real production server now scores correctly has **not** been re-verified live since the fix, for the same reason as §2: no device and no authorized test account exist in this environment. This is stated as a confirmed source-level fix with passing unit/integration-style tests, not a confirmed live-verified fix.

### 3.3 Tests — run this phase, not assumed

```
$ flutter test test/features/activities/mcq/mcq_exercise_repository_test.dart \
    test/features/matching/data/matching_exercise_repository_test.dart \
    test/features/matching/data/matching_exercise_remote_datasource_test.dart
...
+26: All tests passed!
```
**27 tests, 0 failed.** These already include (pre-existing, re-run and re-confirmed this phase, not newly added): an MCQ test explicitly asserting the `{"1": {"chosen": "b"}, ...}` shape "matching `activities/grading.py`'s mcq branch exactly," and three Matching tests explicitly labeled `REGRESSION (Phase 16)` covering the correct-pair-must-still-send-`paired` case, the incorrect-pair case, and a mixed scenario. **No new or updated test was needed** — the existing coverage already demonstrates the exact contract and the exact historical anomaly correctly, re-confirmed by direct re-reading of both the tests and the current server source, not merely by their having passed before.

### 3.4 Live verification status

**Not performed.** No authorized test account and no safe test-activity session exists in this environment. Compatibility is verified by direct source comparison and by existing, passing regression tests only — explicitly not by a live scoring session, per this task's own required disclosure.

## 4. Create Resume navigation (Task 3)

### 4.1 Before

Both the unauthenticated and authenticated home screen's "Create Resume" button pushed directly to `RoutePaths.resumeBuilder` (the AI resume-parsing/ATS upload screen) — one hardcoded destination, no choice.

### 4.2 A correction to Phase 33's own framing, found this phase

Phase 33's report characterized the fix as "re-point the CTA to the Manual Resume Builder." Direct inspection of the updated web source this phase found that framing **imprecise**: the web's own hero "Create Resume" button (`landing.html:6552`) scrolls to a `#create-resume` anchor (`landing.html:7155-7179`) that is a **third, entirely separate** free-form resume builder (`career_app/create_resume_views.py`, its own `ResumeDraft` model, template switcher, live preview, signed-in draft persistence — explicitly commented in its own template as *"No AI, no suggestions, no sample data"*) — distinct from **both** the AI-parsing flow **and** the role-driven Manual Resume Builder (`career_app/manual_resume_views.py`, Phases 24-32's Flutter feature). Flutter has no equivalent of this third, free-form builder at all; building one would be a large, separate feature (matching the scope of Phases 24-32 themselves), not an in-scope navigation fix. This is stated plainly rather than silently building something different from what was asked, or silently mapping to the wrong existing screen and calling it parity.

A second, independent finding ruled out "just push straight to the Manual Resume Builder" as a clean substitute on its own: `ManualResumeBuilderScreen`'s `role` parameter is nullable and the screen degrades gracefully without one, **but there is no affordance anywhere inside that screen to select or change a role afterward** — a user entering with no role gets no role-specific skill suggestions, templates, or fields, with no way to add one short of backing out entirely. Confirmed by reading the full screen and its five step widgets; the only place a role is ever set is the constructor parameter, supplied today exclusively by the Role Picker's own action sheet.

### 4.3 The fix made

`home_screen.dart`'s `onCreateResume` (both branches) now calls a new `_showCreateResumeChoice(context)`, which opens a small modal bottom sheet (`_CreateResumeChoiceSheet`) offering exactly two choices, using the identical tile labels already shipped in `role_picker_screen.dart`'s own action sheet for consistency:
- **"Build Resume"** → `context.push(RoutePaths.manualResumeBuilder)` (no role — an acceptable, honest trade-off per §4.2; a candidate who wants role-specific suggestions can still reach them via the unchanged "Choose Target Role" button inside the Resume Parsing screen).
- **"Resume Parsing & Interview"** → `context.push(RoutePaths.resumeBuilder)` — the exact same destination the CTA always used, now reachable in one extra tap instead of being the only option.

No existing route, provider, controller, or screen was modified. `RolePickerScreen`'s own action-sheet code and the AI resume-parsing flow are completely untouched — both still work exactly as before, independently of this change.

### 4.4 Route protection — confirmed unchanged, not re-tested redundantly

`RoutePaths.manualResumeBuilder` is still absent from `publicRoutes`/`universalRoutes` (unchanged — no route definition was touched), so the existing auth guard still protects it identically to before. This exact route is already covered by name in `test/app/router/route_guards_test.dart`'s "Manual Resume Builder routes" group (added Phase 30: unauthenticated → login, authenticated → no redirect, session-unknown → splash) — re-running that file this phase (§5) re-confirms it still passes; a duplicate test was not added, since the guard logic and the route constant are both unchanged by this phase's work.

### 4.5 Tests added

`test/features/home/presentation/screens/home_screen_test.dart`:
- Added `RoutePaths.manualResumeBuilder` to the test router.
- Replaced the 2 existing single-destination "tapping Create Resume..." tests (one per auth state) with 6 new tests: tapping "Create Resume" opens the sheet (not a direct navigation) in each auth state; choosing "Build Resume" pushes the Manual Resume Builder; choosing "Resume Parsing & Interview" pushes the same destination the old single-tap behavior always used — covering both the guest and authenticated branches.

## 5. Exact test and analyzer results, compared to the Phase 33 baseline

```
$ flutter test test/features/home/presentation/screens/home_screen_test.dart
...
+22: All tests passed!
```
**23 tests, 0 failed** (in this file alone).

```
$ flutter analyze
...
7 issues found.
```
**7 warnings, 0 errors** — identical set to the Phase 33 baseline (all pre-existing `unused_element_parameter` warnings on unrelated resume-feature test fakes; none introduced or touched this phase).

```
$ flutter test
...
+2300: All tests passed!
```
**2301 passed, 0 failed** — up from the Phase 33 baseline of 2296 by 5 (net effect of replacing 2 single-destination tests with 6 choice-based ones across the two auth-state groups in `home_screen_test.dart`). No test was weakened, skipped, or deleted — the two removed tests' assertions are both still covered (now via the "Resume Parsing & Interview" choice reaching the identical destination) plus additional new coverage for the sheet itself and the "Build Resume" choice.

## 6. Device/emulator, backend, and account limitations

- **No Android/iOS emulator or physical device was available or used this phase.** `flutter devices` lists only `macOS (desktop)` and `Chrome (web)`; Chrome was attempted and found non-functional for this project (no web platform support configured) — see §2.
- **No authorized test account exists or was used.** No login was attempted, no credential was fabricated, and no OTP/authentication restriction was bypassed anywhere in this phase.
- **No live request was made to `https://careerbuddy4u.com`** or to any Django instance, local or remote, this phase.
- **The local Django dev server** (already running, not started by this phase) continues to serve the original, pre-update codebase — unchanged finding from Phase 33, re-confirmed this phase.

## 7. Remaining blockers and recommended next priority

1. **Highest priority, unchanged from Phase 33**: a usable emulator/device plus an authorized test account are both still needed to close the one open question each of Tasks 1 and 2 actually has — whether the (unmodified, previously live-verified) login path and the (already-fixed, now-re-confirmed-correct-by-source) MCQ/Matching scoring both behave correctly against real production today. Neither is a code question anymore; both are access/verification questions.
2. **If/when a device becomes available**: run `flutter run -d <device> --dart-define=ENV=production` first (no credentials needed) to confirm the app reaches production at all, before attempting any credentialed login.
3. **The "Create Resume" choice-sheet fix (Task 3) is complete and tested**, but, like every other UI change in this entire engagement, has not been visually confirmed on a real screen — no device was available to do so.
4. Everything else flagged in the Phase 33 report (employer-portal placeholder re-check, the async lifecycle findings, the completeness indicator, stale landing-page stats) remains exactly as that report left it — out of scope for this phase's three named tasks, not re-investigated here.

## 8. Confirmation

- Only `lib/features/home/presentation/screens/home_screen.dart` and `test/features/home/presentation/screens/home_screen_test.dart` were changed. No other Flutter source, test, dependency, route guard, or configuration file was modified.
- `activities/grading.py` and the MCQ/Matching submission code were read and compared, but **not changed** — no concrete mismatch was found to justify a fix.
- Neither Django reference tree (`Career_Buddy_LMS/`, `royalStaffing_CB01/`) was edited, created, or deleted — both read-only throughout.
- No signing file, credential, API key, or secret was inspected, printed, exposed, or modified.
- No account was fabricated, no OTP/authentication was bypassed, and no production request of any kind was made.
- No release build, deployment, or Play Store action was taken.

---

**Phase 34 is complete.** Returning this report for review; awaiting explicit approval before any further phase.
