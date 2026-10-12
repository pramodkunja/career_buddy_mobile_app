# Pre-Update Baseline Report (Phase 0)

Purpose: a factual snapshot of both repositories and the Flutter app's
current implementation **before** the web application's updated code is
received, so later phases can distinguish "this changed because the web
app changed" from "this was already true." No application code was
changed to produce this report; no build, deploy, or backend action was
performed.

## 1. Documentation read this phase

Re-read in full before writing anything below: `docs/WEB_MOBILE_GAP_ANALYSIS.md`,
`docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md`, `docs/PHASE_5_REGRESSION_REPORT.md`,
`docs/PHASE_6_READINESS_REPORT.md`, `docs/PHASE_7_RELEASE_SIGNING_REPORT.md`,
`docs/PHASE_8_RELEASE_READINESS_CHECKLIST.md`,
`docs/PHASE_9_RELEASE_VERIFICATION_REPORT.md`,
`docs/PHASE_10_TEST_ENVIRONMENT_AND_QA_REPORT.md`,
`docs/PHASE_11_MANUAL_QA_REPORT.md`. All nine were present. Their
conclusions are summarized in §6 rather than repeated in full.

## 2. Git status, branches, and recent commits — both repositories

### Mobile_app (this project — read/write)
- Branch: `main`, tracking `origin/main` (`pramodkunja/career_buddy_mobile_app`),
  **0 ahead / 0 behind** — fully in sync with the remote, nothing to pull.
- Last commit: `03964b6` ("Protected media downloads, Candidate CSV, Grammar
  illustrations, HTML entity cleanup, cross-account isolation, and
  file-open crash fix"), dated 2026-10-08. 4 commits total on this branch's
  visible history (`62f80d7` initial commit → `961cda3` → `b3c172f` →
  `03964b6`).
- Working tree: **unchanged from the end of Phase 11** — same 11 modified
  tracked files and same 12 untracked paths as every prior phase's closing
  status (full list in §3). Nothing was reset, stashed, or committed to
  produce this report.

### Career_Buddy_LMS (web reference — read-only)
- Branch: `main`, tracking `origin/main` (`srinivas1543/Career_Buddy_LMS`),
  **0 ahead / 0 behind**. `origin/dev` and `origin/main` point at the same
  history (no diff either direction) — re-confirms Phase 1's original
  finding that dev and main are not meaningfully diverged.
- Last commit: `3d4a1ba` (a merge of `dev` into itself), dated
  **2026-09-17** — i.e. no new commits have landed in this repo across the
  entire engagement so far (Phases 1–11 all observed the identical
  commit). This is the exact pre-update state this baseline is meant to
  capture.
- Working tree: the same pre-existing, uncommitted work present since
  Phase 1 — **3 modified files** (`activities/urls.py`, `activities/views.py`,
  `business_english_lms/urls.py`) and **3 untracked files**
  (`activities/tests_activities_api.py`, `activities/tests_dashboard_api.py`,
  `activities/tests_mcq_exercise_api.py`) — a JSON `dashboard_api`/`activities_api`
  contribution, unrelated to subscription work, never committed by anyone
  across this engagement. **Not touched, read beyond what prior phases
  already documented, or relied upon.**

## 3. File inventory — modified, untracked, ignored-sensitive, pre-existing

**Mobile_app — modified (tracked, uncommitted)**: `android/app/build.gradle.kts`,
`ios/Runner.xcodeproj/.../Package.resolved`, `ios/Runner.xcworkspace/.../Package.resolved`,
`lib/app/router/app_router.dart`, `lib/app/router/route_guards.dart`,
`lib/core/network/api_endpoints.dart`, `pubspec.lock`, `pubspec.yaml`,
`scripts/build_release.sh`, `test/app/client_flow_test.dart`,
`test/app/router/route_guards_test.dart`, `test/shared/widgets/buddy_chatbot_overlay_test.dart`
— all attributable to Phases 2–7 of this engagement (routing fix, subscription
module wiring, ARIA test additions, release-signing guard script), none
reverted or altered this phase.

**Mobile_app — untracked (new, uncommitted)**: `docs/ANDROID_RELEASE_SIGNING.md`,
`docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md`, `docs/PHASE_5_REGRESSION_REPORT.md`,
`docs/PHASE_6_READINESS_REPORT.md`, `docs/PHASE_7_RELEASE_SIGNING_REPORT.md`,
`docs/PHASE_8_RELEASE_READINESS_CHECKLIST.md`,
`docs/PHASE_9_RELEASE_VERIFICATION_REPORT.md`,
`docs/PHASE_10_TEST_ENVIRONMENT_AND_QA_REPORT.md`,
`docs/PHASE_11_MANUAL_QA_REPORT.md`, `docs/WEB_MOBILE_GAP_ANALYSIS.md`,
`lib/features/subscription/` (full module), `scripts/build_release_aab.sh`,
`test/features/subscription/` (full test module). This report adds one more:
`docs/PRE_UPDATE_BASELINE_REPORT.md`.

**Mobile_app — ignored (git-ignored, build/IDE noise, as expected)**:
`.DS_Store`, `.dart_tool/`, `.flutter-plugins-dependencies`, `.idea/`,
`android/.gradle/`, `android/app/src/main/java/` (generated), `android/gradle/wrapper/gradle-wrapper.jar`,
`android/gradlew`(`.bat`), `android/local.properties`, `build/`, `*.iml`,
`ios/.symlinks/`, `ios/Flutter/Generated.xcconfig`, `ios/Flutter/ephemeral/`,
`ios/Flutter/flutter_export_environment.sh`, `ios/Pods/`,
`ios/Runner/GeneratedPluginRegistrant.{h,m}` — all routine, expected, and
unremarkable.

**One ignored file is not routine and is flagged explicitly**:
`android/key.properties` **now exists** (142 bytes, modified timestamp
2026-10-12 12:13, i.e. created sometime between Phase 11's close and this
phase's start — Phase 7, 8, 9, 10, and 11 each independently and
explicitly confirmed this file was absent). This is exactly the file
`docs/ANDROID_RELEASE_SIGNING.md` describes as needing to be created by
"whoever holds signing authority for this app," containing the production
keystore path and passwords. **This report does not read, print, or
otherwise inspect its contents** — only its existence and modification
time were checked (`ls -la`), and `git check-ignore -v` re-confirmed it is
still correctly excluded from Git. No `.jks` keystore file appeared
alongside it in this repository or the home directory's existing (still
unattributed, still unused) keystores. **This is a material change to the
Android signing blocker's status described in Phases 7–9** and should be
verified directly with whoever created it before any phase attempts a
release build again — this report only records that it now exists.

**Career_Buddy_LMS — modified/untracked/ignored**: as listed in §2 and the
ignored-file list (`.env`, all `__pycache__/` dirs, `docs/` — the web
repo's own separate, gitignored `docs/` folder, distinct from Mobile_app's
tracked one — `logs/`, `media/`, `venv/`). All consistent with every prior
phase's observation; nothing new found here.

## 4. Current Flutter implementation inventory

**Feature modules** (`lib/features/`, 25 total): `activities`, `ai_listening`,
`ai_reading`, `ai_speaking`, `ai_writing`, `aria_chat`, `auth`, `bingo`,
`certifications`, `dashboard`, `employer`, `fill_blank`, `generic_writing`,
`grammar`, `group_discussion`, `home`, `jam`, `matching`, `mock_interview`,
`mock_tests`, `resume`, `roleplay`, `skill_up`, `splash`, `subscription`,
`timer_exercise`. `lib/` top level is otherwise `app/` (router, theming,
config), `core/` (network client, errors, shared utils, and the `demo/`
preview affordance noted below), and `shared/` (reusable widgets).

**Routing**: `lib/app/router/route_paths.dart` defines **66** named route
constants. Exactly **one** route (`RoutePaths.jobDetail`) still resolves to
a bare `ComingSoonScreen` placeholder in `app_router.dart` — every other
route maps to a real, built screen. This is the only remaining "screen
doesn't exist yet" gap found; it is not evaluated further here (no claim of
completeness or priority is made — that is explicitly out of scope for a
baseline-only phase).

**Preview/demo/testing affordance** (relevant to this engagement's stated
longer-term goal of eventually removing obsolete demo scaffolding, **not
acted on this phase**): `lib/core/demo/demo_entry_screen.dart`, surfaced to
a user via a "Preview Demo (Debug)" link on `login_screen.dart`. Confirmed
in Phase 10 to render client-side mock data only (zero backend requests)
and to be reachable only from a debug build. Recorded here as existing and
identified; no judgment is made yet about whether it is still needed —
that determination explicitly requires proving it unnecessary first, which
is future-phase work, not this one.

**API configuration**: `lib/core/network/api_endpoints.dart` is **1,014
lines**, the single source of truth for every backend path constant used
across all feature modules (session-cookie auth via `ApiClient`, confirmed
unchanged in structure since Phase 3's discovery work).

**Test inventory**: **267** test files under `test/`, together comprising
**1,885** individual test cases (see §5 for the freshly-executed count).

## 5. Automated test and analysis baseline — executed this phase, not historical

Per the task's instruction to record this only if actually run: both were
executed fresh, this phase, immediately before writing this report (not
copied from a prior phase's report):

- `flutter analyze`: **clean, no issues** (ran in ~2.8s).
- `flutter test` (full suite): **1885/1885 passing**, 0 skipped, 0 failing.

This matches the figure every phase since Phase 6 has reported, confirming
no regression has crept in across Phases 7–11's work (signing-script
changes, documentation-only phases, and the live manual-QA session) — but
it is reported here as a **freshly re-executed, current result**, not an
inherited one.

## 6. Prior findings — summarized, not re-litigated

- **Web/mobile gap analysis (Phase 1)**: Home entry-routing gap (fixed,
  Phase 2) and Subscription (total gap at the time, closed in Phase 3) were
  the two real, actionable gaps found; ARIA bot navigation and
  welcome/related-questions already matched production.
- **Subscription (Phase 3)**: no JSON endpoint exists for current
  plan/expiry status (still true — re-confirmed in Phase 11); the
  `razorpay_flutter` package and form-urlencoded request contract were
  verified directly against Django source, not guessed.
- **Regression audit (Phase 5)**: "PASS WITH DOCUMENTED LIMITATIONS" —
  zero regressions found across all five user journeys; six items
  classified by blocker type.
- **Phase 6 readiness**: one real, confirmed Flutter defect found and
  fixed this engagement — a duplicate-tap race in
  `SubscriptionCheckoutController.startCheckout`, reproduced with a failing
  test before the fix, regression-tested after.
- **Release signing (Phases 7–9)**: both release build scripts now refuse
  to silently debug-sign a "production" artifact; no authorized production
  keystore existed as of Phase 9 — **superseded by §3's finding above**,
  which must be reconciled before this is treated as still accurate.
- **Manual QA (Phases 10–11)**: a real local Android emulator and Django
  dev server were stood up (and, per §2/§3, **remain running right now** —
  PID 56123 for the Django server, PID 55429 for the `Pixel_9a` emulator,
  confirmed alive at the time of writing this report); ARIA chat, route-guard
  redirects, and login error-handling were confirmed working end-to-end
  against a live backend. Six of ten QA checklist items remain BLOCKED for
  one concrete, documented reason: no authorized test account exists or
  was obtainable (OTP email verification requires real SMTP delivery to a
  mailbox this engagement cannot access, and looking up existing users'
  credentials is correctly blocked as a PII-handling matter). The ARIA TTS
  endpoint's `400` response was root-caused to a missing
  `SARVAM_API_KEY` in this machine's local `.env` — a local configuration
  gap, not a Flutter defect — without reading the key's actual value.

## 7. Known limitations going into Phase 1

Carried forward, unchanged by this phase:
1. No subscription-status JSON endpoint (backend-owned).
2. No valid test account for authenticated manual QA (needs an approved
   test mailbox or directly-provided credentials from someone authorized
   to give them).
3. Android production signing — **status now uncertain**, not
   "still blocked": `android/key.properties` appeared during this
   engagement (§3) but has not been verified, built against, or confirmed
   authorized by anyone in this session. The next phase that touches
   signing must confirm with the signing authority whether this file is
   real/authorized before relying on it, rather than assuming either that
   it works or that it doesn't.
4. No physical iOS device available (offline throughout the engagement).
5. ARIA audio-stall watchdog remains an open product decision, not an
   engineering gap — untouched, per every prior phase's instruction.
6. `RoutePaths.jobDetail` is the one remaining route still mapped to a
   placeholder screen.
7. `lib/core/demo/demo_entry_screen.dart` (the debug-only preview
   affordance) still exists and has not yet been evaluated for removal.

## What this phase did not do

No source file was edited. No file was reset, stashed, discarded, or
committed. No backend code, API, migration, or seed data was created or
changed. No APK/AAB was built. No deployment of any kind occurred. The
`android/key.properties` discovery in §3 was recorded by checking existence
and timestamp only — its contents were never opened, read, or referenced.

## Status

Baseline captured. Both repositories are exactly where every prior phase
left them, with one exception requiring attention before any future
release-signing work: `android/key.properties` now exists and its
authenticity/authorization has not been confirmed. Awaiting approval before
Phase 1.
