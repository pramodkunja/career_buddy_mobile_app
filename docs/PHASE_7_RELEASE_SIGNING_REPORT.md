# Phase 7 — Android Release Signing and Production Build Verification

## Starting state (re-verified, not assumed)

Git status checked before any change: working tree matched exactly the end-state of Phase 6 (route/subscription/test files from Phases 2–6, plus `docs/ANDROID_RELEASE_SIGNING.md` and `scripts/build_release_aab.sh` from Phase 7A, still untracked and unmodified). Nothing was reset, stashed, or discarded. Re-read `docs/ANDROID_RELEASE_SIGNING.md` and the current `android/app/build.gradle.kts` in full before making any change, per the task's explicit instruction.

## 1–2. Git status and file review

Reviewed, this phase:
- `android/app/build.gradle.kts` — unchanged since Phase 7A: builds a `release` signing config from `android/key.properties` when that file exists, falling back to the debug signing config when it does not.
- `android/.gitignore` — confirmed it ignores `key.properties`, `**/*.keystore`, and `**/*.jks` (verified with `git check-ignore -v` against both `android/key.properties` and a hypothetical `.jks` path — both correctly matched).
- `android/key.properties` — confirmed **absent** (`ls` reports no such file).
- Home directory keystores — re-confirmed the same two generic, unattributed files noted in Phase 7A (`~/upload-keystore.jks`, `~/royalhrms-upload-keystore.jks`) still exist and are still not usable: undated/generic metadata, one explicitly named for an unrelated project, and neither previously authorized by the project owner as this app's production key. Not touched, not read, not used.
- `scripts/build_release.sh` and `scripts/build_release_aab.sh` — both already pass `--dart-define=ENV=production` (re-confirmed, satisfies item 6 below) but, before this phase, both would **succeed silently** using the debug signing key whenever `key.properties` was absent — the exact gap item 3 below closes.

## 3. Production builds can no longer silently use the debug signing key

**Change made** (the only Dart-adjacent/build-tooling change this phase; no Dart source file was touched): added a pre-flight guard to both `scripts/build_release.sh` and `scripts/build_release_aab.sh`. Each now checks for `android/key.properties` before invoking `flutter build`, and if it is absent, prints a clear error to stderr naming the problem and pointing at `docs/ANDROID_RELEASE_SIGNING.md`, then exits with status 1 — no build is attempted.

This does not change `android/app/build.gradle.kts`'s own conditional fallback (left as-is, since other legitimate paths — e.g. Android Studio's default debug-variant builds — still rely on it and changing it would be a broader behavioral change than this phase's scope calls for). Instead, the fix targets the two actual, documented entry points this team uses to produce a distributable artifact (`docs/ANDROID_RELEASE_SIGNING.md` §3 names `scripts/build_release_aab.sh` as *the* build-and-verify step) — those now refuse outright rather than quietly producing a debug-signed "production" build.

**Verified working**: ran both scripts directly with `key.properties` absent (the current real state). Both exited immediately with status 1 and the expected error message, confirming no build was attempted and no accidental debug-signed artifact could result:
```
ERROR: android/key.properties not found.
This script produces the real, client-facing release APK and refuses to
silently fall back to debug signing for that artifact.
See docs/ANDROID_RELEASE_SIGNING.md ...
```
(and the equivalent message in the `.aab` script, naming Play Console upload specifically.)

## 4. No production keystore available — documented, not worked around

Re-confirmed this phase: no authorized production upload keystore exists anywhere in this environment. The exact steps and required inputs remain exactly as `docs/ANDROID_RELEASE_SIGNING.md` already specifies (keystore generation command, where to store it, the `android/key.properties` format, and the build-and-verify command) — that document was re-read and found still accurate; no change was needed to it. No keystore was generated, no `android/key.properties` was created, and no placeholder/fake credential was substituted. Per the task's explicit instruction, this phase stops at the configuration/documentation stage for signing itself.

## 5. No keystore passwords or private signing material exposed

No keystore password, key password, or private key material appears anywhere in this report, in the two modified scripts, in `build.gradle.kts`, or in any file this phase touched — the scripts only check for the *existence* of `android/key.properties`, never read or print its contents. `android/key.properties` itself remains absent and, per `.gitignore`, would be excluded from Git if it existed.

## 6. AAB build script uses `--dart-define=ENV=production`

Re-confirmed directly: `scripts/build_release_aab.sh` line `flutter build appbundle --release --dart-define=ENV=production`. Unchanged from Phase 7A; this phase's edit only added the pre-flight signing guard above it.

## 7. Validation run

- `flutter analyze`: **clean, no issues** (re-run after the script changes; no Dart source was modified, so this reconfirms the baseline rather than testing new code).
- Full `flutter test`: **1885/1885 passing** — identical to the count at the end of Phase 6, confirming the shell-script-only change in this phase did not affect any Dart code or test outcome.
- No new automated test was added this phase: the change is a Bash pre-flight check in two release-build scripts, outside Flutter's test runner's reach. It was instead verified directly by executing both scripts against the real, current (keystore-absent) environment and confirming the exact refuse-and-exit-1 behavior shown above — the most direct verification available for shell tooling of this kind.

## 8. Production AAB build and certificate verification

**Not performed.** No authorized production keystore is available (see item 4), and per the task's explicit instruction, a build was not attempted and signing completion was not simulated or claimed. Running `scripts/build_release_aab.sh` right now correctly refuses with the error shown above — this is the intended behavior, not a failure to investigate further.

## Remaining blockers and required external actions

1. **Production Android upload keystore** — must be generated and authorized by whoever holds signing authority for this app, per `docs/ANDROID_RELEASE_SIGNING.md` §1–2 (run `keytool -genkey` outside this repo, store the `.jks` securely, populate `android/key.properties` with the real values). This is the only remaining blocker to producing a real, Play-Store-uploadable `.aab`. Once that file exists, `scripts/build_release_aab.sh` will build normally and print the `jarsigner` verification command as before — no further code change is needed.
2. All other blockers listed in `docs/PHASE_6_READINESS_REPORT.md` (backend JSON status endpoint, live Razorpay click-through, physical iOS device, Mock Interview paid-tier account, ARIA audio-stall watchdog) are unchanged and outside this phase's scope.

## Final status

**Configuration-and-documentation stage complete.** Production builds can no longer silently ship debug-signed — both release scripts now fail fast and loudly, pointing at the exact remaining human action required, instead of quietly producing an artifact that would be rejected (or worse, wrongly trusted) at Play Console upload. No keystore was generated, no credential was fabricated, no build was uploaded or published, and no existing work was reset, discarded, or overwritten.

## Final Git status

```
Changes not staged for commit:
  modified:   android/app/build.gradle.kts        (Phase 7A, unchanged this phase)
  modified:   ios/.../Package.resolved (x2)        (unchanged this phase)
  modified:   lib/app/router/app_router.dart        (Phase 2, unchanged this phase)
  modified:   lib/app/router/route_guards.dart       (Phase 2, unchanged this phase)
  modified:   lib/core/network/api_endpoints.dart    (Phase 3, unchanged this phase)
  modified:   pubspec.lock / pubspec.yaml            (Phase 3, unchanged this phase)
  modified:   scripts/build_release.sh               (THIS PHASE — signing guard added)
  modified:   test/app/client_flow_test.dart          (Phase 2/5, unchanged this phase)
  modified:   test/app/router/route_guards_test.dart  (Phase 2, unchanged this phase)
  modified:   test/shared/widgets/buddy_chatbot_overlay_test.dart (Phase 4, unchanged this phase)

Untracked files:
  docs/ANDROID_RELEASE_SIGNING.md, docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md,
  docs/PHASE_5_REGRESSION_REPORT.md, docs/PHASE_6_READINESS_REPORT.md,
  docs/PHASE_7_RELEASE_SIGNING_REPORT.md (new, this phase),
  docs/WEB_MOBILE_GAP_ANALYSIS.md,
  lib/features/subscription/ (unchanged this phase),
  scripts/build_release_aab.sh                (THIS PHASE — signing guard added)
  test/features/subscription/ (unchanged this phase)
```

Last commit unchanged: `03964b6` — nothing has been committed. **Test count: 1885/1885 passing. `flutter analyze`: clean.**
