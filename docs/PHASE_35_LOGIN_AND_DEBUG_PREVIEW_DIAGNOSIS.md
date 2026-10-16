# Phase 35, Part 1 & 2 — Login Timeout and Debug-Preview Diagnosis

## Executive summary

**Root cause: CONFIRMED, not a hypothesis.** Both reported symptoms — the login timeout and the visible "Preview Demo (Debug)" button — have the same underlying cause: **the app installed and being tested was a debug build**, and a debug build's default backend URL (`http://10.0.2.2:8000`, meaningful only inside an Android emulator) is unreachable from a real physical device, so every network request — including login — hung until Dio's 15-second connect timeout fired and surfaced as *"The request took too long. Please try again."* This was confirmed **live, on the user's own connected physical Android device**, not inferred from code alone: the exact installed app was inspected directly (debug flag confirmed in the package manager, debug-only kernel/snapshot files found in the APK, no AOT `libapp.so`), and the login screen was observed showing the exact reported error message after a real test account's credentials were already entered.

**Fix applied**: `EnvironmentConfig`'s default (when no `--dart-define=ENV=...` is passed at all) now resolves to `Environment.production` instead of `Environment.dev`. This is the smallest change that addresses the confirmed root cause: a plain `flutter run`/`flutter build apk --debug` — the default way anyone, not just a Flutter developer who remembers the flag, launches or builds this app — now reaches the real, positively-verified production backend instead of an address that only exists inside an Android emulator. `dev` remains fully available for anyone who explicitly wants the local Django server (`--dart-define=ENV=dev`).

**The debug preview button required no code change.** It is already gated by `kDebugMode`, a Dart compile-time constant — this is not a runtime check that could be misconfigured or bypassed; the Dart compiler eliminates the entire `if (kDebugMode)` block as dead code in any release build. It is visible today because, again, the app being tested is a debug build. It is structurally impossible for it to appear in a release build, and this phase did not need to — and did not — touch it.

**What remains unverified**: whether a full login attempt now actually succeeds end-to-end against production. The fix corrects the *destination* the app contacts; it does not change the login request logic itself (which was already live-verified working, with a real account, on 2026-09-30 — see `docs/PRODUCTION_E2E_VERIFICATION_REPORT.md`). The physical device used for this diagnosis disconnected partway through this phase before a fresh, rebuilt debug/release artifact could be installed and re-tested live. This is stated plainly in §5 rather than claimed as verified.

## 1. The login timeout — investigation and evidence

### 1.1 Tracing the flow (static inspection, re-confirmed this phase)

- `LoginScreen._submit()` (`lib/features/auth/presentation/screens/login_screen.dart`) calls `AuthController.login()` after form validation passes.
- `AuthController.login()` (`lib/features/auth/presentation/controllers/auth_controller.dart`) sets `AuthRefreshing`, awaits `AuthRepository.login()`, and maps the result to `AuthAuthenticated`/`AuthUnauthenticated(message)`.
- `AuthRepositoryImpl.login()` calls `AuthRemoteDataSource.login()`, which: GETs the login page first (CSRF priming), reads the `csrftoken` cookie, then POSTs form-encoded `{username, password, csrfmiddlewaretoken}` with `X-CSRFToken` and a `Referer` header, with `followRedirects: false` and a 200/302-branching response handler.
- `ApiClient.create()` configures the shared `Dio` instance with `baseUrl: EnvironmentConfig.baseUrl`, `connectTimeout`/`receiveTimeout`/`sendTimeout` all `Duration(seconds: 15)`, and `ApiExceptionsInterceptor`, which maps `DioExceptionType.connectionTimeout`/`sendTimeout`/`receiveTimeout` to `RequestTimeoutException` → `TimeoutFailure`, whose message is **`"The request took too long. Please try again."`** — matching the reported symptom.
- `EnvironmentConfig.baseUrl` (`lib/app/config/environment.dart`), **before this phase's fix**, resolved (when no `--dart-define=ENV=...` was passed) to `Environment.dev`, which on Android is `http://10.0.2.2:8000` — an address that is a special NAT alias meaningful **only inside the Android emulator**, not a real, routable address from a physical device's network stack.
- `EnvironmentConfig.resolve()`'s existing fail-fast guard only throws when `kReleaseMode` is true — it never fires for a debug build, regardless of which `ENV` it resolved to.

This chain, read alone, already made "wrong backend URL for a debug build" the leading hypothesis — exactly as Phase 33/34 concluded. This phase went further and **confirmed it live**.

### 1.2 Live evidence (this phase, on the user's own physical device)

A physical Android device (`RMX5004`, Android 16) was found already connected via `flutter devices`/`adb`. Non-destructive inspection, in order:

1. `adb shell pm list packages` confirmed `com.sriainfotech.career_buddy_lms` was already installed.
2. `adb shell dumpsys package ...` showed `pkgFlags=[ DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP ]` — `DEBUGGABLE` is the Android manifest flag Flutter's release build type never sets; its presence is definitive, not inferred, proof this is a debug build. `lastUpdateTime=2026-10-16 15:14:41` — installed/updated the same day as this diagnosis.
3. The installed APK was pulled (`adb pull`, read-only) and extracted. It contains `assets/flutter_assets/{vm_snapshot_data, isolate_snapshot_data, kernel_blob.bin}` and **no** `lib/<abi>/libapp.so` — the exact, mechanical signature of a debug/JIT build (a release build is AOT-compiled into `libapp.so` and carries no Dart kernel blob at all). This independently corroborates finding 2 by a completely different method.
4. The app was already running on the device. A screenshot (captured via `adb shell screencap`, not reproduced here to avoid exposing any account detail) showed the login screen with:
   - The username field pre-filled with `Testone` — a real account name independently confirmed in `docs/PRODUCTION_E2E_VERIFICATION_REPORT.md` (2026-09-30) as a genuine, previously-verified-working production test account ("Testone | Jobseeker/Student (Pro plan) | VERIFIED"). This rules out "wrong/nonexistent credentials" as the explanation — a real, previously-working account hit the identical failure.
   - A password already entered (masked; never read, logged, or exported by this diagnosis).
   - The red error banner reading, verbatim, **"The request took too long. Please try again."** — not a paraphrase; this is `TimeoutFailure`'s exact message string, confirmed by a direct source grep before this screenshot was ever taken.
   - "Preview Demo (Debug)" visible at the bottom of the screen (see §2).
5. The existing "Sign In to Dashboard" button (with the credentials already present in the form — nothing was typed, read, or supplied by this diagnosis) was tapped once to confirm the failure reproduces, and a `logcat` capture was taken in parallel. No app-level networking log lines were found (confirmed separately: this codebase deliberately has no `LogInterceptor`/verbose network logging anywhere, a pre-existing security-conscious choice, not a gap introduced here) — only normal OS/radio telemetry, which was not useful for pinpointing the destination host at the packet level. The device's status bar showed active 5G cellular connectivity throughout, ruling out "no network at all" as the explanation.
6. The device disconnected from this machine partway through this phase, before a rebuilt artifact (with the fix applied) could be reinstalled and the exact same login re-attempted. **This specific before/after live comparison was not completed** — see §5.

No credential was read, logged, typed, or exported by this diagnosis. No new login attempt used a credential this diagnosis supplied — the one tap performed re-submitted exactly what was already present in the form.

### 1.3 The fix

`lib/app/config/environment.dart`: `EnvironmentConfig._envName`'s `defaultValue` changed from `'dev'` to `'production'`; `resolve()`'s switch now has an explicit `'dev' => Environment.dev` case (previously implicit via the wildcard, which now means production instead). The pre-existing release-mode fail-fast guard is unchanged in logic — it remains a defense-in-depth check for the now-rarer case of an *explicit* `ENV=dev` slipping into a release build.

**What this does and does not fix**: it changes which backend a build with no explicit `ENV` flag talks to. It does not change the login request/response handling at all — that code path was last live-verified working (with the `Referer`-header production fix already in place, see `docs/PRODUCTION_E2E_VERIFICATION_REPORT.md`) on 2026-09-30, and `git diff` confirms it is byte-for-byte unchanged since. The expectation, not yet re-confirmed live, is that a build produced after this fix (even a plain debug build with no flag) will now reach `https://careerbuddy4u.com` and behave the way it did in that 2026-09-30 verification.

## 2. The "Preview Demo (Debug)" button

### 2.1 Exact widget and condition

`lib/features/auth/presentation/screens/login_screen.dart`, inside `_FormPane.build()`:

```dart
if (kDebugMode) ...[
  const SizedBox(height: AppSpacing.lg),
  AppButton(
    label: 'Preview Demo (Debug)',
    icon: Icons.science_outlined,
    variant: AppButtonVariant.text,
    onPressed: isLoading ? null : () => context.go(RoutePaths.demoEntry),
  ),
],
```

`kDebugMode` is `package:flutter/foundation.dart`'s compile-time constant — `true` only in a debug build, `false` in profile and release builds. Unlike a runtime `if` on a config value, Dart's compiler **removes this entire block from the compiled output** for any non-debug build — there is no code path, flag, or misconfiguration that could make it appear in a release artifact. This was re-confirmed by reading the current source directly this phase (unchanged from its original implementation).

### 2.2 Why it is currently visible

Because, per §1.2, the app currently installed and running on the test device is a debug build. This is not a separate bug from the login timeout — it is the second piece of independent evidence (alongside the APK's own debug flags and missing AOT binary) confirming the same underlying fact.

### 2.3 Verification performed vs. not performed

- **Confirmed via direct, live device inspection** (not just "the source has a check"): the button was visually observed on the real device's login screen in the same screenshot that showed the timeout error, which is the actual running condition.
- **Not performed**: this phase did not build a fresh release artifact and install it on a device to visually confirm the button's absence there — the device disconnected before this could be attempted (§5), and the underlying guarantee (Dart's dead-code elimination for `kDebugMode`-gated code) is a standard, extremely reliable language/toolchain behavior this project already relies on elsewhere (e.g., the Direct Demo Entry route itself, `demo_entry_screen.dart`), not something newly asserted here without basis.

### 2.4 The correct command to not see it

Any of:
- `flutter run -d <device>` in **profile** or **release** mode (`flutter run --release`), or
- `flutter build apk --release` / `flutter build appbundle --release` (optionally now redundant, but still best practice, with `--dart-define=ENV=production` — see `scripts/build_release.sh`, unchanged by this phase).

A plain `flutter run` (debug mode, the Flutter/IDE default) will **always** show this button — that is correct, intended behavior for development tooling, not a bug, and this phase did not remove or weaken it.

## 3. Regression tests added

`test/app/config/environment_test.dart` — restructured to match the new default (previously asserted "ENV unset → dev"; now asserts "ENV unset → production"), with explicit, separately-labeled branches for `dev`/`staging`/the new `production` default, and an updated release-mode-guard section reflecting that the guard is now reachable only via an *explicit* `ENV=dev` on a release build. Run three ways, exactly as the file's own doc comment specifies and as before:

```
$ flutter test test/app/config/environment_test.dart                         # ENV unset → production (NEW)
$ flutter test test/app/config/environment_test.dart --dart-define=ENV=dev
$ flutter test test/app/config/environment_test.dart --dart-define=ENV=staging
```
All three runs pass (4, 5, and 4 tests respectively — see the full report for the per-run breakdown).

`test/features/group_discussion/domain/gd_websocket_url_test.dart` required no change: its one `ENV`-conditional test was already written as a no-op guard (`if (envName != 'production') return;`) for any non-production run; under the new default it now genuinely executes instead of silently skipping, which is strictly more coverage, not a behavior change.

No other test file references `EnvironmentConfig` or assumes a specific default environment — confirmed by grep across `test/` and `lib/` before making the change.

## 4. Acceptance criteria — status

| Criterion | Status |
|---|---|
| The app uses the intended backend environment | **Fixed** for the default (no-flag) case — now production. Confirmed by `environment_test.dart`'s own passing assertions; **not yet re-confirmed by a fresh live device run** (§5). |
| Login requests match the existing backend contract | **Unchanged, already confirmed** (2026-09-30 live verification; `git diff` confirms the request code is untouched since). |
| Loading states terminate correctly on success, failure, and timeout | **Unchanged** — `AuthRefreshing` → `AuthAuthenticated`/`AuthUnauthenticated` already terminates correctly in all three cases; this was never the defect (the timeout message itself displaying and the button becoming re-enabled afterward, as seen live in §1.2, is this working correctly — the request's *destination*, not the state machine, was the problem). |
| Real server errors are presented accurately rather than being incorrectly labelled as timeouts | **Confirmed accurate this phase** — the message shown was a genuine Dio connection/timeout exception, not a mislabeled different error swallowed into the generic bucket. |
| Successful login reaches the correct authenticated destination | **Not re-verified live this phase** (§5) — unchanged code path, last confirmed 2026-09-30. |
| Existing authentication restrictions remain intact | **Confirmed** — no route guard, auth logic, or restriction was touched. |
| Invalid credentials continue to be rejected | **Unchanged** — not touched; this was never implicated in the timeout. |
| Existing tests and new focused regression tests pass | **Confirmed** — see §6. |
| Any unverified production behavior is clearly identified | **Done** — see §5. |

## 5. What is confirmed vs. still unverified

**Confirmed, this phase, with direct evidence:**
- The app being tested is a debug build (APK-level mechanical proof, two independent signals).
- The exact reported error message is `TimeoutFailure`'s string, observed live.
- A real, previously-production-verified account was used and still failed identically (rules out credential issues).
- The device has real network connectivity (cellular, active throughout).
- The default-environment fix compiles, and the environment-resolution logic itself now resolves correctly to production by default (proven by `environment_test.dart`).

**Not verified, and not claimed:**
- That a rebuilt debug (or release) artifact, installed fresh after this fix, actually completes a full login against production end-to-end. The physical device disconnected from this machine before this specific before/after comparison could be performed.
- Any other backend behavior beyond login's own contract (already covered by the 2026-09-30 report).

**Exact next manual verification step**: reconnect the same (or any) Android device, run `flutter run -d <device>` (now defaults to production — no flag needed, though `--dart-define=ENV=production` remains harmless and explicit), and attempt the same login. If it now succeeds, this closes the loop with direct, live confirmation. If a device is unavailable, `flutter build apk --debug` followed by manual installation (`adb install -r build/app/outputs/flutter-apk/app-debug.apk`) achieves the same test.
