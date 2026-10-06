# Batch 13 — Live Production Authentication & End-to-End Smoke Test

## STATUS

**NOT_VERIFIED**

No real student or employer test credentials were available anywhere in
the project, environment, or this conversation. Per this batch's own
explicit instruction ("If credentials are not available, STOP and
report that clearly instead of guessing" / "If credentials are
unavailable, stop at the authentication blocker"), no live
authentication or authenticated-feature smoke test was attempted. This
is not a code or backend defect — the production configuration itself
(from Batches 11-12) remains fully verified and unchanged.

## PRODUCTION HOST

Confirmed unchanged from Batch 12: `EnvironmentConfig.baseUrl` under
`Environment.production` still resolves to `https://careerbuddy4u.com`
(`lib/app/config/environment.dart`, re-read this batch, byte-identical
to Batch 12's version). `Environment.dev` is unchanged.
`Environment.staging` remains explicitly unconfigured (still throws a
clear `UnsupportedError`).

## CREDENTIAL SOURCE

**No real student or employer test credentials were available.**
Searched, this batch:
- `teamcontextfile.md` — explicitly states (written back in Batch 1,
  never contradicted since): "No test/demo credentials exist anywhere
  in the repo."
- This session's own conversation — the user did not supply any
  credentials.
- The Mobile_app project tree — no `.env`/`.env.*` file exists at all
  (confirmed via a direct filesystem search).
- The current shell environment — no credential-shaped environment
  variable found (checked for test-account/student/employer-credential-
  looking variable names; none present).
- Every `.md`/`.dart`/`.yaml`/`.json` file matching "credential"/
  "testuser"/"demo password"-style text — every hit was either this
  same "no credentials exist" statement repeated across docs, or a
  fake, non-functional placeholder value inside a **widget test**
  (e.g. a login form's test input like `'testuser'`/`'password123'`,
  used only to exercise the UI's own text-field/validation logic
  against a **fake, in-memory** `AuthRepository` — never sent to any
  real server, confirmed by reading the test files themselves).

**No credential was fabricated, guessed, or brute-forced to force a
result**, per this batch's absolute rule. No value resembling a real
credential is reproduced anywhere in this report.

## STUDENT AUTHENTICATION

| Flow | Status | Evidence |
|---|---|---|
| Login page | NOT VERIFIED (live) | Batch 12 confirmed `GET https://careerbuddy4u.com/users/login/` → `200` (page reachable); not re-fetched this batch since nothing changed |
| Login POST | NOT VERIFIED | No credentials to submit |
| CSRF | NOT VERIFIED (live, with a real login) | Batch 12 confirmed the real `csrftoken` cookie mechanics (name, `Secure`/`SameSite=Lax`) on an unauthenticated request; the CSRF-token-then-POST-login round trip specifically was never exercised |
| Session cookie | NOT VERIFIED (live) | Cookie persist/replay/clear mechanics verified against a **fake** server in Batch 11 (`test/core/network/api_client_test.dart`); never verified against the real production host end-to-end |
| Authenticated home | NOT VERIFIED | Requires a successful login first |
| Session restoration | NOT VERIFIED | Requires a successful login first |
| Logout | NOT VERIFIED (live) | Logout's `clearCookies()`-in-`finally` mechanics verified against a fake server (Batch 11); never exercised against a real live session |
| Cookie clearing | NOT VERIFIED (live) | Same as above |

## STUDENT SMOKE TEST

Not performed — every item below requires an authenticated session,
which requires the same missing credentials.

| Feature | Status | Evidence |
|---|---|---|
| Home | NOT VERIFIED | Blocked on login |
| Activities | NOT VERIFIED | Blocked on login |
| Exercise | NOT VERIFIED | Blocked on login |
| AI module | NOT VERIFIED | Blocked on login |
| Skill-Up | PARTIALLY VERIFIED (unauthenticated only) | Batch 12 confirmed `GET https://careerbuddy4u.com/static/001%20Career%20Buddy/index.html` → `200` — the real static content is reachable, since Skill-Up's lesson pages are genuinely unauthenticated (confirmed architecture since Batch 7); the in-app WebView screen itself was not exercised live this batch |
| Grammar | NOT VERIFIED | Grammar's index/detail/media are `@login_required` — blocked on login |
| Resume | NOT VERIFIED | Blocked on login |
| ARIA | NOT VERIFIED (live) | `POST /api/riya/chat/` is genuinely public/unauthenticated (confirmed architecture since Batch 8), so login is not a blocker for this one specifically — but no live message was sent this batch, since doing so would mean making a real, non-idempotent request against the live third-party AI backend (Sarvam) with no way to distinguish this from a real, if low-stakes, production interaction; deliberately deferred rather than assumed safe without being asked to specifically confirm this trade-off — see FINAL REMAINING ITEMS |
| JAM | NOT VERIFIED | Blocked on login |
| Roleplay | NOT VERIFIED | Blocked on login |
| Group Discussion | NOT VERIFIED | Blocked on login (a live WebSocket handshake also requires a valid session id from a real `create_session` call, which itself requires login) |
| Mock Interview | NOT VERIFIED | Blocked on login |

## EMPLOYER AUTHENTICATION

**NOT VERIFIED — no real employer test credentials were provided.**

## SECURITY

No live authenticated traffic was generated this batch, so most of
this section reduces to "nothing new to find," re-confirming Batch
12's own findings rather than superseding them:

- **HTTP downgrade**: none — `Environment.production` returns
  `https://careerbuddy4u.com` unchanged; re-confirmed via the existing
  `environment_test.dart` assertion (`uri.scheme == 'https'`), re-run
  this batch (see BUILD).
- **Certificate bypass**: none — re-confirmed no
  `badCertificateCallback`/custom `SecurityContext` anywhere in `lib/`
  (unchanged since Batch 11's sweep; no new networking code was
  written this batch).
- **Hardcoded secret**: none found this batch (see CREDENTIAL SOURCE
  above — the only credential-shaped strings found were fake widget-
  test fixtures, never sent anywhere real).
- **Session leakage**: none observed — no session was ever
  established, so there was nothing to leak.
- **CSRF failure**: not exercised (no login attempted).
- **Debug bypass**: none — re-confirmed `kDebugMode`-gated Demo Mode
  remains compile-time-eliminated in release builds (unchanged).
- **Sensitive logging**: none — this report reproduces no cookie
  value, token, or credential; the only value from a live host
  observed anywhere in this batch's work was a transient CSRF-token
  string from Batch 12's own earlier read-only check, not reproduced
  here either.

## BUILD

```text
flutter analyze                                              → No issues found.
flutter test                                                  → 1544/1544 passing
                                                                  (unchanged from Batch 12 — no test was
                                                                   added, removed, or modified this batch)
flutter build apk --release --dart-define=ENV=production      → SUCCESS
                                                                  build/app/outputs/flutter-apk/app-release.apk (68.9MB)
flutter build appbundle --release --dart-define=ENV=production → SUCCESS
                                                                  build/app/outputs/bundle/release/app-release.aab (68.3MB)
flutter build ios --no-codesign --dart-define=ENV=production  → SUCCESS
                                                                  build/ios/iphoneos/Runner.app (28.7MB)
```

No code was changed this batch, so this is a straight re-run of
Batch 12's own build matrix — reported honestly as a re-confirmation,
not new work.

## DJANGO

```text
Django changes:    NONE
Database changes:  NONE
Migrations:        NONE
API changes:       NONE
```

`git status --short` in `Career_Buddy_LMS/` shows only the same
pre-existing baseline diff present since Batch 6, independently
re-confirmed via unchanged file modification timestamps (Sep 21-22,
over a week predating this batch's work). This batch made no request
of any kind — read-only or otherwise — against the live production
server (no credentials meant no live verification was attempted at
all), so there is nothing beyond the already-established baseline to
report here.

## FINAL REMAINING ITEMS

Only genuine, real remaining items — nothing invented to manufacture a
Batch 14:

1. **Live student login/session/authenticated-feature verification is
   still unverified.** This is the same single blocker Batch 12 already
   identified, unchanged: real student credentials are needed. Once
   provided, Phases 2-3 of this batch's own instructions (login →
   session → dashboard → representative feature smoke test → logout →
   cookie clearing) can be executed exactly as written, on a real
   device/emulator/simulator running the app built with
   `--dart-define=ENV=production`.
2. **Live employer login/session/authenticated-feature verification is
   still unverified**, for the same reason — real employer credentials
   are additionally needed for this half.
3. **A live ARIA chat message was deliberately not sent** even though
   ARIA itself requires no login — sending one means making a real
   request against the live third-party AI backend behind it; this was
   judged worth flagging for an explicit decision rather than treated
   as automatically in-scope for an unattended "safe, read-only" smoke
   test. If the project owner considers this an acceptable, low-stakes
   check, it can be performed on request without needing any
   credentials at all.

**Exact next action**: the project/backend owner provides one real
student test account (username/email + password) and, if employer-side
verification is also wanted, one real employer test account. With
either in hand, this batch's Phases 2-6 can be completed exactly as
specified, and the STATUS in this document can move to `READY` or
`READY_WITH_LIMITATIONS` based on what's actually observed — not
before.

Per this batch's own explicit instruction, no further batch was started
automatically. The application's release-readiness conclusion is
unchanged from Batch 12: the app itself, its production configuration,
and its build artifacts are ready; the one open question is a live
authenticated-flow verification that requires credentials this session
does not have.
