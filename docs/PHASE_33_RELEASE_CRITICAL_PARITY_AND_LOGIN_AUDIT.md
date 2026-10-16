# Phase 33 — Updated Web-to-Mobile Parity, Login Diagnosis & Release-Critical Audit

**Audit-only phase. No application code, test, dependency, route, or configuration file was changed. Neither Django reference tree was touched.** Deliverables: this report and `docs/PHASE_33_UPDATED_WEB_MOBILE_PARITY_MATRIX.md`.

## 1. Executive summary

Two user complaints were investigated: (1) mobile doesn't visibly reflect updated-web changes, (2) login is not working. Neither was reproduced live this phase (no authorized test account, no confirmed-reachable device — see §4), so both conclusions below are **evidence-based diagnoses from code and configuration inspection**, not confirmed-by-reproduction facts. They are stated as such throughout.

**Login**: no code-level regression was found in the login path itself. The exact code that handles login (request shape, CSRF, the production-specific `Referer`-header fix) is byte-identical to what was live-verified against real production with 4 real accounts on 2026-09-30 (`docs/PRODUCTION_E2E_VERIFICATION_REPORT.md`), confirmed via `git diff HEAD` showing zero changes to those files since. **The best-evidenced hypothesis is environmental, not a code defect**: this project's only existing build artifact is a **debug APK** (`build/app-debug.apk`, built 2026-10-15), and a debug build silently defaults to `Environment.dev` (`http://10.0.2.2:8000`/`127.0.0.1:8000`) unless `--dart-define=ENV=production` is explicitly passed — a footgun this exact project has hit once before (`scripts/build_release.sh`'s own comment: *"This happened once already"*). The local dev server currently running on this machine was independently confirmed to serve the **original, pre-update** `Career_Buddy_LMS/` codebase, not the updated `royalStaffing_CB01/` one — so even a debug build that *does* connect would never show any updated-web change. This single, well-evidenced scenario plausibly explains both complaints at once. See §4 for exactly what is confirmed versus hypothesis.

**Visible parity**: the Manual Resume Builder (Phases 24–32) is real, thoroughly tested, and reachable — but not from the home screen's own prominent "Create Resume" button, which still opens the older AI resume-parsing flow instead (a confirmed, direct-inspection finding, not carried from an old report). The home screen also has stale marketing stats and is missing several of the web's marketing-only sections (lower-risk). Everything else inspected this phase (auth, dashboard, role-fit picker, resume analysis, job board, employer portal, profile) looks implemented and structurally sound. One item from the **pre-existing Phase 15 roadmap could not be re-verified this phase and must not be assumed resolved**: the MCQ/Matching scoring-contract regression Phase 15 called its single highest-priority finding.

**New async-safety finding**: the Phase 32 fix covered 3 controllers, but a parallel audit this phase found the same exact bug class, unfixed, in at least 6 more controllers already in `AuthController`'s own invalidation list — most notably `ManualResumeBuilderController.load()` itself (the very controller the 3 already-fixed ones were built alongside) and `AriaChatController` (where the realistic scenario is an **audible** cross-account leak — another user's chat reply being spoken aloud in the next account's session). See §5.

## 2. What was inspected and verified, and what was not

**Inspected directly this phase** (not merely cited from earlier reports): `lib/features/auth/` (login screen, datasource, `ApiClient`), `lib/app/config/environment.dart`, `scripts/build_release.sh`, `android/app/build.gradle.kts` (existence checks only, no signing content read), the running local Django process's working directory, `build/` for existing artifacts, `lib/features/home/` CTA routing, `lib/features/resume/domain/entities/manual_resume_completeness.dart` and the corresponding web `completeness()`/`rbComp` source, `git log`/`git diff` on the critical auth files, `flutter analyze`/`flutter test` (fresh run, not assumed from Phase 32's report).

**Delegated to two focused research passes this phase** (each independently verified key claims against source, not assumed): a broad web-to-mobile scan across auth, home, dashboard, resume analysis, job board, profile, and other feature areas (feeding the parity matrix); and a full re-audit of every provider in `AuthController._invalidateUserScopedProviders()` for the Phase-31/32 async-lifecycle bug class.

**Not performed, and explicitly not claimed**: no live HTTP request was made to production or to any Django instance. No device/emulator was booted this phase (none was running; booting one was not attempted, consistent with every prior phase's stated restraint). No login was attempted anywhere, with any credential, real or fabricated. No code was changed, including no attempt to "just try" the environment-flag fix.

## 3. Current project state (Work Item 1)

- **Entry point / navigation**: `lib/main.dart` → `MaterialApp.router` via `app_router.dart`; `route_guards.dart`'s `computeRedirect()` gates every non-public/non-universal route behind `AuthAuthenticated`.
- **Login/auth**: session-cookie based (Django `sessionid`/`csrftoken`), no JSON auth API — `AuthRemoteDataSource` scrapes real HTML error patterns because none exists. CSRF primed via an explicit GET before the POST. A production-specific `Referer` header is set on every request (see §4).
- **Dashboard**: HTML-scraped (`dashboard_html_parser.dart`) against `activities/views.py`'s `dashboard()` — confirmed structurally matching this phase.
- **Authenticated-only features**: Dashboard, Activities, all AI exercise types, Grammar, Mock Tests, Resume (both analysis and Manual Builder), ARIA (chat is itself unauthenticated per `PRODUCTION_E2E_VERIFICATION_REPORT.md` but reached from an authenticated shell), JAM, Roleplay, Group Discussion, Mock Interview, Skill-Up lesson detail, Certifications, the full Employer portal.
- **Test/analyzer baseline, re-run fresh this phase** (not assumed from Phase 32):
  ```
  $ flutter analyze
  7 issues found (warnings only — same pre-existing unused_element_parameter class, unchanged since Phase 32)
  $ flutter test
  2296 passed, 0 failed
  ```
  Identical to Phase 32's own reported end-state — confirms no drift occurred between phases.
- **Verified against the updated web vs. merely implemented/unit-tested**: see the parity matrix. In short — Manual Resume Builder is the most thoroughly verified area in this codebase (Phases 24–32, dozens of automated tests, direct source cross-checks every phase). Most other features are "implemented, code inspected, structurally correct" but not independently re-verified against a live updated-web instance this phase or in Phase 15. Only the 2026-09-30 production E2E report represents genuine live, real-account, real-production verification of anything in this app — and that was against the **pre-update** backend contract for everything except what Phase 15 later found had changed.

## 4. Login diagnosis (Work Item 2)

### 4.1 Confirmed facts (direct evidence, file-and-line level)

1. **The login request/response flow is unchanged since its last successful live verification.** `git diff HEAD` on `lib/core/network/api_client.dart`, `lib/features/auth/data/datasources/auth_remote_datasource.dart`, and `lib/app/config/environment.dart` returns empty — these files are byte-identical to what's committed, and `PRODUCTION_E2E_VERIFICATION_REPORT.md` (2026-09-30) documents these exact files being used to successfully log in and out 4 real accounts (2 student, 2 employer) on real production, after two defects (a missing `Referer` header causing every login to fail with 403, and a cosmetic false-error-after-successful-logout) were found and fixed **in that same task**. Both fixes are present in the current code (`api_client.dart`'s `headers: {'Referer': EnvironmentConfig.baseUrl}`; `auth_remote_datasource.dart`'s `logout()` accepting a 302).
2. **No `.vscode/launch.json` or equivalent exists** — there is no saved default run configuration anywhere in this repo that passes `--dart-define=ENV=production`. A plain `flutter run` or an IDE's default "Run" button produces a debug build on `Environment.dev`.
3. **`EnvironmentConfig.resolve()`'s fail-fast guard (`lib/app/config/environment.dart:51-58`) only fires when `kReleaseMode` is true.** A debug build gets no warning, no error, and no indication at all that it is pointed at `http://10.0.2.2:8000` (Android emulator alias) or `127.0.0.1:8000` (iOS sim/desktop) instead of `https://careerbuddy4u.com`.
4. **This exact failure mode has already happened once in this project.** `scripts/build_release.sh`'s own comment: *"Plain `flutter build apk --release` (no --dart-define) resolves EnvironmentConfig.baseUrl to the dev server... producing a release APK that can never reach any backend. This happened once already (see docs/ for the incident)."* — independently corroborated by `BATCH_14_RELEASE_CANDIDATE.md`'s own "FOUND & FIXED" entry for a *different* but related defect (missing `INTERNET` permission in every release build through Batch 13) — re-confirmed **still fixed** in the current `AndroidManifest.xml` this phase.
5. **The only build artifact present anywhere in this project right now is a debug APK** (`build/app/outputs/flutter-apk/app-debug.apk`, 2026-10-15 16:49 — from this session's own Phase 29 smoke test, built via plain `flutter run --debug` with no production flag). No release APK/AAB exists in the build output as of this phase.
6. **The local Django dev server currently running on this machine (port 8000, process already running before this phase started) serves `Career_Buddy_LMS/` — the original, pre-update codebase — confirmed via `lsof -p <pid> -d cwd`, not the updated `royalStaffing_CB01/` tree.** A debug build reaching this server would authenticate against an unchanged `users/` app (Phase 15 confirmed that contract didn't change) but would never show any of the updated web's new features or content.
7. **Live production login/session/logout has never been independently re-verified since 2026-09-30.** `BATCH_13_LIVE_PRODUCTION_SMOKE_TEST.md` and `BATCH_14_RELEASE_CANDIDATE.md` both record this as the single open item for two consecutive batches before it was finally closed in the Sep 30 report; nothing in Phases 15–32 touched the login code path (confirmed by #1) or re-ran a live check.
8. **A connection failure is mapped to a specific, distinct, named failure** (`NetworkFailure`, message: *"No internet connection. Check your network and try again."*) — **not** the generic `ServerFailure` message. If the real symptom is "the app can't reach its configured server," the app should show this specific message, not a silent hang or a misleading one. (This is a fact about current behavior, not a defect — it's relevant to §4.2's suggested diagnostic.)

### 4.2 The leading hypothesis (clearly labeled as such, not a confirmed defect)

**The person observing "login is not working" is very likely testing a debug build that is not pointed at production — and, separately, the content gap complaint is very likely explained by the same build also not being pointed at the updated backend.** Two concrete sub-scenarios, both consistent with every fact in §4.1:

- **On a physical device**: `10.0.2.2` is an Android-emulator-only loopback alias and resolves to nothing on a real phone — every network call, including login, would fail outright with the `NetworkFailure`/`NetworkUnavailableException` path (or a connection-refused/timeout variant), not a login-specific error. This would look exactly like "login is not working," because *every* backend call fails identically.
- **On an emulator, but with no local Django server running at the time** (the one currently running was almost certainly started for this session's own audit work, not something that runs persistently) — same outcome: every call fails.

A third, less likely but possible scenario: the debug build *does* reach the local `Career_Buddy_LMS/` server (as it does right now), in which case login itself would likely **succeed** (the `users/` contract is unchanged per Phase 15) but the user would see old content — explaining complaint 1 but not complaint 2 as stated. This phase cannot distinguish between these scenarios without knowing exactly how the app was built/launched when the complaint was observed — information this phase does not have.

### 4.3 What would confirm or rule this out (safe, no-credential-needed verification)

None of the following require an authorized test account:
1. Confirm how the app currently being evaluated was built/installed — specifically, whether `--dart-define=ENV=production` was passed. This alone would likely resolve the ambiguity in §4.2.
2. If a debug build is in use, rebuild with `flutter run --dart-define=ENV=production` (or install `scripts/build_release.sh`'s output) and retest navigation/content alone (no login needed) — if the home screen's content now matches the live site, the hypothesis is confirmed.
3. Attempt to load `https://careerbuddy4u.com/users/login/` directly in a mobile browser on the same device being used to test the app, to confirm the device itself has real internet access independent of the app.

### 4.4 What remains genuinely blocked

**Live, credentialed login against production has still never been re-verified since 2026-09-30**, and this phase did not and could not change that — no authorized test account exists or was sought. If §4.2/§4.3 rule out the environment hypothesis, the next step would be a fresh live login attempt with a real account, which requires exactly what `BATCH_13`/`14` already identified as the one missing input: real student and/or employer test credentials from the project owner.

## 5. Async account-switching risk audit (Work Item 5 — summary; no code changed)

The Phase 32 fix (an incrementing `_generation` counter, checked alongside `ref.mounted` after every `await`) covered exactly the 3 controllers it was scoped to. A dedicated pass this phase checked every one of the 42 providers in `AuthController._invalidateUserScopedProviders()` and found the same vulnerable shape — a plain `Notifier` (or an `AsyncNotifier`'s own custom method) writing `state = ...`/`ref.read(...)` directly after an `await`, with no generation guard — recurring widely. Riverpod's internal protection (confirmed from `riverpod-3.4.3` source) only guards state that flows through a `Notifier`'s own `build()`/`invalidateSelf()` path; it does **not** extend to a hand-written method's own direct `state =` write, which is exactly the shape every finding below has.

**Highest priority:**
- **`ManualResumeBuilderController.load()`** (`manual_resume_builder_controller.dart:202-218`) — **confirmed in the invalidation list, NOT covered by the Phase 32 fix**, despite being the sibling controller in the very same feature area. Unconditionally writes `state = ManualResumeBuilderReady(draft: ...)` after awaiting the repository. Realistic scenario: Account A opens the builder (load in flight), logs out; Account B logs in and opens the builder; whichever `load()` resolves last wins, so B could see A's name/phone/employment history, or A's slower response could clobber B's freshly-loaded draft.
- **`AriaChatController`** (`sendMessage`/`_autoSpeak`) — a stale reply-stream event from a logged-out account can append onto and **audibly speak into** the next account's chat session (nothing cancels the underlying HTTP stream on invalidation).
- **`ResumeBuilderController.uploadAndAnalyze`/`reanalyze`** — same shape and same PII sensitivity (full parsed resume content) as the already-fixed resume controllers, in the same feature directory, not covered.
- **`MockInterviewController`** — a singleton (always collides between any two accounts on one device); a late-arriving stale result/termination state could overwrite a different account's live, in-progress interview.
- **`CertificateFormController`**, **AMCAT/CoCubes/MockTest submission controllers** — same unconditional-write-after-await shape; `.family`-keyed controllers only collide when two accounts share the same subject/exercise id on one device, which is a real (not hypothetical) shared-device scenario.
- **Lower priority** (same pattern, but `.family`-keyed by exercise id, narrower collision window, and several reset fully on retry): the per-exercise-type AI Speaking/Reading/Writing/Listening, MCQ, and Bingo controllers.
- **Checked, no risk found**: every pure `AsyncNotifier` controller whose action methods route exclusively through `ref.invalidateSelf(); await future;` (Dashboard, Profile, Activities, Workshop, Resume History, and the full Employer/JAM/GD controller set) — protected by Riverpod's own internal `running`-flag mechanism, confirmed from source.

**Recommendation**: these are confirmed-by-code-inspection risks, not yet confirmed-by-deterministic-test (the same category Phase 32's own fixes started in, before their regression tests were added). None was fixed this phase per the explicit stop condition. See §7, Priority 1 item 3.

## 6. Visible UI and real-user readiness assessment (Work Item 4)

Ranked by plausibility, not certainty — no device was available this phase to distinguish between them directly:

1. **Most likely**: the build/environment being evaluated isn't pointed at production (§4) — this alone would explain *both* complaints simultaneously and requires no Flutter code change, only a correct build command.
2. **Also real, independent of #1**: the home screen's "Create Resume" CTA genuinely does not open the newest feature (Manual Resume Builder) — a real, confirmed navigation gap a user would notice even on a correctly-configured production build.
3. **Also real**: the landing page's marketing sections and stat numbers are stale/incomplete relative to the current web — a user comparing the two side by side would notice this regardless of backend configuration.
4. **Not ruled out, not confirmed**: a genuine, as-yet-unidentified code regression in the login path. Given §4.1's evidence (unchanged, previously-live-verified code), this is the least likely explanation, but it cannot be fully excluded without a live retest.

**Safe next verification steps requiring no device/account**: §4.3's three steps. **Requiring a device but no account**: install/launch with `--dart-define=ENV=production` and confirm the home screen's content now matches the live site (no login needed for this specific check). **Requiring an authorized account**: the full login→dashboard→feature walkthrough, unchanged as an open item since Batch 13.

## 7. Prioritized plan for 27 October 2026

### P0 — Submission blockers

1. **Confirm the build/environment used for user-facing evaluation, and rebuild/retest with `--dart-define=ENV=production` if needed.** *Problem addressed*: §4's leading hypothesis. *User-visible outcome*: if confirmed, both complaints resolve without any code change. *Needs*: no credentials; a device to install the corrected build on. *Verification*: §4.3. *Effort*: Small. *Risk*: none — this is a build-command fix, not a code change.
2. **Re-verify the MCQ/Matching exercise scoring-contract status against the currently-deployed backend.** *Problem*: Phase 15 called this its single highest-priority finding; this phase found no evidence it was ever addressed, and `PRODUCTION_E2E_VERIFICATION_REPORT.md` independently observed a live Matching-exercise scoring anomaly. *Impact if unresolved*: every MCQ/Matching submission could silently score 0. *Needs*: access to the currently-deployed backend's actual payload contract (code inspection alone was insufficient to resolve this in Phase 15 either). *Verification*: a single real or test-account submission compared against the documented contract. *Effort*: Small to re-check; unknown to fix if still broken. *This is the one item on this entire list that could independently sink a submission even if login/parity are both fine.*
3. **Once a device/account is available: re-run a real, credentialed login against production** (Batch 13/14's long-standing open item). *Needs*: one real student (and ideally one employer) test account from the project owner. *Verification*: live login → dashboard → logout, exactly as Batch 13 specified. *Effort*: Small, once credentials exist — this is testing, not engineering.

### P1 — Required parity gaps

1. **Re-point the home screen's "Create Resume" CTA to the Manual Resume Builder** (or add an explicit choice between the two builders, matching whichever the web's current information architecture actually implies). *Scope*: `home_screen.dart:62,78`. *Effort*: Small. *Verification*: tap the button, confirm it opens `manualResumeBuilder`.
2. **Fix `ManualResumeBuilderController.load()`'s async lifecycle gap** using the proven Phase 32 pattern (generation counter). *Scope*: one file, one method, plus a regression test mirroring Phase 32's three. *Effort*: Small. *Verification*: a deterministic completer-based test, same shape as Phase 32's.
3. **Re-verify the 5 employer-portal screens `PRODUCTION_E2E_VERIFICATION_REPORT.md` found as `ComingSoonScreen` placeholders** (Post Job, All Applications, Job Openings, Candidate Search, Company Profile edit/create) — confirm whether they're still placeholders or were completed since Sep 30. *Effort*: Small to check, unknown to complete if still missing.

### P2 — Important quality improvements

1. **Apply the Phase 32 async-safety pattern to the next-highest-risk controllers** from §5 (`AriaChatController` first, given the audible-leak scenario; then `ResumeBuilderController`, `MockInterviewController`). *Effort*: Small per controller, same proven pattern each time.
2. **Live completeness indicator on the Manual Resume Builder's own wizard screen** (not just a one-line post-preview summary). *Scope*: already-parsed data exists; needs UI + a client-side computation decision. *Effort*: Medium.
3. **Update the home screen's stale marketing stats.** *Effort*: Small.

### P3 — Deferrable work

1. Build out the landing page's missing marketing-only sections (Features grid, Career Journey, Stories, etc.) — every underlying feature already exists elsewhere in-app.
2. Apply the async-safety pattern to the remaining lower-priority, `.family`-keyed exercise controllers from §5.
3. Investigate the still-unresolved Phase 28 testing mystery (the Generate PDF button's `tester.tap()` failure) — polish on test quality, not user-facing.

**Sequencing recommendation**: do P0 item 1 first — it is the cheapest possible action (a build command, not code) and could immediately resolve the reported symptom without touching anything else. Do P0 item 2 in parallel if backend access allows, since it is a silent, severe risk independent of everything else in this report. Everything else can proceed in parallel once P0 is addressed. **No promise is made that 27 October is achievable** — that depends on backend/scoring findings (P0.2) and signing/store-listing items this phase did not re-investigate (carried over, unresolved, from `BATCH_14_RELEASE_CANDIDATE.md`'s own FINAL OWNER CHECKLIST), neither of which this phase controls.

## 8. Confirmation

- No Flutter source, test, dependency, route, provider, controller, or configuration file was created, edited, or deleted this phase.
- Neither `Career_Buddy_LMS/` nor `royalStaffing_CB01/` was modified — both read-only throughout.
- No signing file, credential, API key, token, or `.properties`/keystore content was printed or exposed — `android/key.properties`'s *existence* was checked (relevant to the login diagnosis's signing-adjacent context) but its contents were never read.
- No account was fabricated, no OTP/authentication was bypassed, and no production request of any kind was made.
- `git status --porcelain` before and after this phase is identical except for the two new files this phase adds.

---

**Phase 33 is complete. No fix was implemented and no Phase 34 work has begun.** Returning both deliverables for review; awaiting explicit approval before any further phase.
