# Batch 12 — Production Backend Verification & Release Candidate

Positively verifies the real, deployed HTTPS backend host for Career
Buddy LMS via multiple independent, read-only, non-destructive signals,
configures `Environment.production` accordingly, and re-runs the full
release build matrix against it. **No Django file was modified. No
backend URL was fabricated or assumed — every claim below is backed by
an actual command and its actual output**, captured during this batch.

## STATUS

**READY_PENDING_LIVE_AUTH**

The production backend host is positively verified (see PRODUCTION HOST
below) and `Environment.production` is now configured to it. The app
itself, its configuration architecture, and all three release build
artifacts are release-ready. This is not called **READY** because the
full live login → authenticated-session flow was never exercised against
the real host — no test/demo credentials exist anywhere in this project
(confirmed in this repo's own `teamcontextfile.md`, written back in
Batch 1, and never contradicted since), and none were invented to force
a result. It is not **BLOCKED** because the actual blocker from Batch 11
(no verified host) is now resolved.

## PRODUCTION HOST

```text
Verified HTTPS host: https://careerbuddy4u.com
(www.careerbuddy4u.com resolves to the same IP and serves byte-identical
responses — same Content-Length, same behavior on every route checked.)
```

**This was not assumed from `CSRF_TRUSTED_ORIGINS` alone** (explicitly
prohibited this batch). Evidence gathered, each one an actual command
run during this batch, output captured:

| Check | Result | What it proves |
|---|---|---|
| DNS: `careerbuddy4u.com`, `www.careerbuddy4u.com` | Both resolve to `2.25.73.246` | A real host is actually deployed there (not just registered) |
| DNS: `api.careerbuddy4u.com` | No record | No separate API subdomain exists — the bare/www domain *is* the API host, not a placeholder guess |
| `HEAD https://careerbuddy4u.com/` | `200`, `Server: nginx/1.24.0 (Ubuntu)`, `Set-Cookie: csrftoken=...; SameSite=Lax; Secure`, `Strict-Transport-Security`, `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `Vary: Cookie` | The exact cookie name (`csrftoken`) and security-header set Django's own `SecurityMiddleware` emits when `DEBUG=False` — matching this project's own `settings.py` (`CSRF_COOKIE_SECURE`/`SESSION_COOKIE_SECURE`/`SECURE_SSL_REDIRECT`, all gated on `not DEBUG`) |
| `GET https://careerbuddy4u.com/` body | Contains "Career Buddy", "Riya"/"riya", "Aria"/"aria", "Ai_Robot", "Skill Up" | Distinctive branding/asset-name strings unique to *this* codebase (the ARIA/Riya chatbot's own asset filename, this app's exact feature naming) — not a generic or unrelated site |
| `GET https://careerbuddy4u.com/users/login/` | `200` | The exact real login route this app's own `AuthController`/team-context file already documents (`users.urls` mounted at `/users/`) |
| `GET https://careerbuddy4u.com/static/js/BOTscript.js` | `200` | ARIA's real, distinctive client-side script (confirmed by name during Batch 8's own deep investigation of `riya_bot`) is genuinely being served |
| `GET https://careerbuddy4u.com/activities/` | `302` | Matches the real `@login_required`-gated route's expected unauthenticated behavior |
| `GET https://careerbuddy4u.com/api/riya/chat/` | `405` | Matches the real `riya_chat` view's exact POST-only behavior, confirmed in Batch 8 — a very specific, deep-in-the-codebase behavioral match unlikely to be replicated by an unrelated site by coincidence |
| `GET https://careerbuddy4u.com/static/001%20Career%20Buddy/index.html` | `200` | Skill-Up's real static lesson content is genuinely present and unauthenticated, exactly as `SkillUpLessonScreen`'s real URL construction expects |
| `GET https://careerbuddy4u.com/ws/GD_app/1/` (plain HTTPS GET, not a real WS handshake) | `404`, Django's own minimal (`DEBUG=False`-style) error page, `Content-Length: 255` | The path is routed through to the same Django/ASGI application (not blocked or absent at the nginx/infra level) — a plain HTTP GET correctly 404s via Django's own URL resolver since that path is only registered on Channels' *websocket* protocol branch |
| TLS certificate | `subject=CN=careerbuddy4u.com`, `issuer=Let's Encrypt`, valid `Sep 29 2026 – Dec 28 2026` | A real, currently-valid, domain-specific certificate (issued the day before this verification), not a wildcard/generic/expired cert |

**Is it the Career Buddy Django backend specifically?** Yes — the
combination of the exact CSRF cookie name, the exact security-header
set matching this project's own `settings.py` logic, the exact login
route, the exact ARIA static asset, the exact Skill-Up static content
path, and the exact 405-on-GET behavior of a deep, specific, real view
(`riya_chat`) is conclusive: no unrelated site would coincidentally
match all of these.

**Does staging exist?** No separate staging host was found.
`api.careerbuddy4u.com` has no DNS record; no other subdomain was
discovered from any project evidence (`README.md`'s own "Deployment
Notes" section uses a literal `<domain>` placeholder for its webhook URL
example, confirming no other real host was ever documented anywhere in
this project). `Environment.staging` remains unconfigured and still
throws a clear, actionable error if selected.

No secret, cookie value, token, or credential is reproduced anywhere in
this document — only a freshly-issued CSRF token value was observed
transiently during verification and is not recorded here.

## ENVIRONMENT CONFIG

```text
dev:        http://10.0.2.2:8000 (Android emulator) /
            http://127.0.0.1:8000 (iOS simulator/macOS/other) — unchanged,
            still the current local Django dev-server convention.
staging:    UNCONFIGURED — throws a clear UnsupportedError
            ("Staging backend URL not configured...") if selected. No
            host was found to configure it to.
production: https://careerbuddy4u.com — CONFIGURED this batch, positively
            verified (see PRODUCTION HOST above).
```

`lib/app/config/environment.dart` is the one and only place this was
changed — no second configuration architecture was introduced, and every
backend destination in the app still derives from this same
`EnvironmentConfig.baseUrl` (re-confirmed by a full repeat source sweep
this batch — see PRODUCTION URL SWEEP below).

## PRODUCTION URL SWEEP

Repeated the full sweep from Batch 11 after wiring in the production
URL. Every backend-destination file is unchanged from Batch 11's own
inventory (`ApiClient`, `skill_up_lesson_url.dart`,
`resume_history_screen.dart`, `resume_builder_screen.dart`,
`gd_websocket_url.dart`/`gd_session_controller.dart`, plus `main.dart`
which only references `EnvironmentConfig` indirectly through
`ApiClient.create()`) — all still funnel through `EnvironmentConfig
.baseUrl`, nothing new bypasses it. The only two hardcoded URL literals
anywhere in `lib/` remain: `environment.dart`'s own `dev`/`production`
branches (both correctly scoped) and `country_codes.dart`'s
`flagcdn.com` (an unrelated, real, independent third-party CDN for
country-flag images, not a candidate for this backend's config).

## AUTHENTICATION

- **Session cookies**: verified this batch, live, against the real
  production host — a first unauthenticated request to
  `https://careerbuddy4u.com/` receives a real `Set-Cookie: csrftoken=...`
  with `Secure`/`SameSite=Lax`, exactly matching this app's own
  `ApiClient`/`CookieManager` expectations (and exactly matching the
  automated `test/core/network/api_client_test.dart` behavior verified
  in Batch 11 against a fake server).
- **CSRF handling**: the CSRF cookie mechanics (name, security
  attributes) are confirmed live and identical in shape to what
  `readCookie('csrftoken')`/the `X-CSRFToken` header pattern already
  used throughout this app expects.
- **Login verification status**: **NOT VERIFIED end-to-end.** `GET
  /users/login/` on the live host returns `200` (the real login page is
  reachable), but no actual `POST` login attempt was made — this project
  has no test/demo credentials anywhere (confirmed in `teamcontextfile
  .md`, unchanged since Batch 1), and inventing/guessing credentials to
  force a "successful login" result would be exactly the kind of
  fabrication this batch's rules explicitly prohibit. This is the one
  remaining verification this batch could not close — see REMAINING
  BLOCKERS.
- **Logout verification status**: not separately re-verified against the
  live host this batch (would require a real authenticated session
  first, per the same credentials gap above); the logout mechanics
  themselves (`clearCookies()` in a `finally` block) were already
  verified against a fake server in Batch 11 and are unchanged.
- **Session restoration**: unchanged, already covered by the
  pre-existing `auth_controller_test.dart` suite; not re-derived.

## WEBSOCKET

- **HTTP → ws**: unchanged, dev continues to use `ws://` — verified by
  the existing `buildGdWebSocketUri` tests (Batch 11).
- **HTTPS → wss**: `buildGdWebSocketUri(EnvironmentConfig.baseUrl,
  sessionId)` applied to the real, now-configured production URL
  produces `wss://careerbuddy4u.com/ws/GD_app/<id>/` — added a new,
  specific test this batch proving exactly this real case (not just a
  generic `https://` example), verified passing under
  `--dart-define=ENV=production`.
- **Session ID / path correctness**: unchanged, already covered.
- **Cookie/session handling**: `buildCookieHeader()`'s mechanics are
  unchanged and were verified against a fake server in Batch 11; a live
  WebSocket handshake against the production host was **not** attempted
  (would need a real authenticated session, which requires the same
  missing credentials noted under AUTHENTICATION). A plain HTTPS GET to
  the real WebSocket path (`/ws/GD_app/1/`) was made instead, as a
  non-invasive proxy check — it returned Django's own `404` (not an
  nginx-level one), confirming the path is genuinely routed to the same
  Django/ASGI application rather than blocked or absent at the
  infrastructure level.
- **No production `ws://` downgrade**: confirmed by the new test —
  `uri.scheme` is asserted to be exactly `wss`, never `ws`, for the real
  production host.

## WEBVIEW & DOWNLOADS

- **Skill-Up**: `EnvironmentConfig.baseUrl + /static/001%20Career%20
  Buddy/...` — the real static lesson content
  (`static/001%20Career%20Buddy/index.html`) was confirmed live and
  reachable (`200`, unauthenticated) on the verified production host.
- **Resume files / templates**: URL construction (`EnvironmentConfig
  .baseUrl` + the server's own returned path, or a known public static
  path) is unchanged and now correctly resolves against the real
  production host; the actual authenticated fetch was not live-tested
  (requires a real session — same credentials gap as above).
- **Certificates**: unchanged — downloaded through the authenticated Dio
  client first, then opened from a local file path, never a raw remote
  URL launch. Not live-tested for the same reason.
- No arbitrary external URL handling was introduced; the only 3
  `launchUrl` call sites in the app are unchanged from Batch 11's own
  inventory.

## SECURITY

```text
SAFE — no certificate bypass anywhere in lib/ (re-confirmed, unchanged).
SAFE — no secrets/API keys/passwords hardcoded in Flutter (re-confirmed;
       the live host's own response headers/cookies were inspected but
       never logged with real values reproduced in this report).
SAFE — no verbose network logging (LogInterceptor) anywhere (re-confirmed).
SAFE — no debug-only authentication bypass reachable in a release build
       (kDebugMode-gated Direct Demo Entry, compile-time eliminated,
       unchanged since Batch 5A).
SAFE — Environment.production now resolves to a real HTTPS host, not an
       accidental local address — verified both by direct assertion in
       `environment_test.dart` (asserting the host is never `localhost`/
       `127.0.0.1`/`10.0.2.2`) and by confirming the literal string
       `careerbuddy4u.com` is genuinely compiled into the release APK's
       AOT binary (`libapp.so`) when built with
       `--dart-define=ENV=production` — not merely assumed from the
       build succeeding.
```

## BUILD

```text
flutter analyze                                            → No issues found.
flutter test                                                → 1544/1544 passing
  (+ test/app/config/environment_test.dart independently re-run under
    --dart-define=ENV=staging and --dart-define=ENV=production, both
    passing — see ENVIRONMENT CONFIG above)
flutter build apk --release --dart-define=ENV=production    → SUCCESS
  build/app/outputs/flutter-apk/app-release.apk (68.9MB)
flutter build appbundle --release --dart-define=ENV=production → SUCCESS
  build/app/outputs/bundle/release/app-release.aab (68.3MB)
flutter build ios --no-codesign --dart-define=ENV=production → SUCCESS
  build/ios/iphoneos/Runner.app (28.7MB)
```

One pre-existing, non-blocking warning on every build (`flutter_tts`'s
Kotlin Gradle Plugin / Swift Package Manager deprecation notices,
unchanged since Batches 9-11).

## DJANGO

```text
Django changes:    NONE
Database changes:  NONE
Migrations:        NONE
Seed data:         NONE
API changes:       NONE
```

`git status --short` in `Career_Buddy_LMS/` shows only the same
pre-existing baseline diff present since Batch 6 — independently
re-confirmed via file modification timestamps to still predate this
batch's work by over a week (Sep 21-22, vs. this batch's work on Sep
30). Every live-host check this batch performed (`curl`/`dig`/`openssl
s_client`) was a read-only, non-destructive request against the
**deployed, remote** production server — none of it touches, and could
not touch, the local Django source tree at all.

## REMAINING BLOCKERS

Only one genuine blocker remains, and it is external, not a code defect:

1. **No test/demo credentials exist to verify the full live login →
   authenticated-session flow end-to-end** (dashboard, activities,
   resume upload, employer portal, etc. against the real production
   host). The login page itself, CSRF mechanics, and every URL
   construction are verified; the actual "enter valid credentials, reach
   the dashboard" path has never been observed against either the dev
   or the production backend, in this project's entire history — this
   is not new to this batch. **Exact next action**: the backend/
   deployment owner (or project owner) provides one real, valid set of
   student credentials (and, separately, employer credentials if that
   flow needs the same live check) so this final path can be exercised
   once, without fabricating a result in its place.

Everything else this batch's scope covered — production host
verification, environment configuration, the full URL sweep, WebSocket
scheme correctness, WebView/download URL correctness, the security
sweep, and the full build matrix — is resolved.
