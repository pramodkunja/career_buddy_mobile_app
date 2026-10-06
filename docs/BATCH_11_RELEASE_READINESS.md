# Batch 11 — Production Backend & Release Readiness

Read-only audit + minimal, evidence-driven hardening of environment
configuration, session/cookie handling, WebSocket URL derivation, and
release-build correctness. **No Django file was modified. No backend URL
was fabricated.** No new feature was built.

## STATUS

**READY_PENDING_BACKEND**

The Flutter app itself is release-hardened: environment/config
architecture is clean and single-sourced, session-cookie handling is
verified with real tests, WebSocket scheme derivation is correct and
tested, both Android build artifacts (APK + AAB) and the iOS build
succeed, and a misconfigured (staging/production) build now fails
loudly with an actionable message instead of a silent/confusing crash.
It cannot be called **READY** because no real production or staging
backend host has been verified — that is a genuine, external blocker
this batch cannot close (see BACKEND HOST below), not a code defect.

## BACKEND HOST

```text
Development: VERIFIED — http://10.0.2.2:8000 (Android emulator) /
             http://127.0.0.1:8000 (iOS simulator, macOS, other
             platforms). This is the actual local Django dev-server
             convention every prior batch has built and tested against;
             re-confirmed working this batch (see BUILD below).
Staging:     UNVERIFIED. `EnvironmentConfig.baseUrl` has no staging
             branch value — accessing it under `Environment.staging`
             throws a clear `UnsupportedError` (verified this batch by
             actually running the test suite with
             `--dart-define=ENV=staging`, not just by reading the code).
Production:  UNVERIFIED. Same as Staging — `Environment.production`
             throws, verified the same way with
             `--dart-define=ENV=production`.
```

**One real, source-backed candidate found, deliberately NOT wired in**:
Django's own `business_english_lms/settings.py` declares
`CSRF_TRUSTED_ORIGINS = ['https://careerbuddy4u.com', 'https://www.careerbuddy4u.com']`.
This is a genuine signal — someone configured the backend to trust
CSRF requests claiming to originate from that domain — but it is
**REFERENCED, not VERIFIED**: it does not confirm that domain is where
this specific API is actually deployed and reachable, only that the
Django project is configured to trust it as an origin (which could just
as easily be the marketing website, a different subdomain, or a domain
reserved for later use). Per this batch's explicit, absolute rule
against fabricating a backend URL, this was **not** used to fill in
`Environment.production`.

**Exact next action required from the backend/deployment owner**: confirm
(a) whether `careerbuddy4u.com` (or a specific subdomain such as
`api.careerbuddy4u.com`) is the intended live production API host, (b)
that it is actually deployed and reachable over HTTPS, and (c) provide
that confirmed URL so it can be filled into
`lib/app/config/environment.dart`'s `Environment.production` branch (and
`Environment.staging`'s, if a separate staging host exists). Once
provided, that is a one-line change in an already-designed-for-it spot —
no architecture change is needed.

## NETWORK INVENTORY

Every network destination in the app, found via a full source sweep
(`baseUrl`/`baseURL`/`apiUrl`/`API_URL`/`localhost`/`127.0.0.1`/
`10.0.2.2`/hardcoded `http://`/`https://`/Dio `BaseOptions`/WebSocket/
WebView/download URLs):

| Destination | Category | Source |
|---|---|---|
| `ApiClient`'s Dio `BaseOptions.baseUrl` (every REST call: auth, activities, exercises, AI modules, mock tests, resume, skill-up, grammar, certifications, ARIA, JAM, roleplay, group discussion HTTP endpoints, mock interview) | **Production candidate** | `EnvironmentConfig.baseUrl` |
| Group Discussion's WebSocket URI (`ws/GD_app/<id>/`) | **WebSocket / production candidate** | `buildGdWebSocketUri(EnvironmentConfig.baseUrl, sessionId)` — new this batch, see WEBSOCKET below |
| Skill-Up lesson pages (48 real static HTML files) | **WebView / production candidate** | `EnvironmentConfig.baseUrl` + `/static/001%20Career%20Buddy/...` |
| Resume History's "View File" (external browser) | **File/download / production candidate** | `EnvironmentConfig.baseUrl` + the real file path from the server response |
| Resume template download ("Download Template") | **File/download / production candidate** | `EnvironmentConfig.baseUrl` + a real static path |
| Certificate PDF (downloaded then opened locally) | **File/download / production candidate** | `EnvironmentConfig.baseUrl` via the certifications datasource |
| Country-picker flag images (`flagcdn.com`) | **External/public** | Hardcoded `https://flagcdn.com/w20/<iso2>.png` — a real, independent third-party CDN, unrelated to this backend, already HTTPS, not a candidate for `EnvironmentConfig` |
| Local dev-server address (`10.0.2.2`/`127.0.0.1:8000`) | **Development-only** | `EnvironmentConfig.baseUrl`'s `Environment.dev` branch only — never reachable from a staging/production build |

**Every single backend-destination reference in the entire app already
funnels through the one `EnvironmentConfig.baseUrl` getter** — confirmed
by grep, not assumed. There is no scattered/duplicated URL anywhere to
consolidate; the "Environment → AppConfig → ApiClient/WebSocket/WebView/
downloads" architecture this batch's own instructions asked for already
existed (built incrementally since early batches) and needed no
rewrite — only the hardening described below.

## AUTHENTICATION

Session-cookie architecture (Django session auth, confirmed — **not**
replaced with JWT, per this batch's explicit rule) verified this batch
with new, real (not fake-repository) tests against `ApiClient` itself:
- A `Set-Cookie` response header is genuinely captured by
  `dio_cookie_manager`'s `CookieManager` into the persisted `CookieJar`
  and later readable via `readCookie` — **verified** (`test/core/network/
  api_client_test.dart`).
- `buildCookieHeader()` (used to attach the session cookie to the
  Group Discussion WebSocket's handshake, since `web_socket_channel`
  bypasses Dio entirely) correctly joins every persisted cookie into one
  real `name=value; name2=value2` string — **verified**.
- `clearCookies()` — the exact method `AuthRemoteDataSource.logout()`'s
  `finally` block already calls unconditionally (even if the server
  logout request itself fails) — genuinely empties the jar —
  **verified**.
- CSRF handling: the established pattern (read `csrftoken` via
  `readCookie`, send it back as `X-CSRFToken`) is used consistently
  across every state-changing request in the app (login, logout, resume
  upload, certificate actions, JAM/Roleplay/Mock-Interview submissions,
  etc.) — spot-checked, not re-derived from scratch, since Batches 1-10
  already established and tested this per-feature.
- One real testability gap found and fixed: `ApiClient.forTesting`
  always built a **fresh, disconnected** in-memory `CookieJar()`
  regardless of what the caller's `Dio` was configured with — meaning no
  test in this codebase could previously exercise real cookie
  persist-then-replay behavior end-to-end. Widened (backward-compatibly:
  a new optional `cookieJar` parameter, defaulting to the exact same
  behavior every existing caller already gets) so this batch's new tests
  could verify the real mechanism, not just its own bookkeeping.
- Login persistence / session restoration / expiry: already covered by
  the pre-existing, still-passing `auth_controller_test.dart` suite from
  earlier batches — re-run this batch, not re-derived.

## WEBSOCKET

Group Discussion's WebSocket URL derivation was **already correct**
(built this way back in Batch 9) — `scheme: baseUri.scheme == 'https' ?
'wss' : 'ws'` — confirmed by direct code read, then extracted into its
own pure, directly-testable function (`buildGdWebSocketUri`, in
`lib/features/group_discussion/domain/gd_websocket_url.dart`) purely for
testability (it was previously inline inside a private controller
method, unreachable by a focused unit test). 4 new tests prove: `http://`
→ `ws://`, `https://` → `wss://` (never hardcoded), the real session id
is preserved in the path, and the scheme is never silently left as `ws`
when the base URL is already secure. The session cookie is attached to
the WebSocket's initial HTTP upgrade request via `buildCookieHeader()`
(Dio's own cookie manager doesn't run for a socket handshake), matching
exactly how Django Channels' `AuthMiddlewareStack` authenticates it —
confirmed against `asgi.py` in an earlier batch, re-confirmed unchanged
this batch.

## SECURITY

Full sweep of `lib/` for hardcoded credentials, verbose logging, and
insecure defaults:

```text
SAFE            — no badCertificateCallback / disabled cert verification
                  / custom SecurityContext anywhere.
SAFE            — no LogInterceptor / verbose network logging anywhere.
SAFE            — no hardcoded API keys, passwords, or secrets found
                  (Sarvam/Razorpay keys live only server-side, in Django
                  env vars — confirmed by reading .env.example's KEY
                  NAMES only, no values printed, none referenced from
                  Flutter at all).
SAFE            — zero print()/debugPrint() calls anywhere in lib/.
SAFE            — zero TODO/FIXME comments anywhere in lib/.
DEVELOPMENT-ONLY — Direct Demo Entry's kDebugMode gate: a compile-time
                  constant, so the code path is provably eliminated by
                  tree-shaking in every release build, not just
                  logically unreachable. Unchanged this batch, already
                  documented since Batch 5A.
RELEASE-BLOCKER (external, not a code defect) — see BACKEND HOST above:
                  a release build with no `--dart-define=ENV=production`
                  defaults to `Environment.dev`, which resolves to a
                  plain-HTTP local address. This is not fixable by this
                  batch (no real host exists yet to put there); it is
                  now at least impossible to do *silently* for
                  staging/production (both throw a clear, actionable
                  error — verified, see ENVIRONMENT below), but `dev` has
                  no such guard by design (it must keep working for
                  ordinary development). **The actual release process
                  must explicitly pass `--dart-define=ENV=production`**
                  once a real host is configured — flagged here as the
                  single most important process step, not a code
                  change.
UNKNOWN         — iOS App Transport Security behavior for the *dev*
                  `http://127.0.0.1:8000` configuration on a real device/
                  simulator was not empirically re-tested this batch (no
                  running iOS simulator in this environment); no
                  `NSAppTransportSecurity`/`NSAllowsArbitraryLoads`
                  override exists in `Info.plist` today. This is a
                  dev-workflow question only — once a real HTTPS
                  production host is configured, default ATS already
                  permits it with zero configuration, so this does not
                  affect release readiness.
```

No secret **value** is reproduced anywhere in this document or was
printed to the terminal during this audit — only key names/locations,
per this batch's own explicit instruction.

## PERMISSIONS

```text
Android (AndroidManifest.xml):
  RECORD_AUDIO           — present (AI Speaking/Writing/Listening/
                            Reading, JAM, Roleplay, Group Discussion,
                            Mock Interview, Timer's on-device STT)
  CAMERA                 — present (Mock Interview's camera gate/
                            recording)
  <uses-feature camera, required="false"> — present, correctly marked
                            optional (a device without a camera can
                            still install the app; Mock Interview alone
                            would be unavailable)
  No unnecessary permission found.

iOS (Info.plist):
  NSMicrophoneUsageDescription       — present, real description
  NSCameraUsageDescription           — present, real description
  NSSpeechRecognitionUsageDescription — present, real description
  No NSPhotoLibrary/NSContacts/NSLocation or other unused permission
  present.
```

Both re-confirmed present and correctly worded this batch (added in
Batch 9, unchanged since); both release builds (APK/AAB/iOS) below
compiled cleanly with them in place.

## WEBVIEW

Skill-Up's 48 real lesson pages (`SkillUpLessonScreen`):
- **HTTPS compatibility**: the WebView loads whatever `EnvironmentConfig
  .baseUrl` resolves to — automatically HTTPS once a real production
  host is configured, no separate WebView-specific TLS configuration
  needed or added.
- **Authenticated content**: confirmed (Batch 7) these specific static
  files are served unauthenticated by Django's plain `static()` file
  server — no session-cookie sharing into the WebView is required or
  attempted for this feature.
- **Unrecoverable error state / retry**: fixed in Batch 10
  (`onWebResourceError`, main-frame errors only, real `AppErrorView` +
  retry that reloads the same URL) — re-confirmed present and unchanged
  this batch.
- **External URL handling**: this screen only ever loads the app's own
  configured backend's static files; it does not navigate to arbitrary
  external URLs.

## DOWNLOAD / EXTERNAL URL AUDIT

Every `launchUrl(...)` call site in the app (3 total, confirmed by
direct grep, none added or changed this batch):
1. Resume History's "View File" — a real path from the server's own
   response, opened in the external browser (a known, documented
   limitation: the external browser doesn't share the app's session
   cookie — unchanged since Batch 6, not this batch's scope to fix).
2. Resume template download ("Download Template") — a real, public,
   unauthenticated static `.docx` path.
3. Certificate PDF — downloaded via the authenticated Dio client first,
   then opened from a local file path (`Uri.file(...)`), not a remote
   URL at all.

All three are real, source-backed, already-existing destinations from
earlier batches — none replaced, none added, none pointed at a
fabricated URL.

## BUILD

```text
flutter analyze                        → No issues found. (0 issues)
flutter test                            → 1543/1543 passing
flutter build apk --release             → SUCCESS
                                           build/app/outputs/flutter-apk/
                                           app-release.apk (68.9MB)
flutter build appbundle --release       → SUCCESS
                                           build/app/outputs/bundle/
                                           release/app-release.aab
                                           (68.3MB)
flutter build ios --no-codesign         → SUCCESS
                                           build/ios/iphoneos/Runner.app
                                           (28.7MB)
```

One pre-existing, non-blocking warning on every build (`flutter_tts`'s
Kotlin Gradle Plugin / Swift Package Manager deprecation notices,
carried over unchanged from Batches 9-10 — a Flutter-tooling notice
about the plugin's own packaging, not an error, and not something this
batch's scope covers changing).

## TEST COUNT

**1543/1543 passing** (1532 Batch-10 baseline + 11 new this batch: 4
`buildGdWebSocketUri` scheme-derivation tests, 4 real `ApiClient` cookie-
persistence tests, 3 `EnvironmentConfig` tests for the default/dev run —
plus 2 more `EnvironmentConfig` tests each independently verified via
dedicated `--dart-define=ENV=staging`/`ENV=production` runs, shown
passing above but not double-counted in the default suite's own total
since a single test binary only exercises one compiled-in `ENV` value at
a time).

Every pre-existing test from Batches 1-10 still passes unmodified —
nothing weakened, skipped, deleted, or replaced with a vacuous
assertion.

## DJANGO

```text
Django/Web project modified: NO
Database modified:           NO
Migrations:                  NO
Seed data:                   NO
API changes:                 NO
```

`git status --short` in `Career_Buddy_LMS/` shows only the same
pre-existing baseline diff present at the start of every batch since
Batch 6 — independently re-confirmed via file modification timestamps
to still predate this batch's work by over a week (Sep 21-22, vs. this
batch's work on Sep 30). Every Django-side investigation this batch
performed (`ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, `SESSION_COOKIE_
SECURE`/`CSRF_COOKIE_SECURE`/`SECURE_SSL_REDIRECT`, `ASGI_APPLICATION`/
`CHANNEL_LAYERS`, CORS config, `.env.example`'s key names) was `Read`/
`grep` only — never a write, never a migration, never a database
mutation, never a settings change.

## REMAINING RELEASE BLOCKERS

Only genuine blockers, not cosmetic items:

1. **No verified production or staging backend host exists yet.** This
   is the one real, external blocker on shipping a functioning release
   build. `careerbuddy4u.com`/`www.careerbuddy4u.com` are *referenced*
   (Django's own `CSRF_TRUSTED_ORIGINS`) but not confirmed as the actual
   deployed, reachable API host — see BACKEND HOST above for the exact
   confirmation needed from the backend/deployment owner.
2. **The release process itself must remember to pass
   `--dart-define=ENV=production`** once that host is confirmed and
   filled in — otherwise a release build silently defaults to `dev`
   (this is a process/checklist item for whoever cuts the release
   build, not something further code can force, since `dev` must keep
   working with no flag for ordinary development).

Everything else audited this batch (network inventory, session/cookie
handling, WebSocket scheme derivation, security sweep, permissions,
WebView/download URLs, the full build matrix) came back clean or was
fixed in place; none of it blocks a release once item 1 is resolved.
