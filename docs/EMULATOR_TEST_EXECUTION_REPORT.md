# Emulator Test Execution Report — Career Buddy LMS

**Date:** 2026-10-27
**Companion to:** `docs/COMPLETE_WEB_MOBILE_PARITY_AUDIT.md`, `docs/REMAINING_IMPLEMENTATION_ROADMAP.md`

This report documents exactly what was run on a real device, what the actual observed outcome was, and — just as important — what was **not** attempted and why. Every "tested" claim below was produced by physically driving the running app via `adb` and capturing a screenshot; nothing here is inferred from source code alone.

## 1. Emulator environment

- Device: already-running Android Virtual Device, `emulator-5554`.
- Android version: **14 (API 34)**, AVD system image `sdk_gphone64_arm64`.
- Screen: 1080×1920, 420 dpi (`wm size` / `wm density`).
- Storage at test time: ~875 MB free of the emulator's allotted space (`df /data`) — sufficient for the install, not touched further.
- The emulator was **pre-existing and already running** — it was not created, wiped, or factory-reset for this task, per the task's explicit constraint.
- A second, unrelated app (`com.royalhrms.app`, belonging to a different, concurrently-running Claude Code session on the same machine) was in the foreground when this testing began. It was left untouched; only the Career Buddy LMS package was interacted with.
- A stale package `com.example.career_buddy_lms` from an older, unrelated build was also present on the device. It was not touched, removed, or interacted with.

## 2. Build and install

Command run:
```
cd "Mobile_app" && flutter run -d emulator-5554 --debug
```
No `--dart-define` flags were passed (see §3 for why this matters), no signing configuration was touched (a plain debug build uses Flutter's own debug keystore, never the release config), and no other emulator/app was modified.

**Actual output (verbatim, relevant excerpt):**
```
Running Gradle task 'assembleDebug'...                             41.4s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing build/app/outputs/flutter-apk/app-debug.apk...           3.1s
...
Syncing files to device sdk gphone64 arm64...                      856ms

Flutter run key commands.
...
A Dart VM Service on sdk gphone64 arm64 is available at: http://127.0.0.1:63087/...
```
- Build: **successful**, 41.4s.
- Install: **successful**, 3.1s.
- Launch: **successful** — the process started with no exceptions and no crash. A single informational line (`Choreographer: Skipped 300 frames!`) appeared, indicating one moment of main-thread jank during startup, not a crash or error.
- One pre-existing, unrelated build warning was printed: the `flutter_tts` plugin still applies the legacy (non-built-in) Kotlin Gradle Plugin mechanism, which Flutter has deprecated. This did not block the build and is a third-party plugin's own compatibility note, not an app-code issue.
- Package confirmed installed via `adb shell pm list packages`: **`com.sriainfotech.career_buddy_lms`** — matches the project's configured `applicationId`.

## 3. Safety-critical environment finding

`lib/app/config/environment.dart` defaults to `Environment.production` (`https://careerbuddy4u.com`) whenever no `--dart-define=ENV=...` flag is supplied. Since none was supplied for this test run, **every network request made by the app during this test session targeted the real, live production backend**, not a sandbox or local server.

Because of this, and in direct compliance with the task's explicit restrictions (no real payments, no production-data mutation, no invented credentials, no login bypass), testing in this session was deliberately limited to **read-only navigation and viewing**:
- No login was attempted with any credential, because no authorized test account was available or provided.
- No form (resume builder, employer job posting, registration, OTP) was submitted.
- No chat message was sent to the AI chatbot — only the panel opening/UI was observed.
- No job application, job posting, or payment action was triggered.

This constraint is the single biggest reason several of the 15 `CB_changes.docx` items and several screens remain **BLOCKED** for live confirmation in the parity audit — not because they couldn't be reached, but because reaching their actual logic safely requires a real account.

## 4. Tested flows and actual outcomes

All screenshots referenced below are at `docs/audit_evidence/screenshots/` in this repository.

| # | Action performed | Actual observed outcome | Screenshot |
|---|---|---|---|
| 1 | Cold launch, wait ~5s | Landing page loaded; IT/Non-IT choice popup appeared automatically within the expected window | `01_initial_launch.png` |
| 2 | Tap "IT Job Seeker" | Navigated to the IT department list | `02_after_it_job_seeker_tap.png` |
| 3 | Tap "Development" department | Navigated to a role list (e.g. Software Developer, Python Developer, etc.) | `03_development_roles.png` |
| 4 | Tap a role | A 3-action popup appeared ("Skills", "Build Resume", "Resume Parsing & Interview") | `04_role_popup.png` |
| 5 | Tap "Skills" | Navigated to a skills list for that role, rendered correctly | `05_skills_list.png` |
| 6 | Back-navigate, reopen a role popup, tap "Build Resume" | Cleanly redirected to the Job Seeker Sign In screen (no crash, no error) | `06_build_resume.png` |
| 7 | Press hardware/software back | Returned correctly to the prior screen (department/role list), no stack corruption observed | `07_after_back.png` |
| 8 | Reopen the role popup | Popup re-rendered correctly from a fresh tap | `08_popup_reopened.png` |
| 9 | Tap "Resume Parsing & Interview" | **Did not navigate.** Instead showed a red inline message: "Your session has expired. Please sign in again." (See Issue AUDIT-01 in the parity audit — this contrasts with "Build Resume"'s clean redirect, even though neither user was ever signed in to begin with.) | `09_resume_parsing_tap.png` |
| 10 | Observe the same screen after the message appeared | Message persisted, no crash | `10_resume_parsing_screen.png` |
| 11 | Wait/settle | Screen remained stable, no further errors | `11_resume_parsing_screen_settled.png` |
| 12 | Back-navigate to the landing page | Returned cleanly | `12_back_to_landing.png` |
| 13 | Tap "Create Resume" on the landing page | Opened the guest resume builder with **no login prompt** — confirms CB_changes Item 4's guest-access claim is a real PASS for this specific sub-behavior. Form was opened, not filled in or submitted. | `13_create_resume_tap.png` |
| 14 | Tap "Find Jobs" | Redirected to the Job Seeker Sign In screen (same clean pattern as "Build Resume") | `14_find_jobs.png` |
| 15 | Open the navigation drawer | Rendered correctly in the logged-out state, confirmed only 4 of the expected Skill-Up mega-menu entries are present (see CB_changes Item 2 PARTIAL finding) | `15_nav_drawer.png` |
| 16 | Tap the floating AI chatbot button | Chat overlay opened with a greeting, language selector, mic icon, and contextual action chips. No message was sent. | `16_chatbot_tap.png` |

No crash, ANR (app-not-responding), or unhandled exception occurred across any of these 16 interactions. No `adb logcat` error-level entries referencing the app's own package were observed during this sequence (only the informational/warning lines already quoted in §2).

## 5. Flows explicitly NOT tested live, and why

- **Any authenticated student flow** (dashboard, activities, mock tests, Skill-Up lessons, JAM, group discussion, resume history, manual resume builder, grammar, roleplay, subscription purchase): not reached, because no authorized test account/credential was available. All assessment is source-based only for these areas (see the parity audit's PASS/PARTIAL/BLOCKED table).
- **Employer job posting** (the subject of Phases 52-65 and CB_changes Item 5): not exercised live for the same reason — no authorized employer test account was available. All verification of this flow is via the 348-test automated suite plus direct source reading, not a live device session.
- **OTP send/verify, registration, password reset**: not attempted, since each requires a real inbox/phone number and would be a production-affecting action.
- **Payment (Razorpay)**: not attempted under any circumstance, per the task's explicit restriction on real payments.
- **Sending an actual message to the AI chatbot**: not attempted, to avoid any state-changing production call; only the overlay's static UI was observed.
- **Rotation/orientation testing**: not performed — not needed to evaluate any of the flows actually reached.

## 6. Automated test and static-analysis results (actually executed this session)

```
$ flutter analyze
Analyzing Mobile_app...
No issues found! (ran in 8.4s)
```

```
$ flutter test
...
04:20 +2710: All tests passed!
```

**2,710 tests passed, 0 failed.** This matches the figure already recorded in this repo's own `docs/PHASE_65_REMAINING_TEXT_VALIDATION_REPORT.md`, independently re-confirmed by actually re-running the full suite in this session (not merely read from that prior report). No test was skipped, modified, or added to produce this result.

No build-only check beyond `flutter analyze` and the debug `flutter run` build itself (§2) was run — a release build was intentionally not attempted, per the task's restriction against touching signing configuration.

## 7. Summary: what was confirmed on a real device vs. inferred from source

- **Confirmed on real device, this session:** app builds, installs, and launches without error on Android 14; the landing page, IT career-path browsing, role popups, guest Create Resume, the two "requires sign-in" redirects, the inconsistent third "session expired" message, the nav drawer's incomplete menu, and the chatbot overlay's static UI.
- **Inferred from source only (not live-tested this session or confirmed in any earlier phase):** every authenticated student/employer flow, OTP/registration/password-reset, payment, and the specific rendering of Skill-Up WebView lesson content.
- No evidence in this repository (across all `docs/PHASE_*` and `docs/W0*` reports, checked by directory listing) shows that any phase prior to this one ever launched the compiled app on a device either — this is the **first** recorded live-device test pass for this project.
