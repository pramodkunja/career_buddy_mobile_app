# Phase 36 — Real-Device Login Verification & Environment Confirmation

## 1. Summary

**The Phase 35 environment fix is confirmed working on a real physical device.** A freshly built debug APK (no `--dart-define=ENV=...` flag — the default, most common way this app is built) was installed on the same physical Android device used in Phase 35 (`RMX5004`, Android 16) and launched fresh. Submitting the login form with deliberately invalid test credentials produced, within ~5 seconds (well inside Dio's 15-second timeout), the response **"Invalid username or password. Please try again."** — a message that can only be returned by the real Django backend after it actually receives and evaluates the request. This is direct, device-level proof that the app now reaches the real production server instead of hanging on the previously-misconfigured dev address.

**Not fully closed**: a successful login with *valid* credentials was not performed. This session has no authorized account password available to it (Phase 35 only observed a real account's credentials already entered on-screen by the user; it never read, logged, or stored the password, and this phase did not request or receive one). Per the task's explicit instruction, no credentials were invented and the user was not asked to paste a password into chat. The invalid-credential test above is the closest safe substitute, and it already proves every component up to and including the backend's own credential check (network reachability, CSRF/session handling, request formatting, response parsing, UI state termination) is functioning correctly — only the final "credentials happen to be valid" branch remains unobserved this phase.

**Debug-preview safety**: confirmed on-device in both directions — visibly present in the debug build, visibly absent (after full source-matching navigation and a full scroll to the bottom of the same screen) in a freshly built **profile** build (which shares `kDebugMode == false` with release, see §6 for why profile was used instead of release).

## 2. Working-tree protection

**Initial status** (before any action this phase): working tree matched the exact state left at the end of Phase 35 — the same modified/untracked files from Phases 24-35's ongoing work (environment.dart, the resume-builder feature set, router/home-screen changes, etc.). No unrelated or unexpected files were present.

**Final status** (after this phase): **identical to the initial status.** Phase 36 made zero additional changes to any source file — it is a verification-only phase, and no reproducible defect requiring a code fix was found. `git status --short` before and after this phase's work match exactly, confirmed by direct comparison.

**Files changed this phase**: none in `lib/` or `test/`. One new file added: this report (`docs/PHASE_36_DEVICE_LOGIN_VERIFICATION_REPORT.md`). Both Django reference directories (`Career_Buddy_LMS/`, `royalStaffing_CB01/`) were not touched — this repository's git root does not even include them.

## 3. Environment evidence

- **Source re-inspected this phase** (`lib/app/config/environment.dart`): confirmed unchanged since Phase 35 — the default (`_envName`'s `defaultValue`) is `'production'`; the `resolve()` switch has explicit `'dev'`/`'staging'` cases with `_ => Environment.production` as the fallback for anything else, including no flag at all.
- **Automated confirmation, all 4 scenarios re-run this phase**:

  | Invocation | Resolves to | Result |
  |---|---|---|
  | `flutter test test/app/config/environment_test.dart` (no flag) | `Environment.production` | 4/4 pass |
  | `--dart-define=ENV=dev` | `Environment.dev` | 5/5 pass |
  | `--dart-define=ENV=production` | `Environment.production` | 4/4 pass |
  | `--dart-define=ENV=staging` | throws a clear `UnsupportedError`, never a fabricated URL | 4/4 pass |

- **Sanitized API host** (no credentials/tokens/cookies involved): the default and explicit-`production` cases resolve `EnvironmentConfig.baseUrl` to `https://careerbuddy4u.com` (HTTPS, not `127.0.0.1`/`localhost`/`10.0.2.2`). `dev` resolves to the emulator-loopback convention only when explicitly requested.
- **Runtime confirmation on the physical device** (§5): the debug build's actual login request reached a real server and received a real, server-computed "invalid credentials" response — this is only possible if the live app is using the production host, not an unreachable local address. This is the strongest possible runtime confirmation short of literally logging the resolved URL (which this diagnosis deliberately avoids adding, consistent with the project's existing no-network-logging posture).

## 4. Device details

- **Physical device**: model `RMX5004`, Android 16 (API 36), connected via USB, the same device used in Phase 35. Serial number omitted from this report per the instruction to avoid unnecessary device identifiers.
- **No emulator was used** — all testing in this phase is physical-device evidence, not emulator-supplemented.
- Connection was briefly interrupted once mid-session (an `adb` daemon hiccup, not a device disconnect) and recovered automatically with `adb kill-server && adb start-server`; the device remained physically connected throughout.

## 5. Login results

| # | Test | Result | Notes |
|---|---|---|---|
| 1 | Launch app from a clean start (fresh debug build, no flag) | **Pass** | Home screen rendered correctly, no crash, no stuck splash. |
| 2 | Navigate to Job Seeker login screen | **Pass** | Reached via the drawer menu; screen rendered correctly with empty fields. |
| 3 | Submit valid credentials, confirm login succeeds and correct authenticated screen opens | **Not tested** | No authorized account credentials available to this session (see §1 and §9). Not invented, not requested from the user in chat, per the task's explicit instruction. |
| 4 | Session persists across app restart | **Not tested** | Depends on test 3 having first produced an authenticated session. |
| 5 | Log out; confirm protected screens are no longer accessible | **Not tested** | Depends on test 3. Existing automated route-guard tests (`test/app/router/route_guards_test.dart`) continue to pass (see §7), which is source/test-level evidence only, not device-level evidence, for this specific behavior. |
| 6 | Submit invalid credentials; confirm a suitable error is shown without exposing sensitive information | **Pass** | Deliberately invalid test values (`phase36_nonexistent_user` / a fabricated password used solely for this negative test, never a real account) were typed into the form and submitted. Within ~5 seconds, the app displayed "Invalid username or password. Please try again." — accurate, no sensitive detail exposed, form fields and button correctly re-enabled afterward. |
| 7 | Observe network failure / timeout handling; confirm the UI does not get stuck indefinitely | **Pass (by direct observation)** | The same submission in test 6 demonstrates the full loading → resolved cycle completing well under the 15-second timeout, with the button and fields properly disabled during the request and re-enabled after. A genuine timeout condition was not separately forced (e.g., by disabling network mid-request), but the now-confirmed-reachable backend made this unnecessary for closing out the original reported symptom. |

No credential was invented for a positive (successful) login attempt. The one negative-test credential pair was chosen to be obviously fake (`phase36_nonexistent_user`) specifically so it could never collide with or resemble a real account, and was never treated as anything other than a negative-path test input.

## 6. Demo-preview safety

- **Source re-inspected** (`lib/features/auth/presentation/screens/login_screen.dart`): the `if (kDebugMode) ...` block around the "Preview Demo (Debug)" button is unchanged since Phase 35.
- **Debug build, on-device**: the button is visibly present at the bottom of the Job Seeker Sign In screen (confirmed by scrolling to it and screenshotting).
- **Non-debug build, on-device**: a **profile** build (`flutter build apk --profile`) was built and installed fresh. Profile mode sets `kDebugMode = false` identically to release mode (the exact condition this button's visibility is gated on), while using **debug signing** by default — this device/machine has no `android/key.properties` configured (confirmed by its absence; this was a read-only check of the build script's own documented fallback logic, no keystore file or value was inspected or touched), so `flutter build apk --release` would also fall back to debug signing, but **profile mode was used anyway, in preference to release, to stay unambiguously clear of this project's standing release/signing restrictions while still testing the exact same `kDebugMode` condition**. After navigating to the identical login screen and scrolling to its very bottom, **no "Preview Demo (Debug)" button or flask icon appears anywhere on screen** — the area where it renders in the debug build is blank in the profile build.
- **Mechanical build-type confirmation**: the profile APK was inspected and found to contain `lib/<abi>/libapp.so` (AOT-compiled) for all three ABIs, with no `kernel_blob.bin`/`vm_snapshot_data`/`isolate_snapshot_data` — the same AOT signature a release build has, confirming this was genuinely not a JIT/debug artifact, independent of the Android-level `DEBUGGABLE` manifest flag (which Flutter sets for both debug *and* profile builds, for native-profiler attachment — a separate, unrelated mechanism from the Dart-level `kDebugMode` constant this button actually checks).
- **No safety gate was weakened or removed.** No file governing this button was modified this phase.
- **Remaining limitation**: a true `--release` build was not built or installed this phase (by design, to stay maximally clear of the signing-related restrictions), so the button's absence was verified via profile mode rather than literal release mode. Given `kDebugMode` is `false` in both profile and release and this button's only gate is `kDebugMode`, this is considered sufficient confirmation without needing to build a release artifact.

## 7. Automated checks

| Command | Result |
|---|---|
| `flutter analyze` | **7 warnings, 0 errors** — identical pre-existing warnings (all in `test/features/resume/...`, all `unused_element_parameter`), no new issues introduced. |
| `flutter test` (full suite) | **2299 passing, 0 failing** — exactly matches Phase 35's final re-verified baseline. No regressions, no change. |
| `flutter test test/app/config/environment_test.dart` × 4 (no flag, `ENV=dev`, `ENV=production`, `ENV=staging`) | All pass — see §3 table. |

No command failed to run. No dependency, build config, or unrelated test file was modified to obtain these results.

## 8. Changes made

**None.** Phase 36 is a verification phase; no reproducible defect requiring a source change was found. The Phase 35 fix (`lib/app/config/environment.dart`'s new default) stands confirmed, unmodified, by the device evidence in §5. The only new file is this report.

## 9. Unverified items

- **A successful login with valid, authorized credentials.** This remains the single open item from Phase 35, now narrowed considerably: every component up to the backend's own credential check is confirmed working (see §1, §5). What's left is specifically "does a *correct* username/password pair complete login and land on the expected authenticated screen" — this requires either the user personally attempting it on the now-reinstalled debug build, or providing a test account through a channel other than this chat (e.g., typing it directly on the device).
- **Session restoration across app restart** and **logout correctly revoking access** — both depend on a successful login first (items 4 and 5 in §5's table) and so remain untested at the device level this phase, though the latter is covered by passing automated route-guard unit tests.
- **A literal `flutter build apk --release` build's debug-preview absence** — not built this phase (profile mode substituted, see §6's rationale); considered low-risk to leave unverified given `kDebugMode` is identical across profile and release.
- Nothing about server-side behavior beyond the login endpoint's credential check was newly verified this phase — all other backend-contract findings carry forward unchanged from prior phases' reports.

## 10. Recommendation

**Single highest-priority next action**: have the user (or an authorized tester) attempt a real login on the device — which now has the fixed debug build reinstalled and ready — using their own account, typed directly on the device rather than shared in chat. If it succeeds, this closes the loop on Phase 35/36's login investigation entirely with full, direct, positive confirmation. If it still fails, the exact error shown should be captured (screenshot, no credentials visible) and treated as a new, distinct finding — since this phase's evidence makes a renewed timeout very unlikely, but does not rule out some other server-side or account-specific issue.

No further implementation work (landing-page redesign, Skill-Up gating, resume-builder features, or any other item from the Phase 35 roadmap) was started, per this phase's own scope boundary. Awaiting approval before Phase 37.
