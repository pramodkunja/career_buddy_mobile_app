# Phase 9 — Signed AAB Build and Manual Release Verification

## Preflight

Read `docs/PHASE_8_RELEASE_READINESS_CHECKLIST.md`, `docs/ANDROID_RELEASE_SIGNING.md`,
and `docs/PHASE_7_RELEASE_SIGNING_REPORT.md` before acting (all three were
authored/re-verified in this same engagement; re-checked for drift, none
found). Git status inspected first and reconfirmed identical to the end of
Phase 8 — same 11 modified files, same 8 untracked paths, last commit still
`03964b6`. Nothing was reset, stashed, rebased, or committed. No file outside
this check and the new report (below) was touched this phase.

## 1. Signing readiness — checked fresh, not assumed

- `android/key.properties`: **confirmed absent** (`ls` reports no such
  file).
- Project tree searched for any `.jks` or `key.properties` file: **none
  found** anywhere under `Career_Buddy_LMS/`.
- Home directory keystores re-checked: the same two generic,
  previously-rejected files from Phase 7A/7 are still present
  (`~/upload-keystore.jks`, `~/royalhrms-upload-keystore.jks`) — both already
  confirmed with the project owner to **not** be this app's authorized key
  (undated/generic metadata; neither attributable to Career Buddy LMS). A
  third, unrelated keystore was also found this phase
  (`~/Flutter Projects/Cashora_Version_1/upload-key.jks`) — belongs to a
  different Flutter project entirely and was not considered, read, or used.
- **No keystore was generated, requested, or substituted this phase.** No
  keystore password or private key material was requested, typed, printed,
  or logged at any point.
- `android/.gitignore` re-verified to exclude both `key.properties` and
  `**/*.jks` (`git check-ignore -v`, same result as Phase 7).

**Conclusion: the authorized production signing key is still not
available.** Per the task's explicit instruction, the build attempt stops
here — Section 3 (Production AAB build) is not performed, since its
precondition ("only when signing configuration is complete") is not met.

## 2. Signing-guard verification (not a production build attempt)

To confirm Phase 7's safety fix still holds (distinct from attempting an
actual production build, which was correctly not attempted), re-ran
`scripts/build_release_aab.sh` as-is against the current, keystore-absent
environment:
```
ERROR: android/key.properties not found.
This script produces the .aab meant for Google Play Console upload and
refuses to silently sign it with the Android debug key.
See docs/ANDROID_RELEASE_SIGNING.md for how to generate and configure
the production upload keystore before running this script.
```
Exit code 1. No `flutter build` command ran; no artifact was produced.
Confirmed via `ls build/app/outputs/bundle/release/` — directory does not
exist. The script is doing exactly what it should: refusing rather than
silently falling back to debug signing.

## 3. Production AAB build

**Not performed**, per §1's conclusion and the task's own precondition. No
output path, no artifact, no signing certificate to report — there is
nothing to verify yet. This is not a failure of this phase; it is the
correct outcome given the unmet prerequisite.

**Exact missing items, for the signing authority**:
1. Run (manually, outside any AI session, per `docs/ANDROID_RELEASE_SIGNING.md`):
   ```bash
   keytool -genkey -v -keystore ~/career-buddy-upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias career_buddy_upload
   ```
2. Create `android/key.properties` on the build machine with the real
   `storePassword`/`keyPassword`/`keyAlias`/`storeFile` values (never
   committed; already git-ignored).
3. Re-run `scripts/build_release_aab.sh` — it will then build normally.
4. Verify with `jarsigner -verify -verbose -certs
   build/app/outputs/bundle/release/app-release.aab` and confirm the
   certificate is not `CN=Android Debug`.

## 4. Manual QA

**Environment availability checked fresh, not assumed**:
- `flutter devices`: only `macOS (desktop)` and `Chrome (web)` connected.
  No physical Android device, no running Android emulator.
- `flutter emulators`: two Android AVDs are *installable/launchable*
  (`Android_Emulator_34`, `Pixel_9a`) but **neither is currently running**.
- `xcrun xctrace list devices`: `Pramod's iPhone` still shows **Offline** —
  unchanged across every phase of this engagement.
- Local Django dev backend: `curl http://127.0.0.1:8000/` returned no
  response (connection failed) — **no backend server is currently running**
  to test against.
- Razorpay test-mode credentials: not confirmed populated or available in
  this session (per Phase 3's discovery, this is self-diagnosing at
  runtime via the `"Payment is not configured."` 500 response, and was
  deliberately not determined by reading `.env` directly, consistent with
  not handling secrets).

**No device, backend, or confirmed Razorpay credentials were available this
phase.** Per the task's explicit instruction ("record the relevant checks as
BLOCKED rather than inventing results"), every item in Phase 8's 10-item
checklist is recorded below as BLOCKED, not NOT TESTED — the blocking
reason is identical and external for all ten (no runnable target
environment), not a per-item gap:

| # | Item | Result | Evidence |
|---|---|---|---|
| 1 | Login | **BLOCKED** | No device/emulator running; no backend reachable |
| 2 | Role-based navigation | **BLOCKED** | Same |
| 3 | Core learning features | **BLOCKED** | Same |
| 4 | ARIA chatbot | **BLOCKED** | Same |
| 5 | Subscription — plan display | **BLOCKED** | Same |
| 6 | Subscription — checkout (test mode) | **BLOCKED** | Same, plus Razorpay test credentials unconfirmed |
| 7 | Payment cancellation | **BLOCKED** | Same |
| 8 | Payment failure | **BLOCKED** | Same |
| 9 | Session restoration | **BLOCKED** | Same |
| 10 | Logout | **BLOCKED** | Same |

No real payment was attempted, no production data was touched, and no
emulator/backend was autonomously started this phase — standing up a full
test environment (booting an AVD, starting the Django dev server against the
read-only web repo, provisioning test accounts) is a meaningful setup step
that was not requested and was not performed speculatively. If a manual QA
pass is wanted next, the two Android AVDs above are ready to launch and the
Django project is present locally; this just was not attempted
unprompted in this phase.

## 5. Regression verification

No source, test, or configuration file was changed this phase (purely a
verification/reporting phase; §1–4 found nothing to fix). Per the task's
"do not modify application code merely to make the report appear complete"
instruction, nothing was touched.

- `flutter analyze`: **clean, no issues.**
- `flutter test`: **1885/1885 passing**, 0 skipped, 0 failing — identical to
  the count carried forward from Phase 7/8 (expected, since no source file
  changed).

No defect was discovered this phase, so there is nothing to fix under
Section 5's "fix only if reproducible and in-scope" clause.

## 6. Remaining blockers and owners

| Blocker | Owner | What's needed |
|---|---|---|
| No authorized Android upload keystore | App/signing authority | Generate + configure per §3 above; cannot be done by this engagement |
| No manual QA evidence | QA / device access | A running Android emulator or connected device, a running backend, test accounts, and confirmed Razorpay test-mode keys |
| Subscription-status JSON endpoint | Backend team | Contract already specified in `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §2 / `docs/PHASE_8_RELEASE_READINESS_CHECKLIST.md` §5 |
| Physical iOS device | Device owner | Still offline, unchanged since Phase 1 |
| ARIA audio-stall watchdog | Product | Explicit decision required; not touched this phase, per instruction |

All five are unchanged in substance from Phase 8 — this phase closes none
of them, since none of their prerequisites became available in this
environment.

## Final status

# BLOCKED

Both of this phase's two central objectives — a verified signed production
AAB, and real manual QA evidence — remain blocked by factors outside this
codebase: no authorized signing key exists, and no runnable
device/backend/credential combination was available to execute the manual
QA checklist. The one thing this phase could and did verify — that the
Phase 7 signing guard still correctly refuses to build a "production"
artifact without a real key — passed. No credential was fabricated, no
keystore was generated without authorization, no build artifact was
produced, and no QA result was invented. `flutter analyze` is clean and the
full automated suite is at **1885/1885 passing**, unchanged from Phase 7/8.

## Final Git status

Identical to Phase 8's end-state, plus this one new report file:
```
Changes not staged for commit: (same 11 files as Phases 7–8 — android/app/build.gradle.kts,
  ios/.../Package.resolved x2, lib/app/router/{app_router,route_guards}.dart,
  lib/core/network/api_endpoints.dart, pubspec.lock, pubspec.yaml,
  scripts/build_release.sh, test/app/client_flow_test.dart,
  test/app/router/route_guards_test.dart, test/shared/widgets/buddy_chatbot_overlay_test.dart)

Untracked files: docs/ANDROID_RELEASE_SIGNING.md, docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md,
  docs/PHASE_5_REGRESSION_REPORT.md, docs/PHASE_6_READINESS_REPORT.md,
  docs/PHASE_7_RELEASE_SIGNING_REPORT.md, docs/PHASE_8_RELEASE_READINESS_CHECKLIST.md,
  docs/PHASE_9_RELEASE_VERIFICATION_REPORT.md (new, this phase),
  docs/WEB_MOBILE_GAP_ANALYSIS.md, lib/features/subscription/,
  scripts/build_release_aab.sh, test/features/subscription/
```
Last commit unchanged: `03964b6`. Nothing committed, nothing uploaded,
nothing reset or discarded. Test count: **1885/1885 passing.**
`flutter analyze`: **clean.**
