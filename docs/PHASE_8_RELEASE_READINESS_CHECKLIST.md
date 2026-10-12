# Phase 8 — Release Readiness Checklist

Single consolidated reference, built from `docs/PHASE_6_READINESS_REPORT.md`,
`docs/PHASE_7_RELEASE_SIGNING_REPORT.md`, `docs/ANDROID_RELEASE_SIGNING.md`,
and `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` — re-read in full before writing
this document, not summarized from memory. This phase made **no source code
changes**: it is a planning/coordination document only, per its own scope.

## How to read this document

- **Owner** says who can actually close the item — this app's Flutter work
  does not block most of these; most are waiting on a person or system
  outside this codebase.
- **Status** is one of: `Done (automated)`, `Done (code-complete, manual
  check pending)`, `Blocked`, or `Decision required`.
- Nothing here is marked `Done` without the specific automated test or
  verification step that backs it, per Phase 6/7's own evidentiary standard.

## 1. Blockers grouped by owner

### Owner: Flutter (this codebase) — all currently closed

| Item | Status | Evidence |
|---|---|---|
| Home entry-routing gap (Phase 2) | Done (automated) | `route_guards_test.dart`, re-run clean |
| Subscription screen + checkout flow (Phase 3) | Done (code-complete; see §5/§6 for what's still manual) | 36 automated tests across datasource/repository/controller/widget layers |
| ARIA bot navigation verification (Phase 4) | Done (automated) | 1884-test full suite, 95 ARIA-specific tests |
| Cross-feature regression audit (Phase 5) | Done (automated) | Full-app-boot integration test via the real router |
| Duplicate-tap checkout race (Phase 6) | Done (automated) | Reproduced with a failing test, fixed, regression test added — 12/12 in `subscription_checkout_controller_test.dart` |
| Release script silently debug-signing (Phase 7) | Done (automated — verified by direct script execution) | Both `scripts/build_release*.sh` now refuse to run without `android/key.properties` |

Nothing remaining in this column requires further Flutter engineering work
under current scope. The only Flutter-side item still open is the ARIA
watchdog, which is a **product decision**, not an engineering task — see §3.

### Owner: Backend (Django/web team) — read-only to this engagement

| Item | Status | What's needed |
|---|---|---|
| Subscription-status JSON endpoint | Blocked | See §5 for the full contract spec, already written and waiting for backend review |
| Staging backend host | Blocked (lower priority) | No DNS record exists for `api.careerbuddy4u.com`; `Environment.staging` in `lib/app/config/environment.dart` is deliberately left unconfigured until one exists |

### Owner: App/signing authority (whoever controls Play Console + the upload key)

| Item | Status | What's needed |
|---|---|---|
| Production Android upload keystore | Blocked | See §4/§8 — generation is a manual, one-time, irreversible step that must be done outside any AI session |

### Owner: QA / device access

| Item | Status | What's needed |
|---|---|---|
| Live Razorpay test-mode checkout click-through | Blocked | Needs confirmed test API keys + an interactive device/emulator session |
| Physical iOS device verification | Blocked | Device has been offline across every phase of this engagement (`xcrun xctrace list devices` re-checked each phase) |
| AI Mock Interview Pro/Normal-tier device test | Blocked | No paid-tier test account has been made available |
| Full manual QA pass (§6) | Not started | Needs a tester with device/emulator access; checklist is ready below |

## 2. What "release ready" does and does not mean right now

**This app is not release-ready today.** Two independent, external blockers
sit outside this engagement's ability to close:
1. No production Android signing key exists (§1/§4/§8).
2. No manual QA pass has been performed against a running build (§6/§7).

Both are necessary, not optional, before any Play Console upload. This
document deliberately does not claim otherwise — see Phase 6/7's own
"PASS WITH DOCUMENTED LIMITATIONS" framing, carried forward here unchanged.

## 3. Product decision required (not an engineering blocker)

**ARIA audio-stall auto-navigation watchdog**: `aria_chat_controller.dart`
has no forced-navigate timeout if speech playback stalls. Every action is
still always rendered as an immediately-tappable chip regardless (confirmed,
`buddy_chatbot_overlay.dart`), so a stall degrades to "tap manually," never a
dead end — this has been re-verified, unchanged, in every phase since Phase
4. Per this phase's explicit restriction, **no change was made** to this
behavior. A product owner must decide whether a watchdog is wanted before any
engineering work on it begins.

## 4. Android signing — authorized steps and certificate verification

Reproduced here as the release-blocking item's single point of reference
(full detail remains in `docs/ANDROID_RELEASE_SIGNING.md`, re-verified
accurate this phase — no change needed to it).

**Who must do this**: whoever holds signing authority for this app's Play
Console listing. Not performed by, or delegable to, this engagement — the
keystore password must never be typed into an AI session or committed to
git.

**Step 1 — generate the upload keystore** (run manually, outside any AI
session):
```bash
keytool -genkey -v \
  -keystore ~/career-buddy-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias career_buddy_upload
```
Store the resulting `.jks` outside this repo, back it up durably and
privately — losing it permanently blocks future updates to this app's
existing Play Store listing (there is no supported reset).

**Step 2 — create `android/key.properties`** (already git-ignored —
re-verified this phase via `git check-ignore -v`, matches both the
`key.properties` and `**/*.jks` patterns in `android/.gitignore`):
```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=career_buddy_upload
storeFile=/absolute/path/to/career-buddy-upload-keystore.jks
```
`android/app/build.gradle.kts` already reads this file automatically — no
further code change is needed once it exists.

**Step 3 — build and verify**:
```bash
scripts/build_release_aab.sh
```
As of Phase 7, this script **refuses to run** until `android/key.properties`
exists (prevents an accidental debug-signed "production" artifact). Once it
exists and the build succeeds, verify the actual signing certificate before
ever uploading anything:
```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```
Confirm the printed certificate's `CN`/fingerprint matches the real upload
key — **not** `CN=Android Debug`. For the `.apk` built by
`scripts/build_release.sh`, the equivalent check is
`apksigner verify --print-certs`.

**Explicitly not done, and not to be done without authorization**: no
keystore was generated this phase or any prior phase. Two generic,
unattributed `.jks` files exist on the development machine
(`~/upload-keystore.jks`, `~/royalhrms-upload-keystore.jks`) — both were
previously confirmed with the project owner to **not** be this app's
authorized key (undated, generic metadata; one explicitly named for an
unrelated project). They must not be used as a substitute.

## 5. Subscription status — outstanding API contract and Flutter dependency

**Current state**: `pro_page` (`career_app/views.py:159-180`) renders HTML
only; no JSON endpoint, committed or uncommitted, returns structured
current-plan/expiry data (re-confirmed directly against Django source in
Phase 3 and re-checked, unchanged, at each later phase). The mobile
`SubscriptionScreen` therefore shows an explicit, honest banner —
*"We can't check your current plan from the app yet. Visit the Career Buddy
website to see your active plan and expiry date."* — rather than fabricating
or inferring a plan status. This is correct, current behavior, not a defect.

**Contract spec, for the backend owner to review and implement** (verbatim
from `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §2, not re-invented here):
- `GET /pro/api/` (or similar), requiring authentication and returning
  `401 {"error": "..."}` for an anonymous request — **not** Django's default
  302-to-login redirect, which a JSON client would otherwise silently follow
  into a misleading 200.
- Suggested response body, built entirely from fields that already exist on
  `UserProfile`/`_get_user_plan` — nothing new to compute:
  ```json
  {
    "plan": "free" | "normal" | "pro",
    "is_active": true,
    "subscription_start": "2026-01-01T00:00:00Z",
    "subscription_expiry": "2027-01-01T00:00:00Z",
    "days_until_expiry": 360,
    "pending_expiry_notice": false,
    "can_access_interview": true,
    "job_recommendation_limit": 5
  }
  ```

**Flutter-side dependency once this endpoint exists**: a new
`lib/features/subscription/domain/.../plan_status.dart` entity +
datasource/repository/controller call, following the exact layering already
used for `createOrder`/`verifyPayment` in
`lib/features/subscription/` — no architectural change needed, only an
additive call once a real endpoint is available. Building this speculatively
against a nonexistent endpoint was explicitly ruled out in Phase 3 and
remains out of scope here.

**Not done this phase, and not to be done**: no endpoint was invented, no
backend file was read or modified beyond what Phase 1/3's read-only
investigation already covered.

## 6. Manual QA checklist (not yet executed — for whoever has device/emulator access)

None of the following have been executed against a running build in any
phase of this engagement; all are currently **automated-coverage-backed but
not manually click-tested**, per §7's distinction.

- [ ] **Login** — Job Seeker login, Employer login, invalid-credentials
      error display, session cookie persists across app restart.
- [ ] **Role-based navigation** — Job Seeker reaches Dashboard/Activities;
      Employer reaches the Employer dashboard; neither can reach the other
      role's protected routes (manually confirm the router guard in a live
      app, not just in the test harness).
- [ ] **Core learning features** — Activities, Grammar, Skill-Up, Resume
      Parsing/ATS score, Workshop/GD/JAM/Roleplay all open and function
      against the real backend (not a fake/mocked response).
- [ ] **ARIA chatbot** — open the panel, send a message, confirm a reply
      streams in; tap a single action chip and confirm auto-navigation;
      tap a multi-chip reply and confirm each chip navigates independently;
      switch language and confirm it carries into the next message.
- [ ] **Subscription — plan display** — `/pro` opens the real
      `SubscriptionScreen`; both plan cards render with the correct
      base price; the "can't check your current plan" banner is visible.
- [ ] **Subscription — checkout (TEST MODE KEYS ONLY — never real payment)**
      — tapping Upgrade opens the native Razorpay Checkout sheet with the
      correct amount/order id/prefill; a fast double-tap does **not** open
      the sheet twice (Phase 6's fix — now verifiable live, not just in the
      unit test).
- [ ] **Payment cancellation** — dismiss the Checkout sheet without paying;
      confirm the app shows a quiet "no charge was made" state, not an
      error.
- [ ] **Payment failure** — force a failure (e.g. a test card configured to
      decline, if Razorpay test mode supports it) and confirm a clear
      error state, never a false "activated" result.
- [ ] **Session restoration** — kill and relaunch the app while logged in;
      confirm it lands back on the correct role's Home/Dashboard without
      re-prompting for login.
- [ ] **Logout** — confirm logout clears the session and returns to the
      logged-out Home, and that a subsequent protected-route deep link
      redirects to login rather than showing stale content.

**Explicitly out of scope for this checklist** (real payment, store
upload, production data mutation): never to be performed as "QA" — Razorpay
test-mode keys and a sandboxed account only.

## 7. Automated vs. manual — the line, stated plainly

**Automated and currently passing** (re-confirmed at the end of Phase 7,
unchanged since no source file was modified this phase):
- `flutter analyze`: clean, no issues.
- `flutter test`: **1885/1885 passing**, 0 skipped, 0 failing.
- This covers: routing/guards, auth flows, ARIA chat logic and action-chip
  navigation, subscription order-creation/verification/error-state logic
  (including the Phase 6 duplicate-tap fix), and widget-level rendering —
  all against fakes/mocks of the network and native plugin layers, never
  against the real backend or real Razorpay sandbox.

**Not automated, not yet executed, genuinely manual** (§6's full checklist):
every item there requires a real device/emulator, a live backend connection,
and (for the checkout items) real Razorpay test-mode credentials — none of
which were available in this environment at any point in this engagement.
No manual QA result is claimed or implied anywhere in this document.

## 8. Exact prerequisites for a signed, uploadable production AAB

In order, all required, none optional:
1. A real, authorized upload keystore generated per §4 Step 1, by the
   signing authority, outside any AI session.
2. `android/key.properties` populated per §4 Step 2, on the machine that
   will run the build — never committed (already `.gitignore`d).
3. `scripts/build_release_aab.sh` run on that machine — as of Phase 7, it
   will refuse to proceed if step 2 is incomplete, which is the intended
   safety behavior, not a bug to work around.
4. Certificate verification via `jarsigner -verify -verbose -certs ...`
   before upload, confirming the artifact is signed with the real key, not
   `CN=Android Debug`.
5. A completed manual QA pass (§6) against that same build — signing
   correctness and functional correctness are independent checks; neither
   substitutes for the other.
6. Separately, and only once the backend owner has implemented §5's
   contract (not a hard blocker for an initial release, since the current
   honest "can't check your plan" banner is a legitimate, shippable state):
   update the Flutter subscription module to call it.

Only step 6 is non-blocking for a first release; steps 1–5 are all required.

## 9. Automated validation run for this phase

No Dart source, test, or build-script file was changed while producing this
checklist (it is a planning document only), so per this phase's own
instruction, `flutter analyze`/`flutter test` were **not** re-run — doing so
would only reproduce Phase 7's already-current result with no new
information. That result (`flutter analyze`: clean; `flutter test`:
1885/1885 passing) is cited in §7 as the current, still-valid automated
baseline, and remains attributable to Phase 7's run, not fabricated or
re-claimed as new work here.

## 10. Final status

**Not release-ready.** Two independent, non-Flutter blockers remain: no
authorized production signing key (§4/§8), and no manual QA pass has been
performed (§6/§7). Every Flutter-side defect found across Phases 2–7 has
been fixed and is covered by an automated regression test; the backend
contract gap (§5) and the ARIA watchdog (§3) are explicitly owned outside
this codebase or pending a product decision, not engineering gaps. Nothing
in this document claims readiness beyond what is actually verified above.

## Final Git status

Unchanged from the end of Phase 7 — this phase added only this one new file.
```
Changes not staged for commit: (same 11 files as Phase 7 — android/app/build.gradle.kts,
  ios/.../Package.resolved x2, lib/app/router/{app_router,route_guards}.dart,
  lib/core/network/api_endpoints.dart, pubspec.lock, pubspec.yaml,
  scripts/build_release.sh, test/app/client_flow_test.dart,
  test/app/router/route_guards_test.dart, test/shared/widgets/buddy_chatbot_overlay_test.dart)

Untracked files: docs/ANDROID_RELEASE_SIGNING.md, docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md,
  docs/PHASE_5_REGRESSION_REPORT.md, docs/PHASE_6_READINESS_REPORT.md,
  docs/PHASE_7_RELEASE_SIGNING_REPORT.md,
  docs/PHASE_8_RELEASE_READINESS_CHECKLIST.md (new, this phase),
  docs/WEB_MOBILE_GAP_ANALYSIS.md, lib/features/subscription/,
  scripts/build_release_aab.sh, test/features/subscription/
```
Last commit unchanged: `03964b6`. Nothing committed, nothing reset,
nothing discarded.
