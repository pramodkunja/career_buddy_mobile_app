# Career Buddy LMS — Full Production E2E, API, Data, UI & Web-Flow Verification

Real production backend (`https://careerbuddy4u.com`) exercised with 4 real
test accounts (2 student/jobseeker, 2 employer). Findings below come from
four independent per-account verification passes (one background agent per
account, each isolated to its own cookie jar) plus my own direct work: root
cause analysis, code fixes, and on-device verification against a real
release build (`--dart-define=ENV=production`) on an Android emulator.

All credentials, session cookies, and CSRF tokens are redacted throughout.
No password was changed. No destructive account action was taken. All
`/tmp` scratch files (cookie jars, header/body dumps) were deleted by each
agent and by me as a final step.

---

## 1. Executive Summary

**PASS WITH ISSUES.**

The app correctly targets real production (`https://careerbuddy4u.com`),
and — after two Flutter defects found and fixed during this task — logs in
and out correctly against all tested account types, with sessions that
match the real Django `sessionid`-cookie contract. Every endpoint that IS
live matched Flutter's parsing/field expectations exactly, across ~20 real
authenticated features spanning 4 accounts. No fabricated or assumed data
appears anywhere in the app; every failure mode observed (404s, locked
workshops, incomplete-employer-profile gates) is handled with a real,
honest error state — never a crash, never silently-faked content.

The two defects found here were both **production-only** (invisible in the
dev/HTTP environment used by every prior batch) and both **blocking**:
without the first fix, no account of any kind could log in to the real
production app at all. Both are now fixed, verified on-device against a
real, unmodified production account, and covered by new regression tests.

What keeps this from a clean PASS:
- A real, undeployed backend gap blocks the Dashboard, Activities list/
  detail, and MCQ exercise screens for **every** account (BACKEND/
  DEPLOYMENT gap, not a Flutter defect — the code exists in the local
  Django checkout but isn't live).
- A live scoring anomaly on Matching-exercise submission (server returned
  score 0 for a verified fully-correct, correctly-shaped submission) —
  flagged for backend investigation, not attributable to Flutter.
- 5 real, live, 200-reachable employer features are `ComingSoonScreen`
  placeholders in the app (Post Job, All Applications, Job Openings,
  Candidate Search, Company Profile edit/create).
- No privacy policy, store listing, real signing keystore, or Apple
  Developer Team exist yet (carried over, unchanged, from Batch 14 — store
  submission readiness is a separate, still-open concern from this task's
  functional-parity scope).

---

## 2. Environment

- Backend: `https://careerbuddy4u.com` — confirmed via `EnvironmentConfig.
  baseUrl` under `Environment.production` (`lib/app/config/environment.
  dart`), and via every account agent's own live `curl`/on-device traffic
  actually landing there. No account, request, or test in this task used
  `localhost`/dev.
- Build: `flutter build apk --release --dart-define=ENV=production`,
  confirmed via `aapt2 dump badging` (package `com.sriainfotech.
  career_buddy_lms`) and by the literal host string being present in the
  compiled AOT binary (re-confirmed this task, same technique as Batch 12).
- Device: Android emulator (`emulator-5554`), release APK installed via
  `adb install -r`, fresh app state via `adb shell pm clear` before each
  login test (rules out stale-cookie-jar contamination from earlier
  batches' testing on the same emulator).
- iOS: not device-tested this task (no signed device available, unchanged
  from Batch 14's own finding — no Apple Developer Team configured).
- Django checkout used for read-only source cross-referencing:
  `Career_Buddy_LMS/Career_Buddy_LMS/` — **never modified**, confirmed
  clean of any edit from this task (only pre-existing baseline diff from
  Batch 6 remains, unchanged).

---

## 3. Authentication (per account)

| Account | Role | Result | Evidence |
|---|---|---|---|
| `nvenkatsai` | Student (Free plan) | ✅ VERIFIED (after fix) | Login/logout both confirmed live via curl AND on-device release build; session cookie set/cleared correctly; cross-role guard confirmed |
| `Testone` | Jobseeker/Student (Pro plan) | ✅ VERIFIED | Login/logout confirmed live via curl; 36 real resumes, 4 real payments, 20 activities on this account — a heavily-used real account, not a fresh seed |
| `rameshn` | Employer | ✅ VERIFIED | Login (`/employer/accounts/employer/login/` → 302 → `/employer-home/`), logout, and both-direction cross-role guard confirmed live |
| `Testthree` | Employer | ✅ VERIFIED | Login confirmed; this account has an **incomplete** EmployerProfile (missing GST/PAN), so `employer_dashboard` correctly redirects to profile-create — a real account state, not a bug |

**Before the Referer-header fix (§9), zero accounts could log in through
the real compiled app in production** — every login attempt failed with a
generic `ServerFailure`, despite the exact same credentials succeeding
every time via direct `curl`. This was root-caused, fixed, and re-verified
live on-device for `nvenkatsai`; the fix is architecture-wide (applies to
every request through the single shared `ApiClient`), so it is not
account-specific.

Cross-role guards (re-verified live, matching Batch 10's original finding):
employer session → `/dashboard/` → real `302` to `/employer-home/` (no
forced logout); confirmed in both directions by Agent 3 (`rameshn`).

---

## 4. Feature Matrix (real, live results — not assumed)

| Feature | `nvenkatsai` | `Testone` | `rameshn` | `Testthree` |
|---|---|---|---|---|
| Login/Logout | ✅ (after fix) | ✅ | ✅ | ✅ |
| Dashboard (data) | ❌ BACKEND/DEPLOYMENT gap | ❌ BACKEND/DEPLOYMENT gap | n/a (employer) | n/a (employer) |
| Employer Dashboard | n/a | n/a | ✅ (full stats) | ❌ real incomplete-profile gate (not a bug) |
| Activities list (JSON) | ❌ BACKEND/DEPLOYMENT gap | ❌ BACKEND/DEPLOYMENT gap | n/a | n/a |
| Activities list (HTML, web-only) | ✅ 4 free-preview cards, 1 unlocked | ✅ 20 cards, 5 done | n/a | n/a |
| MCQ exercise | ❌ blocked by JSON API gap | ❌ blocked by JSON API gap | n/a | n/a |
| Matching exercise | n/a (no unlocked instance) | ⚠️ correct submission scored 0 (anomaly, see §10) | n/a | n/a |
| Fill-Blank exercise | n/a | ✅ correct shape, correct score (5/5) | n/a | n/a |
| Generic-Writing exercise | n/a | ✅ real Sarvam AI grading, 100/100 | n/a | n/a |
| Bingo exercise | NOT VERIFIED (no unlocked instance either account) | NOT VERIFIED | n/a | n/a |
| AI Listening (token+config) | ✅ exact contract match | (not separately re-tested) | n/a | n/a |
| AI Speaking/Writing/Reading | NOT VERIFIED (locked/no reachable instance); contract code-verified, MATCH | NOT VERIFIED (same); contract code-verified, MATCH | n/a | n/a |
| Mock Test — OOP/AMCAT/CoCubes | ✅ all 3, exact field match | ✅ OOP confirmed | n/a | n/a |
| Resume/ATS | ✅ history parsed correctly | ✅ history parsed (36 items); upload/reanalyze NOT VERIFIED (write-safety guard) | n/a | n/a |
| Skill-Up | ✅ exact match | ✅ (code-verified) | n/a | n/a |
| Grammar | ✅ 9 topics exact match | ✅ (code-verified) | n/a | n/a |
| Certifications | ✅ exact field match | ✅ exact field match | n/a | n/a |
| ARIA | ✅ 2 real messages, contract match | ✅ auth-vs-anon personalization confirmed | n/a | n/a |
| JAM (practice) | ✅ locked (real plan gate) | ✅ reachable, topics parsed | n/a | n/a |
| JAM Assessment | code-verified present, MATCH (see §9 note below) | code-verified present, MATCH | n/a | n/a |
| Roleplay | ✅ locked (real plan gate) | ✅ reachable | n/a | n/a |
| Group Discussion | ✅ locked (real plan gate) | ✅ 8 real sessions, exact field match | n/a | n/a |
| Post New Job | n/a | n/a | MISSING (placeholder) | MISSING (placeholder) |
| All Applications | n/a | n/a | MISSING (placeholder) | MISSING (placeholder) |
| Job Openings | n/a | n/a | MISSING (placeholder) | MISSING (placeholder) |
| Candidate Search | n/a | n/a | MISSING (placeholder) | MISSING (placeholder) |
| Company Profile edit/create | n/a | n/a | MISSING (placeholder) | MISSING (placeholder) — the one screen `Testthree` actually needs right now |

**JAM Assessment vs web**: confirmed present on both — `jam_app/urls.py`
has a real, distinct Assessment Module (`assessment/start/`, `assessment/
session/<id>/`, `assessment/result/<id>/`), and Flutter's `api_endpoints.
dart` implements the full 3-stage flow (`jamAssessmentStart`,
`jamCompleteSession`'s stage-aware branching, `JamAssessmentEligibility
Controller`) against those exact same views — not missing, not a stub.

---

## 5. API Matrix (consolidated)

| Feature | Web request | Flutter request | Same endpoint | Same method | Request data matches | Response handled | Status |
|---|---|---|---|---|---|---|---|
| Student login | `POST /users/login/` | `AuthRemoteDataSource.login()` | ✅ | ✅ | ✅ | ✅ (after fix) | PASS |
| Student logout | `POST /users/logout/` | `AuthRemoteDataSource.logout()` | ✅ | ✅ | ✅ | ✅ (after fix) | PASS |
| Employer login | `POST /employer/accounts/employer/login/` | `EmployerAuthRemoteDataSource.login()` | ✅ | ✅ | ✅ | ✅ | PASS |
| Dashboard (JSON) | n/a (web is HTML-only) | `GET /dashboard/api/` | n/a | n/a | n/a | 404 → `NotFoundFailure` → honest error UI | BACKEND/DEPLOYMENT GAP |
| Activities list/detail/MCQ (JSON) | n/a | `GET /activities/api/...` | n/a | n/a | n/a | 404 → honest error UI | BACKEND/DEPLOYMENT GAP |
| Exercise submit | `POST /activities/exercise/<id>/submit/` | same, same JSON shape | ✅ | ✅ | ✅ (Fill-Blank verified correct) | ⚠️ Matching type scored unexpectedly | BACKEND/API LIMITATION (needs investigation) |
| Mock quiz OOP/AMCAT/CoCubes | `GET /activities/{oop-quiz,amcat,cocubes}/questions/` | same | ✅ | ✅ | ✅ | ✅ | PASS |
| Certifications status | `GET /skill-up/assessment/api/status/` | same | ✅ | ✅ | ✅ | ✅ | PASS |
| Resume history | `GET /resume-builder/history/` (HTML) | same, regex-scraped | ✅ | ✅ | n/a (GET) | ✅ | PASS (INTENTIONAL MOBILE ADAPTATION: HTML scrape, no JSON API exists) |
| ARIA chat | `POST /api/riya/chat/` | `AriaRemoteDataSource.sendMessage()` | ✅ | ✅ | ✅ | ✅ | PASS |
| GD sessions | `GET /gd/api/sessions/` | same | ✅ | ✅ | n/a | ✅ | PASS |
| Employer dashboard | `GET /employer/employer/dashboard/` (HTML) | same, HTML-scraped | ✅ | ✅ | n/a | ✅ (incl. incomplete-profile redirect classification) | PASS |
| `GET /dashboard/api/` as employer session | n/a | n/a | — | — | — | **404, not the 401/403 the checked-in source implies** | BACKEND/API LIMITATION (informational, outside employer scope, flagged not chased) |

---

## 6. Static Content Matrix

| Content | Web source | Flutter source | Match? |
|---|---|---|---|
| Skill-Up hero stats (48/3/3/100%) | `templates`/live HTML | `lib/.../skill_up_data.dart` (hand-transcribed constants) | ✅ STATIC WEB CONTENT, byte-identical |
| Grammar topic list (9 topics) | `GET /subject/` | `assets/data/grammar_data.json` | ✅ STATIC WEB CONTENT, exact order/names |
| Login page copy/branding | `templates/users/login.html` | `login_screen.dart` (hand-transcribed) | ✅ matches, confirmed via direct on-device screenshot comparison this task |
| Employer Home copy | live HTML | `employer_home_screen.dart` | ✅ verbatim match ("Manage Dashboard"/"Find Candidates") |

---

## 7. Data Comparison

| Feature | Web (real value) | Flutter (parsed/rendered) | Expected | Actual | Difference | Root cause |
|---|---|---|---|---|---|---|
| Dashboard greeting | "Welcome back, venkat" (from `user.first_name`) | Shows literal login string `"nvenkatsai"` | Personalized first name | Raw username | Real, visible difference | **MISSING** — the documented `/dashboard/api/` contract has no `first_name`/display-name field for Flutter to read even once deployed; not fixable client-side alone |
| Dashboard stats (Total/Completed/In-Progress/Score) | 27/5/8/1284 (`nvenkatsai`) | Would map field-for-field via `DashboardDataParsing` | Match | Unreachable (404) | N/A live | BACKEND/DEPLOYMENT GAP |
| Certifications status | `total_count=27, attempted=0, earned=0` | Same, field-for-field | Match | Match | None | — |
| Matching exercise score | Client sends correct shape, `score:5/max_score:5` | Server returns `score:0/5` despite documented "trusts client score verbatim" | 5/5 | 0/5 | Real anomaly | BACKEND/API LIMITATION — needs backend investigation; Flutter's wire shape verified correct against the documented contract |
| Fill-Blank exercise score | Correct shape → 5/5 | Same | Match | Match | None | — (first 2 attempts scored 0 due to the *tester's* wrong wire shape, not a Flutter bug — corrected on 3rd attempt) |
| Employer dashboard stats (`rameshn`) | Total Jobs=1, Active=1, Applications=4 | Same via `employer_dashboard_html_parser.dart` regexes | Match | Match | None | — |

---

## 8. UI Comparison

Severity scale: P0 = blocks core flow, P1 = significant but workaroundable,
P2 = minor/cosmetic, P3 = negligible.

| Finding | Severity | Notes |
|---|---|---|
| Login failed with a generic, unhelpful error in production | P0 | Fixed this task (§9) |
| Logout showed a false "Something unexpected happened" error after a real, successful logout | P1 | Fixed this task (§9); cosmetic only — session was always correctly cleared |
| Dashboard greeting shows raw username instead of first name | P2 | Root cause is a data-contract gap (§7), not a rendering bug |
| Structure/typography/color/spacing across all screens tested | — | No P0–P3 findings — every screen tested (login, dashboard error state, employer home, mock quiz, certifications, resume history, skill-up, grammar) reproduces the web's information hierarchy; mobile-native layout differences (single-column stacking, bottom nav vs sidebar) are INTENTIONAL MOBILE ADAPTATION, not defects, per this task's own instruction not to flag those |

---

## 9. Fixes Applied This Task (Flutter defects — root-caused, fixed, verified)

Both fixes are confined to `Mobile_app/`; the Django project was never
touched. Both were root-caused via direct evidence (live reproduction +
code inspection) before any fix was made, per this task's own rule.

### 9.1 Missing `Referer` header broke every production login (P0, FLUTTER DEFECT)

- **Symptom**: on a real device, release build, `--dart-define=ENV=
  production`, a clean, single, correctly-filled login submission for
  `nvenkatsai` failed with a generic `ServerFailure` ("Something went wrong
  on our end"), while the identical credentials succeeded via `curl`
  moments before and after.
- **Root cause**: `lib/core/network/api_client.dart`'s single shared `Dio`
  instance never set a `Referer` header on any request. Django's
  `CsrfViewMiddleware` enforces a same-origin `Referer` check specifically
  for HTTPS requests (`request.is_secure()`), independent of and in
  addition to the CSRF token check — rejecting the request with `403` even
  with a valid token. Confirmed by live reproduction: an otherwise-
  identical `curl` POST to the same production login endpoint with the
  same credentials went from a guaranteed `302` success to a `403
  Forbidden` (body containing "CSRF"/"Forbidden"/"Referer") purely by
  omitting `--referer`. This was invisible through every prior batch
  because the dev backend is plain HTTP, where Django skips this check
  entirely.
- **Impact**: every unsafe-method request (POST/PUT/PATCH/DELETE) from the
  compiled app to real production — not just login — was affected.
  Effectively, **no account of any kind could authenticate through the
  real production app before this fix.**
- **Fix**: added a default `Referer: <baseUrl>` header to `ApiClient.
  create()`'s `BaseOptions` — a single, architecture-wide fix (per the
  class's own existing doc comment: "add a request interceptor here rather
  than changing every call site").
- **Verified**: live on-device, release build, fresh install (`pm clear`),
  real credentials — login now succeeds cleanly and reproducibly (tested
  twice, same result both times).

### 9.2 `logout()` treated a correct 302 response as an error (P1, FLUTTER DEFECT)

- **Symptom**: on-device, immediately after a real, successful logout, the
  app showed "Something unexpected happened. Please try again." on the
  login screen.
- **Root cause**: `AuthRemoteDataSource.logout()` never overrode Dio's
  default `validateStatus` (200-299 only), but the real Django logout view
  responds `302` on success — confirmed independently by 3 of the 4
  background agents' live `curl` tests. Dio treated the 302 as an HTTP
  error, `ApiExceptionsInterceptor` mapped it to `UnexpectedResponseException`
  → `UnexpectedFailure`, and `AuthController.logout()` surfaced that
  message to the user. The `finally` block still cleared cookies
  regardless, so the session was always correctly torn down — only the
  displayed message was wrong.
- **Fix**: added `validateStatus: (status) => status != null && status <
  500` to the logout POST's `Options`, mirroring the same redirect-on-
  success handling `login()` already had.
- **Verified**: live on-device, same account, same build — logout now
  returns cleanly to the login screen with no error banner.

### 9.3 Regression tests added

- `test/core/network/api_client_test.dart` — asserts a `Dio` built the same
  way `ApiClient.create()` builds it sends a same-origin `Referer` header.
- `test/features/auth/data/datasources/auth_remote_datasource_test.dart`
  (new file) — asserts `logout()` completes (does not throw) on a real 302
  response, and still throws on a genuine 5xx.
- `test/support/fake_http_client_adapter.dart` — added an optional
  `onRequest` callback so tests can inspect outgoing request headers
  without a real network call (backward-compatible; no existing test
  changed behavior).

Full suite after both fixes: **`flutter analyze` → No issues found.**
**`flutter test` → 1547/1547 passing** (1544 baseline + 3 new). Production
release APK rebuilt and re-verified on-device after each fix.

---

## 10. Missing Features

Confirmed live and via source (`route_paths.dart`'s own doc comments):

- Employer: Post New Job, All Applications, Job Openings, Candidate
  Search, Company Profile create/edit — all 5 are real, live, 200-
  reachable web features rendered as `ComingSoonScreen` placeholders in
  Flutter. Company Profile is the one `Testthree` specifically needs today
  to unblock its own dashboard.
- Employer: per-job Edit/Delete/View-Applications action links — no
  Flutter destination at all (not even a placeholder route).
- Resume upload / re-analyze — not exercised this task (see §12); existing
  history reading works.
- Dashboard first/last-name greeting — not reproducible even once
  `/dashboard/api/` is deployed, since that documented contract has no
  name field (§7).

---

## 11. Backend/API Limitations

**FLUTTER DEFECT** (fixed this task): missing `Referer` header (§9.1);
`logout()` validateStatus gap (§9.2).

**BACKEND/DEPLOYMENT GAP** (not a Flutter defect — code exists locally,
not deployed): `/dashboard/api/`, `/activities/api/`, `/activities/api/
<id>/`, `/activities/api/sub/<id>/`, `/activities/api/exercise/<id>/` all
404 live on production, while the corresponding views exist as
**uncommitted, unpushed changes** in the local Django checkout
(`activities/urls.py`, `activities/views.py`, `business_english_lms/
urls.py`). Flutter's parsing code for all of these was verified
field-for-field correct against the local view source — it will work
once deployed, no Flutter change needed.

**BACKEND/API LIMITATION (needs investigation)**: live `submit_exercise`
for a "matching" exercise returned `score:0/5` for a verified, correctly-
shaped, fully-correct submission, contradicting the documented "trusts
client score verbatim" contract; the live response also includes fields
(`sub_progress`, `activity_progress`) absent from the local checkout's
version of that view, meaning production has diverged from the local
Django checkout beyond the known API-deployment gap. Flutter sends the
documented-correct wire shape; this is not attributable to the app.

**BACKEND/API LIMITATION (informational)**: `GET /dashboard/api/` as an
authenticated employer session returns a real `404`, not the `401`/`403`
JSON the checked-in Django source implies — flagged, not chased further
(outside this task's employer-portal scope; not used by Flutter's employer
flow).

**INTENTIONAL MOBILE ADAPTATION**: HTML-scraping (regex/embedded-JSON) for
Resume, Skill-Up, Grammar, Certifications-adjacent flows, JAM, Roleplay,
GD where no JSON API exists — deliberate, documented, and every scrape
point checked against real live HTML matched.

**MISSING BACKEND API**: none beyond the already-flagged first-name field
gap in the documented (not yet even deployed) dashboard contract (§7, §10).

---

## 12. Auth/Session Results

- Session cookie mechanics (Django `sessionid`, `HttpOnly`/`Secure`/
  `SameSite=Lax`) confirmed live for both student and employer login flows.
- Logout confirmed to genuinely invalidate the server-side session
  (re-`GET` to a protected URL after logout correctly redirects to login)
  — for both roles.
- Cross-role guards confirmed live in both directions, matching the
  server's own `_is_employer_session` redirect logic (no forced logout on
  a same-portal-family cross-navigation, consistent across student↔
  employer).
- A stray leftover `/tmp/cbl_verify_*` cookie file from earlier in this
  task's own work (containing a live, unexpired session cookie for a
  different test account) was found and deleted by Agent 1 as a real
  operational risk — remediated, not a code defect.

---

## 13. Production Test Results

Summarized fully in §3-§10. Every finding in this report was produced
against the real `careerbuddy4u.com` host, using the 4 real provided
accounts, with no fabricated data and no destructive account action.

---

## 14. Device Test Results

- Android (emulator, release APK, `--dart-define=ENV=production`): login,
  dashboard error-state handling, logout, and session-guard redirect all
  directly verified on-device this task, before and after both fixes.
- iOS: NOT VERIFIED (no signed device/Apple Developer Team available,
  unchanged from Batch 14).

---

## 15. Automated Tests

```text
flutter analyze   → No issues found.
flutter test      → 1547/1547 passing (1544 baseline + 3 new this task)
flutter build apk --release --dart-define=ENV=production  → SUCCESS (rebuilt twice this task, once per fix)
```

---

## Final Classification

**B — Functionally sound with real, fixed defects and disclosed backend
gaps.** (Scale: A = fully verified, zero issues; B = solid, real issues
found and either fixed or clearly attributed; C = significant unresolved
gaps; D = not production-ready.)

Rationale: two genuine, production-blocking Flutter defects existed and
have been fixed and verified live; every other discrepancy found traces to
either a real, undeployed backend feature or a live backend scoring
anomaly outside Flutter's control — not to Flutter mis-implementing a
working contract. Store-readiness items (privacy policy, signing,
metadata) remain open from Batch 14 and are unaffected by this task's
functional scope.

### Final Questions

**A. Does Flutter follow the web's flow?** YES, for every flow reachable
this task (login, logout, dashboards, exercises, mock tests, resume,
certifications, ARIA, JAM/Roleplay/GD reachability). PARTIAL for employer
job-management flows (5 features are placeholders).

**B. Does Flutter use the backend correctly?** YES, after the two fixes in
§9. Before the fixes: NO (login was completely broken in production).

**C. Are API connections correct?** YES for every endpoint that is live.
NO/PARTIAL for the undeployed `/dashboard/api/` + `/activities/api/*`
family (§11) — a backend gap, not a Flutter defect.

**D. Does dynamic data match?** YES for every feature with a live
endpoint (certifications, mock quizzes, resume history, employer
dashboard, GD sessions, ARIA). NO for the Matching-exercise score anomaly
(§7, §11) — server-side, not Flutter. PARTIAL for the dashboard greeting's
missing first-name field.

**E. Is static content correctly converted?** YES — Skill-Up, Grammar,
login-page branding all verified STATIC WEB CONTENT matches.

**F. Does the UI match?** YES on information hierarchy and structure for
every screen tested; no P0-P1 UI-fidelity defects found (§8). Mobile-
native layout adaptations are intentional, not defects.

**G. List ALL missing features found:**
1. Employer: Post New Job
2. Employer: All Applications
3. Employer: Job Openings
4. Employer: Candidate Search
5. Employer: Company Profile create/edit
6. Employer: per-job Edit/Delete/View-Applications links
7. Dashboard first/last-name display (contract-level gap, not yet even
   deployable)

**H. List ALL backend/API limitations found:**
1. `/dashboard/api/` and the `/activities/api/*` family undeployed to
   production (BACKEND/DEPLOYMENT GAP)
2. Matching-exercise submission scoring anomaly (BACKEND/API LIMITATION,
   needs investigation)
3. `/dashboard/api/` returns 404 instead of 401/403 for an authenticated
   non-student (employer) session (informational, outside scope)

**I. List ALL production blockers found:** Before this task's fixes: total
login failure in production (now fixed). Remaining: none block basic
functional use of the app in production; the undeployed JSON-API family
blocks Dashboard/Activities/MCQ specifically until the backend team
deploys the already-written (but uncommitted) Django code.

**J. What must be fixed before release?**
1. Backend team: deploy the `/dashboard/api/` + `/activities/api/*`
   Django changes already sitting uncommitted in the local checkout.
2. Backend team: investigate the Matching-exercise scoring anomaly.
3. Product decision: whether the 5 missing employer features and the
   dashboard first-name gap need to ship before release, or are
   acceptable as known v1 gaps.
4. Carried over from Batch 14, unrelated to this task's functional
   findings: real signing keystore, Apple Developer Team, privacy policy,
   store listing metadata.

Both Flutter-side defects this task could act on (§9) are already fixed,
tested, and verified live — no further Flutter code change is required for
anything found in this pass.
