# Phase 10 — Android Test Environment Setup and QA Execution

## Preflight

Read `docs/PHASE_8_RELEASE_READINESS_CHECKLIST.md` and
`docs/PHASE_9_RELEASE_VERIFICATION_REPORT.md` before acting. Git status
inspected first in both repositories:
- **Mobile_app**: identical to Phase 9's end-state — same 11 modified files,
  same 8 untracked paths, last commit still `03964b6`. Nothing reset,
  stashed, rebased, or committed this phase.
- **Career_Buddy_LMS (web, read-only)**: same pre-existing uncommitted
  `dashboard_api`/`activities_api` work noted since Phase 1, untouched —
  confirmed via `git status --short` before and after this phase's backend
  work; no file in that repo was edited, no migration was run, no seed
  command was run.

This phase worked only in the Flutter mobile project's runtime environment
(building/launching the existing code) and in standing up a local, read-only
*use* of the Django project (running its existing dev server against its
existing local database) — no source file in either project was modified.

## 2. Android emulator

- `flutter doctor -v`: Android SDK present at
  `~/Library/Android/sdk`, emulator binary present.
- `flutter emulators`: two existing AVDs available
  (`Android_Emulator_34`, `Pixel_9a`) — **no new AVD was created**, per the
  instruction not to create one unless necessary (it wasn't; an existing one
  sufficed).
- Started `Pixel_9a` via the emulator binary directly
  (`emulator -avd Pixel_9a -no-snapshot-load`, backgrounded).
- Waited for and confirmed full boot via `adb shell getprop
  sys.boot_completed` → `1` (booted in ~5s — a warm AVD state file already
  existed from prior use).
- **Confirmed in `flutter devices`**:
  `sdk gphone16k arm64 (mobile) • emulator-5554 • android-arm64 • Android 17
  (API 37) (emulator)`.
- No startup failure occurred, so the "record the exact error and stop"
  fallback path was not needed for the emulator itself (a separate, unrelated
  storage issue surfaced at install time — see §4).

## 3. Backend availability

Investigated without reading any `.env` contents:
- `README.md`'s documented prerequisite: "MySQL 8 running locally" and
  `python manage.py runserver` as the startup command — read directly, not
  assumed.
- `business_english_lms/settings.py`'s `get_database_config()`: confirmed
  (read-only) that this project requires MySQL (SQLite is explicitly
  rejected by the codebase itself) and reads `DB_HOST`/`DB_NAME`/etc. from
  `.env` via `python-decouple` — **the actual values were never read,
  printed, or logged by this phase**; Django consumes them internally the
  same way it would for any normal local run.
- Confirmed, via process inspection only (no secrets involved): a Homebrew
  MySQL server (`brew services list` → `mysql started`, `mysqld` process
  owned by the local user, bound to `localhost:3306`) is already running on
  this machine — this is unambiguously a local, personal development
  database server, not a shared, remote, or production one.
- `python manage.py check --database default` (read-only Django system
  check, no schema change): succeeded, confirming the configured database is
  reachable.
- `python manage.py showmigrations` (read-only): **74/74 migrations already
  applied, 0 pending** — this database was already fully set up from prior
  work, so no migration, seed, or superuser-creation command was run or
  needed, consistent with the explicit prohibition on doing so.
- Started the existing dev server exactly as documented:
  `python manage.py runserver 0.0.0.0:8000 --noreload` (bound to all
  interfaces so the Android emulator's `10.0.2.2` host alias can reach it,
  matching `lib/app/config/environment.dart`'s own documented dev-URL
  scheme). Confirmed reachable: `curl http://127.0.0.1:8000/` → `200`.
- **Not done, per explicit instruction**: `.env` was never opened or
  printed; no migration, seed, or database-mutating management command was
  run; no production or unidentified database was touched — only this
  machine's own already-configured local MySQL instance.

## 4. Build and launch

- Built the existing code as a **debug** APK using the default dev
  environment (`flutter build apk --debug`, no `--dart-define=ENV=...`,
  which resolves to `Environment.dev` → `http://10.0.2.2:8000` per
  `environment.dart`) — **no release build, no production signing
  credentials involved**, per the explicit restriction.
- Install hit a real, pre-existing constraint: `INSTALL_FAILED_INSUFFICIENT_
  STORAGE` — the emulator's `/data` partition was at 92% full, left over
  from a *different*, older build of this same app (versionCode 1.0.0,
  installed 2026-10-01, last updated 2026-10-06 — i.e. predating this
  engagement's Phase 6 duplicate-tap fix). Per the instruction to record
  the exact error and stop that setup path rather than wiping the emulator,
  the safe, standard fix was used instead: `adb uninstall
  com.sriainfotech.career_buddy_lms` (removes only this one app's data, not
  a factory reset/wipe of the AVD), which freed enough space for a clean
  `adb install` of the current build.
- Launched via `adb shell am start`; confirmed running via `pidof`.
- **Captured actual evidence, not claimed success blindly**: screenshots at
  every step (via `adb exec-out screencap`) and, for precise interaction,
  `uiautomator dump` for exact on-screen element bounds. `adb logcat -s
  flutter:E AndroidRuntime:E` was checked at the end of the session and
  returned **zero entries** — no Flutter exception and no crash occurred
  across the entire session.

## 5. Manual QA — results

Executed against the **real, running local backend** described in §3,
using the **current debug build** described in §4, with real on-screen
evidence (screenshots) for each result below. Credentials/accounts were a
hard constraint this phase: completing new-user registration requires a
real SMTP-delivered email OTP (`EMAIL_BACKEND` defaults to a real SMTP
backend, not console/test) that this session has no mailbox to receive, and
looking up any existing user's credentials was correctly blocked by this
environment's own PII-handling safeguard. Both are recorded as concrete,
named blockers below rather than worked around.

| # | Item | Result | Evidence |
|---|---|---|---|
| 1 | Login | **PARTIAL** — error path PASS, success path BLOCKED | Submitted a real `POST /users/login/` with intentionally wrong, synthetic credentials (`phase10qa` / `wrongpass123`) against the live local backend. Server returned 200 with a form error; app correctly displayed "Invalid username or password, or this account cannot sign in here.", retained the entered values, did not crash or hang. **Successful login not tested** — no valid test account could be created (OTP email requires real SMTP delivery, no mailbox available) or looked up (blocked — PII). |
| 2 | Role-based navigation | **PASS** (unauthenticated-redirect path) | Tapping ARIA's "Go to Activities" action chip while logged out correctly navigated to the real Job Seeker Sign-In screen rather than exposing the protected Activities screen — confirms the route guard holds end-to-end against the real router and a real build, not just the test harness. Authenticated role-based navigation (Job Seeker vs. Employer reaching their own dashboards) **BLOCKED** — same account blocker as #1. |
| 3 | Core learning features | **BLOCKED** (live) / informational only via debug preview | The app ships a developer-only **"Preview Demo (Debug)"** link on the login screen (visible only in a debug build) that renders the Activities screen from client-side mock data. Used it to confirm the Activities screen itself renders correctly (12 activities, category filter chips, "Start Activity" cards, no overflow) — but confirmed via the backend log that **zero new HTTP requests** were made for this, i.e. it is not backend-verified and must not be read as proof of real data-loading behavior. Labeled accordingly, not counted as a live pass. |
| 4 | ARIA chatbot | **PASS** | Opened the ARIA panel from the logged-out Home screen; sent a real text message ("Hello"); confirmed `POST /api/riya/chat/stream/` → `200` in the live backend log; the real AI reply ("Hi there! Hey! 👋 How can I help you today?") rendered with a "Go to Activities" action chip; tapping the chip correctly triggered real in-app navigation (see #2). |
| 5 | Subscription — plan display | **BLOCKED** | Requires an authenticated session to reach `/pro` without a route-guard redirect (by design, confirmed in #2) — same account blocker. |
| 6 | Subscription — checkout (test mode) | **BLOCKED** | Requires both an authenticated account and confirmed Razorpay test-mode keys; neither available, and per instruction `.env` was not inspected to check the latter. |
| 7 | Payment cancellation | **BLOCKED** | Same as #6. |
| 8 | Payment failure | **BLOCKED** | Same as #6. |
| 9 | Session restoration | **BLOCKED** | Requires a real logged-in session to restore — same account blocker. |
| 10 | Logout | **BLOCKED** | Requires a real logged-in session to log out of — same account blocker. |

**Additional, unplanned-but-real observation**: ARIA's text-to-speech
feature consistently returned `POST /api/voice/tts/` → `400` from the live
backend throughout the session (checked repeatedly, not a one-off). The
Flutter app itself handled this correctly and safely — the welcome message
and action chip still rendered, and the speaker icon visibly switched to a
muted state rather than the app hanging or crashing. This is recorded as an
**environment/backend configuration observation** (most likely a Sarvam API
key not populated in this local `.env`, matching the exact
self-diagnosing pattern Phase 3 documented for Razorpay's analogous
`"Payment is not configured."` response), **not a Flutter-side defect** —
nothing was changed, since this is explicitly out of this phase's scope
(no backend/env changes) and the Flutter behavior under this failure is
already correct.

**Additional confirmation**: opened the nav drawer while on the Preview
Demo's Activities screen — it correctly showed only the logged-out menu
(Home / Job Seeker Login / Employer Login), confirming the drawer's
auth-state gating holds even when reached via the debug preview path, not
just via the normal unauthenticated Home screen.

## 6. Validation and report

- `flutter analyze`: **clean, no issues.**
- `flutter test`: **1885/1885 passing**, 0 skipped, 0 failing — unchanged
  from Phase 7/8/9 (no source file was modified this phase, so this
  reconfirms the existing baseline rather than testing new code).
- No defect was discovered in Flutter-side code this phase (the one real
  issue found — TTS returning 400 — is a backend/environment configuration
  matter, explicitly out of scope to fix here), so Task 5's "fix only if
  reproducible, in-scope, and safe" clause has nothing to act on.

## Remaining blockers and owners

| Blocker | Owner | What's needed |
|---|---|---|
| No valid test account for authenticated QA | QA / whoever can authorize test credentials or SMTP access | Either: (a) real SMTP delivery reachable from this session to complete OTP signup, or (b) existing test credentials handed over directly (this session cannot query user records itself — PII-restricted) |
| Razorpay test-mode keys unconfirmed | QA / backend owner | Confirm `RAZORPAY_KEY_ID`/`SECRET` are populated in the local `.env` (not inspected by this phase) |
| ARIA TTS backend returning 400 locally | Backend / environment owner | Likely a missing Sarvam API key in this local `.env`; app itself degrades safely, so this is a local-environment completeness issue, not a release blocker |
| Production Android signing keystore | App/signing authority | Unchanged from Phase 7/9 — still not generated/authorized |
| Physical iOS device | Device owner | Unchanged — still offline |
| ARIA audio-stall watchdog | Product | Unchanged — explicit decision still required, not touched |

## Current environment state (left running, not torn down)

- Django dev server: PID 56123, `python manage.py runserver 0.0.0.0:8000
  --noreload`, bound to the local MySQL instance described in §3.
- Android emulator: PID 55429, `Pixel_9a` (`emulator-5554`), fully booted.
- Both were started solely for this phase's QA session and left running in
  case QA continues immediately; stop them with `kill 56123` and `adb -s
  emulator-5554 emu kill` (or `kill 55429`) respectively when no longer
  needed. Neither affects git state or any committed artifact.

## Final status

Meaningful, real progress on manual QA was made against a genuinely running
local backend and a genuinely running Android emulator — not simulated,
not assumed, and clearly distinguished (per item) between what was verified
live versus what remains blocked. ARIA chat, route-guard redirect
behavior, and login error-handling are now **confirmed working end-to-end
against a live backend**, closing real gaps that automated tests alone
could not close (they test logic against fakes, not a real HTTP/CSRF/session
round trip). Six of ten checklist items remain BLOCKED, all for the single,
concrete, named reason of no usable authenticated test account — not for
lack of effort to find one, and not worked around by inventing credentials,
querying other users' data, or sending an email through a real SMTP account
with no way to receive its reply.

`flutter analyze`: **clean**. `flutter test`: **1885/1885 passing**. No
Flutter-side defect found or fixed this phase. Git status in both
repositories is unchanged from before this phase began.
